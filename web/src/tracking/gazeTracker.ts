import { AdaptiveKalmanFilter2D } from './adaptiveKalmanFilter2D'
import { Eyeball3DGazeCalculator } from './eyeball3DGazeCalculator'
import { IrisGazeCalculator } from './irisGazeCalculator'
import { KalmanFilter2D } from './kalmanFilter2D'
import type {
  EyeSelection,
  FaceLandmarkFrame,
  GazeResult,
  SmoothingMode,
  TrackingMethod,
} from './types'

/** Gaze pipeline coordinator (ported from shared GazeTracker.kt, no calibration). */
export class GazeTracker {
  private readonly gazeCalculator = new IrisGazeCalculator()
  private readonly eyeball3DCalculator = new Eyeball3DGazeCalculator()
  private readonly kalmanFilter = new KalmanFilter2D()
  private readonly adaptiveKalmanFilter = new AdaptiveKalmanFilter2D()

  private screenWidth: number
  private screenHeight: number
  private oldGazeX: number | null = null
  private oldGazeY: number | null = null
  private lerpFactor = 0.3
  private lastGazeX: number | null = null
  private lastGazeY: number | null = null
  private lastSmoothTimestampMs: number | null = null

  smoothingMode: SmoothingMode = 'adaptive'
  eyeSelection: EyeSelection = 'both'
  trackingMethod: TrackingMethod = '2D'

  private static readonly LEFT_EYE_OUTER = 33
  private static readonly LEFT_EYE_INNER = 133
  private static readonly LEFT_EYE_TOP = 159
  private static readonly LEFT_EYE_BOTTOM = 145
  private static readonly RIGHT_EYE_OUTER = 362
  private static readonly RIGHT_EYE_INNER = 263
  private static readonly RIGHT_EYE_TOP = 386
  private static readonly RIGHT_EYE_BOTTOM = 374
  private static readonly LEFT_IRIS_CENTER = 468
  private static readonly RIGHT_IRIS_CENTER = 473

  constructor(screenWidth: number, screenHeight: number) {
    this.screenWidth = screenWidth
    this.screenHeight = screenHeight
  }

  setLerpFactor(factor: number): void {
    this.lerpFactor = Math.min(1, Math.max(0.05, factor))
  }

  /** Match KMP: offsets apply to the iris (2D) calculator only. */
  setGazeOffsets(offsetX: number, offsetY: number): void {
    this.gazeCalculator.offsetX = Math.min(1, Math.max(-1, offsetX))
    this.gazeCalculator.offsetY = Math.min(1, Math.max(-1, offsetY))
  }

  updateScreenDimensions(width: number, height: number): void {
    if (width === this.screenWidth && height === this.screenHeight) return
    this.screenWidth = width
    this.screenHeight = height
  }

  usesScreenLerp(): boolean {
    return this.smoothingMode === 'simple'
  }

  processFrame(frame: FaceLandmarkFrame, timestampMs: number = performance.now()): GazeResult | null {
    const { landmarks, frameWidth, frameHeight } = frame
    if (landmarks.length === 0) return null
    return this.trackingMethod === '3D'
      ? this.process3D(landmarks, frameWidth, frameHeight, timestampMs)
      : this.process2D(landmarks, frameWidth, frameHeight, timestampMs)
  }

  /** Linear gaze-to-screen mapping (no calibration UI). */
  gazeToScreen(gazeX: number, gazeY: number): [number, number] {
    const x = Math.round(((gazeX + 1) / 2) * this.screenWidth)
    const y = Math.round(((gazeY + 1) / 2) * this.screenHeight)
    return [
      Math.min(this.screenWidth - 1, Math.max(0, x)),
      Math.min(this.screenHeight - 1, Math.max(0, y)),
    ]
  }

  reset(): void {
    this.kalmanFilter.reset()
    this.adaptiveKalmanFilter.reset()
    this.oldGazeX = null
    this.oldGazeY = null
    this.lastGazeX = null
    this.lastGazeY = null
    this.lastSmoothTimestampMs = null
  }

  private blinkOnlyResult(headYaw: number, headPitch: number, headRoll: number): GazeResult {
    return {
      gazeX: this.lastGazeX ?? 0,
      gazeY: this.lastGazeY ?? 0,
      leftIrisCenter: null,
      rightIrisCenter: null,
      confidence: 0,
      leftBlink: true,
      rightBlink: true,
      headYaw,
      headPitch,
      headRoll,
    }
  }

