import { IrisGazeCalculator } from './irisGazeCalculator'
import type { EyeSelection, LandmarkPoint } from './types'

/** 3D eyeball gaze math (ported from shared Eyeball3DGazeCalculator.kt). */
export class Eyeball3DGazeCalculator {
  sensitivityX = 2.0
  sensitivityY = 2.5
  offsetX = 0.0
  offsetY = 0.0
  headPoseCompensationEnabled = true

  static readonly LEFT_EYE_OUTER = 33
  static readonly LEFT_EYE_INNER = 133
  static readonly LEFT_EYE_TOP = 159
  static readonly LEFT_EYE_BOTTOM = 145
  static readonly LEFT_IRIS_CENTER = 468
  static readonly RIGHT_EYE_OUTER = 362
  static readonly RIGHT_EYE_INNER = 263
  static readonly RIGHT_EYE_TOP = 386
  static readonly RIGHT_EYE_BOTTOM = 374
  static readonly RIGHT_IRIS_CENTER = 473
  static readonly NOSE_TIP = 1
  static readonly CHIN = 152
  static readonly FOREHEAD = 10
  static readonly LEFT_EAR = 234
  static readonly RIGHT_EAR = 454

  private static readonly CORNEA_OFFSET_RATIO = 0.38
  private static readonly PUPIL_DEPTH_RATIO = 0.15

  estimateHeadPose(
    landmarks: LandmarkPoint[],
    _frameWidth: number,
    _frameHeight: number,
  ): [number, number, number] {
    const maxIdx = Math.max(
      Eyeball3DGazeCalculator.NOSE_TIP,
      Eyeball3DGazeCalculator.CHIN,
      Eyeball3DGazeCalculator.FOREHEAD,
      Eyeball3DGazeCalculator.LEFT_EAR,
      Eyeball3DGazeCalculator.RIGHT_EAR,
      Eyeball3DGazeCalculator.RIGHT_EYE_OUTER,
    )
    if (landmarks.length <= maxIdx) return [0, 0, 0]

    try {
      const noseTip = landmarks[Eyeball3DGazeCalculator.NOSE_TIP]
      const chin = landmarks[Eyeball3DGazeCalculator.CHIN]
      const forehead = landmarks[Eyeball3DGazeCalculator.FOREHEAD]
      const leftEar = landmarks[Eyeball3DGazeCalculator.LEFT_EAR]
      const rightEar = landmarks[Eyeball3DGazeCalculator.RIGHT_EAR]

      const earMidX = (leftEar.x + rightEar.x) / 2
      const yaw = (noseTip.x - earMidX) * 100

      const faceHeight = chin.y - forehead.y
      const noseRelative = faceHeight !== 0 ? (noseTip.y - forehead.y) / faceHeight : 0.45
      const pitch = (noseRelative - 0.45) * 150

      const eyeDeltaY =
        landmarks[Eyeball3DGazeCalculator.RIGHT_EYE_OUTER].y -
        landmarks[Eyeball3DGazeCalculator.LEFT_EYE_OUTER].y
      const eyeDeltaX =
        landmarks[Eyeball3DGazeCalculator.RIGHT_EYE_OUTER].x -
        landmarks[Eyeball3DGazeCalculator.LEFT_EYE_OUTER].x
      const roll = (Math.atan2(eyeDeltaY, eyeDeltaX) * 180) / Math.PI

      return [
        Math.min(45, Math.max(-45, yaw)),
        Math.min(45, Math.max(-45, pitch)),
        Math.min(45, Math.max(-45, roll)),
      ]
    } catch {
      return [0, 0, 0]
    }
  }

  buildEyeballModel(
    landmarks: LandmarkPoint[],
    eyeOuter: number,
    eyeInner: number,
    eyeTop: number,
    eyeBottom: number,
    irisCenter: number,
    frameWidth: number,
    frameHeight: number,
  ): { gazeYaw: number; gazePitch: number } | null {
    if (landmarks.length <= Math.max(eyeOuter, eyeInner, eyeTop, eyeBottom)) return null

    try {
      const outer = landmarks[eyeOuter]
      const inner = landmarks[eyeInner]
      const top = landmarks[eyeTop]
      const bottom = landmarks[eyeBottom]

      const outerPoint = this.point3(outer, frameWidth, frameHeight)
      const innerPoint = this.point3(inner, frameWidth, frameHeight)
      const topPoint = this.point3(top, frameWidth, frameHeight)
      const bottomPoint = this.point3(bottom, frameWidth, frameHeight)

      const eyeCenter = {
        x: (outerPoint.x + innerPoint.x) / 2,
        y: (topPoint.y + bottomPoint.y) / 2,
        z: (outerPoint.z + innerPoint.z) / 2,
      }

      const eyeWidth = this.magnitude(this.subtract(innerPoint, outerPoint))
      if (eyeWidth <= 0) return null

      const corneaOffset = eyeWidth * Eyeball3DGazeCalculator.CORNEA_OFFSET_RATIO
      const eyeballCenter = { x: eyeCenter.x, y: eyeCenter.y, z: eyeCenter.z + corneaOffset }

      const irisPoint =
        landmarks.length > irisCenter
          ? this.point3(landmarks[irisCenter], frameWidth, frameHeight)
          : eyeCenter

      const pupilDepth = eyeWidth * Eyeball3DGazeCalculator.PUPIL_DEPTH_RATIO
      const pupilCenter = {
        x: irisPoint.x,
        y: irisPoint.y,
        z: irisPoint.z - pupilDepth,
      }

      const gazeVector = this.normalized(this.subtract(pupilCenter, eyeballCenter))
      const gazeYaw = (Math.atan2(gazeVector.x, -gazeVector.z) * 180) / Math.PI
      const gazePitch =
        (Math.atan2(
          -gazeVector.y,
          Math.hypot(gazeVector.x, gazeVector.z),
        ) *
          180) /
        Math.PI

      return { gazeYaw, gazePitch }
    } catch {
      return null
    }
  }

