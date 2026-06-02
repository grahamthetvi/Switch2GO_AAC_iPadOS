import { useEffect, useRef } from 'react'
import { loadYouTubeIframeApi } from './loadYouTubeIframeApi'

type Props = {
  videoId: string
  isPaused: boolean
  onEnded: () => void
  onError: () => void
}

export function YouTubeChromelessPlayer({ videoId, isPaused, onEnded, onError }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const playerRef = useRef<YT.Player | null>(null)
  const readyRef = useRef(false)

  useEffect(() => {
    let cancelled = false
    readyRef.current = false

    void loadYouTubeIframeApi().then(() => {
      if (cancelled || !hostRef.current || !window.YT?.Player) return

      playerRef.current?.destroy()
      playerRef.current = new window.YT.Player(hostRef.current, {
        videoId,
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          controls: 0,
          modestbranding: 1,
          rel: 0,
          playsinline: 1,
          fs: 0,
          disablekb: 1,
          iv_load_policy: 3,
        },
        events: {
          onReady: () => {
            readyRef.current = true
            if (isPaused) playerRef.current?.pauseVideo()
            else playerRef.current?.playVideo()
          },
          onStateChange: (event) => {
            if (event.data === window.YT!.PlayerState.ENDED) onEnded()
          },
          onError: () => onError(),
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
    else playerRef.current.playVideo()
  }, [isPaused])

  return <div ref={hostRef} className="media-playback-youtube" aria-hidden />
}
