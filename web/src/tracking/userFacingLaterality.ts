export type BodySide = 'left' | 'right'

export interface ArmRaiseStateLike {
  leftRaised: boolean
  rightRaised: boolean
}

/** Maps MediaPipe pose/hand laterality onto the user's left/right. */
export function userFacingSide(mediaPipeSide: BodySide, flip: boolean): BodySide {
  if (!flip) return mediaPipeSide
  return mediaPipeSide === 'left' ? 'right' : 'left'
}

export function userFacingArmState(state: ArmRaiseStateLike, flip: boolean): ArmRaiseStateLike {
  if (!flip) return state
  return { leftRaised: state.rightRaised, rightRaised: state.leftRaised }
}

export function userFacingHandSideFromLabel(label: string, flip: boolean): BodySide {
  const labeled: BodySide = label.toLowerCase() === 'right' ? 'right' : 'left'
  return userFacingSide(labeled, flip)
}

/** Two-choice layouts: user-left → index 0, user-right → index 1. */
export function phraseIndexForSide(side: BodySide): number {
  return side === 'left' ? 0 : 1
}

/** Switch 1 (index 0) → first/left phrase, Switch 2 → second/right, etc. */
export function phraseIndexForSwitch(switchIndex: number): number {
  return switchIndex
}
