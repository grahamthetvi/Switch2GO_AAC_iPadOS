import { describe, expect, it } from 'vitest'
import { ArmRaiseDetector } from './armRaiseDetector'
import type { LandmarkPoint } from './types'
import {
  phraseIndexForSide,
  phraseIndexForSwitch,
  userFacingHandSideFromLabel,
  userFacingSide,
} from './userFacingLaterality'

function lm(x: number, y: number): LandmarkPoint {
  return { x, y, z: 0 }
}

function makeLandmarks(leftRaised: boolean, rightRaised: boolean): LandmarkPoint[] {
  const points = Array.from({ length: 17 }, () => lm(0.5, 0.5))
  points[11] = lm(0.3, 0.4)
  points[12] = lm(0.7, 0.4)
  points[13] = lm(0.3, leftRaised ? 0.2 : 0.55)
  points[14] = lm(0.7, rightRaised ? 0.2 : 0.55)
  points[15] = lm(0.3, leftRaised ? 0.1 : 0.65)
  points[16] = lm(0.7, rightRaised ? 0.1 : 0.65)
  return points
}

describe('userFacingLaterality', () => {
  it('maps user-left to phrase index 0', () => {
    expect(phraseIndexForSide('left')).toBe(0)
    expect(phraseIndexForSide('right')).toBe(1)
  })

  it('maps switch 1 to the first/left phrase slot', () => {
    expect(phraseIndexForSwitch(0)).toBe(0)
    expect(phraseIndexForSwitch(1)).toBe(1)
  })

  it('does not flip MediaPipe labels on unmirrored web frames', () => {
    expect(userFacingSide('left', false)).toBe('left')
    expect(userFacingHandSideFromLabel('Right', false)).toBe('right')
  })

  it('flips MediaPipe labels for selfie-mirrored capture', () => {
    expect(userFacingSide('right', true)).toBe('left')
    expect(userFacingHandSideFromLabel('Left', true)).toBe('right')
    expect(userFacingHandSideFromLabel('Right', true)).toBe('left')
  })
})

describe('ArmRaiseDetector mirrored laterality', () => {
  const holdMs = 1000
  const cooldownMs = 1200
  const margin = 0.08

  it('maps MediaPipe right-arm raise to the left option when flipped', () => {
    const detector = new ArmRaiseDetector()
    const landmarks = makeLandmarks(false, true)
    const config = { margin, holdMs, cooldownMs, flipMediaPipeLaterality: true }

    const held = detector.process(landmarks, null, 2000, config)
    expect(held.activation).toBeNull()
    expect(held.state.leftRaised).toBe(true)

    const result = detector.process(landmarks, null, 3000, config)
    expect(result.activation).toBe('left')
    expect(phraseIndexForSide(result.activation!)).toBe(0)
  })
})
