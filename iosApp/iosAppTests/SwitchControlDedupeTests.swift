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
}
