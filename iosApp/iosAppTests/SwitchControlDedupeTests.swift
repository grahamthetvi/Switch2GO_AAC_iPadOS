import XCTest
@testable import iosApp

final class SwitchControlDedupeTests: XCTestCase {
    func testDuplicateHIDWithinWindowIsIgnored() {
        let previous = (code: 30, pressed: true, time: 100.0)
        XCTAssertTrue(
            SwitchControlManager.isDuplicateHIDEvent(
                code: 30,
                pressed: true,
                now: 100.04,
                previous: previous
            )
        )
    }

    func testDifferentCodeIsNotDuplicate() {
        let previous = (code: 30, pressed: true, time: 100.0)
        XCTAssertFalse(
            SwitchControlManager.isDuplicateHIDEvent(
                code: 31,
                pressed: true,
                now: 100.01,
                previous: previous
            )
        )
    }

    func testOutsideWindowIsNotDuplicate() {
        let previous = (code: 30, pressed: true, time: 100.0)
        XCTAssertFalse(
            SwitchControlManager.isDuplicateHIDEvent(
                code: 30,
                pressed: true,
                now: 100.2,
                previous: previous
            )
        )
    }

    func testNilPreviousIsNotDuplicate() {
        XCTAssertFalse(
            SwitchControlManager.isDuplicateHIDEvent(
                code: 30,
                pressed: true,
                now: 100.0,
                previous: nil
            )
        )
    }

    func testSwitchOneMapsToFirstPhraseSlot() {
        let ids = ["phrase_left", "phrase_right"]
        XCTAssertEqual(
            SwitchControlManager.phraseButtonId(forSwitchIndex: 0, phraseButtonIds: ids),
            "phrase_left"
        )
        XCTAssertEqual(
            SwitchControlManager.phraseButtonId(forSwitchIndex: 1, phraseButtonIds: ids),
            "phrase_right"
        )
    }

    func testSwitchIndexOutOfRangeReturnsNil() {
        XCTAssertNil(
            SwitchControlManager.phraseButtonId(forSwitchIndex: 2, phraseButtonIds: ["a", "b"])
        )
    }

    func testReadingOrderPutsLeftPhraseBeforeRightEvenIfRegisteredBackwards() {
        let ids = ["phrase_right", "phrase_left"]
        let frames: [String: CGRect] = [
            "phrase_right": CGRect(x: 400, y: 80, width: 200, height: 200),
            "phrase_left": CGRect(x: 40, y: 80, width: 200, height: 200),
        ]
        let ordered = DwellSelectionManager.idsInReadingOrder(ids, frames: frames)
        XCTAssertEqual(ordered, ["phrase_left", "phrase_right"])
        XCTAssertEqual(
            SwitchControlManager.phraseButtonId(forSwitchIndex: 0, phraseButtonIds: ordered),
            "phrase_left"
        )
        XCTAssertEqual(
            SwitchControlManager.phraseButtonId(forSwitchIndex: 1, phraseButtonIds: ordered),
            "phrase_right"
        )
    }

    func testReadingOrderIsTopToBottomThenLeftToRight() {
        let ids = ["br", "tl", "tr", "bl"]
        let frames: [String: CGRect] = [
            "tl": CGRect(x: 10, y: 10, width: 100, height: 100),
            "tr": CGRect(x: 200, y: 12, width: 100, height: 100),
            "bl": CGRect(x: 10, y: 200, width: 100, height: 100),
            "br": CGRect(x: 200, y: 200, width: 100, height: 100),
        ]
        XCTAssertEqual(
            DwellSelectionManager.idsInReadingOrder(ids, frames: frames),
            ["tl", "tr", "bl", "br"]
        )
    }

    func testReadingOrderKeepsRegistrationOrderWhenAnyFrameIsMissing() {
        let ids = ["phrase_right", "phrase_left"]
        let frames: [String: CGRect] = [
            "phrase_left": CGRect(x: 40, y: 80, width: 200, height: 200),
        ]
        XCTAssertEqual(
            DwellSelectionManager.idsInReadingOrder(ids, frames: frames),
            ids
        )
    }

    func testFourSwitchReadingOrderIsRowMajor() {
        let ids = ["d", "c", "b", "a"]
        let frames: [String: CGRect] = [
            "a": CGRect(x: 10, y: 10, width: 100, height: 100),
            "b": CGRect(x: 200, y: 10, width: 100, height: 100),
            "c": CGRect(x: 10, y: 200, width: 100, height: 100),
            "d": CGRect(x: 200, y: 200, width: 100, height: 100),
        ]
        let ordered = DwellSelectionManager.idsInReadingOrder(ids, frames: frames)
        XCTAssertEqual(ordered, ["a", "b", "c", "d"])
        XCTAssertEqual(SwitchControlManager.phraseButtonId(forSwitchIndex: 0, phraseButtonIds: ordered), "a")
        XCTAssertEqual(SwitchControlManager.phraseButtonId(forSwitchIndex: 3, phraseButtonIds: ordered), "d")
    }
}
