import Foundation

enum ArmSide: String {
    case left
    case right
}

struct ArmRaiseState: Equatable {
    var leftRaised: Bool
    var rightRaised: Bool
}

struct LandmarkPoint {
    let x: Float
    let y: Float
    let z: Float
}

struct ArmRaiseDetectorConfig {
    /// Normalized distance wrist must be above shoulder (image y grows downward).
    var margin: Float
    var holdMs: Double
    var cooldownMs: Double
}

/// Detects sustained left/right arm raises from pose landmarks.
final class ArmRaiseDetector {
    private var leftHeldSince: Double?
    private var rightHeldSince: Double?
    private var lastActivationTime: Double = 0

    private static let leftShoulder = 11
    private static let rightShoulder = 12
    private static let leftElbow = 13
    private static let rightElbow = 14
    private static let leftWrist = 15
    private static let rightWrist = 16
    private static let minVisibility: Float = 0.5

    func reset() {
        leftHeldSince = nil
        rightHeldSince = nil
    }

    func process(
        landmarks: [LandmarkPoint],
        visibilities: [Float]?,
        now: Double,
        config: ArmRaiseDetectorConfig
    ) -> (activation: ArmSide?, state: ArmRaiseState) {
        let leftRaised = isArmRaised(landmarks: landmarks, visibilities: visibilities, side: .left, margin: config.margin)
        let rightRaised = isArmRaised(landmarks: landmarks, visibilities: visibilities, side: .right, margin: config.margin)
        let state = ArmRaiseState(leftRaised: leftRaised, rightRaised: rightRaised)

        if now - lastActivationTime < config.cooldownMs {
            updateHoldTimers(leftRaised: leftRaised, rightRaised: rightRaised, now: now)
            return (nil, state)
        }

        guard let side = pickDominantSide(leftRaised: leftRaised, rightRaised: rightRaised, landmarks: landmarks) else {
            leftHeldSince = nil
            rightHeldSince = nil
            return (nil, state)
        }

        let heldSince = side == .left ? leftHeldSince : rightHeldSince
        if heldSince == nil {
            if side == .left {
                leftHeldSince = now
            } else {
                rightHeldSince = now
            }
            return (nil, state)
        }

        if now - (heldSince ?? now) >= config.holdMs {
            lastActivationTime = now
            leftHeldSince = nil
            rightHeldSince = nil
            return (side, state)
        }

        return (nil, state)
    }

    private func updateHoldTimers(leftRaised: Bool, rightRaised: Bool, now: Double) {
        if !leftRaised {
            leftHeldSince = nil
        } else if leftHeldSince == nil {
            leftHeldSince = now
        }
        if !rightRaised {
            rightHeldSince = nil
        } else if rightHeldSince == nil {
            rightHeldSince = now
        }
    }

    private func pickDominantSide(
        leftRaised: Bool,
        rightRaised: Bool,
        landmarks: [LandmarkPoint]
    ) -> ArmSide? {
        if leftRaised && !rightRaised { return .left }
        if rightRaised && !leftRaised { return .right }
        if !leftRaised || !rightRaised { return nil }

        guard landmarks.count > Self.rightWrist else { return nil }
        let leftWrist = landmarks[Self.leftWrist]
        let rightWrist = landmarks[Self.rightWrist]
        return leftWrist.y < rightWrist.y ? .left : .right
    }

    private func isArmRaised(
        landmarks: [LandmarkPoint],
        visibilities: [Float]?,
        side: ArmSide,
        margin: Float
    ) -> Bool {
        let shoulderIdx: Int
        let elbowIdx: Int
        let wristIdx: Int
        switch side {
        case .left:
            shoulderIdx = Self.leftShoulder
            elbowIdx = Self.leftElbow
            wristIdx = Self.leftWrist
        case .right:
            shoulderIdx = Self.rightShoulder
            elbowIdx = Self.rightElbow
            wristIdx = Self.rightWrist
        }

        let maxIdx = max(shoulderIdx, elbowIdx, wristIdx)
        guard landmarks.count > maxIdx else { return false }

        if let visibilities {
            let minVis = min(
                visibilities[safe: shoulderIdx] ?? 0,
                visibilities[safe: elbowIdx] ?? 0,
                visibilities[safe: wristIdx] ?? 0
            )
            if minVis < Self.minVisibility { return false }
        }

        let shoulder = landmarks[shoulderIdx]
        let elbow = landmarks[elbowIdx]
        let wrist = landmarks[wristIdx]

        let wristAbove = wrist.y < shoulder.y - margin
        let elbowAbove = elbow.y < shoulder.y - margin * 0.5
        return wristAbove && elbowAbove
    }
}

private extension Array where Element == Float {
    subscript(safe index: Int) -> Float? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
