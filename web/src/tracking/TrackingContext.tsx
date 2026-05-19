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
import { requestCameraAccess } from './cameraAccess'
import { DwellSelectionManager } from './dwellManager'
import { trackingManager, type TrackingState } from './trackingManager'

interface TrackingContextValue {
  tracking: TrackingState
  dwell: DwellSelectionManager
  videoRef: React.RefObject<HTMLVideoElement | null>
  startTracking: () => Promise<void>
  stopTracking: () => void
  recenterCursor: () => void
  trackingBlockedReason: string | null
  fallbackToTouch: () => void
  retryTracking: () => void
  reportTrackingError: (message: string) => void
}

const TrackingContext = createContext<TrackingContextValue | null>(null)

function isCameraDenied(message: string): boolean {
  const lower = message.toLowerCase()
  return (
    lower.includes('permission') ||
    lower.includes('denied') ||
    lower.includes('notallowed') ||
    lower.includes('not allowed')
  )
}

export function TrackingProvider({ children }: { children: ReactNode }) {
  const settings = useSettings()
  const videoRef = useRef<HTMLVideoElement>(null)
  const [trackingBlockedReason, setTrackingBlockedReason] = useState<string | null>(null)
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

  const reportTrackingError = useCallback((message: string) => {
    setTrackingBlockedReason(message)
    if (settings.selectionMode !== 'none') {
      useSettings.getState().setSelectionMode('none')
    }
  }, [settings.selectionMode])

  const startTracking = useCallback(async () => {
    const video = videoRef.current
    if (!video) return
    try {
      await trackingManager.start(video)
      setTrackingBlockedReason(null)
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Camera or tracking unavailable'
      setTrackingBlockedReason(message)
      if (settings.selectionMode !== 'none') {
        useSettings.getState().setSelectionMode('none')
      }
      throw e
    }
  }, [settings.selectionMode])

  const stopTracking = useCallback(() => {
    trackingManager.stop()
  }, [])

  const recenterCursor = useCallback(() => {
    trackingManager.recenter()
  }, [])

  const fallbackToTouch = useCallback(() => {
    setTrackingBlockedReason(null)
    useSettings.getState().setSelectionMode('none')
    stopTracking()
  }, [stopTracking])

  const retryTracking = useCallback(() => {
    setTrackingBlockedReason(null)
    const mode = useSettings.getState().selectionMode
    if (mode === 'none') {
      useSettings.getState().setSelectionMode('eyeGaze')
    }
    void requestCameraAccess()
      .then(() => startTracking())
      .catch(() => {})
  }, [startTracking])

  useEffect(() => {
    if (settings.selectionMode === 'none') {
      stopTracking()
      return
    }
    setTrackingBlockedReason(null)
    void startTracking().catch((e) => {
      const message = e instanceof Error ? e.message : 'Tracking unavailable'
      setTrackingBlockedReason(message)
    })
    return () => stopTracking()
  }, [settings.selectionMode, startTracking, stopTracking])

  useEffect(() => {
    if (
      settings.selectionMode !== 'none' &&
      tracking.showTrackingError &&
      tracking.errorMessage &&
      isCameraDenied(tracking.errorMessage)
    ) {
      setTrackingBlockedReason(tracking.errorMessage)
    }
  }, [settings.selectionMode, tracking.showTrackingError, tracking.errorMessage])

  const value = useMemo(
    () => ({
      tracking,
      dwell,
      videoRef,
      startTracking,
      stopTracking,
      recenterCursor,
      trackingBlockedReason,
      fallbackToTouch,
      retryTracking,
      reportTrackingError,
    }),
    [
      tracking,
      dwell,
      startTracking,
      stopTracking,
      recenterCursor,
      trackingBlockedReason,
      fallbackToTouch,
      retryTracking,
      reportTrackingError,
    ],
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
