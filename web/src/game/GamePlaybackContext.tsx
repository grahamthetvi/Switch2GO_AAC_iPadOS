/* eslint-disable react-refresh/only-export-components */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import type { PhraseDisplay } from '../data/types'
import { useSettings } from '../settings/settingsStore'
import { stopSpeech } from '../tts/speak'
import { GameOverlay } from './GameOverlay'
import { GamePlaybackCoordinator, type GamePlaybackState } from './gamePlaybackCoordinator'

interface GamePlaybackContextValue {
  onPhraseSelected: (phrase: PhraseDisplay) => void
  cancelPending: () => void
  state: GamePlaybackState
}

const GamePlaybackContext = createContext<GamePlaybackContextValue | null>(null)

export function GamePlaybackProvider({ children }: { children: ReactNode }) {
  const mediaPlaybackDelay = useSettings((s) => s.mediaPlaybackDelay)
  const delayRef = useRef(mediaPlaybackDelay)
  delayRef.current = mediaPlaybackDelay

  const coordinator = useMemo(
    () => new GamePlaybackCoordinator(() => delayRef.current),
    [],
  )

  const [state, setState] = useState<GamePlaybackState>({
    phase: 'idle',
    activePhrase: null,
    showExitControl: false,
  })

  useEffect(() => coordinator.subscribe(setState), [coordinator])

  const onPhraseSelected = useCallback(
    (phrase: PhraseDisplay) => {
      coordinator.onPhraseSelected(phrase)
    },
    [coordinator],
  )

  const cancelPending = useCallback(() => {
    coordinator.cancelPending()
  }, [coordinator])

  useEffect(() => {
    if (state.phase === 'playing') {
      stopSpeech()
    }
  }, [state.phase])

  const value = useMemo(
    () => ({ onPhraseSelected, cancelPending, state }),
    [onPhraseSelected, cancelPending, state],
  )

  return (
    <GamePlaybackContext.Provider value={value}>
      {children}
      <GameOverlay coordinator={coordinator} state={state} />
    </GamePlaybackContext.Provider>
  )
}

export function useGamePlayback(): GamePlaybackContextValue {
  const ctx = useContext(GamePlaybackContext)
  if (!ctx) throw new Error('useGamePlayback must be used within GamePlaybackProvider')
  return ctx
}

export function useGamePlaybackState(): GamePlaybackState {
  return useGamePlayback().state
}
