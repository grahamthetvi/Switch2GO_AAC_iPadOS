import type { DetectedHandGesture, DetectedHandSide } from './gestureRecognizerClient'

export type HandSide = DetectedHandSide

export type HandPose = 'open' | 'closed' | null

export interface HandGestureState {
  leftPose: HandPose
  rightPose: HandPose
}

const OPEN_GESTURE = 'Open_Palm'
const CLOSED_GESTURE = 'Closed_Fist'

export interface HandGestureDetectorConfig {
  minScore: number
  stableFrames: number
  cooldownMs: number
}

interface SideTracker {
  stablePose: HandPose
  pendingPose: HandPose
  pendingCount: number
}

/** Detects open↔closed hand transitions for left/right phrase selection. */
export class HandGestureDetector {
  private left: SideTracker = this.freshSide()
  private right: SideTracker = this.freshSide()
  private lastActivationTime = 0

  reset(): void {
    this.left = this.freshSide()
    this.right = this.freshSide()
  }

  process(
    hands: DetectedHandGesture[],
    now: number,
    config: HandGestureDetectorConfig,
  ): { activation: HandSide | null; state: HandGestureState } {
    const detected: Partial<Record<HandSide, HandPose>> = {}

    for (const hand of hands) {
      const pose = this.gestureToPose(hand.gestureName, hand.score, config.minScore)
      if (pose) detected[hand.side] = pose
    }

    let activation: HandSide | null = null

    if (now - this.lastActivationTime >= config.cooldownMs) {
      activation = this.advanceSide('left', this.left, detected.left ?? null, config.stableFrames)
      if (!activation) {
        activation = this.advanceSide('right', this.right, detected.right ?? null, config.stableFrames)
      }
      if (activation) this.lastActivationTime = now
    } else {
      this.advanceSide('left', this.left, detected.left ?? null, config.stableFrames)
      this.advanceSide('right', this.right, detected.right ?? null, config.stableFrames)
    }

    return {
      activation,
      state: {
        leftPose: this.left.stablePose,
        rightPose: this.right.stablePose,
      },
    }
  }

  private freshSide(): SideTracker {
    return { stablePose: null, pendingPose: null, pendingCount: 0 }
  }

  private gestureToPose(name: string, score: number, minScore: number): HandPose {
    if (score < minScore) return null
    if (name === OPEN_GESTURE) return 'open'
    if (name === CLOSED_GESTURE) return 'closed'
    return null
  }

  private advanceSide(
    side: HandSide,
    tracker: SideTracker,
    pose: HandPose,
    stableFrames: number,
  ): HandSide | null {
    if (pose == null) {
      tracker.pendingPose = null
      tracker.pendingCount = 0
      return null
    }

    if (pose !== tracker.pendingPose) {
      tracker.pendingPose = pose
      tracker.pendingCount = 1
      return null
    }

    tracker.pendingCount++
    if (tracker.pendingCount < stableFrames) return null

    const previous = tracker.stablePose
    if (previous != null && previous !== pose) {
      tracker.stablePose = pose
      tracker.pendingPose = null
      tracker.pendingCount = 0
      return side
    }

    tracker.stablePose = pose
    return null
  }
}
