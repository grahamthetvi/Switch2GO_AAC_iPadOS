import XCTest
import AVFoundation
import Combine
import VocableShared
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

    func testRepeatedSpeakUpdatesCurrentTextWithoutDroppingState() {
        ttsManager.speak("First phrase")
        ttsManager.speak("First phrase")
        ttsManager.speak("Second phrase")

        XCTAssertTrue(ttsManager.isSpeaking)
        XCTAssertEqual(ttsManager.currentText, "Second phrase")
    }

    func testStaleDelegateCallbacksDoNotClobberActiveSpeech() {
        let staleUtterance = AVSpeechUtterance(string: "Stale")
        let dummySynthesizer = AVSpeechSynthesizer()

        ttsManager.speak("Active phrase")
        XCTAssertTrue(ttsManager.isSpeaking)
        XCTAssertEqual(ttsManager.currentText, "Active phrase")

        // Simulate a late didCancel and didFinish from a previously interrupted utterance
        ttsManager.speechSynthesizer(dummySynthesizer, didCancel: staleUtterance)
        ttsManager.speechSynthesizer(dummySynthesizer, didFinish: staleUtterance)

        let expectation = XCTestExpectation(description: "Main queue drains stale delegate callbacks")
        DispatchQueue.main.async {
            XCTAssertTrue(self.ttsManager.isSpeaking)
            XCTAssertEqual(self.ttsManager.currentText, "Active phrase")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testStartWatchdogPreservesSpeechAcrossSilentDropWindow() {
        // Interrupt an active utterance immediately with a second phrase and verify
        // that past the 0.35s start-watchdog window, isSpeaking and currentText
        // remain active (never dropped to idle).
        ttsManager.speak("Interrupted phrase")
        ttsManager.speak("Retried phrase")

        let expectation = XCTestExpectation(description: "Start watchdog window completes without dropping active speech")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertTrue(self.ttsManager.isSpeaking)
            XCTAssertEqual(self.ttsManager.currentText, "Retried phrase")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.2)
    }
}

// MARK: - Media Playback & Storage Reliability Tests

final class MediaPlaybackReliabilityTests: XCTestCase {
    private var savedDelay: Double = 2.5

    override func setUp() {
        super.setUp()
        savedDelay = AppSettings.shared.mediaPlaybackDelay
    }

    override func tearDown() {
        AppSettings.shared.mediaPlaybackDelay = savedDelay
        super.tearDown()
    }

    func testRepeatSelectionOfSameArmedPhraseStillTransitionsToPlaying() {
        AppSettings.shared.mediaPlaybackDelay = 0.20
        let coordinator = MediaPlaybackCoordinator()
        let style = PhraseStyle(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil,
            mediaRef: "file:///tmp/clip.m4a",
            mediaType: PhraseStyle.companion.MEDIA_TYPE_AUDIO,
            gameType: nil
        )
        let phrase = PhraseDisplayModel(
            id: "audio_phrase_1",
            text: "Play my song",
            sortOrder: 0,
            isPreset: false,
            style: style
        )

        // First selection arms playback
        coordinator.onPhraseSelected(phrase)
        XCTAssertEqual(coordinator.phase, .armed)

        // Simulate continuous repeat-dwell re-selections arriving every 70ms (faster than
        // mediaPlaybackDelay = 200ms). Re-selecting the same armed phrase must NOT reset or
        // starve the 200ms countdown.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            coordinator.onPhraseSelected(phrase)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            coordinator.onPhraseSelected(phrase)
        }

        let expectation = XCTestExpectation(description: "Coordinator transitions to .playing without starvation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            XCTAssertEqual(coordinator.phase, .playing)
            XCTAssertEqual(coordinator.activePhrase?.id, phrase.id)
            coordinator.stopEarly()
            XCTAssertEqual(coordinator.phase, .idle)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMediaStorageResolvesAcrossStaleContainerPath() throws {
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        guard let savedURL = MediaStorage.saveMedia(data: payload, extension: "m4a") else {
            XCTFail("Expected MediaStorage.saveMedia to succeed")
            return
        }
        defer { MediaStorage.deleteMedia(mediaRef: savedURL.absoluteString) }

        let fileName = savedURL.lastPathComponent
        let staleContainerRef = "file:///var/mobile/Containers/Data/Application/00000000-0000-0000-0000-000000000000/Documents/Media/\(fileName)"

        let resolved = MediaStorage.resolveURL(mediaRef: staleContainerRef)
        XCTAssertNotNil(resolved, "MediaStorage should resolve file in current Documents/Media when container UUIDChanges")
        XCTAssertEqual(resolved?.lastPathComponent, fileName)
    }
}

// MARK: - Dwell & Gaze Reliability Tests

final class DwellAndGazeReliabilityTests: XCTestCase {
    private var savedDwellTime: Double = 1.0
    private var savedRepeatEnabled: Bool = false
    private var savedRepeatDelay: Double = 2.0

