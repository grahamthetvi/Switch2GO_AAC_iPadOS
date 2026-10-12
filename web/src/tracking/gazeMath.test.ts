import { describe, expect, it } from 'vitest'
import { IrisGazeCalculator } from './irisGazeCalculator'
import { KalmanFilter2D } from './kalmanFilter2D'
import { GazeTracker } from './gazeTracker'
import type { LandmarkPoint } from './types'

function lm(x: number, y: number, z = 0): LandmarkPoint {
  return { x, y, z }
}

describe('IrisGazeCalculator EAR blink', () => {
  const calc = new IrisGazeCalculator()

  it('detects closed eye via EAR', () => {
    // Wide eye horizontally, tiny vertical gap → blink
    const blinking = calc.detectBlink(
      lm(0.5, 0.4),
      lm(0.5, 0.405),
      lm(0.4, 0.4),
      lm(0.6, 0.4),
      640,
      480,
    )
    expect(blinking).toBe(true)
  })

  it('does not flag open eye', () => {
    const open = calc.detectBlink(
      lm(0.5, 0.35),
      lm(0.5, 0.45),
      lm(0.4, 0.4),
      lm(0.6, 0.4),
      640,
      480,
    )
    expect(open).toBe(false)
  })
})

describe('KalmanFilter2D dt', () => {
  it('accepts dtSeconds and returns smoothed position', () => {
    const filter = new KalmanFilter2D()
    const [x1, y1] = filter.update(0.1, 0.2, 0.05)
    expect(x1).toBeCloseTo(0.1)
    expect(y1).toBeCloseTo(0.2)
    const [x2, y2] = filter.update(0.12, 0.22, 0.05)
    expect(typeof x2).toBe('number')
    expect(typeof y2).toBe('number')
  })
})

describe('GazeTracker blink hold', () => {
  it('returns blink-only result holding last gaze when both eyes blink', () => {
    const tracker = new GazeTracker(800, 600)
    const landmarks: LandmarkPoint[] = Array.from({ length: 480 }, () => lm(0.5, 0.5))

    // Seed last gaze via a normal frame path is hard without full iris geometry;
    // call processFrame with empty iris but both-eye blink EAR geometry.
    // Set eye corners + lids for left/right blink EAR.
    landmarks[33] = lm(0.3, 0.4) // LEFT_EYE_OUTER
    landmarks[133] = lm(0.4, 0.4) // LEFT_EYE_INNER
    landmarks[159] = lm(0.35, 0.395) // LEFT_EYE_TOP (nearly closed)
    landmarks[145] = lm(0.35, 0.4) // LEFT_EYE_BOTTOM
    landmarks[362] = lm(0.6, 0.4) // RIGHT_EYE_OUTER
    landmarks[263] = lm(0.7, 0.4) // RIGHT_EYE_INNER
    landmarks[386] = lm(0.65, 0.395)
    landmarks[374] = lm(0.65, 0.4)

    const result = tracker.processFrame(
      { landmarks, frameWidth: 640, frameHeight: 480 },
      1000,
    )
    expect(result).not.toBeNull()
    expect(result!.leftBlink).toBe(true)
    expect(result!.rightBlink).toBe(true)
    expect(result!.confidence).toBe(0)
    // No prior gaze → holds at 0
    expect(result!.gazeX).toBe(0)
    expect(result!.gazeY).toBe(0)
  })
})
