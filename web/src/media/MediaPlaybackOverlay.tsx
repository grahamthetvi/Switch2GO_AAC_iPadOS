import { useCallback, useEffect, useRef, useState } from 'react'
import { PhraseMedia } from '../components/phrases/PhraseMedia'
import {
  effectiveBackground,
  effectiveFontSize,
  effectiveTextColor,
  isYouTubePhraseMedia,
  MEDIA_TYPE_VIDEO,
} from '../data/phraseStyle'
import { extractYouTubeVideoId } from '../data/youtube'
import { loadMediaObjectUrl } from '../data/media'
import { hexToCss, useSettings } from '../settings/settingsStore'
import { useTrackingActions, useDwellStatus, useTrackingState } from '../tracking/TrackingContext'
import { GazePointer } from '../components/GazePointer'
import type { MediaPlaybackCoordinator, MediaPlaybackState } from './mediaPlaybackCoordinator'
import { YouTubeChromelessPlayer } from './YouTubeChromelessPlayer'

const mediaPlayPauseButtonId = 'media_playpause'
const mediaExitButtonId = 'media_exit'
const mediaPlaybackAllowedButtons = new Set([mediaPlayPauseButtonId, mediaExitButtonId])

type Props = {
  coordinator: MediaPlaybackCoordinator
  state: MediaPlaybackState
}

