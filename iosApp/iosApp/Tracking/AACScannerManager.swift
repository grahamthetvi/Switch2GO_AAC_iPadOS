import Foundation
import CoreBluetooth
import Combine
import GameController

/// GATT client for AAC Scanner. HID keys still arrive through SwitchControlManager.
/// iOS often hides a paired keyboard from a scan, so this prefers
/// `retrieveConnectedPeripherals` with the scanner service and HID 1812.
final class AACScannerManager: NSObject, ObservableObject {

    static let serviceUUID = CBUUID(string: AACScannerProtocol.serviceUUIDString)
    static let configUUID = CBUUID(string: AACScannerProtocol.configUUIDString)
    static let statusUUID = CBUUID(string: AACScannerProtocol.statusUUIDString)
    static let hidServiceUUID = CBUUID(string: AACScannerProtocol.hidServiceUUIDString)
    static let scanDuration: TimeInterval = 15
    /// After this long in `.connecting`, the status text changes to "waiting".
    /// The pending connect is kept so the board connects as soon as it powers on.
    static let connectWaitNotice: TimeInterval = 10
    static let maxConfigWriteAttempts = 3
    static let configResyncThrottle: TimeInterval = 5

    /// Backoff for automatic reconnects: 1, 2, 4, 8, then 10 s.
    static func reconnectDelay(attempt: Int) -> TimeInterval {
        let exponent = min(max(attempt, 0), 4)
        return min(pow(2.0, Double(exponent)), 10)
    }

    enum ConnectionState: Equatable {
        case idle
        case bluetoothOff
        case scanning
        case connecting
        case waiting
        case ready
        case failed(String)

        var statusText: String {
            switch self {
            case .idle:
                return "Not connected"
            case .bluetoothOff:
                return "Bluetooth is off"
            case .scanning:
                return "Looking for AAC Scanner…"
            case .connecting:
                return "Connecting…"
            case .waiting:
                return "Waiting for AAC Scanner. Turn it on; it connects by itself."
            case .ready:
                return "Connected"
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var lastStatus: AACScannerProtocol.Status?
    @Published private(set) var isDrivingHighlight = false
    /// True when the AAC Scanner is connected to iPadOS as a keyboard, even if the
    /// GATT status link is not up. Its keys 1–N are then choice numbers.
    @Published private(set) var isKeyboardLinked = false
    /// Number of choices the board reports in its config (nil until read).
    @Published private(set) var boardChoiceCount: Int?
    /// True after the iPad gave up writing the choice count to the board.
    @Published private(set) var choiceSyncFailed = false

    var isReady: Bool { state == .ready }

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var configCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var lastConfigData: Data?
    private var desiredChoiceCount: UInt8 = 2
    private var scanTimeoutWork: DispatchWorkItem?
    private var connectWaitWork: DispatchWorkItem?
    private var reconnectWork: DispatchWorkItem?
    private var reconnectAttempt = 0
    private var wantsScan = false
    private var configWriteAttempts = 0
    private var isConfigWriteInFlight = false
    private var lastConfigResyncRequest: TimeInterval = 0
    private var keyboardObserversInstalled = false
    private var statusNotifyRetried = false

    static func isScannerPeripheral(name: String?, advertisedServiceUUIDs: [CBUUID] = []) -> Bool {
        AACScannerProtocol.isScannerPeripheral(
            name: name,
            advertisedServiceUUIDStrings: advertisedServiceUUIDs.map(\.uuidString)
        )
    }

    func start() {
        installKeyboardObservers()
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        wantsScan = true
        reconnectAttempt = 0
        configWriteAttempts = 0
        choiceSyncFailed = false
        guard let central else {
            start()
            return
        }
        guard central.state == .poweredOn else {
            state = central.state == .poweredOff ? .bluetoothOff : .idle
            return
        }
        connectToKnownOrScan()
    }

    func stopListening() {
        wantsScan = false
        cancelTimers()
        stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection(forgetUUID: false)
        isDrivingHighlight = false
        lastStatus = nil
        isKeyboardLinked = false
        state = .idle
    }

    func disconnect() {
        wantsScan = false
        cancelTimers()
        stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection(forgetUUID: true)
        AppSettings.shared.scannerPeripheralUUID = nil
        isDrivingHighlight = false
        lastStatus = nil
        isKeyboardLinked = false
        state = .idle
        DebugLog.info("AAC Scanner disconnected", tag: "Scanner")
    }

    func syncChoiceCount(_ count: Int) {
        let clamped = UInt8(min(max(count, 1), 4))
        if clamped != desiredChoiceCount {
            configWriteAttempts = 0
            choiceSyncFailed = false
        }
        desiredChoiceCount = clamped
        writeChoiceCountIfNeeded()
    }

    /// Re-checks whether iPadOS has the AAC Scanner connected as a keyboard.
    func refreshKeyboardLink() {
        guard let central, central.state == .poweredOn else {
            setKeyboardLinked(false)
            return
        }
        let savedUUID = AppSettings.shared.scannerPeripheralUUID
        let linked = central
            .retrieveConnectedPeripherals(withServices: [Self.serviceUUID, Self.hidServiceUUID])
            .contains { candidate in
                Self.isScannerPeripheral(name: candidate.name)
                    || (savedUUID != nil && candidate.identifier.uuidString == savedUUID)
            }
        setKeyboardLinked(linked || (state == .ready && lastStatus?.keyboardConnected == true))
    }

    private func setKeyboardLinked(_ linked: Bool) {
        guard linked != isKeyboardLinked else { return }
        isKeyboardLinked = linked
        DebugLog.info("AAC Scanner keyboard \(linked ? "linked" : "not linked")", tag: "Scanner")
    }

    private func installKeyboardObservers() {
        guard !keyboardObserversInstalled else { return }
        keyboardObserversInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardConnectionChanged(_:)),
            name: .GCKeyboardDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardConnectionChanged(_:)),
            name: .GCKeyboardDidDisconnect,
            object: nil
        )
    }

