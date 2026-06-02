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
import { GameUnsupportedBanner } from '../components/GameUnsupportedBanner'
import { hasPhraseGame } from '../data/phraseStyle'
import type { PhraseDisplay } from '../data/types'
import { useSettings } from '../settings/settingsStore'
import {
  gameUnsupportedSelectionMessage,
  selectionModeSupportsGames,
} from '../settings/selectionModeGames'
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
  const selectionMode = useSettings((s) => s.selectionMode)
  const delayRef = useRef(mediaPlaybackDelay)
  const supportsGamesRef = useRef(selectionModeSupportsGames(selectionMode))
  delayRef.current = mediaPlaybackDelay
  supportsGamesRef.current = selectionModeSupportsGames(selectionMode)

  const coordinator = useMemo(
    () =>
      new GamePlaybackCoordinator(
        () => delayRef.current,
        () => supportsGamesRef.current,
      ),
    [],
  )

  const [state, setState] = useState<GamePlaybackState>({
    phase: 'idle',
    activePhrase: null,
    showExitControl: false,
  })
  const [unsupportedNotice, setUnsupportedNotice] = useState<string | null>(null)

  useEffect(() => coordinator.subscribe(setState), [coordinator])

  const dismissUnsupportedNotice = useCallback(() => {
    setUnsupportedNotice(null)
  }, [])

  useEffect(() => {
    if (!unsupportedNotice) return
    const id = window.setTimeout(() => setUnsupportedNotice(null), 6000)
    return () => window.clearTimeout(id)
  }, [unsupportedNotice])

  const onPhraseSelected = useCallback(
    (phrase: PhraseDisplay) => {
      if (hasPhraseGame(phrase.style) && !selectionModeSupportsGames(selectionMode)) {
        setUnsupportedNotice(gameUnsupportedSelectionMessage(selectionMode))
      } else {
        setUnsupportedNotice(null)
      }
      coordinator.onPhraseSelected(phrase)
    },
    [coordinator, selectionMode],
  )

  const cancelPending = useCallback(() => {
    coordinator.cancelPending()
  }, [coordinator])

  useEffect(() => {
    if (state.phase === 'playing') {
      stopSpeech()
    }
  }, [state.phase])

  useEffect(() => {
    if (!selectionModeSupportsGames(selectionMode)) {
      coordinator.cancelPending()
      if (state.phase === 'playing') {
        coordinator.stopEarly()
      }
    } else {
      setUnsupportedNotice(null)
    }
  }, [selectionMode, coordinator, state.phase])

  const value = useMemo(
    () => ({ onPhraseSelected, cancelPending, state }),
    [onPhraseSelected, cancelPending, state],
  )

  return (
    <GamePlaybackContext.Provider value={value}>
      {children}
      {unsupportedNotice ? (
        <GameUnsupportedBanner message={unsupportedNotice} onDismiss={dismissUnsupportedNotice} />
      ) : null}
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