export function MediaPlaybackOverlay({ coordinator, state }: Props) {
  const { dwell } = useTrackingActions()
  const { hoveredButtonId } = useDwellStatus()
  const { tracking, dwellProgress } = useTrackingState()
  const settings = useSettings()
  const videoRef = useRef<HTMLVideoElement>(null)
  const audioRef = useRef<HTMLAudioElement>(null)
  const [mediaUrl, setMediaUrl] = useState<string | null>(null)
  const playPauseRef = useRef<HTMLDivElement>(null)
  const exitRef = useRef<HTMLDivElement>(null)

  const phrase = state.phase === 'playing' ? state.activePhrase : null
  const isPlaying = phrase != null

  const isYouTube = isPlaying && isYouTubePhraseMedia(phrase.style)
  const isLocalVideo = isPlaying && phrase.style?.mediaType === MEDIA_TYPE_VIDEO
  const youtubeVideoId = isYouTube ? extractYouTubeVideoId(phrase.style?.mediaRef) : null

  useEffect(() => {
    if (!isPlaying || !isYouTube) return
    if (!youtubeVideoId) coordinator.onNaturalEnd()
  }, [isPlaying, isYouTube, youtubeVideoId, coordinator])

  useEffect(() => {
    if (!isPlaying || isYouTube) {
      setMediaUrl(null)
      return
    }
    const ref = phrase.style?.mediaRef
    if (!ref) {
      coordinator.onNaturalEnd()
      return
    }
    let revoked: string | null = null
    void loadMediaObjectUrl(ref).then((url) => {
      if (!url) {
        coordinator.onNaturalEnd()
        return
      }
      revoked = url
      setMediaUrl(url)
    })
    return () => {
      if (revoked) URL.revokeObjectURL(revoked)
    }
  }, [isPlaying, isYouTube, phrase?.id, phrase?.style?.mediaRef, coordinator])

  useEffect(() => {
    if (!isPlaying) return
    dwell.setAllowedButtonIds(mediaPlaybackAllowedButtons)
    dwell.clearAllButtons()

    const register = () => {
      if (playPauseRef.current) {
        const r = playPauseRef.current.getBoundingClientRect()
        dwell.registerButton(mediaPlayPauseButtonId, r)
      }
      if (exitRef.current) {
        const r = exitRef.current.getBoundingClientRect()
        dwell.registerButton(mediaExitButtonId, r)
      }
    }
    register()
    const id = window.setInterval(register, 150)
    return () => {
      window.clearInterval(id)
      dwell.unregisterButton(mediaPlayPauseButtonId)
      dwell.unregisterButton(mediaExitButtonId)
      dwell.setAllowedButtonIds(null)
    }
  }, [isPlaying, dwell])

  useEffect(() => {
    if (!isPlaying) return
    coordinator.setShowCenterControls(hoveredButtonId === mediaPlayPauseButtonId)
    coordinator.setShowExitControl(hoveredButtonId === mediaExitButtonId)
  }, [hoveredButtonId, isPlaying, coordinator])

  useEffect(() => {
    if (!isPlaying) return
    return dwell.subscribe((id) => {
      if (id === mediaPlayPauseButtonId) coordinator.togglePlayPause()
      if (id === mediaExitButtonId) coordinator.stopEarly()
    })
  }, [isPlaying, dwell, coordinator])

  useEffect(() => {
    if (!isPlaying || isYouTube || !mediaUrl) return
    const el =
      phrase.style?.mediaType === MEDIA_TYPE_VIDEO ? videoRef.current : audioRef.current
    if (!el) return
    if (state.isPaused) {
      el.pause()
    } else {
      void el.play().catch(() => {})
    }
  }, [state.isPaused, isPlaying, isYouTube, mediaUrl, phrase?.style?.mediaType])

  const onEnded = useCallback(() => {
    coordinator.onNaturalEnd()
  }, [coordinator])

  if (!isPlaying || !phrase) return null

  const tileBg = hexToCss(effectiveBackground(phrase.style))
  const showPointer =
    settings.selectionMode !== 'none' &&
    settings.selectionMode !== 'armRaise' &&
    settings.selectionMode !== 'handGesture' &&
    tracking.isTracking &&
    tracking.isCursorVisible &&
    tracking.gazePosition

  return (
    <div className="media-playback-overlay" role="dialog" aria-modal="true">
      {isYouTube && youtubeVideoId ? (
        <YouTubeChromelessPlayer
          videoId={youtubeVideoId}
          isPaused={state.isPaused}
          onEnded={onEnded}
          onError={onEnded}
        />
      ) : isLocalVideo ? (
        <video
          ref={videoRef}
          className="media-playback-video"
          src={mediaUrl ?? undefined}
          playsInline
          onEnded={onEnded}
        />
      ) : (
        <div className="media-playback-audio-screen" style={{ background: tileBg }}>
          <div className="media-playback-phrase-image">
            <PhraseMedia imageRef={phrase.style?.imageRef} />
          </div>
          <p
            className="media-playback-phrase-text"
            style={{
              color: hexToCss(effectiveTextColor(phrase.style)),
              fontSize: `${Math.max(effectiveFontSize(phrase.style) * 2.5, 32)}px`,
              fontWeight: phrase.style?.bold ? 'bold' : undefined,
            }}
          >
            {phrase.text}
          </p>
          <audio ref={audioRef} src={mediaUrl ?? undefined} onEnded={onEnded} />
        </div>
      )}

      <div ref={playPauseRef} className="media-gaze-zone media-gaze-zone-center" aria-hidden />
      <div ref={exitRef} className="media-gaze-zone media-gaze-zone-exit" aria-hidden />

      {showPointer && tracking.gazePosition ? (
        <GazePointer
          x={tracking.gazePosition.x}
          y={tracking.gazePosition.y}
          dwellProgress={hoveredButtonId ? dwellProgress : 0}
        />
      ) : null}

      {state.showCenterControls ? (
        <button
          type="button"
          className="media-playback-control media-playback-control-center"
          onClick={() => coordinator.togglePlayPause()}
          aria-label={state.isPaused ? 'Play' : 'Pause'}
        >
          {state.isPaused ? '▶' : '❚❚'}
        </button>
      ) : null}

      {state.showExitControl ? (
        <button
          type="button"
          className="media-playback-control media-playback-control-exit"
          onClick={() => coordinator.stopEarly()}
          aria-label="Exit playback"
        >
          ✕
        </button>
      ) : null}
    </div>
  )
}
