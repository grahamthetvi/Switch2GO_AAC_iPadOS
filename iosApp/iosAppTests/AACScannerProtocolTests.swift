import XCTest
@testable import iosApp

final class AACScannerProtocolTests: XCTestCase {
    func testConfigRoundTripPreservesAllFields() throws {
        let original = AACScannerProtocol.Config(
            numChoices: 3,
            scanTenths: 20,
            holdTenths: 300,
            longPressMs: 1000,
            flags: AACScannerProtocol.flagSendEnter,
            options: [
                .init(r: 255, g: 0, b: 0, brightness: 80, mode: 0),
                .init(r: 0, g: 255, b: 0, brightness: 90, mode: 1),
                .init(r: 0, g: 0, b: 255, brightness: 100, mode: 0),
                .init(r: 255, g: 255, b: 255, brightness: 40, mode: 1),
            ]
        )
        let encoded = try XCTUnwrap(AACScannerProtocol.encodeConfig(original))
        XCTAssertEqual(encoded.count, 29)
        XCTAssertEqual(encoded[0], 1)
        let decoded = try XCTUnwrap(AACScannerProtocol.decodeConfig(encoded))
        XCTAssertEqual(decoded, original)
    }

    func testReplacingNumChoicesLeavesOtherBytesUntouched() throws {
        var bytes = [UInt8](repeating: 0xAB, count: 29)
        bytes[0] = 1
        bytes[1] = 4
        let original = Data(bytes)
        let updated = try XCTUnwrap(AACScannerProtocol.replacingNumChoices(in: original, with: 2))
        XCTAssertEqual(updated.count, 29)
        XCTAssertEqual(updated[1], 2)
        for index in 0..<29 where index != 1 {
            XCTAssertEqual(updated[index], original[index], "byte \(index) changed")
        }
    }

    func testDecodeStatusForAllStatesIncludingPausedChoiceZero() {
        let cases: [(UInt8, AACScannerProtocol.ScanState, UInt8)] = [
            (0, .scanning, 1),
            (1, .holding, 2),
            (2, .selecting, 3),
            (3, .paused, 0),
        ]
        for (stateByte, expectedState, choice) in cases {
            let status = AACScannerProtocol.decodeStatus(Data([stateByte, choice, 2, 1, 12]))
            XCTAssertEqual(status?.state, expectedState)
            XCTAssertEqual(status?.choice, choice)
            XCTAssertEqual(status?.primaryPosition, 2)
            XCTAssertEqual(status?.keyboardConnected, true)
            XCTAssertEqual(status?.holdSecondsLeft, 12)
        }
    }

    func testPausedHighlightIsCleared() {
        XCTAssertNil(
            AACScannerProtocol.highlightButtonId(
                choice: 0,
                state: .paused,
                phraseButtonIds: ["a", "b"]
            )
        )
    }

    func testScanningHighlightMapsChoiceToPhraseSlot() {
        XCTAssertEqual(
            AACScannerProtocol.highlightButtonId(
                choice: 2,
                state: .scanning,
                phraseButtonIds: ["left", "middle", "right"]
            ),
            "middle"
        )
    }

    func testScannerNameAndServiceUUIDAreDetected() {
        XCTAssertTrue(AACScannerProtocol.isScannerPeripheral(name: "AAC Scanner"))
        XCTAssertFalse(AACScannerProtocol.isScannerPeripheral(name: "Switch2GO-A1B2"))
        XCTAssertTrue(
            AACScannerProtocol.isScannerPeripheral(
                name: nil,
                advertisedServiceUUIDStrings: [AACScannerProtocol.serviceUUIDString.lowercased()]
            )
        )
    }

    func testRejectsWrongConfigVersionOrLength() {
        XCTAssertNil(AACScannerProtocol.decodeConfig(Data([0x02] + [UInt8](repeating: 0, count: 28))))
        XCTAssertNil(AACScannerProtocol.decodeConfig(Data([1, 4])))
        XCTAssertNil(AACScannerProtocol.decodeStatus(Data([0, 1, 1])))
    }
}
