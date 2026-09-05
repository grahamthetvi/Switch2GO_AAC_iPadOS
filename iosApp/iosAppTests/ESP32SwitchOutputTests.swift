import XCTest
@testable import iosApp
import CoreBluetooth
import VocableShared

final class ESP32SwitchOutputTests: XCTestCase {
    func testPulsePayloadIsCommandByteOne() {
        XCTAssertEqual(ESP32SwitchOutputManager.pulsePayload, Data([0x01]))
        XCTAssertTrue(ESP32SwitchOutputManager.isPulseCommand(Data([0x01])))
        XCTAssertTrue(ESP32SwitchOutputManager.isPulseCommand(Data([UInt8(ascii: "P")])))
        XCTAssertFalse(ESP32SwitchOutputManager.isPulseCommand(Data()))
        XCTAssertFalse(ESP32SwitchOutputManager.isPulseCommand(Data([0x00])))
    }

    func testShouldSendPulseRequiresPhraseFlagAndReadyConnection() {
        XCTAssertTrue(ESP32SwitchOutputManager.shouldSendPulse(phraseEnabled: true, isOutputReady: true))
        XCTAssertFalse(ESP32SwitchOutputManager.shouldSendPulse(phraseEnabled: false, isOutputReady: true))
        XCTAssertFalse(ESP32SwitchOutputManager.shouldSendPulse(phraseEnabled: true, isOutputReady: false))
        XCTAssertFalse(ESP32SwitchOutputManager.shouldSendPulse(phraseEnabled: false, isOutputReady: false))
    }

    func testSwitch2GONamePrefixIsDetected() {
        XCTAssertTrue(ESP32SwitchOutputManager.isSwitch2GOPeripheral(name: "Switch2GO-A1B2"))
        XCTAssertFalse(ESP32SwitchOutputManager.isSwitch2GOPeripheral(name: "Magic Keyboard"))
        XCTAssertTrue(
            ESP32SwitchOutputManager.isSwitch2GOPeripheral(
                name: nil,
                advertisedServiceUUIDs: [ESP32SwitchOutputManager.serviceUUID]
            )
        )
    }

    func testLegacyStyleJSONOmitsSendSwitchOutput() throws {
        let decoded = try JSONDecoder().decode(PhraseStyleData.self, from: Data("{\"isBold\":true}".utf8))
        XCTAssertNil(decoded.sendSwitchOutput)
        XCTAssertTrue(decoded.isBold)
    }

    func testSendSwitchOutputRoundTripsInStyleJSON() throws {
        let original = PhraseStyleData(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil,
            mediaRef: nil,
            mediaType: nil,
            gameType: nil,
            sendSwitchOutput: true
        )
        let encoded = try JSONEncoder().encode(original)
        let json = String(data: encoded, encoding: .utf8)
        XCTAssertTrue(json?.contains("sendSwitchOutput") == true)
        let decoded = try JSONDecoder().decode(PhraseStyleData.self, from: encoded)
        XCTAssertEqual(decoded.sendSwitchOutput, true)
    }

    func testSendSwitchOutputSurvivesPhraseStyleAssociatedObjectRoundTrip() {
        let style = PhraseStyle()
        style.sendSwitchOutput = true
        let json = style.toJSONString()
        XCTAssertNotNil(json)
        XCTAssertTrue(json?.contains("sendSwitchOutput") == true)
        let restored = PhraseStyle.fromJSONString(json)
        XCTAssertEqual(restored?.sendSwitchOutput, true)

        let omitted = PhraseStyle.fromJSONString("{\"isBold\":false}")
        XCTAssertEqual(omitted?.sendSwitchOutput, false)
    }
}
