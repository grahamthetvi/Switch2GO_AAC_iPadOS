import XCTest
@testable import iosApp

final class DwellSelectionManagerTests: XCTestCase {
    private var manager: DwellSelectionManager!

    override func setUp() {
        super.setUp()
        manager = DwellSelectionManager()
        manager.isEnabled = true
    }

    /// 12pt gutter between 100pt tiles, matching the phrase grid. 16pt hit padding
    /// from the left tile overlaps 4pt into the right tile.
    func testLookAtRightTileIsNotStolenByLeftPadding() {
        manager.registerButton(id: "left", frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        manager.registerButton(id: "right", frame: CGRect(x: 112, y: 0, width: 100, height: 200))

        manager.updateGazePosition(CGPoint(x: 114, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "right")
    }

    func testLookAtLeftTileSelectsLeft() {
        manager.registerButton(id: "left", frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        manager.registerButton(id: "right", frame: CGRect(x: 112, y: 0, width: 100, height: 200))

        manager.updateGazePosition(CGPoint(x: 50, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "left")
    }

    func testStickyHoverKeepsRightTileInTheGutter() {
        manager.registerButton(id: "left", frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        manager.registerButton(id: "right", frame: CGRect(x: 112, y: 0, width: 100, height: 200))

        manager.updateGazePosition(CGPoint(x: 162, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "right")

        manager.updateGazePosition(CGPoint(x: 106, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "right")
    }

    func testMovingOntoLeftTileSwitchesAwayFromRight() {
        manager.registerButton(id: "left", frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        manager.registerButton(id: "right", frame: CGRect(x: 112, y: 0, width: 100, height: 200))

        manager.updateGazePosition(CGPoint(x: 162, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "right")

        manager.updateGazePosition(CGPoint(x: 50, y: 100))
        XCTAssertEqual(manager.hoveredButtonId, "left")
    }

    func testAllowedButtonIdsMasksAndRestoresUnderlyingButtons() {
        manager.registerButton(id: "phrase_1", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        manager.registerButton(id: "phrase_2", frame: CGRect(x: 120, y: 0, width: 100, height: 100))

        // Hover over phrase_1
        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_1")

        // Overlay appears with scoped button
        manager.setAllowedButtonIds(["overlay_exit"])
        manager.registerButton(id: "overlay_exit", frame: CGRect(x: 0, y: 0, width: 50, height: 50))

        // Gaze on phrase_2 should be ignored because it's not allowed
        manager.updateGazePosition(CGPoint(x: 150, y: 50))
        XCTAssertNil(manager.hoveredButtonId)

        // Gaze on overlay_exit works
        manager.updateGazePosition(CGPoint(x: 25, y: 25))
        XCTAssertEqual(manager.hoveredButtonId, "overlay_exit")

        // Overlay dismissed
        manager.unregisterButton(id: "overlay_exit")
        manager.setAllowedButtonIds(nil)

        // phrase_2 should still be registered and hoverable without re-registration!
        manager.updateGazePosition(CGPoint(x: 150, y: 50))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_2")
    }

    func testEmptyAllowListBlocksGazeAndClearsHover() {
        manager.registerButton(id: "phrase_1", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_1")

        manager.setAllowedButtonIds([])
        XCTAssertNil(manager.hoveredButtonId)

        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertNil(manager.hoveredButtonId)
    }

    func testCancelDwellForTrackingLossDropsAnArmedHover() {
        manager.registerButton(id: "phrase_1", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        manager.updateGazePosition(CGPoint(x: 50, y: 50))
        XCTAssertEqual(manager.hoveredButtonId, "phrase_1")

        manager.cancelDwellForTrackingLoss()
        XCTAssertNil(manager.hoveredButtonId)
        XCTAssertEqual(manager.dwellProgress, 0)
    }

    func testSteadyGazeStillActivatesWithoutFurtherMovement() {
        let savedDwell = AppSettings.shared.dwellTime
        let savedRepeat = AppSettings.shared.enableRepeatDwell
        defer {
            AppSettings.shared.dwellTime = savedDwell
            AppSettings.shared.enableRepeatDwell = savedRepeat
            manager.reset()
        }
        AppSettings.shared.dwellTime = 0.12
        AppSettings.shared.enableRepeatDwell = false

        manager.registerButton(id: "phrase_steady", frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        manager.updateGazePosition(CGPoint(x: 100, y: 100))

        let expectation = XCTestExpectation(description: "steady gaze activates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(self.manager.lastActivation?.buttonId, "phrase_steady")
            XCTAssertTrue(self.manager.hasActivatedCurrentDwell)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRepeatDwellFiresAgainWhileTheCursorStaysStill() {
        let savedDwell = AppSettings.shared.dwellTime
        let savedRepeat = AppSettings.shared.enableRepeatDwell
        let savedDelay = AppSettings.shared.repeatDwellDelay
        defer {
            AppSettings.shared.dwellTime = savedDwell
            AppSettings.shared.enableRepeatDwell = savedRepeat
            AppSettings.shared.repeatDwellDelay = savedDelay
            manager.reset()
        }
        AppSettings.shared.dwellTime = 0.12
        AppSettings.shared.enableRepeatDwell = true
        AppSettings.shared.repeatDwellDelay = 0.55

        manager.registerButton(id: "phrase_repeat", frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        manager.updateGazePosition(CGPoint(x: 100, y: 100))

        let expectation = XCTestExpectation(description: "repeat dwell fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            XCTAssertGreaterThanOrEqual(self.manager.activationToken, 2)
            XCTAssertEqual(self.manager.lastActivation?.buttonId, "phrase_repeat")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.5)
    }

    func testLookAwayToTheScreenMarginReleasesAOneShotDwell() {
        let savedDwell = AppSettings.shared.dwellTime
        let savedRepeat = AppSettings.shared.enableRepeatDwell
        defer {
            AppSettings.shared.dwellTime = savedDwell
            AppSettings.shared.enableRepeatDwell = savedRepeat
            manager.reset()
        }
        AppSettings.shared.dwellTime = 0.12
        AppSettings.shared.enableRepeatDwell = false

        // One large tile with a 12pt outer margin, matching a single-phrase page.
        manager.registerButton(id: "phrase_single", frame: CGRect(x: 12, y: 12, width: 1000, height: 744))
        manager.updateGazePosition(CGPoint(x: 500, y: 380))

        let expectation = XCTestExpectation(description: "margin glance releases hover")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.manager.activationToken, 1)
            self.manager.updateGazePosition(CGPoint(x: 4, y: 380))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            // Another sample at the margin must not be pulled back by hit padding.
            self.manager.updateGazePosition(CGPoint(x: 4, y: 380))
            XCTAssertNil(self.manager.hoveredButtonId)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