    @objc private func keyboardConnectionChanged(_ notification: Notification) {
        // Core Bluetooth can lag the GameController notification slightly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.refreshKeyboardLink()
            if self.wantsScan, self.isKeyboardLinked, !self.isReady,
               self.state != .connecting, self.state != .scanning {
                self.connectToKnownOrScan()
            }
        }
    }

    // MARK: - Connection

    private func connectToKnownOrScan() {
        guard let central, central.state == .poweredOn else { return }
        reconnectWork?.cancel()
        reconnectWork = nil

        if let peripheral, peripheral.state == .connected, statusCharacteristic != nil {
            state = .ready
            return
        }

        let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID, Self.hidServiceUUID])
            .filter { Self.isScannerPeripheral(name: $0.name) }
        if let match = connected.first {
            setKeyboardLinked(true)
            attach(match)
            return
        }

        if let uuidString = AppSettings.shared.scannerPeripheralUUID,
           let uuid = UUID(uuidString: uuidString) {
            let remembered = central.retrievePeripherals(withIdentifiers: [uuid])
            if let match = remembered.first {
                attach(match)
                return
            }
        }

        if wantsScan {
            beginScan()
        } else {
            state = .idle
        }
    }

    private func beginScan() {
        guard let central, central.state == .poweredOn else { return }
        stopScan()
        state = .scanning
        connectedDeviceName = nil
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .scanning else { return }
            self.stopScan()
            self.state = .failed("No AAC Scanner found. Pair AAC Scanner in iPad Settings → Bluetooth, then tap Connect.")
        }
        scanTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanDuration, execute: work)
        DebugLog.info("Scanning for AAC Scanner", tag: "Scanner")
    }

    private func stopScan() {
        scanTimeoutWork?.cancel()
        scanTimeoutWork = nil
        central?.stopScan()
    }

    private func cancelTimers() {
        connectWaitWork?.cancel()
        connectWaitWork = nil
        reconnectWork?.cancel()
        reconnectWork = nil
    }

    private func attach(_ peripheral: CBPeripheral) {
        stopScan()
        if let current = self.peripheral, current.identifier != peripheral.identifier {
            central?.cancelPeripheralConnection(current)
            clearConnection(forgetUUID: false)
        }
        self.peripheral = peripheral
        peripheral.delegate = self
        connectedDeviceName = peripheral.name
        AppSettings.shared.scannerPeripheralUUID = peripheral.identifier.uuidString
        state = .connecting
        armConnectWaitNotice()
        if peripheral.state == .connected {
            peripheral.discoverServices([Self.serviceUUID])
        } else {
            // No timeout on purpose: iOS keeps this pending and connects when the
            // board powers on, which is what a classroom setup needs.
            central?.connect(peripheral, options: nil)
        }
    }

    private func armConnectWaitNotice() {
        connectWaitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .connecting else { return }
            self.state = .waiting
            DebugLog.info("AAC Scanner not answering yet; connect stays pending", tag: "Scanner")
        }
        connectWaitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectWaitNotice, execute: work)
    }

    private func scheduleReconnect(reason: String) {
        // Only while switch input is on; stopListening/disconnect clear wantsScan.
        guard wantsScan else { return }
        reconnectWork?.cancel()
        let delay = Self.reconnectDelay(attempt: reconnectAttempt)
        reconnectAttempt += 1
        DebugLog.info("AAC Scanner reconnect in \(delay)s (\(reason))", tag: "Scanner")
        let work = DispatchWorkItem { [weak self] in
            self?.connectToKnownOrScan()
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func clearConnection(forgetUUID: Bool) {
        connectWaitWork?.cancel()
        connectWaitWork = nil
        peripheral?.delegate = nil
        peripheral = nil
        configCharacteristic = nil
        statusCharacteristic = nil
        lastConfigData = nil
        isConfigWriteInFlight = false
        boardChoiceCount = nil
        connectedDeviceName = nil
        if forgetUUID {
            AppSettings.shared.scannerPeripheralUUID = nil
        }
    }

    // MARK: - Choice count sync

    private func writeChoiceCountIfNeeded() {
        guard state == .ready,
              let lastConfigData,
              let updated = AACScannerProtocol.replacingNumChoices(in: lastConfigData, with: desiredChoiceCount) else {
            return
        }
        guard updated != lastConfigData else {
            // Board already matches the iPad.
            configWriteAttempts = 0
            choiceSyncFailed = false
            return
        }
        guard !isConfigWriteInFlight else { return }
        guard configWriteAttempts < Self.maxConfigWriteAttempts else {
            if !choiceSyncFailed {
                choiceSyncFailed = true
                let boardText = boardChoiceCount.map { String($0) } ?? "?"
                DebugLog.warn(
                    "AAC Scanner kept \(boardText) choices after \(Self.maxConfigWriteAttempts) writes of \(desiredChoiceCount)",
                    tag: "Scanner"
                )
            }
            return
        }
        writeConfig(updated)
    }

    private func writeConfig(_ data: Data) {
        guard let peripheral, let configCharacteristic else { return }
        configWriteAttempts += 1
        DebugLog.info(
            "Writing AAC Scanner numChoices=\(desiredChoiceCount) (attempt \(configWriteAttempts))",
            tag: "Scanner"
        )
        if configCharacteristic.properties.contains(.write) {
            // With response, so a failed write is reported and retried.
            isConfigWriteInFlight = true
            peripheral.writeValue(data, for: configCharacteristic, type: .withResponse)
        } else {
            peripheral.writeValue(data, for: configCharacteristic, type: .withoutResponse)
            readConfigBack(after: 0.5)
        }
    }

    /// Reads the config so `lastConfigData` reflects what the board really stored.
    private func readConfigBack(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let peripheral = self.peripheral, peripheral.state == .connected,
                  let configCharacteristic = self.configCharacteristic else { return }
            peripheral.readValue(for: configCharacteristic)
        }
    }

    private func requestConfigResyncIfNeeded(for status: AACScannerProtocol.Status) {
        guard AACScannerProtocol.statusShowsExtraChoices(
            statusChoice: status.choice,
            expectedChoices: desiredChoiceCount
        ) else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastConfigResyncRequest > Self.configResyncThrottle, !isConfigWriteInFlight else { return }
        lastConfigResyncRequest = now
        DebugLog.warn(
            "AAC Scanner is on choice \(status.choice) but the iPad shows \(desiredChoiceCount); re-reading config",
            tag: "Scanner"
        )
        readConfigBack(after: 0)
    }

    private func dropLink(_ message: String?) {
        clearConnection(forgetUUID: false)
        isDrivingHighlight = false
        lastStatus = nil
        if let message {
            state = .failed(message)
        } else {
            state = .idle
        }
        refreshKeyboardLink()
    }
}