    override func setUp() {
        super.setUp()
        savedDwellTime = AppSettings.shared.dwellTime
        savedRepeatEnabled = AppSettings.shared.enableRepeatDwell
        savedRepeatDelay = AppSettings.shared.repeatDwellDelay
    }

    override func tearDown() {
        AppSettings.shared.dwellTime = savedDwellTime
        AppSettings.shared.enableRepeatDwell = savedRepeatEnabled
        AppSettings.shared.repeatDwellDelay = savedRepeatDelay
        super.tearDown()
    }

    func testAdjacentButtonPaddedOverlapDoesNotStealHoveredButton() {
        let manager = DwellSelectionManager()
        // Two buttons separated by 12pt (matching PhrasesView / CategoriesView spacing),
        // which is smaller than hitTestPadding (16pt).
        let leftFrame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let rightFrame = CGRect(x: 212, y: 0, width: 200, height: 200)

        manager.registerButton(id: "phrase_left", frame: leftFrame)
        manager.registerButton(id: "phrase_right", frame: rightFrame)

        // Start dwelling inside the right button (even near its left edge at x=214,
        // where leftFrame.insetBy(dx: -16, dy: -16) overlaps up to x=216)
        manager.updateGazePosition(CGPoint(x: 214, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_right")

        // Slight jitter into the 12pt inter-button gap (x=204, within right button's 16pt padding)
        // must keep hovering phrase_right instead of being stolen by phrase_left.
        manager.updateGazePosition(CGPoint(x: 204, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_right")
    }

    func testSetAllowedButtonIdsPreservesUnderlyingButtonsAndOrder() {
        let manager = DwellSelectionManager()
        manager.registerButton(id: "phrase_1", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        manager.registerButton(id: "phrase_2", frame: CGRect(x: 120, y: 0, width: 100, height: 100))

        manager.setAllowedButtonIds(["media_exit"])
        XCTAssertEqual(manager.getOrderedButtonIds(), [])

        // While overlay is active, gazing at phrase_1 must not hover it
        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertNil(manager.hoveredButtonId)

        // Closing the overlay immediately restores phrase_1 and phrase_2 in order
        manager.setAllowedButtonIds(nil)
        XCTAssertEqual(manager.getOrderedButtonIds(), ["phrase_1", "phrase_2"])
        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_1")
    }

    func testRepeatDwellFiresRepeatedActivationsOnSteadyGaze() {
        AppSettings.shared.dwellTime = 0.15
        AppSettings.shared.enableRepeatDwell = true
        AppSettings.shared.repeatDwellDelay = 0.55

        let manager = DwellSelectionManager()
        manager.registerButton(id: "phrase_repeat", frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        var activations: [DwellActivation] = []
        let cancellable = manager.$lastActivation
            .compactMap { $0 }
            .sink { activation in
                activations.append(activation)
            }
        defer { cancellable.cancel() }

        // Feed a single steady gaze position; the internal 30Hz dwellTimer must drive
        // both the initial activation and the repeat activation without needing cursor movement.
        manager.updateGazePosition(CGPoint(x: 100, y: 100))

        let expectation = XCTestExpectation(description: "Initial and repeat dwell activations fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            XCTAssertGreaterThanOrEqual(activations.count, 2, "Should fire initial + at least one repeat activation")
            XCTAssertEqual(activations.first?.buttonId, "phrase_repeat")
            XCTAssertNotEqual(activations.first?.token, activations.last?.token)
            manager.cancelDwell()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.5)
    }

    func testReturningInsideExitMarginCancelsExitGraceTimerAndPreservesDwell() {
        AppSettings.shared.dwellTime = 0.40
        AppSettings.shared.enableRepeatDwell = false

        let manager = DwellSelectionManager()
        let frame = CGRect(x: 100, y: 100, width: 200, height: 200)
        manager.registerButton(id: "phrase_1", frame: frame)

        // Start dwelling at center
        manager.updateGazePosition(CGPoint(x: 200, y: 200))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_1")

        // Brief 1-frame spike outside exitMargin (35pt -> x < 65) starts the 250ms exitGraceTimer
        manager.updateGazePosition(CGPoint(x: 50, y: 200))

        // Next frame (20ms later) returns inside exitMargin (75 is 25pt outside frame, inside 35pt exitMargin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            manager.updateGazePosition(CGPoint(x: 75, y: 200))
        }

        // Wait past the 250ms exitGracePeriod — dwell must NOT have been cancelled!
        let expectation = XCTestExpectation(description: "Dwell survives brief excursion after returning inside exitMargin")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            XCTAssertEqual(manager.hoveredButtonId, "phrase_1")
            manager.cancelDwell()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSingleDwellLookAwayToScreenMarginReleasesAndAllowsRepeatActivation() {
        AppSettings.shared.dwellTime = 0.12
        AppSettings.shared.enableRepeatDwell = false

        let manager = DwellSelectionManager()
        // Simulate a 1-tile CVI layout with 12pt outer screen padding on a 1024x768 screen
        let singleTileFrame = CGRect(x: 12, y: 12, width: 1000, height: 744)
        manager.registerButton(id: "phrase_single", frame: singleTileFrame)

        var activations: [DwellActivation] = []
        let cancellable = manager.$lastActivation
            .compactMap { $0 }
            .sink { activations.append($0) }
        defer { cancellable.cancel() }

        // 1. Gaze at tile center to trigger first activation
        manager.updateGazePosition(CGPoint(x: 500, y: 380))

        let expectation = XCTestExpectation(description: "Glancing to 12pt screen margin releases hover and looking back re-activates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            XCTAssertEqual(activations.count, 1)
            XCTAssertTrue(manager.hasActivatedCurrentDwell)

            // 2. Glance to the 12pt left screen margin (x = 4, which would previously be trapped inside 16pt hitTestPadding)
            manager.updateGazePosition(CGPoint(x: 4, y: 380))
        }

        // 3. After the 80ms post-activation release grace, hover must be released
        //    and after the 500ms cooldown, looking back at the center must trigger a second activation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            XCTAssertNil(manager.hoveredButtonId)
            manager.updateGazePosition(CGPoint(x: 500, y: 380))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            XCTAssertEqual(activations.count, 2)
            manager.cancelDwell()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.5)
    }

    func testHeadPoseTrackerJawMovementDoesNotShiftPitchAndPreservesUnclampedNormalizedCoords() {
        let tracker = HeadPoseTracker()
        var closedMouth = Array(repeating: iosApp.LandmarkPoint(x: 0.5, y: 0.5, z: 0), count: 468)
        closedMouth[10] = iosApp.LandmarkPoint(x: 0.50, y: 0.28, z: 0)  // forehead
        closedMouth[33] = iosApp.LandmarkPoint(x: 0.40, y: 0.40, z: 0)  // left eye outer
        closedMouth[263] = iosApp.LandmarkPoint(x: 0.60, y: 0.40, z: 0) // right eye outer
        closedMouth[1] = iosApp.LandmarkPoint(x: 0.50, y: 0.50, z: 0)   // nose tip
        closedMouth[152] = iosApp.LandmarkPoint(x: 0.50, y: 0.72, z: 0) // chin (closed mouth)
        closedMouth[234] = iosApp.LandmarkPoint(x: 0.30, y: 0.45, z: 0) // left ear
        closedMouth[454] = iosApp.LandmarkPoint(x: 0.70, y: 0.45, z: 0) // right ear

        var openMouth = closedMouth
        openMouth[152] = iosApp.LandmarkPoint(x: 0.50, y: 0.88, z: 0)   // chin drops when mouth opens wide

        let closedPose = tracker.estimateHeadPose(points: closedMouth)
        let openPose = tracker.estimateHeadPose(points: openMouth)
        XCTAssertNotNil(closedPose)
        XCTAssertNotNil(openPose)
        XCTAssertEqual(closedPose?.pitch ?? -999, openPose?.pitch ?? 999, accuracy: 0.001,
                       "Opening the mouth (chin drop) must not shift vertical pitch")

        // Verify extreme head rotation produces unclamped normalizedX / normalizedY (> 1.2)
        // in TrackingResult while clamping screenX / screenY to screen bounds.
        var turnedFarRight = closedMouth
        turnedFarRight[1] = iosApp.LandmarkPoint(x: 0.80, y: 0.50, z: 0) // strong yaw right
        let result = tracker.processLandmarks(
            points: turnedFarRight,
            screenWidth: 1024,
            screenHeight: 768,
            smoothingMode: "none",
            lerpFactor: 1.0
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(abs(result?.normalizedX ?? 0), 1.2,
                             "TrackingResult.normalizedX must preserve unclamped coordinates for OOB detection")
        XCTAssertTrue(result?.isOutOfBounds == true)
        XCTAssertLessThanOrEqual(result?.screenX ?? 9999, 1024)
    }
}

