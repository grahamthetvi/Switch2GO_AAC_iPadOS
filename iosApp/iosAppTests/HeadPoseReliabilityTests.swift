import XCTest
@testable import iosApp

final class HeadPoseReliabilityTests: XCTestCase {
    func testOpeningTheMouthDoesNotChangePitch() {
        let tracker = HeadPoseTracker()
        var closed = Array(repeating: LandmarkPoint(x: 0.5, y: 0.5, z: 0), count: 468)
        closed[10] = LandmarkPoint(x: 0.50, y: 0.28, z: 0)
        closed[33] = LandmarkPoint(x: 0.40, y: 0.40, z: 0)
        closed[263] = LandmarkPoint(x: 0.60, y: 0.40, z: 0)
        closed[1] = LandmarkPoint(x: 0.50, y: 0.50, z: 0)
        closed[152] = LandmarkPoint(x: 0.50, y: 0.72, z: 0)
        closed[234] = LandmarkPoint(x: 0.30, y: 0.45, z: 0)
        closed[454] = LandmarkPoint(x: 0.70, y: 0.45, z: 0)

        var open = closed
        open[152] = LandmarkPoint(x: 0.50, y: 0.88, z: 0)

        let closedPose = tracker.estimateHeadPose(points: closed)
        let openPose = tracker.estimateHeadPose(points: open)
        XCTAssertEqual(closedPose?.pitch ?? -999, openPose?.pitch ?? 999, accuracy: 0.001)
    }

    func testExtremeYawStaysOutOfBoundsWithoutLeavingTheScreen() {
        let tracker = HeadPoseTracker()
        var turned = Array(repeating: LandmarkPoint(x: 0.5, y: 0.5, z: 0), count: 468)
        turned[10] = LandmarkPoint(x: 0.50, y: 0.28, z: 0)
        turned[33] = LandmarkPoint(x: 0.40, y: 0.40, z: 0)
        turned[263] = LandmarkPoint(x: 0.60, y: 0.40, z: 0)
        turned[1] = LandmarkPoint(x: 0.80, y: 0.50, z: 0)
        turned[234] = LandmarkPoint(x: 0.30, y: 0.45, z: 0)
        turned[454] = LandmarkPoint(x: 0.70, y: 0.45, z: 0)

        let result = tracker.processLandmarks(
            points: turned,
            screenWidth: 1024,
            screenHeight: 768,
            smoothingMode: "none",
            lerpFactor: 1
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(abs(result?.normalizedX ?? 0), 1.2)
        XCTAssertEqual(result?.isOutOfBounds, true)
        XCTAssertLessThanOrEqual(result?.screenX ?? 9999, 1024)
        XCTAssertGreaterThanOrEqual(result?.screenX ?? -1, 0)
    }
}
