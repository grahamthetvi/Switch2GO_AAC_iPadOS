import { TrackingErrorBoundary } from './TrackingErrorBoundary'
import { TrackingFallbackBanner } from './TrackingFallbackBanner'
import { useSettings } from '../settings/settingsStore'
import { useTracking } from '../tracking/TrackingContext'

function GazeOverlayContent() {
  const {
    tracking,
    videoRef,
    trackingBlockedReason,
    fallbackToTouch,
    retryTracking,
  } = useTracking()
  const settings = useSettings()
  const showPointer =
    settings.selectionMode !== 'none' &&
    tracking.isTracking &&
    tracking.isCursorVisible &&
    tracking.gazePosition

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
        <div
          className="gaze-pointer"
          style={{
            left: tracking.gazePosition.x,
            top: tracking.gazePosition.y,
          }}
          aria-hidden
        />
      ) : null}

      {settings.enableOutOfBoundsHiding &&
        settings.selectionMode !== 'none' &&
        tracking.isGazeOutOfBounds ? (
        <div className="tracking-banner">Look at the screen</div>
      ) : null}

      {settings.showTrackingErrorBanner &&
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

    </>
  )
}

function GazeOverlayRoot() {
  const { reportTrackingError } = useTracking()
  return (
    <TrackingErrorBoundary onError={reportTrackingError}>
      <GazeOverlayContent />
    </TrackingErrorBoundary>
  )
}

export function GazeOverlay() {
  return <GazeOverlayRoot />
}