  private process2D(
    landmarks: FaceLandmarkFrame['landmarks'],
    frameWidth: number,
    frameHeight: number,
    timestampMs: number,
  ): GazeResult | null {
    const [headYaw, headPitch, headRoll] = this.gazeCalculator.estimateHeadPose(landmarks)
    const {
      LEFT_EYE_OUTER,
      LEFT_EYE_INNER,
      LEFT_EYE_TOP,
      LEFT_EYE_BOTTOM,
      RIGHT_EYE_OUTER,
      RIGHT_EYE_INNER,
      RIGHT_EYE_TOP,
      RIGHT_EYE_BOTTOM,
      LEFT_IRIS_CENTER,
      RIGHT_IRIS_CENTER,
    } = GazeTracker

    const maxLeft = Math.max(LEFT_EYE_TOP, LEFT_EYE_BOTTOM, LEFT_EYE_OUTER, LEFT_EYE_INNER)
    const maxRight = Math.max(RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM, RIGHT_EYE_OUTER, RIGHT_EYE_INNER)

    const leftBlink =
      landmarks.length > maxLeft
        ? this.gazeCalculator.detectBlink(
            landmarks[LEFT_EYE_TOP],
            landmarks[LEFT_EYE_BOTTOM],
            landmarks[LEFT_EYE_OUTER],
            landmarks[LEFT_EYE_INNER],
            frameWidth,
            frameHeight,
          )
        : false
    const rightBlink =
      landmarks.length > maxRight
        ? this.gazeCalculator.detectBlink(
            landmarks[RIGHT_EYE_TOP],
            landmarks[RIGHT_EYE_BOTTOM],
            landmarks[RIGHT_EYE_OUTER],
            landmarks[RIGHT_EYE_INNER],
            frameWidth,
            frameHeight,
          )
        : false

    if (leftBlink && rightBlink) {
      return this.blinkOnlyResult(headYaw, headPitch, headRoll)
    }

    let leftGaze: [number, number] | null = null
    let leftIrisCenter: [number, number] | null = null
    let rightGaze: [number, number] | null = null
    let rightIrisCenter: [number, number] | null = null

    const useLeft = this.eyeSelection === 'both' || this.eyeSelection === 'left'
    if (useLeft && !leftBlink && landmarks.length > LEFT_IRIS_CENTER) {
      const [gaze, center] = this.gazeCalculator.calculateIrisPosition(
        landmarks[LEFT_EYE_OUTER],
        landmarks[LEFT_EYE_INNER],
        landmarks[LEFT_IRIS_CENTER],
        frameWidth,
        frameHeight,
      )
      leftGaze = gaze
      leftIrisCenter = center
    }

    const useRight = this.eyeSelection === 'both' || this.eyeSelection === 'right'
    if (useRight && !rightBlink && landmarks.length > RIGHT_IRIS_CENTER) {
      const [gaze, center] = this.gazeCalculator.calculateIrisPosition(
        landmarks[RIGHT_EYE_OUTER],
        landmarks[RIGHT_EYE_INNER],
        landmarks[RIGHT_IRIS_CENTER],
        frameWidth,
        frameHeight,
      )
      rightGaze = gaze
      rightIrisCenter = center
    }

    let combined: [number, number]
    let confidence: number
    if (this.eyeSelection === 'left') {
      if (!leftGaze) return null
      combined = leftGaze
      confidence = 1.0
    } else if (this.eyeSelection === 'right') {
      if (!rightGaze) return null
      combined = rightGaze
      confidence = 1.0
    } else {
      const merged = this.gazeCalculator.combineGaze(leftGaze, rightGaze)
      if (!merged) return null
      combined = merged[0]
      confidence = merged[1]
    }

    const [compensatedX, compensatedY] = this.gazeCalculator.applyHeadPoseCompensation(
      combined[0],
      combined[1],
      headYaw,
      headPitch,
    )
    const [smoothedX, smoothedY] = this.applySmoothing(compensatedX, compensatedY, timestampMs)
    this.lastGazeX = smoothedX
    this.lastGazeY = smoothedY

    return {
      gazeX: smoothedX,
      gazeY: smoothedY,
      leftIrisCenter,
      rightIrisCenter,
      confidence,
      leftBlink,
      rightBlink,
      headYaw,
      headPitch,
      headRoll,
    }
  }

