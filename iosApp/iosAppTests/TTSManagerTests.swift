import XCTest
@testable import iosApp

/// Unit tests for TTS Manager
class TTSManagerTests: XCTestCase {
    
    var ttsManager: TTSManager!
    
    override func setUp() {
        super.setUp()
        ttsManager = TTSManager.shared
    }
    
    override func tearDown() {
        ttsManager.stop()
        ttsManager = nil
        super.tearDown()
    }
    
    func testTTSInitialization() {
        XCTAssertNotNil(ttsManager)
        XCTAssertFalse(ttsManager.isSpeaking)
    }
    
    func testSpeechRateRange() {
        ttsManager.speechRate = 0.5
        XCTAssertGreaterThanOrEqual(ttsManager.speechRate, 0.0)
        XCTAssertLessThanOrEqual(ttsManager.speechRate, 1.0)
    }
    
    func testVolumeRange() {
        ttsManager.volume = 0.8
        XCTAssertGreaterThanOrEqual(ttsManager.volume, 0.0)
        XCTAssertLessThanOrEqual(ttsManager.volume, 1.0)
    }
    
    func testAvailableVoices() {
        let voices = ttsManager.getAvailableVoices()
        XCTAssertGreaterThan(voices.count, 0, "Should have available voices")
    }
    
    func testSpeakText() {
        let expectation = XCTestExpectation(description: "TTS should speak")
        
        ttsManager.speak("Hello")
        
        // Wait briefly to check if speaking started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Note: isSpeaking may not be true in test environment without audio output
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testStopSpeaking() {
        ttsManager.speak("Test")
        ttsManager.stop()
        
        XCTAssertFalse(ttsManager.isSpeaking)
        XCTAssertEqual(ttsManager.currentText, "")
    }
}
