import XCTest
@testable import iosApp

final class ArmRaiseDetectorTests: XCTestCase {
    private let margin: Float = 0.08
    private let holdMs: Double = 1000
    private let cooldownMs: Double = 1200

    private func makeLandmarks(leftRaised: Bool, rightRaised: Bool) -> [LandmarkPoint] {
        var points = Array(repeating: LandmarkPoint(x: 0.5, y: 0.5, z: 0), count: 17)
        points[11] = LandmarkPoint(x: 0.3, y: 0.4, z: 0) // left shoulder
        points[12] = LandmarkPoint(x: 0.7, y: 0.4, z: 0) // right shoulder
        points[13] = LandmarkPoint(x: 0.3, y: leftRaised ? 0.2 : 0.55, z: 0)
        points[14] = LandmarkPoint(x: 0.7, y: rightRaised ? 0.2 : 0.55, z: 0)
        points[15] = LandmarkPoint(x: 0.3, y: leftRaised ? 0.1 : 0.65, z: 0)
        points[16] = LandmarkPoint(x: 0.7, y: rightRaised ? 0.1 : 0.65, z: 0)
        return points
    }

    func testLeftArmRaiseActivatesAfterHold() {
        let detector = ArmRaiseDetector()
        let config = ArmRaiseDetectorConfig(margin: margin, holdMs: holdMs, cooldownMs: cooldownMs)
        let landmarks = makeLandmarks(leftRaised: true, rightRaised: false)

        var result = detector.process(landmarks: landmarks, visibilities: nil, now: 0, config: config)
        XCTAssertNil(result.activation)
        XCTAssertTrue(result.state.leftRaised)

        result = detector.process(landmarks: landmarks, visibilities: nil, now: 500, config: config)
        XCTAssertNil(result.activation)

        result = detector.process(landmarks: landmarks, visibilities: nil, now: 1000, config: config)
        XCTAssertEqual(result.activation, .left)
    }

    func testRightArmRaiseActivatesAfterHold() {
        let detector = ArmRaiseDetector()
        let config = ArmRaiseDetectorConfig(margin: margin, holdMs: holdMs, cooldownMs: cooldownMs)
        let landmarks = makeLandmarks(leftRaised: false, rightRaised: true)

        _ = detector.process(landmarks: landmarks, visibilities: nil, now: 0, config: config)
        let result = detector.process(landmarks: landmarks, visibilities: nil, now: 1000, config: config)
        XCTAssertEqual(result.activation, .right)
    }

    func testCooldownPreventsImmediateReactivation() {
        let detector = ArmRaiseDetector()
        let config = ArmRaiseDetectorConfig(margin: margin, holdMs: holdMs, cooldownMs: cooldownMs)
        let landmarks = makeLandmarks(leftRaised: true, rightRaised: false)

        _ = detector.process(landmarks: landmarks, visibilities: nil, now: 0, config: config)
        _ = detector.process(landmarks: landmarks, visibilities: nil, now: 1000, config: config)
        let duringCooldown = detector.process(landmarks: landmarks, visibilities: nil, now: 1500, config: config)
        XCTAssertNil(duringCooldown.activation)
    }
}