// MARK: - CBCentralManagerDelegate

extension AACScannerManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            refreshKeyboardLink()
            if wantsScan {
                connectToKnownOrScan()
            } else {
                state = .idle
            }
        case .poweredOff:
            stopScan()
            cancelTimers()
            clearConnection(forgetUUID: false)
            isDrivingHighlight = false
            lastStatus = nil
            isKeyboardLinked = false
            state = .bluetoothOff
        case .resetting:
            stopScan()
            cancelTimers()
            clearConnection(forgetUUID: false)
            isDrivingHighlight = false
            lastStatus = nil
            state = .idle
        case .unauthorized:
            stopScan()
            cancelTimers()
            clearConnection(forgetUUID: false)
            isDrivingHighlight = false
            lastStatus = nil
            isKeyboardLinked = false
            state = .failed("Bluetooth permission is off for Switch2GO.")
        case .unsupported:
            state = .failed("This device does not support Bluetooth LE.")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertised = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        guard Self.isScannerPeripheral(name: name, advertisedServiceUUIDs: advertised) else { return }
        DebugLog.info("Found \(name ?? peripheral.identifier.uuidString)", tag: "Scanner")
        attach(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DebugLog.info("Connected to \(peripheral.name ?? AACScannerProtocol.deviceName)", tag: "Scanner")
        connectedDeviceName = peripheral.name
        AppSettings.shared.scannerPeripheralUUID = peripheral.identifier.uuidString
        if state == .waiting { state = .connecting }
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Could not connect to AAC Scanner."
        DebugLog.warn("Connect failed: \(message)", tag: "Scanner")
        dropLink(message)
        scheduleReconnect(reason: "connect failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? AACScannerProtocol.deviceName
        let detail = error.map { ": " + $0.localizedDescription } ?? ""
        DebugLog.info("Disconnected from \(name)\(detail)", tag: "Scanner")
        // Ignore a late callback for a peripheral we already replaced.
        if let current = self.peripheral, current.identifier != peripheral.identifier { return }
        dropLink(nil)
        scheduleReconnect(reason: "disconnected")
    }
}

