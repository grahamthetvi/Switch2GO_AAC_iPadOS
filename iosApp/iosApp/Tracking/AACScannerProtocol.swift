import Foundation

/// BLE packet codec for the AAC Scanner companion firmware.
/// UUIDs and layout match Switch2GO_AAC_Companion/README.md. No CoreBluetooth.
enum AACScannerProtocol {
    static let deviceName = "AAC Scanner"
    static let serviceUUIDString = "A5C00001-7D2B-4F6E-9C31-5B8E2A1D0C4F"
    static let configUUIDString = "A5C00002-7D2B-4F6E-9C31-5B8E2A1D0C4F"
    static let statusUUIDString = "A5C00003-7D2B-4F6E-9C31-5B8E2A1D0C4F"
    static let commandUUIDString = "A5C00004-7D2B-4F6E-9C31-5B8E2A1D0C4F"
    static let hidServiceUUIDString = "1812"

    static let configLength = 29
    static let statusLength = 5
    static let configVersion: UInt8 = 1
    static let optionCount = 4
    static let flagSendEnter: UInt8 = 0x01
    static let flagKeyPhysical: UInt8 = 0x02

    struct OptionConfig: Equatable {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var brightness: UInt8
        var mode: UInt8
    }

    struct Config: Equatable {
        var numChoices: UInt8
        var scanTenths: UInt16
        var holdTenths: UInt16
        var longPressMs: UInt16
        var flags: UInt8
        var options: [OptionConfig]
    }

    enum ScanState: UInt8, Equatable {
        case scanning = 0
        case holding = 1
        case selecting = 2
        case paused = 3

        var displayName: String {
            switch self {
            case .scanning: return "Scanning"
            case .holding: return "Holding"
            case .selecting: return "Selecting"
            case .paused: return "Paused"
            }
        }
    }

    struct Status: Equatable {
        var state: ScanState
        var choice: UInt8
        var primaryPosition: UInt8
        var keyboardConnected: Bool
        var holdSecondsLeft: UInt8
    }

    static func isScannerPeripheral(name: String?, advertisedServiceUUIDStrings: [String] = []) -> Bool {
        if let name, name == deviceName || name.hasPrefix(deviceName) {
            return true
        }
        return advertisedServiceUUIDStrings.contains { uuid in
            uuid.caseInsensitiveCompare(serviceUUIDString) == .orderedSame
        }
    }

    static func decodeConfig(_ data: Data) -> Config? {
        guard data.count == configLength, data[0] == configVersion else { return nil }
        let numChoices = data[1]
        guard numChoices >= 1, numChoices <= 4 else { return nil }

        var options: [OptionConfig] = []
        options.reserveCapacity(optionCount)
        for i in 0..<optionCount {
            let base = 9 + i * 5
            let mode = data[base + 4] == 1 ? UInt8(1) : UInt8(0)
            options.append(
                OptionConfig(
                    r: data[base],
                    g: data[base + 1],
                    b: data[base + 2],
                    brightness: data[base + 3],
                    mode: mode
                )
            )
        }

        return Config(
            numChoices: numChoices,
            scanTenths: u16LE(data, 2),
            holdTenths: u16LE(data, 4),
            longPressMs: u16LE(data, 6),
            flags: data[8] & (flagSendEnter | flagKeyPhysical),
            options: options
        )
    }

    static func encodeConfig(_ config: Config) -> Data? {
        guard config.numChoices >= 1, config.numChoices <= 4, config.options.count == optionCount else {
            return nil
        }
        var bytes = [UInt8](repeating: 0, count: configLength)
        bytes[0] = configVersion
        bytes[1] = config.numChoices
        writeU16LE(&bytes, 2, config.scanTenths)
        writeU16LE(&bytes, 4, config.holdTenths)
        writeU16LE(&bytes, 6, config.longPressMs)
        bytes[8] = config.flags & (flagSendEnter | flagKeyPhysical)
        for i in 0..<optionCount {
            let base = 9 + i * 5
            let option = config.options[i]
            bytes[base] = option.r
            bytes[base + 1] = option.g
            bytes[base + 2] = option.b
            bytes[base + 3] = option.brightness
            bytes[base + 4] = option.mode == 1 ? 1 : 0
        }
        return Data(bytes)
    }

    /// Changes only `numChoices` (byte 1). Leaves the other 28 bytes untouched.
    static func replacingNumChoices(in data: Data, with count: UInt8) -> Data? {
        guard data.count == configLength, data[0] == configVersion else { return nil }
        guard count >= 1, count <= 4 else { return nil }
        var updated = data
        updated[1] = count
        return updated
    }

    static func decodeStatus(_ data: Data) -> Status? {
        guard data.count == statusLength else { return nil }
        guard let state = ScanState(rawValue: data[0]) else { return nil }
        return Status(
            state: state,
            choice: data[1],
            primaryPosition: data[2],
            keyboardConnected: data[3] != 0,
            holdSecondsLeft: data[4]
        )
    }

    static func highlightButtonId(
        choice: UInt8,
        state: ScanState,
        phraseButtonIds: [String]
    ) -> String? {
        if state == .paused || choice == 0 { return nil }
        let index = Int(choice) - 1
        guard phraseButtonIds.indices.contains(index) else { return nil }
        return phraseButtonIds[index]
    }

    private static func u16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func writeU16LE(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt16) {
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8(value >> 8)
    }
}
