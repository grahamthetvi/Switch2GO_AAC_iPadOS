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

/** Constant-velocity 2D Kalman filter (ported from shared KalmanFilter2D.kt). */
export class KalmanFilter2D {
  private state = [0, 0, 0, 0]
  private P = createIdentityMatrix(4)
  private initialized = false

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

  private readonly Q: Matrix
  private readonly R: Matrix

  constructor(
    processNoise = 1e-4,
    measurementNoise = 1e-2,
  ) {
    this.Q = createIdentityMatrix(4).map((row) => row.map((v) => v * processNoise))
    this.R = [
      [measurementNoise, 0],
      [0, measurementNoise],
    ]
  }

  predict(): [number, number] {
    if (!this.initialized) return [this.state[0], this.state[1]]
    this.state = multiplyMatrixVector(this.F, this.state)
    const FP = multiplyMatrices(this.F, this.P)
    this.P = addMatrices(multiplyMatrices(FP, transpose(this.F)), this.Q)
    return [this.state[0], this.state[1]]
  }

  update(x: number, y: number): [number, number] {
    if (!this.initialized) {
      this.state = [x, y, 0, 0]
      this.initialized = true
      return [x, y]
    }

    this.predict()
    const Hx = multiplyMatrixVector(this.H, this.state)
    const innovation = [x - Hx[0], y - Hx[1]]
    const HP = multiplyMatrices(this.H, this.P)
    const S = addMatrices2x2(multiplyMatrices(HP, transpose(this.H)), this.R)
    const K = multiplyMatrices(multiplyMatrices(this.P, transpose(this.H)), inverse2x2(S))
    const correction = multiplyMatrixVector4x2(K, innovation)
    this.state = this.state.map((v, i) => v + correction[i])
    const KH = multiplyMatrices(K, this.H)
    this.P = multiplyMatrices(subtractFromIdentity(KH), this.P)
    return [this.state[0], this.state[1]]
  }

  reset(): void {
    this.state = [0, 0, 0, 0]
    this.P = createIdentityMatrix(4)
    this.initialized = false
  }
}
