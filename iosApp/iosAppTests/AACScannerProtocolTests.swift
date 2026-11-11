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

    func testStatusAboveIPadChoiceCountFlagsMismatch() {
        XCTAssertTrue(AACScannerProtocol.statusShowsExtraChoices(statusChoice: 3, expectedChoices: 2))
        XCTAssertTrue(AACScannerProtocol.statusShowsExtraChoices(statusChoice: 4, expectedChoices: 3))
        XCTAssertFalse(AACScannerProtocol.statusShowsExtraChoices(statusChoice: 4, expectedChoices: 4))
        XCTAssertFalse(AACScannerProtocol.statusShowsExtraChoices(statusChoice: 2, expectedChoices: 4))
        // Paused reports choice 0.
        XCTAssertFalse(AACScannerProtocol.statusShowsExtraChoices(statusChoice: 0, expectedChoices: 1))
    }

    func testThreeAndFourChoiceHighlightsMapInOrder() {
        let ids = ["p1", "p2", "p3", "p4"]
        for choice in 1...4 {
            XCTAssertEqual(
                AACScannerProtocol.highlightButtonId(choice: UInt8(choice), state: .scanning, phraseButtonIds: ids),
                ids[choice - 1]
            )
        }
        XCTAssertNil(
            AACScannerProtocol.highlightButtonId(choice: 4, state: .scanning, phraseButtonIds: Array(ids.prefix(3)))
        )
    }

    func testReconnectBackoffIsBounded() {
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: 0), 1)
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: 1), 2)
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: 3), 8)
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: 4), 10)
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: 50), 10)
        XCTAssertEqual(AACScannerManager.reconnectDelay(attempt: -1), 1)
    }

    func testReplacingNumChoicesSupportsThreeAndFour() throws {
        let config = AACScannerProtocol.Config(
            numChoices: 2,
            scanTenths: 20,
            holdTenths: 300,
            longPressMs: 1000,
            flags: AACScannerProtocol.flagSendEnter,
            options: Array(
                repeating: AACScannerProtocol.OptionConfig(r: 255, g: 255, b: 255, brightness: 255, mode: 0),
                count: AACScannerProtocol.optionCount
            )
        )
        let data = try XCTUnwrap(AACScannerProtocol.encodeConfig(config))
        for count: UInt8 in [3, 4] {
            let updated = try XCTUnwrap(AACScannerProtocol.replacingNumChoices(in: data, with: count))
            XCTAssertEqual(AACScannerProtocol.decodeConfig(updated)?.numChoices, count)
        }
        XCTAssertNil(AACScannerProtocol.replacingNumChoices(in: data, with: 5))
    }
}
