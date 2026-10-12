import Foundation
import CoreBluetooth
import Combine

/// GATT client for AAC Scanner. HID keys still arrive through SwitchControlManager.
/// iOS often hides a paired keyboard from a scan, so this prefers
/// `retrieveConnectedPeripherals` with the scanner service and HID 1812.
final class AACScannerManager: NSObject, ObservableObject {

    static let serviceUUID = CBUUID(string: AACScannerProtocol.serviceUUIDString)
    static let configUUID = CBUUID(string: AACScannerProtocol.configUUIDString)
    static let statusUUID = CBUUID(string: AACScannerProtocol.statusUUIDString)
    static let hidServiceUUID = CBUUID(string: AACScannerProtocol.hidServiceUUIDString)
    static let scanDuration: TimeInterval = 15

    enum ConnectionState: Equatable {
        case idle
        case bluetoothOff
        case scanning
        case connecting
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

    var isReady: Bool { state == .ready }

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var configCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var lastConfigData: Data?
    private var desiredChoiceCount: UInt8 = 2
    private var scanTimeoutWork: DispatchWorkItem?
    private var wantsScan = false

    static func isScannerPeripheral(name: String?, advertisedServiceUUIDs: [CBUUID] = []) -> Bool {
        AACScannerProtocol.isScannerPeripheral(
            name: name,
            advertisedServiceUUIDStrings: advertisedServiceUUIDs.map(\.uuidString)
        )
    }

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

    func stopListening() {
        wantsScan = false
        stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection(forgetUUID: false)
        isDrivingHighlight = false
        lastStatus = nil
        state = .idle
    }

    func disconnect() {
        wantsScan = false
        stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        clearConnection(forgetUUID: true)
        AppSettings.shared.scannerPeripheralUUID = nil
        isDrivingHighlight = false
        lastStatus = nil
        state = .idle
        DebugLog.info("AAC Scanner disconnected", tag: "Scanner")
    }

    func syncChoiceCount(_ count: Int) {
        desiredChoiceCount = UInt8(min(max(count, 1), 4))
        writeChoiceCountIfNeeded()
    }

    // MARK: - Connection

    private func connectToKnownOrScan() {
        guard let central, central.state == .poweredOn else { return }

        if let peripheral, peripheral.state == .connected, statusCharacteristic != nil {
            state = .ready
            return
        }

        let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID, Self.hidServiceUUID])
            .filter { Self.isScannerPeripheral(name: $0.name) }
        if let match = connected.first {
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

        beginScan()
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

    private func attach(_ peripheral: CBPeripheral) {
        stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        connectedDeviceName = peripheral.name
        AppSettings.shared.scannerPeripheralUUID = peripheral.identifier.uuidString
        state = .connecting
        if peripheral.state == .connected {
            peripheral.discoverServices([Self.serviceUUID])
        } else {
            central?.connect(peripheral, options: nil)
        }
    }

    private func clearConnection(forgetUUID: Bool) {
        peripheral?.delegate = nil
        peripheral = nil
        configCharacteristic = nil
        statusCharacteristic = nil
        lastConfigData = nil
        connectedDeviceName = nil
        if forgetUUID {
            AppSettings.shared.scannerPeripheralUUID = nil
        }
    }

    private func writeChoiceCountIfNeeded() {
        guard state == .ready,
              let lastConfigData,
              let updated = AACScannerProtocol.replacingNumChoices(in: lastConfigData, with: desiredChoiceCount),
              updated != lastConfigData else {
            return
        }
        writeConfig(updated)
    }

    private func writeConfig(_ data: Data) {
        guard let peripheral, let configCharacteristic else { return }
        let writeType: CBCharacteristicWriteType =
            configCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: configCharacteristic, type: writeType)
        lastConfigData = data
        DebugLog.info("Wrote AAC Scanner numChoices=\(desiredChoiceCount)", tag: "Scanner")
    }
}

// MARK: - CBCentralManagerDelegate

extension AACScannerManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantsScan || AppSettings.shared.scannerPeripheralUUID != nil {
                connectToKnownOrScan()
            } else {
                state = .idle
            }
        case .poweredOff:
            stopScan()
            clearConnection(forgetUUID: false)
            isDrivingHighlight = false
            lastStatus = nil
            state = .bluetoothOff
        case .unauthorized:
            stopScan()
            clearConnection(forgetUUID: false)
            isDrivingHighlight = false
            lastStatus = nil
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
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "Could not connect to AAC Scanner."
        DebugLog.warn("Connect failed: \(message)", tag: "Scanner")
        clearConnection(forgetUUID: false)
        isDrivingHighlight = false
        lastStatus = nil
        state = .failed(message)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DebugLog.info("Disconnected from \(peripheral.name ?? AACScannerProtocol.deviceName)", tag: "Scanner")
        let shouldReconnect = wantsScan || AppSettings.shared.scannerPeripheralUUID != nil
        clearConnection(forgetUUID: false)
        isDrivingHighlight = false
        lastStatus = nil
        state = .idle
        if shouldReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connectToKnownOrScan()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension AACScannerManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            DebugLog.warn("Service discovery failed: \(error.localizedDescription)", tag: "Scanner")
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
                state = .failed("Paired device is not AAC Scanner.")
            }
            return
        }
        peripheral.discoverCharacteristics([Self.configUUID, Self.statusUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            DebugLog.warn("Characteristic discovery failed: \(error.localizedDescription)", tag: "Scanner")
            state = .failed(error.localizedDescription)
            return
        }
        configCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.configUUID })
        statusCharacteristic = service.characteristics?.first(where: { $0.uuid == Self.statusUUID })
        guard configCharacteristic != nil, let statusCharacteristic else {
            state = .failed("AAC Scanner GATT characteristics missing.")
            return
        }
        if let configCharacteristic {
            peripheral.readValue(for: configCharacteristic)
        }
        peripheral.setNotifyValue(true, for: statusCharacteristic)
        peripheral.readValue(for: statusCharacteristic)
        state = .ready
        isDrivingHighlight = true
        connectedDeviceName = peripheral.name ?? AACScannerProtocol.deviceName
        DebugLog.info("AAC Scanner GATT ready", tag: "Scanner")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            DebugLog.warn("Characteristic read failed: \(error.localizedDescription)", tag: "Scanner")
            return
        }
        guard let value = characteristic.value else { return }
        if characteristic.uuid == Self.configUUID {
            lastConfigData = value
            if AACScannerProtocol.decodeConfig(value) == nil {
                DebugLog.warn("AAC Scanner config rejected (len=\(value.count))", tag: "Scanner")
                return
            }
            writeChoiceCountIfNeeded()
        } else if characteristic.uuid == Self.statusUUID {
            guard let status = AACScannerProtocol.decodeStatus(value) else {
                DebugLog.warn("AAC Scanner status rejected (len=\(value.count))", tag: "Scanner")
                return
            }
            lastStatus = status
            isDrivingHighlight = true
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            DebugLog.warn("AAC Scanner config write failed: \(error.localizedDescription)", tag: "Scanner")
        }
    }
}
