import type { LandmarkPoint, SmoothingMode } from './types'

/** Head-pose tracking for face selection mode (ported from iOS HeadPoseTracker.swift). */
export class HeadPoseTracker {
  sensitivityX = 2.0
  sensitivityY = 2.5
  cameraOffsetYaw = 0
  cameraOffsetPitch = 0

  private kalmanX = new SimpleKalmanFilter1D()
  private kalmanY = new SimpleKalmanFilter1D()
  private oldSmoothedX: number | null = null
  private oldSmoothedY: number | null = null

  processLandmarks(
    landmarks: LandmarkPoint[],
    screenWidth: number,
    screenHeight: number,
    smoothingMode: SmoothingMode,
    lerpFactor: number,
  ): { screenX: number; screenY: number; isOutOfBounds: boolean } | null {
    const pose = this.estimateHeadPose(landmarks)
    if (!pose) return null

    const adjustedYaw = pose.yaw - this.cameraOffsetYaw
    const adjustedPitch = pose.pitch - this.cameraOffsetPitch
    const maxAngle = 30
    let normalizedX = (adjustedYaw / maxAngle) * this.sensitivityX
    let normalizedY = (adjustedPitch / maxAngle) * this.sensitivityY
    normalizedX = clamp(normalizedX, -1, 1)
    normalizedY = clamp(normalizedY, -1, 1)

    const [smoothedX, smoothedY] = this.applySmoothing(
      normalizedX,
      normalizedY,
      smoothingMode,
      lerpFactor,
    )

    const screenX = clamp(((smoothedX + 1) / 2) * screenWidth, 0, screenWidth)
    const screenY = clamp(((smoothedY + 1) / 2) * screenHeight, 0, screenHeight)
    const isOutOfBounds = Math.abs(normalizedX) > 1.1 || Math.abs(normalizedY) > 1.1

    return { screenX, screenY, isOutOfBounds }
  }

  detectBlink(landmarks: LandmarkPoint[]): boolean {
    const leftTop = 159
    const leftBottom = 145
    const rightTop = 386
    const rightBottom = 374
    if (landmarks.length <= Math.max(leftTop, leftBottom, rightTop, rightBottom)) return false
    const leftHeight = Math.abs(landmarks[leftBottom].y - landmarks[leftTop].y)
    const rightHeight = Math.abs(landmarks[rightBottom].y - landmarks[rightTop].y)
    return leftHeight < 0.015 && rightHeight < 0.015
  }

  recenter(landmarks: LandmarkPoint[]): void {
    const pose = this.estimateHeadPose(landmarks)
    if (!pose) return
    this.cameraOffsetYaw = pose.yaw
    this.cameraOffsetPitch = pose.pitch
  }

  applyCameraPositionPreset(position: string): void {
    switch (position) {
      case 'left':
        this.cameraOffsetYaw = 4.0
        this.cameraOffsetPitch = 0.0
        break
      case 'right':
        this.cameraOffsetYaw = -4.0
        this.cameraOffsetPitch = 0.0
        break
      case 'center':
        this.cameraOffsetYaw = 0.0
        this.cameraOffsetPitch = 0.0
        break
    }
  }

  reset(): void {
    this.kalmanX.reset()
    this.kalmanY.reset()
    this.oldSmoothedX = null
    this.oldSmoothedY = null
  }

  private estimateHeadPose(landmarks: LandmarkPoint[]): { yaw: number; pitch: number } | null {
    const noseTip = 1
    const chin = 152
    const forehead = 10
    const leftEar = 234
    const rightEar = 454
    const maxIdx = Math.max(noseTip, chin, forehead, leftEar, rightEar)
    if (landmarks.length <= maxIdx) return null

    const nose = landmarks[noseTip]
    const chinLm = landmarks[chin]
    const foreheadLm = landmarks[forehead]
    const leftEarLm = landmarks[leftEar]
    const rightEarLm = landmarks[rightEar]

    const earMidX = (leftEarLm.x + rightEarLm.x) / 2
    const rawYaw = (nose.x - earMidX) * 100

    const faceHeight = chinLm.y - foreheadLm.y
    if (faceHeight <= 0.01) return null
    const noseRelative = (nose.y - foreheadLm.y) / faceHeight
    const rawPitch = (noseRelative - 0.45) * 150

    return {
      yaw: clamp(rawYaw, -45, 45),
      pitch: clamp(rawPitch, -45, 45),
    }
  }

