import XCTest
@testable import iosApp

final class PlaybackReliabilityTests: XCTestCase {
    private var savedDelay: Double = 0
    private var savedMode: String = ""

    override func setUp() {
        super.setUp()
        savedDelay = AppSettings.shared.mediaPlaybackDelay
        savedMode = AppSettings.shared.selectionMode
        AppSettings.shared.selectionMode = "eyeGaze"
    }

    override func tearDown() {
        AppSettings.shared.mediaPlaybackDelay = savedDelay
        AppSettings.shared.selectionMode = savedMode
        super.tearDown()
    }

    func testRepeatSelectionOfTheSameArmedClipDoesNotStarvePlayback() {
        AppSettings.shared.mediaPlaybackDelay = 0.20
        let coordinator = MediaPlaybackCoordinator()
        let phrase = makePhrase(id: "audio_1", mediaType: "audio", mediaRef: "Media/clip.m4a", gameType: nil)

        coordinator.onPhraseSelected(phrase)
        XCTAssertEqual(coordinator.phase, .armed)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            coordinator.onPhraseSelected(phrase)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            coordinator.onPhraseSelected(phrase)
        }

        let expectation = XCTestExpectation(description: "original countdown still plays")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            XCTAssertEqual(coordinator.phase, .playing)
            XCTAssertEqual(coordinator.activePhrase?.id, phrase.id)
            coordinator.stopEarly()
            XCTAssertEqual(coordinator.phase, .idle)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSelectingADifferentClipRestartsTheCountdown() {
        AppSettings.shared.mediaPlaybackDelay = 0.30
        let coordinator = MediaPlaybackCoordinator()
        let first = makePhrase(id: "audio_1", mediaType: "audio", mediaRef: "Media/a.m4a", gameType: nil)
        let second = makePhrase(id: "audio_2", mediaType: "audio", mediaRef: "Media/b.m4a", gameType: nil)

        coordinator.onPhraseSelected(first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            coordinator.onPhraseSelected(second)
        }

        let stillArmed = XCTestExpectation(description: "second clip has not started yet")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(coordinator.phase, .armed)
            stillArmed.fulfill()
        }
        let playing = XCTestExpectation(description: "second clip plays from its own delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            XCTAssertEqual(coordinator.phase, .playing)
            XCTAssertEqual(coordinator.activePhrase?.id, second.id)
            coordinator.stopEarly()
            playing.fulfill()
        }
        wait(for: [stillArmed, playing], timeout: 1.0)
    }

    func testSelectingAPlainPhraseCancelsAnArmedClip() {
        AppSettings.shared.mediaPlaybackDelay = 0.40
        let coordinator = MediaPlaybackCoordinator()
        let clip = makePhrase(id: "audio_1", mediaType: "audio", mediaRef: "Media/a.m4a", gameType: nil)
        let plain = PhraseDisplayModel(
            id: "plain",
            text: "Hello",
            spokenText: nil,
            sortOrder: 0,
            isPreset: false,
            style: nil
        )

        coordinator.onPhraseSelected(clip)
        XCTAssertEqual(coordinator.phase, .armed)
        coordinator.onPhraseSelected(plain)
        XCTAssertEqual(coordinator.phase, .idle)

        let expectation = XCTestExpectation(description: "cancelled clip does not start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(coordinator.phase, .idle)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRepeatSelectionOfTheSameArmedGameDoesNotStarveLaunch() {
        AppSettings.shared.mediaPlaybackDelay = 0.20
        let coordinator = GamePlaybackCoordinator()
        let phrase = makePhrase(id: "game_1", mediaType: nil, mediaRef: nil, gameType: "cursor_rocket")

        coordinator.onPhraseSelected(phrase)
        XCTAssertEqual(coordinator.phase, .armed)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            coordinator.onPhraseSelected(phrase)
        }

        let expectation = XCTestExpectation(description: "game still launches")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            XCTAssertEqual(coordinator.phase, .playing)
            XCTAssertEqual(coordinator.activePhrase?.id, phrase.id)
            coordinator.stopEarly()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func makePhrase(
        id: String,
        mediaType: String?,
        mediaRef: String?,
        gameType: String?
    ) -> PhraseDisplayModel {
        let style = PhraseStyleData(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil,
            mediaRef: mediaRef,
            mediaType: mediaType,
            gameType: gameType,
            sendSwitchOutput: nil
        ).toPhraseStyle()
        return PhraseDisplayModel(
            id: id,
            text: id,
            spokenText: nil,
            sortOrder: 0,
            isPreset: false,
            style: style
        )
    }
}
