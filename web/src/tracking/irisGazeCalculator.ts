import type { LandmarkPoint } from './types'

/** 2D iris gaze math (ported from shared IrisGazeCalculator.kt). */
export class IrisGazeCalculator {
  sensitivityX = 2.5
  sensitivityY = 3.0
  offsetX = 0.0
  offsetY = 0.3
  headPoseCompensationEnabled = true
  headYawCompensation = 0.3
  headPitchCompensation = 0.25

  static readonly BLINK_EAR_THRESHOLD = 0.2
  /** @deprecated Use BLINK_EAR_THRESHOLD. */
  static readonly BLINK_THRESHOLD = 0.2
  private static readonly NOSE_TIP = 1
  private static readonly CHIN = 152
  private static readonly LEFT_EYE_CORNER = 33
  private static readonly RIGHT_EYE_CORNER = 263

  estimateHeadPose(landmarks: LandmarkPoint[]): [number, number, number] {
    const maxIdx = Math.max(
      IrisGazeCalculator.NOSE_TIP,
      IrisGazeCalculator.CHIN,
      IrisGazeCalculator.LEFT_EYE_CORNER,
      IrisGazeCalculator.RIGHT_EYE_CORNER,
    )
    if (landmarks.length <= maxIdx) return [0, 0, 0]

    try {
      const noseTip = landmarks[IrisGazeCalculator.NOSE_TIP]
      const chin = landmarks[IrisGazeCalculator.CHIN]
      const leftEye = landmarks[IrisGazeCalculator.LEFT_EYE_CORNER]
      const rightEye = landmarks[IrisGazeCalculator.RIGHT_EYE_CORNER]

      const eyeMidX = (leftEye.x + rightEye.x) / 2
      const yaw = (noseTip.x - eyeMidX) * 100

      const noseY = noseTip.y
      const chinY = chin.y
      const eyeMidY = (leftEye.y + rightEye.y) / 2
      const noseToEyeY = noseY - eyeMidY
      const noseToChinY = chinY - noseY
      const expectedRatio = 0.6
      const actualRatio = noseToChinY > 0.01 ? noseToEyeY / noseToChinY : expectedRatio
      const pitch = (actualRatio - expectedRatio) * 150

      const eyeDeltaY = rightEye.y - leftEye.y
      const eyeDeltaX = rightEye.x - leftEye.x
      const roll = eyeDeltaX > 0.01 ? (Math.atan2(eyeDeltaY, eyeDeltaX) * 180) / Math.PI : 0

      return [
        Math.min(45, Math.max(-45, yaw)),
        Math.min(45, Math.max(-45, pitch)),
        Math.min(45, Math.max(-45, roll)),
      ]
    } catch {
      return [0, 0, 0]
    }
  }

  applyHeadPoseCompensation(
    gazeX: number,
    gazeY: number,
    headYaw: number,
    headPitch: number,
  ): [number, number] {
    if (!this.headPoseCompensationEnabled) return [gazeX, gazeY]
    const yawCorrection = (-headYaw / 45) * this.headYawCompensation
    const pitchCorrection = (-headPitch / 45) * this.headPitchCompensation
    return [
      Math.min(1, Math.max(-1, gazeX + yawCorrection)),
      Math.min(1, Math.max(-1, gazeY + pitchCorrection)),
    ]
  }

  calculateIrisPosition(
    outer: LandmarkPoint,
    inner: LandmarkPoint,
    irisCenter: LandmarkPoint,
    frameWidth: number,
    frameHeight: number,
  ): [[number, number] | null, [number, number] | null] {
    try {
      const outerPx = [outer.x * frameWidth, outer.y * frameHeight]
      const innerPx = [inner.x * frameWidth, inner.y * frameHeight]
      const eyeWidth = Math.hypot(innerPx[0] - outerPx[0], innerPx[1] - outerPx[1])
      if (eyeWidth < 1) return [null, null]

      const eyeCenter = [(outerPx[0] + innerPx[0]) / 2, (outerPx[1] + innerPx[1]) / 2]
      const irisPx = [irisCenter.x * frameWidth, irisCenter.y * frameHeight]

      let gazeX = ((irisPx[0] - eyeCenter[0]) / (eyeWidth / 2)) * this.sensitivityX
      let gazeY = ((irisPx[1] - eyeCenter[1]) / (eyeWidth / 4)) * this.sensitivityY
      gazeX += this.offsetX
      gazeY += this.offsetY

      return [
        [Math.min(1, Math.max(-1, gazeX)), Math.min(1, Math.max(-1, gazeY))],
        [irisPx[0], irisPx[1]],
      ]
    } catch {
      return [null, null]
    }
  }

  private distancePx(
    a: LandmarkPoint,
    b: LandmarkPoint,
    frameWidth: number,
    frameHeight: number,
  ): number {
    const dx = (a.x - b.x) * frameWidth
    const dy = (a.y - b.y) * frameHeight
    return Math.hypot(dx, dy)
  }

  /**
   * Eye Aspect Ratio blink detection (distance-invariant), matching shared IrisGazeCalculator.kt.
   */
  detectBlink(
    eyeTop: LandmarkPoint,
    eyeBottom: LandmarkPoint,
    eyeOuter: LandmarkPoint,
    eyeInner: LandmarkPoint,
    frameWidth: number,
    frameHeight: number,
  ): boolean {
    try {
      const eyeHeight = this.distancePx(eyeTop, eyeBottom, frameWidth, frameHeight)
      const eyeWidth = this.distancePx(eyeOuter, eyeInner, frameWidth, frameHeight)
      if (eyeWidth < 1) return false
      return eyeHeight / eyeWidth < IrisGazeCalculator.BLINK_EAR_THRESHOLD
    } catch {
      return false
    }
  }

  combineGaze(
    leftGaze: [number, number] | null,
    rightGaze: [number, number] | null,
  ): [[number, number], number] | null {
    if (leftGaze && rightGaze) {
      return [[(leftGaze[0] + rightGaze[0]) / 2, (leftGaze[1] + rightGaze[1]) / 2], 1.0]
    }
    if (leftGaze) return [leftGaze, 0.7]
    if (rightGaze) return [rightGaze, 0.7]
    return null
  }
}
