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
import { useSettings } from '../settings/settingsStore'
import { DwellSelectionManager } from './dwellManager'
import { trackingManager, type TrackingState } from './trackingManager'

interface TrackingContextValue {
  tracking: TrackingState
  dwell: DwellSelectionManager
  videoRef: React.RefObject<HTMLVideoElement | null>
  startTracking: () => Promise<void>
  stopTracking: () => void
  recenterCursor: () => void
}

const TrackingContext = createContext<TrackingContextValue | null>(null)

export function TrackingProvider({ children }: { children: ReactNode }) {
  const settings = useSettings()
  const videoRef = useRef<HTMLVideoElement>(null)
  const [tracking, setTracking] = useState<TrackingState>({
    gazePosition: null,
    isTracking: false,
    isCursorVisible: false,
    isGazeOutOfBounds: false,
    showTrackingError: false,
    errorMessage: null,
  })

  const dwell = useMemo(
    () =>
      new DwellSelectionManager(
        () => useSettings.getState().dwellTime * 1000,
        () => {
          const s = useSettings.getState()
          return {
            enabled: s.enableRepeatDwell,
            delayMs: s.repeatDwellDelay * 1000,
          }
        },
      ),
    [],
  )

  useEffect(() => {
    dwell.isEnabled = settings.selectionMode !== 'none'
  }, [dwell, settings.selectionMode])

  useEffect(() => {
    return trackingManager.subscribe(setTracking)
  }, [])

  useEffect(() => {
    trackingManager.configure({
      mode: settings.selectionMode === 'face' ? 'face' : 'eyeGaze',
      sensitivity: settings.sensitivity,
      gazeAmplification: settings.gazeAmplification,
      headOffsetYaw: settings.headCameraOffsetYaw,
      headOffsetPitch: settings.headCameraOffsetPitch,
      headSensX: settings.headSensitivityX,
      headSensY: settings.headSensitivityY,
      headCameraPosition: settings.headCameraPosition,
      useGPU: settings.useGPU,
      trackingMethod: settings.trackingMode,
      smoothingMode: settings.smoothingMode,
      eyeSelection: settings.eyeSelection,
      enableDoubleBlinkRecenter: settings.enableDoubleBlinkRecenter,
      enableAutoRecenter: settings.enableAutoRecenter,
      enableOutOfBoundsHiding: settings.enableOutOfBoundsHiding,
      showTrackingErrorBanner: settings.showTrackingErrorBanner,
    })
  }, [settings])

  useEffect(() => {
    if (tracking.gazePosition && settings.selectionMode !== 'none') {
      dwell.updateGazePosition(tracking.gazePosition)
    } else {
      dwell.updateGazePosition(null)
    }
  }, [tracking.gazePosition, dwell, settings.selectionMode])

  const startTracking = useCallback(async () => {
    const video = videoRef.current
    if (!video) return
    await trackingManager.start(video)
  }, [])

  const stopTracking = useCallback(() => {
    trackingManager.stop()
  }, [])

  const recenterCursor = useCallback(() => {
    trackingManager.recenter()
  }, [])

  useEffect(() => {
    if (settings.selectionMode === 'none') {
      stopTracking()
      return
    }
    void startTracking().catch(() => {})
    return () => stopTracking()
  }, [settings.selectionMode, startTracking, stopTracking])

  const value = useMemo(
    () => ({ tracking, dwell, videoRef, startTracking, stopTracking, recenterCursor }),
    [tracking, dwell, startTracking, stopTracking, recenterCursor],
  )

  return (
    <TrackingContext.Provider value={value}>{children}</TrackingContext.Provider>
  )
}

export function useTracking(): TrackingContextValue {
  const ctx = useContext(TrackingContext)
  if (!ctx) throw new Error('useTracking must be used within TrackingProvider')
  return ctx
}
