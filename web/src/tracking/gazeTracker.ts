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

  smoothingMode: SmoothingMode = 'adaptive'
  eyeSelection: EyeSelection = 'both'
  trackingMethod: TrackingMethod = '2D'

  constructor(screenWidth: number, screenHeight: number) {
    this.screenWidth = screenWidth
    this.screenHeight = screenHeight
  }

  setLerpFactor(factor: number): void {
    this.lerpFactor = Math.min(1, Math.max(0.05, factor))
  }

  setGazeOffsets(offsetX: number, offsetY: number): void {
    this.gazeCalculator.offsetX = Math.min(1, Math.max(-1, offsetX))
    this.gazeCalculator.offsetY = Math.min(1, Math.max(-1, offsetY))
    this.eyeball3DCalculator.offsetX = Math.min(1, Math.max(-1, offsetX))
    this.eyeball3DCalculator.offsetY = Math.min(1, Math.max(-1, offsetY))
  }

  setHeadPoseCompensationEnabled(enabled: boolean): void {
    this.gazeCalculator.headPoseCompensationEnabled = enabled
    this.eyeball3DCalculator.headPoseCompensationEnabled = enabled
  }

  updateScreenDimensions(width: number, height: number): void {
    if (width === this.screenWidth && height === this.screenHeight) return
    this.screenWidth = width
    this.screenHeight = height
  }

  usesScreenLerp(): boolean {
    return this.smoothingMode === 'simple'
  }

  processFrame(frame: FaceLandmarkFrame): GazeResult | null {
    const { landmarks, frameWidth, frameHeight } = frame
    if (landmarks.length === 0) return null
    return this.trackingMethod === '3D'
      ? this.process3D(landmarks, frameWidth, frameHeight)
      : this.process2D(landmarks, frameWidth, frameHeight)
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
  }

  private process2D(
    landmarks: FaceLandmarkFrame['landmarks'],
    frameWidth: number,
    frameHeight: number,
  ): GazeResult | null {
    const [headYaw, headPitch, headRoll] = this.gazeCalculator.estimateHeadPose(landmarks)

    const leftBlink =
      landmarks.length > 145
        ? this.gazeCalculator.detectBlink(landmarks[159], landmarks[145])
        : false
    const rightBlink =
      landmarks.length > 374
        ? this.gazeCalculator.detectBlink(landmarks[386], landmarks[374])
        : false

    let leftGaze: [number, number] | null = null
    let leftIrisCenter: [number, number] | null = null
    let rightGaze: [number, number] | null = null
    let rightIrisCenter: [number, number] | null = null

    const useLeft = this.eyeSelection === 'both' || this.eyeSelection === 'left'
    if (useLeft && !leftBlink && landmarks.length > 468) {
      const [gaze, center] = this.gazeCalculator.calculateIrisPosition(
        landmarks[33],
        landmarks[133],
        landmarks[468],
        frameWidth,
        frameHeight,
      )
      leftGaze = gaze
      leftIrisCenter = center
    }

    const useRight = this.eyeSelection === 'both' || this.eyeSelection === 'right'
    if (useRight && !rightBlink && landmarks.length > 473) {
      const [gaze, center] = this.gazeCalculator.calculateIrisPosition(
        landmarks[362],
        landmarks[263],
        landmarks[473],
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
    const [smoothedX, smoothedY] = this.applySmoothing(compensatedX, compensatedY)

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

    const leftBlink = calc.detectBlink(landmarks, LEFT_EYE_TOP, LEFT_EYE_BOTTOM)
    const rightBlink = calc.detectBlink(landmarks, RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM)

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

    const [smoothedX, smoothedY] = this.applySmoothing(combined[0], combined[1])

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

  private applySmoothing(gazeX: number, gazeY: number): [number, number] {
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
        return this.kalmanFilter.update(gazeX, gazeY)
      case 'adaptive':
        return this.adaptiveKalmanFilter.update(gazeX, gazeY)
      case 'combined': {
        const [fx, fy] = this.adaptiveKalmanFilter.update(gazeX, gazeY)
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
