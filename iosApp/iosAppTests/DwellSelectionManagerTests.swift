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
}
