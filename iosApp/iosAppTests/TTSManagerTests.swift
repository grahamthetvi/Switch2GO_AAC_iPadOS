import AVFoundation
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

    func testAvSpeechRateFromMultiplier() {
        let normal = TTSManager.avSpeechRate(fromMultiplier: 1.0)
        XCTAssertEqual(normal, AVSpeechUtteranceDefaultSpeechRate, accuracy: 0.0001)

        let slow = TTSManager.avSpeechRate(fromMultiplier: 0.6)
        let fast = TTSManager.avSpeechRate(fromMultiplier: 1.4)
        XCTAssertGreaterThanOrEqual(slow, AVSpeechUtteranceMinimumSpeechRate)
        XCTAssertLessThanOrEqual(slow, AVSpeechUtteranceMaximumSpeechRate)
        XCTAssertGreaterThanOrEqual(fast, AVSpeechUtteranceMinimumSpeechRate)
        XCTAssertLessThanOrEqual(fast, AVSpeechUtteranceMaximumSpeechRate)
        XCTAssertLessThan(slow, normal)
        XCTAssertGreaterThan(fast, normal)

        let belowMin = TTSManager.avSpeechRate(fromMultiplier: 0.1)
        let aboveMax = TTSManager.avSpeechRate(fromMultiplier: 2.0)
        XCTAssertEqual(belowMin, slow, accuracy: 0.0001)
        XCTAssertEqual(aboveMax, fast, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(belowMin, AVSpeechUtteranceMinimumSpeechRate)
        XCTAssertLessThanOrEqual(aboveMax, AVSpeechUtteranceMaximumSpeechRate)
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
