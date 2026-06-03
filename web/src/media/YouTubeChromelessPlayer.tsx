import { useEffect, useRef } from 'react'
import { loadYouTubeIframeApi } from './loadYouTubeIframeApi'

type Props = {
  videoId: string
  isPaused: boolean
  onEnded: () => void
  onError: () => void
}

function ensureAudible(player: YT.Player) {
  player.unMute()
  player.setVolume(100)
  player.playVideo()
}

/** Pause briefly then play with sound (mirrors iOS WKWebView workaround). */
function pauseThenPlay(player: YT.Player) {
  player.pauseVideo()
  window.setTimeout(() => ensureAudible(player), 200)
}

export function YouTubeChromelessPlayer({ videoId, isPaused, onEnded, onError }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const playerRef = useRef<YT.Player | null>(null)
  const readyRef = useRef(false)
  const audioWakeDoneRef = useRef(false)

  useEffect(() => {
    let cancelled = false
    readyRef.current = false
    audioWakeDoneRef.current = false

    void loadYouTubeIframeApi().then(() => {
      if (cancelled || !hostRef.current || !window.YT?.Player) return

      playerRef.current?.destroy()
      const origin = window.location.origin || 'https://www.youtube.com'
      playerRef.current = new window.YT.Player(hostRef.current, {
        videoId,
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 0,
          controls: 0,
          modestbranding: 1,
          rel: 0,
          playsinline: 1,
          fs: 0,
          disablekb: 1,
          iv_load_policy: 3,
          enablejsapi: 1,
          origin,
          mute: 1,
        },
        events: {
          onReady: () => {
            readyRef.current = true
            const player = playerRef.current
            if (!player) return
            if (isPaused) player.pauseVideo()
            else player.playVideo()
          },
          onStateChange: (event) => {
            if (event.data === window.YT!.PlayerState.PLAYING) {
              const player = playerRef.current
              if (player && !audioWakeDoneRef.current) {
                audioWakeDoneRef.current = true
                pauseThenPlay(player)
              }
            }
            if (event.data === window.YT!.PlayerState.ENDED) onEnded()
          },
          onAutoplayBlocked: () => {
            const player = playerRef.current
            if (!player) return
            player.mute()
            player.playVideo()
            window.setTimeout(() => pauseThenPlay(player), 300)
          },
          onError: (event) => {
            console.error('[YouTube] player error', event.data)
            onError()
          },
        },
      })
    })

    return () => {
      cancelled = true
      readyRef.current = false
      playerRef.current?.destroy()
      playerRef.current = null
    }
  }, [videoId, onEnded, onError])

  useEffect(() => {
    if (!readyRef.current || !playerRef.current) return
    if (isPaused) playerRef.current.pauseVideo()
    else ensureAudible(playerRef.current)
  }, [isPaused])

  return <div ref={hostRef} className="media-playback-youtube" aria-hidden />
}
