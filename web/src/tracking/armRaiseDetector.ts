import type { LandmarkPoint } from './types'

export type ArmSide = 'left' | 'right'

export interface ArmRaiseState {
  leftRaised: boolean
  rightRaised: boolean
}

/** BlazePose upper-body indices (person's left/right). */
const LEFT_SHOULDER = 11
const RIGHT_SHOULDER = 12
const LEFT_ELBOW = 13
const RIGHT_ELBOW = 14
const LEFT_WRIST = 15
const RIGHT_WRIST = 16

const MIN_VISIBILITY = 0.5

export interface ArmRaiseDetectorConfig {
  /** Normalized distance wrist must be above shoulder (image y grows downward). */
  margin: number
  holdMs: number
  cooldownMs: number
}

/** Detects sustained left/right arm raises from pose landmarks. */
export class ArmRaiseDetector {
  private leftHeldSince: number | null = null
  private rightHeldSince: number | null = null
  private lastActivationTime = 0

  reset(): void {
    this.leftHeldSince = null
    this.rightHeldSince = null
  }

  process(
    landmarks: LandmarkPoint[],
    visibilities: number[] | null,
    now: number,
    config: ArmRaiseDetectorConfig,
  ): { activation: ArmSide | null; state: ArmRaiseState } {
    const leftRaised = this.isArmRaised(landmarks, visibilities, 'left', config.margin)
    const rightRaised = this.isArmRaised(landmarks, visibilities, 'right', config.margin)
    const state: ArmRaiseState = { leftRaised, rightRaised }

    if (now - this.lastActivationTime < config.cooldownMs) {
      this.updateHoldTimers(leftRaised, rightRaised, now)
      return { activation: null, state }
    }

    const side = this.pickDominantSide(leftRaised, rightRaised, landmarks)
    if (!side) {
      this.leftHeldSince = null
      this.rightHeldSince = null
      return { activation: null, state }
    }

    const heldSince = side === 'left' ? this.leftHeldSince : this.rightHeldSince
    if (heldSince == null) {
      if (side === 'left') this.leftHeldSince = now
      else this.rightHeldSince = now
      return { activation: null, state }
    }

    if (now - heldSince >= config.holdMs) {
      this.lastActivationTime = now
      this.leftHeldSince = null
      this.rightHeldSince = null
      return { activation: side, state }
    }

    return { activation: null, state }
  }

  private updateHoldTimers(leftRaised: boolean, rightRaised: boolean, now: number): void {
    if (!leftRaised) this.leftHeldSince = null
    else if (this.leftHeldSince == null) this.leftHeldSince = now
    if (!rightRaised) this.rightHeldSince = null
    else if (this.rightHeldSince == null) this.rightHeldSince = now
  }

  private pickDominantSide(
    leftRaised: boolean,
    rightRaised: boolean,
    landmarks: LandmarkPoint[],
  ): ArmSide | null {
    if (leftRaised && !rightRaised) return 'left'
    if (rightRaised && !leftRaised) return 'right'
    if (!leftRaised || !rightRaised) return null

    const leftWrist = landmarks[LEFT_WRIST]
    const rightWrist = landmarks[RIGHT_WRIST]
    if (!leftWrist || !rightWrist) return null
    return leftWrist.y < rightWrist.y ? 'left' : 'right'
  }

  private isArmRaised(
    landmarks: LandmarkPoint[],
    visibilities: number[] | null,
    side: ArmSide,
    margin: number,
  ): boolean {
    const [shoulderIdx, elbowIdx, wristIdx] =
      side === 'left'
        ? [LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST]
        : [RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]

    const maxIdx = Math.max(shoulderIdx, elbowIdx, wristIdx)
    if (landmarks.length <= maxIdx) return false

    if (visibilities) {
      const minVis = Math.min(
        visibilities[shoulderIdx] ?? 0,
        visibilities[elbowIdx] ?? 0,
        visibilities[wristIdx] ?? 0,
      )
      if (minVis < MIN_VISIBILITY) return false
    }

    const shoulder = landmarks[shoulderIdx]
    const elbow = landmarks[elbowIdx]
    const wrist = landmarks[wristIdx]

    const wristAbove = wrist.y < shoulder.y - margin
    const elbowAbove = elbow.y < shoulder.y - margin * 0.5
    return wristAbove && elbowAbove
  }
}