  private applySmoothing(
    x: number,
    y: number,
    mode: SmoothingMode,
    lerpFactor: number,
  ): [number, number] {
    switch (mode) {
      case 'none':
        this.oldSmoothedX = x
        this.oldSmoothedY = y
        return [x, y]
      case 'simple':
        return this.applyLerp(x, y, lerpFactor)
      case 'kalman': {
        const fx = this.kalmanX.update(x)
        const fy = this.kalmanY.update(y)
        this.oldSmoothedX = fx
        this.oldSmoothedY = fy
        return [fx, fy]
      }
      case 'adaptive': {
        const fx = this.kalmanX.updateAdaptive(x)
        const fy = this.kalmanY.updateAdaptive(y)
        this.oldSmoothedX = fx
        this.oldSmoothedY = fy
        return [fx, fy]
      }
      case 'combined': {
        const fx = this.kalmanX.updateAdaptive(x)
        const fy = this.kalmanY.updateAdaptive(y)
        return this.applyLerp(fx, fy, Math.min(lerpFactor * 1.5, 1))
      }
    }
  }

  private applyLerp(x: number, y: number, alpha: number): [number, number] {
    const a = clamp(alpha, 0.05, 1)
    if (this.oldSmoothedX != null && this.oldSmoothedY != null) {
      const nx = this.oldSmoothedX + a * (x - this.oldSmoothedX)
      const ny = this.oldSmoothedY + a * (y - this.oldSmoothedY)
      this.oldSmoothedX = nx
      this.oldSmoothedY = ny
      return [nx, ny]
    }
    this.oldSmoothedX = x
    this.oldSmoothedY = y
    return [x, y]
  }
}

class SimpleKalmanFilter1D {
  private estimate = 0
  private errorEstimate = 1
  private lastEstimate = 0
  private initialized = false
  private readonly processNoise = 0.0001
  private readonly measurementNoise = 0.01
  private readonly lowVelocityThreshold = 0.02
  private readonly highVelocityThreshold = 0.15

  update(measurement: number): number {
    if (!this.initialized) {
      this.estimate = measurement
      this.lastEstimate = measurement
      this.initialized = true
      return measurement
    }
    const prediction = this.estimate
    this.errorEstimate += this.processNoise
    const kalmanGain = this.errorEstimate / (this.errorEstimate + this.measurementNoise)
    this.estimate = prediction + kalmanGain * (measurement - prediction)
    this.errorEstimate = (1 - kalmanGain) * this.errorEstimate
    this.lastEstimate = this.estimate
    return this.estimate
  }

  updateAdaptive(measurement: number): number {
    if (!this.initialized) {
      this.estimate = measurement
      this.lastEstimate = measurement
      this.initialized = true
      return measurement
    }
    const velocity = Math.abs(measurement - this.lastEstimate)
    let adaptiveNoise: number
    if (velocity < this.lowVelocityThreshold) {
      adaptiveNoise = this.measurementNoise * 3
    } else if (velocity > this.highVelocityThreshold) {
      adaptiveNoise = this.measurementNoise * 0.3
    } else {
      adaptiveNoise = this.measurementNoise
    }
    const prediction = this.estimate
    this.errorEstimate += this.processNoise
    const kalmanGain = this.errorEstimate / (this.errorEstimate + adaptiveNoise)
    this.estimate = prediction + kalmanGain * (measurement - prediction)
    this.errorEstimate = (1 - kalmanGain) * this.errorEstimate
    this.lastEstimate = this.estimate
    return this.estimate
  }

  reset(): void {
    this.estimate = 0
    this.errorEstimate = 1
    this.lastEstimate = 0
    this.initialized = false
  }
}

function clamp(value: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, value))
}