  private process3D(
    landmarks: FaceLandmarkFrame['landmarks'],
    frameWidth: number,
    frameHeight: number,
    timestampMs: number,
  ): GazeResult | null {
    const calc = this.eyeball3DCalculator
    const {
      LEFT_EYE_TOP,
      LEFT_EYE_BOTTOM,
      RIGHT_EYE_TOP,
      RIGHT_EYE_BOTTOM,
      LEFT_EYE_OUTER,
      LEFT_EYE_INNER,
      LEFT_IRIS_CENTER,
      RIGHT_EYE_OUTER,
      RIGHT_EYE_INNER,
      RIGHT_IRIS_CENTER,
    } = Eyeball3DGazeCalculator
    const [headYaw, headPitch, headRoll] = calc.estimateHeadPose(landmarks, frameWidth, frameHeight)

    const leftBlink = calc.detectBlink(
      landmarks,
      LEFT_EYE_TOP,
      LEFT_EYE_BOTTOM,
      LEFT_EYE_OUTER,
      LEFT_EYE_INNER,
      frameWidth,
      frameHeight,
    )
    const rightBlink = calc.detectBlink(
      landmarks,
      RIGHT_EYE_TOP,
      RIGHT_EYE_BOTTOM,
      RIGHT_EYE_OUTER,
      RIGHT_EYE_INNER,
      frameWidth,
      frameHeight,
    )

    if (leftBlink && rightBlink) {
      return this.blinkOnlyResult(headYaw, headPitch, headRoll)
    }

    const useLeft = this.eyeSelection === 'both' || this.eyeSelection === 'left'
    const useRight = this.eyeSelection === 'both' || this.eyeSelection === 'right'

    const leftEye =
      useLeft && !leftBlink
        ? calc.buildEyeballModel(
            landmarks,
            LEFT_EYE_OUTER,
            LEFT_EYE_INNER,
            LEFT_EYE_TOP,
            LEFT_EYE_BOTTOM,
            LEFT_IRIS_CENTER,
            frameWidth,
            frameHeight,
          )
        : null

    const rightEye =
      useRight && !rightBlink
        ? calc.buildEyeballModel(
            landmarks,
            RIGHT_EYE_OUTER,
            RIGHT_EYE_INNER,
            RIGHT_EYE_TOP,
            RIGHT_EYE_BOTTOM,
            RIGHT_IRIS_CENTER,
            frameWidth,
            frameHeight,
          )
        : null

    const combined = calc.combineGaze(leftEye, rightEye, headYaw, headPitch, this.eyeSelection)
    if (!combined) return null

    const [smoothedX, smoothedY] = this.applySmoothing(combined[0], combined[1], timestampMs)
    this.lastGazeX = smoothedX
    this.lastGazeY = smoothedY

    const leftIrisCenter: [number, number] | null =
      landmarks.length > LEFT_IRIS_CENTER
        ? [
            landmarks[LEFT_IRIS_CENTER].x * frameWidth,
            landmarks[LEFT_IRIS_CENTER].y * frameHeight,
          ]
        : null
    const rightIrisCenter: [number, number] | null =
      landmarks.length > RIGHT_IRIS_CENTER
        ? [
            landmarks[RIGHT_IRIS_CENTER].x * frameWidth,
            landmarks[RIGHT_IRIS_CENTER].y * frameHeight,
          ]
        : null

    return {
      gazeX: smoothedX,
      gazeY: smoothedY,
      leftIrisCenter,
      rightIrisCenter,
      confidence: combined[2],
      leftBlink,
      rightBlink,
      headYaw,
      headPitch,
      headRoll,
    }
  }

  private computeSmoothDt(timestampMs: number): number {
    const DEFAULT_DT = 1 / 20
    const MIN_DT = 1 / 120
    const MAX_DT = 0.25
    if (this.lastSmoothTimestampMs == null || timestampMs <= 0) {
      this.lastSmoothTimestampMs = timestampMs
      return DEFAULT_DT
    }
    const dt = (timestampMs - this.lastSmoothTimestampMs) / 1000
    this.lastSmoothTimestampMs = timestampMs
    return Math.min(MAX_DT, Math.max(MIN_DT, dt))
  }

  private applySmoothing(gazeX: number, gazeY: number, timestampMs: number): [number, number] {
    const dt = this.computeSmoothDt(timestampMs)
    switch (this.smoothingMode) {
      case 'none':
        return [gazeX, gazeY]
      case 'simple': {
        const ox = this.oldGazeX
        const oy = this.oldGazeY
        if (ox == null || oy == null) {
          this.oldGazeX = gazeX
          this.oldGazeY = gazeY
          return [gazeX, gazeY]
        }
        const nx = ox + this.lerpFactor * (gazeX - ox)
        const ny = oy + this.lerpFactor * (gazeY - oy)
        this.oldGazeX = nx
        this.oldGazeY = ny
        return [nx, ny]
      }
      case 'kalman':
        return this.kalmanFilter.update(gazeX, gazeY, dt)
      case 'adaptive':
        return this.adaptiveKalmanFilter.update(gazeX, gazeY, dt)
      case 'combined': {
        const [fx, fy] = this.adaptiveKalmanFilter.update(gazeX, gazeY, dt)
        const ox = this.oldGazeX
        const oy = this.oldGazeY
        if (ox == null || oy == null) {
          this.oldGazeX = fx
          this.oldGazeY = fy
          return [fx, fy]
        }
        const combinedLerp = Math.min(this.lerpFactor * 1.5, 1)
        const nx = ox + combinedLerp * (fx - ox)
        const ny = oy + combinedLerp * (fy - oy)
        this.oldGazeX = nx
        this.oldGazeY = ny
        return [nx, ny]
      }
    }
  }
}
