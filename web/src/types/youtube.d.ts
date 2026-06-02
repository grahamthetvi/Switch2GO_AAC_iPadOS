declare namespace YT {
  enum PlayerState {
    ENDED = 0,
    PLAYING = 1,
    PAUSED = 2,
    BUFFERING = 3,
    CUED = 5,
  }

  interface PlayerOptions {
    videoId?: string
    width?: string | number
    height?: string | number
    playerVars?: Record<string, string | number>
    events?: {
      onReady?: (event: { target: Player }) => void
      onStateChange?: (event: { data: number; target: Player }) => void
      onError?: (event: { data: number; target: Player }) => void
      onAutoplayBlocked?: () => void
    }
  }

  class Player {
    constructor(element: HTMLElement | string, options: PlayerOptions)
    playVideo(): void
    pauseVideo(): void
    stopVideo(): void
    mute(): void
    unMute(): void
    destroy(): void
  }
}

declare const YT: typeof YT