  combineGaze(
    leftEye: { gazeYaw: number; gazePitch: number } | null,
    rightEye: { gazeYaw: number; gazePitch: number } | null,
    headYaw: number,
    headPitch: number,
    eyeSelection: EyeSelection,
  ): [number, number, number] | null {
    let avgYaw: number
    let avgPitch: number
    let confidence: number

    if (eyeSelection === 'left') {
      if (!leftEye) return null
      avgYaw = leftEye.gazeYaw
      avgPitch = leftEye.gazePitch
      confidence = 1.0
    } else if (eyeSelection === 'right') {
      if (!rightEye) return null
      avgYaw = rightEye.gazeYaw
      avgPitch = rightEye.gazePitch
      confidence = 1.0
    } else if (leftEye && rightEye) {
      avgYaw = (leftEye.gazeYaw + rightEye.gazeYaw) / 2
      avgPitch = (leftEye.gazePitch + rightEye.gazePitch) / 2
      confidence = 1.0
    } else if (leftEye) {
      avgYaw = leftEye.gazeYaw
      avgPitch = leftEye.gazePitch
      confidence = 0.7
    } else if (rightEye) {
      avgYaw = rightEye.gazeYaw
      avgPitch = rightEye.gazePitch
      confidence = 0.7
    } else {
      return null
    }

    const compensatedYaw = this.headPoseCompensationEnabled
      ? avgYaw - headYaw * 0.5
      : avgYaw
    const compensatedPitch = this.headPoseCompensationEnabled
      ? avgPitch - headPitch * 0.5
      : avgPitch
    const maxGazeAngle = 30
    let gazeX = (compensatedYaw / maxGazeAngle) * this.sensitivityX + this.offsetX
    let gazeY = (compensatedPitch / maxGazeAngle) * this.sensitivityY + this.offsetY
    gazeX = Math.min(1, Math.max(-1, gazeX))
    gazeY = Math.min(1, Math.max(-1, gazeY))
    return [gazeX, gazeY, confidence]
  }

  detectBlink(
    landmarks: LandmarkPoint[],
    eyeTop: number,
    eyeBottom: number,
    eyeOuter: number,
    eyeInner: number,
    frameWidth: number,
    frameHeight: number,
  ): boolean {
    if (landmarks.length <= Math.max(eyeTop, eyeBottom, eyeOuter, eyeInner)) return false
    try {
      const top = landmarks[eyeTop]
      const bottom = landmarks[eyeBottom]
      const outer = landmarks[eyeOuter]
      const inner = landmarks[eyeInner]

      const heightDx = (top.x - bottom.x) * frameWidth
      const heightDy = (top.y - bottom.y) * frameHeight
      const eyeHeight = Math.hypot(heightDx, heightDy)

      const widthDx = (outer.x - inner.x) * frameWidth
      const widthDy = (outer.y - inner.y) * frameHeight
      const eyeWidth = Math.hypot(widthDx, widthDy)

      if (eyeWidth < 1) return false
      return eyeHeight / eyeWidth < IrisGazeCalculator.BLINK_EAR_THRESHOLD
    } catch {
      return false
    }
  }

  private point3(lm: LandmarkPoint, frameWidth: number, frameHeight: number) {
    return { x: lm.x * frameWidth, y: lm.y * frameHeight, z: lm.z * frameWidth }
  }

  private subtract(a: { x: number; y: number; z: number }, b: { x: number; y: number; z: number }) {
    return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z }
  }

  private magnitude(p: { x: number; y: number; z: number }) {
    return Math.hypot(p.x, p.y, p.z)
  }

  private normalized(p: { x: number; y: number; z: number }) {
    const mag = this.magnitude(p)
    return mag > 0 ? { x: p.x / mag, y: p.y / mag, z: p.z / mag } : p
  }
}
