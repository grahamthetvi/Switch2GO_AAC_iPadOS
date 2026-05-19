/** Normalized MediaPipe landmark (0–1 range). */
export interface LandmarkPoint {
  x: number
  y: number
  z: number
}

export interface GazeResult {
  gazeX: number
  gazeY: number
  leftIrisCenter: [number, number] | null
  rightIrisCenter: [number, number] | null
  confidence: number
  leftBlink: boolean
  rightBlink: boolean
  headYaw: number
  headPitch: number
  headRoll: number
}

export type EyeSelection = 'left' | 'right' | 'both'

export type TrackingMethod = '2D' | '3D'

export type SmoothingMode = 'none' | 'simple' | 'kalman' | 'adaptive' | 'combined'

export interface FaceLandmarkFrame {
  landmarks: LandmarkPoint[]
  frameWidth: number
  frameHeight: number
  /** 4×4 row-major facial transformation matrix when available. */
  facialTransformationMatrix?: Float32Array | number[]
}
