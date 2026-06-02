import type { PhraseDisplay } from '../data/types'
import { hasPhraseMedia } from '../data/phraseStyle'

export type MediaPlaybackPhase = 'idle' | 'armed' | 'playing'

export type MediaPlaybackListener = (state: MediaPlaybackState) => void

export interface MediaPlaybackState {
  phase: MediaPlaybackPhase
  activePhrase: PhraseDisplay | null
  isPaused: boolean
  showCenterControls: boolean
  showExitControl: boolean
}

const initialState: MediaPlaybackState = {
  phase: 'idle',
  activePhrase: null,
  isPaused: false,
  showCenterControls: false,
  showExitControl: false,
}

export class MediaPlaybackCoordinator {
  private state: MediaPlaybackState = { ...initialState }
  private listeners = new Set<MediaPlaybackListener>()
  private idleTimer: ReturnType<typeof setTimeout> | null = null
  private armedPhrase: PhraseDisplay | null = null
  private getDelay: () => number

  constructor(getDelay: () => number) {
    this.getDelay = getDelay
  }

  subscribe(listener: MediaPlaybackListener): () => void {
    this.listeners.add(listener)
    listener(this.state)
    return () => this.listeners.delete(listener)
  }

  private emit() {
    const snapshot = { ...this.state }
    this.listeners.forEach((l) => l(snapshot))
  }

  onPhraseSelected(phrase: PhraseDisplay) {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer)
      this.idleTimer = null
    }

    if (!hasPhraseMedia(phrase.style)) {
      if (this.state.phase === 'armed') {
        this.armedPhrase = null
        this.state = { ...initialState }
        this.emit()
      }
      return
    }

    if (this.state.phase === 'playing') return

    if (this.state.phase === 'armed' && this.armedPhrase?.id === phrase.id) {
      return
    }

    this.armedPhrase = phrase
    this.state = { ...this.state, phase: 'armed' }
    this.emit()

    this.idleTimer = setTimeout(() => {
      this.beginPlayback()
    }, this.getDelay() * 1000)
  }

  cancelPending() {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer)
      this.idleTimer = null
    }
    if (this.state.phase === 'armed') {
      this.armedPhrase = null
      this.state = { ...initialState }
      this.emit()
    }
  }

  beginPlayback() {
    const phrase = this.armedPhrase
    if (!phrase || !hasPhraseMedia(phrase.style)) {
      this.state = { ...initialState }
      this.emit()
      return
    }
    this.idleTimer = null
    this.armedPhrase = null
    this.state = {
      phase: 'playing',
      activePhrase: phrase,
      isPaused: false,
      showCenterControls: false,
      showExitControl: false,
    }
    this.emit()
  }

  togglePlayPause() {
    if (this.state.phase !== 'playing') return
    this.state = { ...this.state, isPaused: !this.state.isPaused }
    this.emit()
  }

  setShowCenterControls(show: boolean) {
    if (this.state.showCenterControls === show) return
    this.state = { ...this.state, showCenterControls: show }
    this.emit()
  }

  setShowExitControl(show: boolean) {
    if (this.state.showExitControl === show) return
    this.state = { ...this.state, showExitControl: show }
    this.emit()
  }

  stopEarly() {
    this.tearDown()
  }

  onNaturalEnd() {
    this.tearDown()
  }

  private tearDown() {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer)
      this.idleTimer = null
    }
    this.armedPhrase = null
    this.state = { ...initialState }
    this.emit()
  }
}
