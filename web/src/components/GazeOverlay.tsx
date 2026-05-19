import { useSettings } from '../settings/settingsStore'
import { useTracking } from '../tracking/TrackingContext'

export function GazeOverlay() {
  const { tracking, videoRef } = useTracking()
  const settings = useSettings()
  const showPointer =
    settings.selectionMode !== 'none' &&
    tracking.isTracking &&
    tracking.isCursorVisible &&
    tracking.gazePosition

  return (
    <>
      {settings.showDebugCameraPreview && settings.selectionMode !== 'none' ? (
        <div className="debug-camera">
          <video ref={videoRef} muted playsInline autoPlay />
        </div>
      ) : (
        <video ref={videoRef} muted playsInline autoPlay className="hidden-video" />
      )}

      {showPointer && tracking.gazePosition && (
        <div
          className="gaze-pointer"
          style={{
            left: tracking.gazePosition.x,
            top: tracking.gazePosition.y,
          }}
          aria-hidden
        />
      )}

      {settings.enableOutOfBoundsHiding &&
        settings.selectionMode !== 'none' &&
        tracking.isGazeOutOfBounds && (
          <div className="tracking-banner">Look at the screen</div>
        )}

      {settings.showTrackingErrorBanner &&
        settings.selectionMode !== 'none' &&
        tracking.showTrackingError && (
          <div className="tracking-banner error">
            {tracking.errorMessage ?? 'Face not detected — check lighting and camera'}
          </div>
        )}
    </>
  )
}
