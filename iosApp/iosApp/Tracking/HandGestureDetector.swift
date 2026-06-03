import Foundation

typealias HandSide = ArmSide

enum HandPose: Equatable {
    case open
    case closed
}

struct HandGestureState: Equatable {
    var leftPose: HandPose?
    var rightPose: HandPose?
}

struct DetectedHandGesture {
    let side: HandSide
    let gestureName: String
    let score: Float
}

struct HandGestureDetectorConfig {
    var minScore: Float
    var stableFrames: Int
    var cooldownMs: Double
}

/// Detects open↔closed hand transitions for left/right phrase selection.
final class HandGestureDetector {
    private struct SideTracker {
        var stablePose: HandPose?
        var pendingPose: HandPose?
        var pendingCount: Int
    }

    private static let openGesture = "Open_Palm"
    private static let closedGesture = "Closed_Fist"

    private var left = SideTracker(stablePose: nil, pendingPose: nil, pendingCount: 0)
    private var right = SideTracker(stablePose: nil, pendingPose: nil, pendingCount: 0)
    private var lastActivationTime: Double = 0

    func reset() {
        left = freshSide()
        right = freshSide()
    }

    func process(
        hands: [DetectedHandGesture],
        now: Double,
        config: HandGestureDetectorConfig
    ) -> (activation: HandSide?, state: HandGestureState) {
        var detected: [HandSide: HandPose] = [:]
        for hand in hands {
            if let pose = gestureToPose(name: hand.gestureName, score: hand.score, minScore: config.minScore) {
                detected[hand.side] = pose
            }
        }

        var activation: HandSide?
        if now - lastActivationTime >= config.cooldownMs {
            activation = advanceSide(.left, tracker: &left, pose: detected[.left], stableFrames: config.stableFrames)
            if activation == nil {
                activation = advanceSide(.right, tracker: &right, pose: detected[.right], stableFrames: config.stableFrames)
            }
            if activation != nil {
                lastActivationTime = now
            }
        } else {
            _ = advanceSide(.left, tracker: &left, pose: detected[.left], stableFrames: config.stableFrames)
            _ = advanceSide(.right, tracker: &right, pose: detected[.right], stableFrames: config.stableFrames)
        }

        return (
            activation,
            HandGestureState(leftPose: left.stablePose, rightPose: right.stablePose)
        )
    }

    private func freshSide() -> SideTracker {
        SideTracker(stablePose: nil, pendingPose: nil, pendingCount: 0)
    }

    private func gestureToPose(name: String, score: Float, minScore: Float) -> HandPose? {
        guard score >= minScore else { return nil }
        if name == Self.openGesture { return .open }
        if name == Self.closedGesture { return .closed }
        return nil
    }

    private func advanceSide(
        _ side: HandSide,
        tracker: inout SideTracker,
        pose: HandPose?,
        stableFrames: Int
    ) -> HandSide? {
        guard let pose else {
            tracker.pendingPose = nil
            tracker.pendingCount = 0
            return nil
        }

        if pose != tracker.pendingPose {
            tracker.pendingPose = pose
            tracker.pendingCount = 1
            return nil
        }

        tracker.pendingCount += 1
        if tracker.pendingCount < stableFrames { return nil }

        let previous = tracker.stablePose
        if previous != nil && previous != pose {
            tracker.stablePose = pose
            tracker.pendingPose = nil
            tracker.pendingCount = 0
            return side
        }

        tracker.stablePose = pose
        return nil
    }
}
