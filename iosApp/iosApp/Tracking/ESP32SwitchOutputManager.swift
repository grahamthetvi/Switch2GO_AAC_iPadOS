import Foundation
import CoreBluetooth
import Combine
import QuartzCore

/// BLE write path: iPad phrase activation → ESP32 GPIO pulse → PowerLink.
///
/// This is independent of HID switch *input*. The ESP32 still appears as a
/// keyboard in iPad Settings; this manager talks to the extra GATT service
/// on that same firmware for environmental-control *output*.
final class ESP32SwitchOutputManager: NSObject, ObservableObject {

    static let serviceUUID = CBUUID(string: "8e7c0001-4f52-4c4e-9353-5332474f3031")
    static let characteristicUUID = CBUUID(string: "8e7c0002-4f52-4c4e-9353-5332474f3031")
    static let hidServiceUUID = CBUUID(string: "1812")
    static let pulseCommand: UInt8 = 0x01
    static let pulsePayload = Data([pulseCommand])
    static let clientPulseCooldown: TimeInterval = 0.25
    static let scanDuration: TimeInterval = 15
    static let deviceNamePrefix = "Switch2GO"

    enum ConnectionState: Equatable {
        case idle
        case bluetoothOff
        case scanning
        case connecting
        case ready
        case firmwareMissingOutput
        case failed(String)

        var statusText: String {
            switch self {
            case .idle:
                return "Not connected"
            case .bluetoothOff:
                return "Bluetooth is off"
            case .scanning:
                return "Scanning for Switch2GO…"
            case .connecting:
                return "Connecting…"
            case .ready:
                return "Ready to send switch output"
            case .firmwareMissingOutput:
                return "Connected, but this firmware has no PowerLink output. Reflash ESP32/Switch2GO_BLE_Switch, then Forget Device and pair again."
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var lastPulseTime: TimeInterval?

    var isReady: Bool { state == .ready }

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var outputCharacteristic: CBCharacteristic?
    private var scanTimeoutWork: DispatchWorkItem?
    private var lastPulseSentAt: TimeInterval = 0
    private var wantsScan = false

    // MARK: - Command helpers (unit-tested)

    static func isPulseCommand(_ data: Data) -> Bool {
        guard let byte = data.first else { return false }
        return byte == pulseCommand || byte == UInt8(ascii: "P") || byte == UInt8(ascii: "p") || byte == UInt8(ascii: "1")
    }

    static func shouldSendPulse(phraseEnabled: Bool, isOutputReady: Bool) -> Bool {
        phraseEnabled && isOutputReady
    }

    static func isSwitch2GOPeripheral(name: String?, advertisedServiceUUIDs: [CBUUID] = []) -> Bool {
        if let name, name.hasPrefix(deviceNamePrefix) { return true }
        return advertisedServiceUUIDs.contains(serviceUUID)
    }

    // MARK: - Lifecycle

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        wantsScan = true
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

    func disconnect() {
        stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection()
        AppSettings.shared.switchOutputPeripheralUUID = nil
        state = .idle
        DebugLog.info("ESP32 switch output disconnected", tag: "SwitchOut")
    }

    /// Send a PowerLink pulse if the GATT characteristic is ready.
    /// Overlapping calls within `clientPulseCooldown` are ignored.
    @discardableResult
    func sendPulse() -> Bool {
        guard state == .ready,
              let peripheral,
              let outputCharacteristic else {
            DebugLog.debug("Switch output pulse skipped — not ready (\(state.statusText))", tag: "SwitchOut")
            return false
        }

        let now = CACurrentMediaTime()
        if now - lastPulseSentAt < Self.clientPulseCooldown {
            DebugLog.debug("Switch output pulse ignored (client cooldown)", tag: "SwitchOut")
            return false
        }
        lastPulseSentAt = now

        let writeType: CBCharacteristicWriteType =
            outputCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(Self.pulsePayload, for: outputCharacteristic, type: writeType)
        lastPulseTime = now
        DebugLog.info("Sent switch-output pulse to \(peripheral.name ?? "ESP32")", tag: "SwitchOut")
        return true
    }

    // MARK: - Connection

    private func connectToKnownOrScan() {
        guard let central, central.state == .poweredOn else { return }

        if let peripheral, peripheral.state == .connected, outputCharacteristic != nil {
            state = .ready
            return
        }

        let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID, Self.hidServiceUUID])
            .filter { Self.isSwitch2GOPeripheral(name: $0.name) }
        if let match = connected.first {
            attach(match)
            return
        }

        if let uuidString = AppSettings.shared.switchOutputPeripheralUUID,
           let uuid = UUID(uuidString: uuidString) {
            let remembered = central.retrievePeripherals(withIdentifiers: [uuid])
            if let match = remembered.first {
                attach(match)
                return
            }
        }

        beginScan()
    }

