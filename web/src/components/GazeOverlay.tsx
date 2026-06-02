import { GazePointer } from './GazePointer'
import { TrackingErrorBoundary } from './TrackingErrorBoundary'
import { TrackingFallbackBanner } from './TrackingFallbackBanner'
import { TtsStatusBanner } from './TtsStatusBanner'
import { useMediaPlaybackState } from '../media/MediaPlaybackContext'
import { useGamePlaybackState } from '../game/GamePlaybackContext'
import { useSettings } from '../settings/settingsStore'
import { useTracking, useTrackingActions } from '../tracking/TrackingContext'

function GazeOverlayContent() {
  const {
    tracking,
    armRaise,
    handGesture,
    dwell,
    dwellProgress,
    videoRef,
    trackingBlockedReason,
    fallbackToTouch,
    retryTracking,
  } = useTracking()
  const settings = useSettings()
  const mediaState = useMediaPlaybackState()
  const gameState = useGamePlaybackState()
  const isArmRaise = settings.selectionMode === 'armRaise'
  const isHandGesture = settings.selectionMode === 'handGesture'
  const isBodyGesture = isArmRaise || isHandGesture
  const showPointer =
    !isBodyGesture &&
    settings.selectionMode !== 'none' &&
    tracking.isTracking &&
    tracking.isCursorVisible &&
    tracking.gazePosition &&
    mediaState.phase !== 'playing' &&
    gameState.phase !== 'playing'

  const blockedMessage =
    trackingBlockedReason ??
    (tracking.showTrackingError && tracking.errorMessage ? tracking.errorMessage : null)

  const showFallback = settings.selectionMode === 'none' && blockedMessage != null

  return (
    <>
      {settings.showDebugCameraPreview && settings.selectionMode !== 'none' ? (
        <div className="debug-camera">
          <video ref={videoRef} muted playsInline autoPlay />
        </div>
      ) : (
        <video ref={videoRef} muted playsInline autoPlay className="hidden-video" />
      )}

      {showPointer && tracking.gazePosition ? (
        <GazePointer
          x={tracking.gazePosition.x}
          y={tracking.gazePosition.y}
          dwellProgress={dwell.hoveredButtonId ? dwellProgress : 0}
        />
      ) : null}

      {settings.enableOutOfBoundsHiding &&
        !isBodyGesture &&
        settings.selectionMode !== 'none' &&
        tracking.isGazeOutOfBounds ? (
        <div className="tracking-banner">Look at the screen</div>
      ) : null}

      {settings.showTrackingErrorBanner &&
        isArmRaise &&
        armRaise.showTrackingError &&
        !trackingBlockedReason ? (
        <div className="tracking-banner error">
          {armRaise.errorMessage ?? 'Body not detected — show your shoulders in the camera'}
        </div>
      ) : null}

      {settings.showTrackingErrorBanner &&
        isHandGesture &&
        handGesture.showTrackingError &&
        !trackingBlockedReason ? (
        <div className="tracking-banner error">
          {handGesture.errorMessage ?? 'Hands not detected — hold your hands in view of the camera'}
        </div>
      ) : null}

      {settings.showTrackingErrorBanner &&
        !isBodyGesture &&
        settings.selectionMode !== 'none' &&
        tracking.showTrackingError &&
        !trackingBlockedReason ? (
        <div className="tracking-banner error">
          {tracking.errorMessage ?? 'Face not detected — check lighting and camera'}
        </div>
      ) : null}

      {showFallback && blockedMessage ? (
        <TrackingFallbackBanner
          message={blockedMessage}
          onUseTouch={fallbackToTouch}
          onRetry={retryTracking}
        />
      ) : null}

      <TtsStatusBanner />
    </>
  )
}

function GazeOverlayRoot() {
  const { reportTrackingError } = useTrackingActions()
  return (
    <TrackingErrorBoundary onError={reportTrackingError}>
      <GazeOverlayContent />
    </TrackingErrorBoundary>
  )
}

export function GazeOverlay() {
  return <GazeOverlayRoot />
}
