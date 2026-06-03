import XCTest
@testable import iosApp

final class HandGestureDetectorTests: XCTestCase {
    private let config = HandGestureDetectorConfig(minScore: 0.55, stableFrames: 3, cooldownMs: 1200)

    private func hand(side: HandSide, gesture: String, score: Float = 0.9) -> DetectedHandGesture {
        DetectedHandGesture(side: side, gestureName: gesture, score: score)
    }

    func testOpenToClosedTransitionActivatesLeftHand() {
        let detector = HandGestureDetector()
        let open = [hand(side: .left, gesture: "Open_Palm")]
        let closed = [hand(side: .left, gesture: "Closed_Fist")]

        _ = detector.process(hands: open, now: 0, config: config)
        _ = detector.process(hands: open, now: 100, config: config)
        var result = detector.process(hands: open, now: 200, config: config)
        XCTAssertNil(result.activation)
        XCTAssertEqual(result.state.leftPose, .open)

        _ = detector.process(hands: closed, now: 300, config: config)
        _ = detector.process(hands: closed, now: 400, config: config)
        result = detector.process(hands: closed, now: 500, config: config)
        XCTAssertEqual(result.activation, .left)
        XCTAssertEqual(result.state.leftPose, .closed)
    }

    func testLowScoreGestureIsIgnored() {
        let detector = HandGestureDetector()
        let weakOpen = [hand(side: .right, gesture: "Open_Palm", score: 0.2)]
        let result = detector.process(hands: weakOpen, now: 0, config: config)
        XCTAssertNil(result.state.rightPose)
        XCTAssertNil(result.activation)
    }

    func testCooldownPreventsImmediateReactivation() {
        let detector = HandGestureDetector()
        let open = [hand(side: .right, gesture: "Open_Palm")]
        let closed = [hand(side: .right, gesture: "Closed_Fist")]

        _ = detector.process(hands: open, now: 0, config: config)
        _ = detector.process(hands: open, now: 100, config: config)
        _ = detector.process(hands: open, now: 200, config: config)
        _ = detector.process(hands: closed, now: 300, config: config)
        _ = detector.process(hands: closed, now: 400, config: config)
        _ = detector.process(hands: closed, now: 500, config: config)

        let openAgain = detector.process(hands: open, now: 700, config: config)
        XCTAssertNil(openAgain.activation)
    }
}
