import {
  addMatrices,
  addMatrices2x2,
  createIdentityMatrix,
  inverse2x2,
  multiplyMatrices,
  multiplyMatrixVector,
  multiplyMatrixVector4x2,
  subtractFromIdentity,
  transpose,
  type Matrix,
} from './matrixMath'

/** Velocity-adaptive 2D Kalman filter (ported from shared AdaptiveKalmanFilter2D.kt). */
export class AdaptiveKalmanFilter2D {
  private state = [0, 0, 0, 0]
  private P = createIdentityMatrix(4)
  private initialized = false
  private velocityHistory: number[] = []

  private readonly F: Matrix = [
    [1, 0, 1, 0],
    [0, 1, 0, 1],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
  ]

  private readonly H: Matrix = [
    [1, 0, 0, 0],
    [0, 1, 0, 0],
  ]

  constructor(
    private readonly baseProcessNoise = 1e-4,
    private readonly baseMeasurementNoise = 1e-2,
    private readonly lowVelocityThreshold = 0.02,
    private readonly highVelocityThreshold = 0.15,
    private readonly dwellMeasurementMultiplier = 3.0,
    private readonly rapidMeasurementMultiplier = 0.3,
  ) {}

  predict(): [number, number] {
    if (!this.initialized) return [this.state[0], this.state[1]]
    const Q = this.getAdaptiveProcessNoise()
    this.state = multiplyMatrixVector(this.F, this.state)
    const FP = multiplyMatrices(this.F, this.P)
    this.P = addMatrices(multiplyMatrices(FP, transpose(this.F)), Q)
    return [this.state[0], this.state[1]]
  }

  update(x: number, y: number): [number, number] {
    if (!this.initialized) {
      this.state = [x, y, 0, 0]
      this.initialized = true
      return [x, y]
    }

    this.predict()
    const R = this.getAdaptiveMeasurementNoise()
    const Hx = multiplyMatrixVector(this.H, this.state)
    const innovation = [x - Hx[0], y - Hx[1]]
    const HP = multiplyMatrices(this.H, this.P)
    const S = addMatrices2x2(multiplyMatrices(HP, transpose(this.H)), R)
    const K = multiplyMatrices(multiplyMatrices(this.P, transpose(this.H)), inverse2x2(S))
    const correction = multiplyMatrixVector4x2(K, innovation)
    this.state = this.state.map((v, i) => v + correction[i])
    const KH = multiplyMatrices(K, this.H)
    this.P = multiplyMatrices(subtractFromIdentity(KH), this.P)
    this.updateVelocityHistory()
    return [this.state[0], this.state[1]]
  }

  reset(): void {
    this.state = [0, 0, 0, 0]
    this.P = createIdentityMatrix(4)
    this.initialized = false
    this.velocityHistory = []
  }

  private getAdaptiveMeasurementNoise(): Matrix {
    const velocity = this.getSmoothedVelocity()
    let adaptiveMultiplier: number
    if (velocity <= this.lowVelocityThreshold) {
      adaptiveMultiplier = this.dwellMeasurementMultiplier
    } else if (velocity >= this.highVelocityThreshold) {
      adaptiveMultiplier = this.rapidMeasurementMultiplier
    } else {
      const t =
        (velocity - this.lowVelocityThreshold) /
        (this.highVelocityThreshold - this.lowVelocityThreshold)
      const smoothT = t * t * (3 - 2 * t)
      adaptiveMultiplier =
        this.dwellMeasurementMultiplier +
        smoothT * (this.rapidMeasurementMultiplier - this.dwellMeasurementMultiplier)
    }
    const noise = this.baseMeasurementNoise * adaptiveMultiplier
    return [
      [noise, 0],
      [0, noise],
    ]
  }

  private getAdaptiveProcessNoise(): Matrix {
    const velocity = this.getSmoothedVelocity()
    const velocityFactor = Math.min(2, Math.max(0.5, velocity / this.highVelocityThreshold))
    const noise = this.baseProcessNoise * velocityFactor
    return createIdentityMatrix(4).map((row) => row.map((v) => v * noise))
  }

  private updateVelocityHistory(): void {
    const velocity = Math.hypot(this.state[2], this.state[3])
    this.velocityHistory.push(velocity)
    if (this.velocityHistory.length > 5) this.velocityHistory.shift()
  }

  private getSmoothedVelocity(): number {
    if (this.velocityHistory.length === 0) return Math.hypot(this.state[2], this.state[3])
    return this.velocityHistory.reduce((a, b) => a + b, 0) / this.velocityHistory.length
  }
}
