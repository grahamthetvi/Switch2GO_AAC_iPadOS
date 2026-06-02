import type { SelectionMode } from './settingsStore'

/** Selection modes that can arm and play phrase games (cursor / dwell exit). */
export const GAME_SUPPORTED_SELECTION_MODES: readonly SelectionMode[] = [
  'eyeGaze',
  'face',
  'none',
]

export function selectionModeSupportsGames(mode: SelectionMode): boolean {
  return (GAME_SUPPORTED_SELECTION_MODES as readonly string[]).includes(mode)
}

export function selectionModeUsesGazeForGames(mode: SelectionMode): boolean {
  return mode === 'eyeGaze' || mode === 'face'
}

export function selectionModeUsesTouchForGames(mode: SelectionMode): boolean {
  return mode === 'none'
}

/** User-facing message when a game phrase is selected in an unsupported mode. */
export function gameUnsupportedSelectionMessage(mode: SelectionMode): string {
  switch (mode) {
    case 'armRaise':
      return 'Games are not available in arm raise mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode.'
    case 'handGesture':
      return 'Games are not available in hand gesture mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode.'
    default:
      return 'Games are not available in this selection mode. Switch to eye gaze, head tracking, or touch only in Settings → Selection Mode.'
  }
}
