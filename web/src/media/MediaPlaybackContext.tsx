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
import { MediaPlaybackOverlay } from './MediaPlaybackOverlay'
import {
  MediaPlaybackCoordinator,
  type MediaPlaybackState,
} from './mediaPlaybackCoordinator'

interface MediaPlaybackContextValue {
  onPhraseSelected: (phrase: PhraseDisplay) => void
  cancelPending: () => void
  state: MediaPlaybackState
}

const MediaPlaybackContext = createContext<MediaPlaybackContextValue | null>(null)

export function MediaPlaybackProvider({ children }: { children: ReactNode }) {
  const mediaPlaybackDelay = useSettings((s) => s.mediaPlaybackDelay)
  const delayRef = useRef(mediaPlaybackDelay)
  delayRef.current = mediaPlaybackDelay

  const coordinator = useMemo(
    () => new MediaPlaybackCoordinator(() => delayRef.current),
    [],
  )

  const [state, setState] = useState<MediaPlaybackState>({
    phase: 'idle',
    activePhrase: null,
    isPaused: false,
    showCenterControls: false,
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
    <MediaPlaybackContext.Provider value={value}>
      {children}
      <MediaPlaybackOverlay coordinator={coordinator} state={state} />
    </MediaPlaybackContext.Provider>
  )
}

export function useMediaPlayback(): MediaPlaybackContextValue {
  const ctx = useContext(MediaPlaybackContext)
  if (!ctx) throw new Error('useMediaPlayback must be used within MediaPlaybackProvider')
  return ctx
}

export function useMediaPlaybackState(): MediaPlaybackState {
  return useMediaPlayback().state
}
