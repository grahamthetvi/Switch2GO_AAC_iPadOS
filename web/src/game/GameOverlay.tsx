import { useCallback, useEffect, useRef, useState } from 'react'
import { GazePointer } from '../components/GazePointer'
import { GAME_TYPE_CURSOR_ROCKET } from '../data/phraseStyle'
import { hexToCss, useSettings } from '../settings/settingsStore'
import { useTrackingActions, useDwellStatus, useTrackingState } from '../tracking/TrackingContext'
import { CursorRocketGame } from './CursorRocketGame'
import type { GamePlaybackCoordinator, GamePlaybackState } from './gamePlaybackCoordinator'

const gameExitButtonId = 'game_exit'
const gameAllowedButtons = new Set([gameExitButtonId])

type Props = {
  coordinator: GamePlaybackCoordinator
  state: GamePlaybackState
}

export function GameOverlay({ coordinator, state }: Props) {
  const { dwell } = useTrackingActions()
  const { hoveredButtonId } = useDwellStatus()
  const { tracking, dwellProgress } = useTrackingState()
  const settings = useSettings()
  const exitRef = useRef<HTMLDivElement>(null)
  const [pointer, setPointer] = useState(() => ({
    x: window.innerWidth / 2,
    y: window.innerHeight / 2,
  }))

  const phrase = state.activePhrase
  const isPlaying = state.phase === 'playing' && phrase

  useEffect(() => {
    if (!isPlaying) return
    dwell.setAllowedButtonIds(gameAllowedButtons)
    dwell.clearAllButtons()

    const register = () => {
      if (exitRef.current) {
        dwell.registerButton(gameExitButtonId, exitRef.current.getBoundingClientRect())
      }
    }
    register()
    const id = window.setInterval(register, 150)
    return () => {
      window.clearInterval(id)
      dwell.unregisterButton(gameExitButtonId)
      dwell.setAllowedButtonIds(null)
    }
  }, [isPlaying, dwell])

  useEffect(() => {
    if (!isPlaying) return
    coordinator.setShowExitControl(hoveredButtonId === gameExitButtonId)
  }, [hoveredButtonId, isPlaying, coordinator])

  useEffect(() => {
    if (!isPlaying) return
    return dwell.subscribe((id) => {
      if (id === gameExitButtonId) coordinator.stopEarly()
    })
  }, [isPlaying, dwell, coordinator])

  const onPointer = useCallback((e: React.PointerEvent) => {
    setPointer({ x: e.clientX, y: e.clientY })
  }, [])

  if (!isPlaying || !phrase) return null

  const gameType = phrase.style?.gameType
  const useGaze =
    settings.selectionMode !== 'none' &&
    settings.selectionMode !== 'armRaise' &&
    settings.selectionMode !== 'handGesture' &&
    tracking.isTracking &&
    tracking.isCursorVisible &&
    tracking.gazePosition

  const targetX = useGaze ? tracking.gazePosition!.x : pointer.x
  const targetY = useGaze ? tracking.gazePosition!.y : pointer.y

  const showPointer =
    useGaze &&
    tracking.gazePosition

  return (
    <div
      className="game-playback-overlay"
      role="dialog"
      aria-modal="true"
      onPointerMove={onPointer}
      onPointerDown={onPointer}
    >
      {gameType === GAME_TYPE_CURSOR_ROCKET ? (
        <CursorRocketGame targetX={targetX} targetY={targetY} />
      ) : (
        <div className="game-playback-fallback" style={{ color: hexToCss(0xffffffff) }}>
          <p>{phrase.text}</p>
          <p>Game unavailable</p>
        </div>
      )}

      <div ref={exitRef} className="media-gaze-zone media-gaze-zone-exit" aria-hidden />

      {showPointer ? (
        <GazePointer
          x={tracking.gazePosition!.x}
          y={tracking.gazePosition!.y}
          dwellProgress={hoveredButtonId ? dwellProgress : 0}
        />
      ) : null}

      {state.showExitControl ? (
        <button
          type="button"
          className="media-playback-control media-playback-control-exit"
          onClick={() => coordinator.stopEarly()}
          aria-label="Exit game"
        >
          ✕
        </button>
      ) : null}
    </div>
  )
}