// MARK: - CBPeripheralDelegate

extension AACScannerManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            DebugLog.warn("Service discovery failed: \(error.localizedDescription)", tag: "Scanner")
            // Drop the link; didDisconnect schedules a reconnect.
            central?.cancelPeripheralConnection(peripheral)
            state = .failed(error.localizedDescription)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            DebugLog.warn("Connected HID is not AAC Scanner (GATT service missing)", tag: "Scanner")
            central?.cancelPeripheralConnection(peripheral)
            clearConnection(forgetUUID: true)
            if wantsScan {
                beginScan()
            } else {
                state = .failed("Paired device is not AAC Scanner. If the firmware was updated, forget AAC Scanner in iPad Settings → Bluetooth and pair again.")
            }
            return
        }
        peripheral.discoverCharacteristics([Self.configUUID, Self.statusUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard invalidatedServices.contains(where: { $0.uuid == Self.serviceUUID }) else { return }
        DebugLog.info("AAC Scanner services changed; rediscovering", tag: "Scanner")
        configCharacteristic = nil
        statusCharacteristic = nil
        isConfigWriteInFlight = false
        state = .connecting
        peripheral.discoverServices([Self.serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            DebugLog.warn("Characteristic discovery failed: \(error.localizedDescription)", tag: "Scanner")
            central?.cancelPeripheralConnection(peripheral)
            state = .failed(error.localizedDescription)
            return
        }
        configCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.configUUID })
        statusCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.statusUUID })
        guard let configCharacteristic, let statusCharacteristic else {
            state = .failed("AAC Scanner GATT characteristics missing. Forget AAC Scanner in iPad Settings → Bluetooth and pair again.")
            return
        }
        connectWaitWork?.cancel()
        connectWaitWork = nil
        reconnectAttempt = 0
        statusNotifyRetried = false
        peripheral.readValue(for: configCharacteristic)
        peripheral.setNotifyValue(true, for: statusCharacteristic)
        peripheral.readValue(for: statusCharacteristic)
        state = .ready
        isDrivingHighlight = true
        connectedDeviceName = peripheral.name ?? AACScannerProtocol.deviceName
        refreshKeyboardLink()
        DebugLog.info("AAC Scanner GATT ready", tag: "Scanner")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.statusUUID else { return }
        if let error {
            DebugLog.warn("Status notify failed: \(error.localizedDescription)", tag: "Scanner")
            guard !statusNotifyRetried else { return }
            statusNotifyRetried = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, let current = self.peripheral, current === peripheral,
                      current.state == .connected else { return }
                current.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            DebugLog.warn("Characteristic read failed: \(error.localizedDescription)", tag: "Scanner")
            return
        }
        guard let value = characteristic.value else { return }
        if characteristic.uuid == Self.configUUID {
            guard let config = AACScannerProtocol.decodeConfig(value) else {
                DebugLog.warn("AAC Scanner config rejected (len=\(value.count))", tag: "Scanner")
                return
            }
            lastConfigData = value
            boardChoiceCount = Int(config.numChoices)
            writeChoiceCountIfNeeded()
        } else if characteristic.uuid == Self.statusUUID {
            guard let status = AACScannerProtocol.decodeStatus(value) else {
                DebugLog.warn("AAC Scanner status rejected (len=\(value.count))", tag: "Scanner")
                return
            }
            lastStatus = status
            if !isDrivingHighlight {
                isDrivingHighlight = true
            }
            if status.keyboardConnected, !isKeyboardLinked {
                setKeyboardLinked(true)
            }
            requestConfigResyncIfNeeded(for: status)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.configUUID else { return }
        isConfigWriteInFlight = false
        if let error {
            DebugLog.warn("AAC Scanner config write failed: \(error.localizedDescription)", tag: "Scanner")
            // Re-read; the read handler retries the write if attempts remain.
            readConfigBack(after: 0.5)
            return
        }
        // Confirm what the board stored rather than assuming the write landed.
        readConfigBack(after: 0.3)
    }
}