    private func beginScan() {
        guard let central, central.state == .poweredOn else { return }
        stopScan()
        state = .scanning
        connectedDeviceName = nil
        // Scan without a UUID filter so HID-only advertisements still match by name.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .scanning else { return }
            self.stopScan()
            self.state = .failed("No Switch2GO found. Pair Switch2GO-XXXX in iPad Settings → Bluetooth, then tap Connect.")
        }
        scanTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanDuration, execute: work)
        DebugLog.info("Scanning for Switch2GO environmental-control service", tag: "SwitchOut")
    }

    private func stopScan() {
        scanTimeoutWork?.cancel()
        scanTimeoutWork = nil
        central?.stopScan()
    }

    private func attach(_ peripheral: CBPeripheral) {
        stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        connectedDeviceName = peripheral.name
        AppSettings.shared.switchOutputPeripheralUUID = peripheral.identifier.uuidString
        state = .connecting
        if peripheral.state == .connected {
            peripheral.discoverServices([Self.serviceUUID])
        } else {
            central?.connect(peripheral, options: nil)
        }
    }

    private func clearConnection() {
        peripheral?.delegate = nil
        peripheral = nil
        outputCharacteristic = nil
        connectedDeviceName = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension ESP32SwitchOutputManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantsScan || AppSettings.shared.switchOutputPeripheralUUID != nil {
                connectToKnownOrScan()
            } else {
                state = .idle
            }
        case .poweredOff:
            stopScan()
            clearConnection()
            state = .bluetoothOff
        case .unauthorized:
            stopScan()
            clearConnection()
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
        guard Self.isSwitch2GOPeripheral(name: name, advertisedServiceUUIDs: advertised) else { return }
        DebugLog.info("Found \(name ?? peripheral.identifier.uuidString)", tag: "SwitchOut")
        attach(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DebugLog.info("Connected to \(peripheral.name ?? "ESP32")", tag: "SwitchOut")
        connectedDeviceName = peripheral.name
        AppSettings.shared.switchOutputPeripheralUUID = peripheral.identifier.uuidString
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Could not connect to ESP32."
        DebugLog.warn("Connect failed: \(message)", tag: "SwitchOut")
        clearConnection()
        state = .failed(message)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DebugLog.info("Disconnected from \(peripheral.name ?? "ESP32")", tag: "SwitchOut")
        let shouldReconnect = outputCharacteristic != nil || AppSettings.shared.switchOutputPeripheralUUID != nil
        clearConnection()
        state = .idle
        if shouldReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connectToKnownOrScan()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension ESP32SwitchOutputManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            DebugLog.warn("Service discovery failed: \(error.localizedDescription)", tag: "SwitchOut")
            state = .failed(error.localizedDescription)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            state = .firmwareMissingOutput
            DebugLog.warn("HID connected but PowerLink GATT service missing", tag: "SwitchOut")
            return
        }
        peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            DebugLog.warn("Characteristic discovery failed: \(error.localizedDescription)", tag: "SwitchOut")
            state = .failed(error.localizedDescription)
            return
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else {
            state = .firmwareMissingOutput
            return
        }
        outputCharacteristic = characteristic
        state = .ready
        connectedDeviceName = peripheral.name ?? Self.deviceNamePrefix
        DebugLog.info("Switch output characteristic ready", tag: "SwitchOut")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            DebugLog.warn("Switch output write failed: \(error.localizedDescription)", tag: "SwitchOut")
        }
    }
}
