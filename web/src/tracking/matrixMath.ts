export type Matrix = number[][]

export function createIdentityMatrix(size: number): Matrix {
  return Array.from({ length: size }, (_, i) =>
    Array.from({ length: size }, (_, j) => (i === j ? 1 : 0)),
  )
}

export function multiplyMatrixVector(matrix: Matrix, vector: number[]): number[] {
  return matrix.map((row) => row.reduce((sum, val, j) => sum + val * vector[j], 0))
}

export function multiplyMatrixVector4x2(matrix: Matrix, vector: number[]): number[] {
  const result = [0, 0, 0, 0]
  for (let i = 0; i < 4; i++) {
    result[i] = matrix[i][0] * vector[0] + matrix[i][1] * vector[1]
  }
  return result
}

export function multiplyMatrices(a: Matrix, b: Matrix): Matrix {
  const rowsA = a.length
  const colsA = a[0].length
  const colsB = b[0].length
  const result: Matrix = Array.from({ length: rowsA }, () => Array(colsB).fill(0))
  for (let i = 0; i < rowsA; i++) {
    for (let j = 0; j < colsB; j++) {
      let sum = 0
      for (let k = 0; k < colsA; k++) sum += a[i][k] * b[k][j]
      result[i][j] = sum
    }
  }
  return result
}

export function transpose(matrix: Matrix): Matrix {
  const rows = matrix.length
  const cols = matrix[0].length
  return Array.from({ length: cols }, (_, j) =>
    Array.from({ length: rows }, (_, i) => matrix[i][j]),
  )
}

export function addMatrices(a: Matrix, b: Matrix): Matrix {
  return a.map((row, i) => row.map((val, j) => val + b[i][j]))
}

export function addMatrices2x2(a: Matrix, b: Matrix): Matrix {
  return [
    [a[0][0] + b[0][0], a[0][1] + b[0][1]],
    [a[1][0] + b[1][0], a[1][1] + b[1][1]],
  ]
}

export function subtractFromIdentity(matrix: Matrix): Matrix {
  const size = matrix.length
  return Array.from({ length: size }, (_, i) =>
    Array.from({ length: size }, (_, j) => (i === j ? 1 : 0) - matrix[i][j]),
  )
}

export function inverse2x2(matrix: Matrix): Matrix {
  const a = matrix[0][0]
  const b = matrix[0][1]
  const c = matrix[1][0]
  const d = matrix[1][1]
  const det = a * d - b * c
  if (det === 0) {
    return [
      [1, 0],
      [0, 1],
    ]
  }
  const invDet = 1 / det
  return [
    [d * invDet, -b * invDet],
    [-c * invDet, a * invDet],
  ]
}
