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
import {
  armRaiseTrackingManager,
  type ArmRaiseTrackingState,
} from './armRaiseTrackingManager'
import {
  handGestureTrackingManager,
  type HandGestureTrackingState,
} from './handGestureTrackingManager'
import { DwellSelectionManager } from './dwellManager'
import type { ArmSide } from './armRaiseDetector'
import type { HandSide } from './handGestureDetector'
import { trackingManager, type TrackingState } from './trackingManager'

interface TrackingContextValue {
  tracking: TrackingState
  armRaise: ArmRaiseTrackingState
  handGesture: HandGestureTrackingState
  dwell: DwellSelectionManager
  dwellProgress: number
  videoRef: React.RefObject<HTMLVideoElement | null>
  startTracking: () => Promise<void>
  stopTracking: () => void
  recenterCursor: () => void
  trackingBlockedReason: string | null
  fallbackToTouch: () => void
  retryTracking: () => void
  reportTrackingError: (message: string) => void
  subscribeArmRaise: (listener: (side: ArmSide) => void) => () => void
  subscribeHandGesture: (listener: (side: HandSide) => void) => () => void
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
  const [dwellProgress, setDwellProgress] = useState(0)
  const [tracking, setTracking] = useState<TrackingState>({
    gazePosition: null,
    isTracking: false,
    isCursorVisible: false,
    isGazeOutOfBounds: false,
    showTrackingError: false,
    errorMessage: null,
  })
  const [armRaise, setArmRaise] = useState<ArmRaiseTrackingState>({
    isTracking: false,
    armState: { leftRaised: false, rightRaised: false },
    showTrackingError: false,
    errorMessage: null,
  })
  const [handGesture, setHandGesture] = useState<HandGestureTrackingState>({
    isTracking: false,
    handState: { leftPose: null, rightPose: null },
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
    dwell.isEnabled =
      settings.selectionMode !== 'none' &&
      settings.selectionMode !== 'armRaise' &&
      settings.selectionMode !== 'handGesture'
  }, [dwell, settings.selectionMode])

  useEffect(() => {
    return dwell.subscribeProgress((progress) => {
      setDwellProgress(progress)
    })
  }, [dwell])

  useEffect(() => {
    return trackingManager.subscribe(setTracking)
  }, [])

  useEffect(() => {
    return armRaiseTrackingManager.subscribeState(setArmRaise)
  }, [])

  useEffect(() => {
    return handGestureTrackingManager.subscribeState(setHandGesture)
  }, [])

  useEffect(() => {
    armRaiseTrackingManager.configure({
      useGPU: settings.useGPU,
      holdMs: settings.dwellTime * 1000,
    })
  }, [settings.useGPU, settings.dwellTime])

  useEffect(() => {
    handGestureTrackingManager.configure({
      useGPU: settings.useGPU,
    })
  }, [settings.useGPU])

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
    if (
      tracking.gazePosition &&
      settings.selectionMode !== 'none' &&
      settings.selectionMode !== 'armRaise' &&
      settings.selectionMode !== 'handGesture'
    ) {
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
      if (settings.selectionMode === 'armRaise') {
        await armRaiseTrackingManager.start(video)
      } else if (settings.selectionMode === 'handGesture') {
        await handGestureTrackingManager.start(video)
      } else {
        await trackingManager.start(video)
      }
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
    armRaiseTrackingManager.stop()
    handGestureTrackingManager.stop()
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

  const subscribeArmRaise = useCallback(
    (listener: (side: ArmSide) => void) => armRaiseTrackingManager.subscribeActivation(listener),
    [],
  )

  const subscribeHandGesture = useCallback(
    (listener: (side: HandSide) => void) =>
      handGestureTrackingManager.subscribeActivation(listener),
    [],
  )

  const value = useMemo(
    () => ({
      tracking,
      armRaise,
      handGesture,
      dwell,
      dwellProgress,
      videoRef,
      startTracking,
      stopTracking,
      recenterCursor,
      trackingBlockedReason,
      fallbackToTouch,
      retryTracking,
      reportTrackingError,
      subscribeArmRaise,
      subscribeHandGesture,
    }),
    [
      tracking,
      armRaise,
      handGesture,
      dwell,
      dwellProgress,
      startTracking,
      stopTracking,
      recenterCursor,
      trackingBlockedReason,
      fallbackToTouch,
      retryTracking,
      reportTrackingError,
      subscribeArmRaise,
      subscribeHandGesture,
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
