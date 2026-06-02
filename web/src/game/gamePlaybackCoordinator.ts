import type { PhraseDisplay } from '../data/types'
import { hasPhraseGame } from '../data/phraseStyle'

export type GamePlaybackPhase = 'idle' | 'armed' | 'playing'

export type GamePlaybackListener = (state: GamePlaybackState) => void

export interface GamePlaybackState {
  phase: GamePlaybackPhase
  activePhrase: PhraseDisplay | null
  showExitControl: boolean
}

const initialState: GamePlaybackState = {
  phase: 'idle',
  activePhrase: null,
  showExitControl: false,
}

export class GamePlaybackCoordinator {
  private state: GamePlaybackState = { ...initialState }
  private listeners = new Set<GamePlaybackListener>()
  private idleTimer: ReturnType<typeof setTimeout> | null = null
  private armedPhrase: PhraseDisplay | null = null
  private getDelay: () => number
  private getSupportsGames: () => boolean

  constructor(getDelay: () => number, getSupportsGames: () => boolean) {
    this.getDelay = getDelay
    this.getSupportsGames = getSupportsGames
  }

  subscribe(listener: GamePlaybackListener): () => void {
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

    if (!hasPhraseGame(phrase.style) || !this.getSupportsGames()) {
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
      this.beginGame()
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

  beginGame() {
    const phrase = this.armedPhrase
    if (!phrase || !hasPhraseGame(phrase.style) || !this.getSupportsGames()) {
      this.state = { ...initialState }
      this.emit()
      return
    }
    this.idleTimer = null
    this.armedPhrase = null
    this.state = {
      phase: 'playing',
      activePhrase: phrase,
      showExitControl: false,
    }
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
