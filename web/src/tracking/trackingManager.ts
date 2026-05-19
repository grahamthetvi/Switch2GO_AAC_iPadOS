import type { Point } from './dwellManager'
import { FaceLandmarkerClient } from './faceLandmarkerClient'
import { GazeTracker } from './gazeTracker'
import { HeadPoseTracker } from './headPoseTracker'
import type {
  EyeSelection,
  FaceLandmarkFrame,
  LandmarkPoint,
  SmoothingMode,
  TrackingMethod,
} from './types'

export interface TrackingState {
  gazePosition: Point | null
  isTracking: boolean
  isCursorVisible: boolean
  isGazeOutOfBounds: boolean
  showTrackingError: boolean
  errorMessage: string | null
}

type TrackingMode = 'eyeGaze' | 'face'

export interface TrackingConfig {
  mode: TrackingMode
  sensitivity: number
  gazeAmplification: number
  headOffsetYaw: number
  headOffsetPitch: number
  headSensX: number
  headSensY: number
  headCameraPosition: string
  useGPU: boolean
  trackingMethod: TrackingMethod
  smoothingMode: SmoothingMode
  eyeSelection: EyeSelection
  enableDoubleBlinkRecenter: boolean
  enableAutoRecenter: boolean
  enableOutOfBoundsHiding: boolean
  showTrackingErrorBanner: boolean
}

const DOUBLE_BLINK_WINDOW_MS = 600
const BLINK_MIN_DURATION_MS = 50
const BLINK_COOLDOWN_MS = 300
const CENTER_GAZE_THRESHOLD = 0.08
const AUTO_RECENTER_DURATION_MS = 1500
const GAZE_OUT_OF_BOUNDS_THRESHOLD = 1.2
const OUT_OF_BOUNDS_TIMEOUT_MS = 500
const WARMUP_DURATION_MS = 1500
const MIN_FRAME_INTERVAL_MS = 1000 / 20
const TRACKING_LOSS_RESET_MS = 1000
const LAST_POSITION_HOLD_MS = 500

function sensitivityToLerp(index: number): number {
  return [0.25, 0.5, 0.8][index] ?? 0.5
}

function gazeCameraOffsetX(headCameraPosition: string, headOffsetYaw: number): number {
  switch (headCameraPosition) {
    case 'left':
      return -0.05
    case 'right':
      return 0.05
    case 'custom':
      return -(headOffsetYaw / 45) * 0.15
    default:
      return 0
  }
}

/** Full gaze pipeline with Web Worker MediaPipe and KMP-ported GazeTracker. */
export class TrackingManager {
  private client = new FaceLandmarkerClient()
  private gazeTracker: GazeTracker | null = null
  private headPoseTracker = new HeadPoseTracker()
  private video: HTMLVideoElement | null = null
  private stream: MediaStream | null = null
  private rafId: number | null = null
  private captureCanvas = document.createElement('canvas')
  private captureCtx = this.captureCanvas.getContext('2d')

  private config: TrackingConfig = {
    mode: 'eyeGaze',
    sensitivity: 1,
    gazeAmplification: 1,
    headOffsetYaw: 4,
    headOffsetPitch: 0,
    headSensX: 2,
    headSensY: 2.5,
    headCameraPosition: 'left',
    useGPU: false,
    trackingMethod: '2D',
    smoothingMode: 'adaptive',
    eyeSelection: 'both',
    enableDoubleBlinkRecenter: true,
    enableAutoRecenter: true,
    enableOutOfBoundsHiding: true,
    showTrackingErrorBanner: true,
  }

  private isProcessingFrame = false
  private lastFrameProcessedTime = 0
  private trackingStartTime = 0
  private lastSuccessfulDetectionTime = 0
  private lastLandmarkTime = 0
  private lastValidPosition: Point | null = null

  private gazeOffsetX = 0
  private gazeOffsetY = 0
  private lastRawGazeX: number | null = null
  private lastRawGazeY: number | null = null

  private wasBlinking = false
  private blinkStartTime = 0
  private lastBlinkEndTime = 0
  private lastRecenterTime = 0

  private headWasBlinking = false
  private headBlinkStartTime = 0
  private headLastBlinkEndTime = 0

  private isGazeCentered = false
  private gazeCenteredStartTime = 0
  private gazeOutOfBoundsStartTime = 0

  gazePosition: Point | null = null
  isTracking = false
  isCursorVisible = false
  isGazeOutOfBounds = false
  showTrackingError = false
  errorMessage: string | null = null

  private listeners = new Set<(s: TrackingState) => void>()

  subscribe(listener: (s: TrackingState) => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  private emit(): void {
    const state: TrackingState = {
      gazePosition: this.gazePosition,
      isTracking: this.isTracking,
      isCursorVisible: this.isCursorVisible,
      isGazeOutOfBounds: this.isGazeOutOfBounds,
      showTrackingError: this.showTrackingError,
      errorMessage: this.errorMessage,
    }
    for (const l of this.listeners) l(state)
  }

  configure(opts: TrackingConfig): void {
    const gpuChanged = this.config.useGPU !== opts.useGPU
    this.config = opts
    this.applyTrackerSettings()

    if (gpuChanged && this.isTracking) {
      void this.reinitWorker()
    }
  }

  async start(videoEl: HTMLVideoElement): Promise<void> {
    this.video = videoEl
    try {
      await this.client.init(this.config.useGPU)
      this.ensureGazeTracker()

      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: false,
      })
      videoEl.srcObject = this.stream
      await videoEl.play()

      this.trackingStartTime = performance.now()
      this.lastSuccessfulDetectionTime = this.trackingStartTime
      this.isTracking = true
      this.showTrackingError = false
      this.errorMessage = null
      this.resetRecenterState()
      this.gazeTracker?.reset()
      this.headPoseTracker.reset()
      this.loop()
      this.emit()
    } catch (e) {
      this.showTrackingError = true
      this.errorMessage = e instanceof Error ? e.message : 'Camera access denied'
      this.isTracking = false
      this.emit()
      throw e
    }
  }

  recenter(): void {
    this.recenterCursor()
  }

  stop(): void {
    if (this.rafId != null) cancelAnimationFrame(this.rafId)
    this.rafId = null
    this.stream?.getTracks().forEach((t) => t.stop())
    this.stream = null
    if (this.video) this.video.srcObject = null
    this.client.dispose()
    this.client = new FaceLandmarkerClient()
    this.isTracking = false
    this.isCursorVisible = false
    this.gazePosition = null
    this.isProcessingFrame = false
    this.emit()
  }

  private async reinitWorker(): Promise<void> {
    this.client.dispose()
    this.client = new FaceLandmarkerClient()
    try {
      await this.client.init(this.config.useGPU)
    } catch (e) {
      this.showTrackingError = true
      this.errorMessage = e instanceof Error ? e.message : 'Failed to reinitialize tracking'
      this.emit()
    }
  }

  private ensureGazeTracker(): void {
    const w = window.innerWidth
    const h = window.innerHeight
    if (!this.gazeTracker) {
      this.gazeTracker = new GazeTracker(w, h)
    } else {
      this.gazeTracker.updateScreenDimensions(w, h)
    }
    this.applyTrackerSettings()
  }

  private applyTrackerSettings(): void {
    const gt = this.gazeTracker
    if (gt) {
      gt.trackingMethod = this.config.trackingMethod
      gt.smoothingMode = this.config.smoothingMode
      gt.eyeSelection = this.config.eyeSelection
      gt.setLerpFactor(sensitivityToLerp(this.config.sensitivity))
      gt.setGazeOffsets(
        gazeCameraOffsetX(this.config.headCameraPosition, this.config.headOffsetYaw),
        0.3,
      )
    }

    this.headPoseTracker.sensitivityX = this.config.headSensX
    this.headPoseTracker.sensitivityY = this.config.headSensY
    this.headPoseTracker.cameraOffsetYaw = this.config.headOffsetYaw
    this.headPoseTracker.cameraOffsetPitch = this.config.headOffsetPitch
    this.headPoseTracker.applyCameraPositionPreset(this.config.headCameraPosition)
  }

  private loop = (): void => {
    if (!this.video || this.video.readyState < 2) {
      this.rafId = requestAnimationFrame(this.loop)
      return
    }

    const now = performance.now()
    if (now - this.lastFrameProcessedTime < MIN_FRAME_INTERVAL_MS) {
      this.rafId = requestAnimationFrame(this.loop)
      return
    }
    this.lastFrameProcessedTime = now

    if (!this.isProcessingFrame) {
      void this.processFrame(now)
    }

    this.rafId = requestAnimationFrame(this.loop)
  }

  private async processFrame(now: number): Promise<void> {
    if (!this.video || !this.captureCtx) return
    this.isProcessingFrame = true

    try {
      const vw = this.video.videoWidth
      const vh = this.video.videoHeight
      if (vw === 0 || vh === 0) return

      this.captureCanvas.width = vw
      this.captureCanvas.height = vh
      this.captureCtx.drawImage(this.video, 0, 0, vw, vh)
      const bitmap = await createImageBitmap(this.captureCanvas)
      const frame = await this.client.detect(bitmap)

      if (frame.landmarks.length === 0) {
        this.handleNoFace(now)
        return
      }

      if (now - this.lastSuccessfulDetectionTime > TRACKING_LOSS_RESET_MS) {
        this.gazeTracker?.reset()
        this.headPoseTracker.reset()
        this.lastValidPosition = null
      }
      this.lastSuccessfulDetectionTime = now
      this.lastLandmarkTime = now

      if (this.config.mode === 'face') {
        this.handleFaceFrame(frame.landmarks, now)
      } else {
        this.handleEyeGazeFrame(frame, now)
      }
    } catch {
      this.handleNoFace(now)
    } finally {
      this.isProcessingFrame = false
    }
  }

  private handleNoFace(now: number): void {
    const isWarmingUp = now - this.trackingStartTime < WARMUP_DURATION_MS
    if (
      this.lastValidPosition &&
      now - this.lastLandmarkTime < LAST_POSITION_HOLD_MS
    ) {
      this.gazePosition = this.lastValidPosition
      this.isTracking = true
      this.showTrackingError = false
    } else {
      this.isTracking = false
      this.isCursorVisible = false
      this.showTrackingError = !isWarmingUp && this.config.showTrackingErrorBanner
    }
    this.emit()
  }

  private handleFaceFrame(landmarks: LandmarkPoint[], now: number): void {
    if (this.config.enableDoubleBlinkRecenter) {
      this.processHeadBlinkDetection(this.headPoseTracker.detectBlink(landmarks), landmarks, now)
    }

    const result = this.headPoseTracker.processLandmarks(
      landmarks,
      window.innerWidth,
      window.innerHeight,
      this.config.smoothingMode,
      sensitivityToLerp(this.config.sensitivity),
    )
    if (!result) {
      this.handleNoFace(now)
      return
    }

    const isWarmingUp = now - this.trackingStartTime < WARMUP_DURATION_MS
    const target = { x: result.screenX, y: result.screenY }
    this.isTracking = true
    this.showTrackingError = false
    this.isGazeOutOfBounds = result.isOutOfBounds

    if (isWarmingUp) {
      this.isCursorVisible = false
    } else {
      const hide =
        result.isOutOfBounds && this.config.enableOutOfBoundsHiding
      this.gazePosition = target
      this.isCursorVisible = !hide
      this.lastValidPosition = target
    }
    this.emit()
  }

  private handleEyeGazeFrame(frame: FaceLandmarkFrame, now: number): void {
    this.ensureGazeTracker()
    const gt = this.gazeTracker!
    const result = gt.processFrame(frame)
    if (!result) {
      this.handleNoFace(now)
      return
    }

    const isWarmingUp = now - this.trackingStartTime < WARMUP_DURATION_MS
    this.lastRawGazeX = result.gazeX
    this.lastRawGazeY = result.gazeY

    const isBlinking = result.leftBlink && result.rightBlink
    this.processBlinkDetection(isBlinking, now)
    this.processAutoRecenter(result.gazeX, result.gazeY, now)

    let adjustedX = Math.min(1, Math.max(-1, result.gazeX - this.gazeOffsetX))
    let adjustedY = Math.min(1, Math.max(-1, result.gazeY - this.gazeOffsetY))
    this.updateGazeOutOfBoundsState(adjustedX, adjustedY, now)

    adjustedX = Math.min(1, Math.max(-1, adjustedX * this.config.gazeAmplification))
    adjustedY = Math.min(1, Math.max(-1, adjustedY * this.config.gazeAmplification))

    const [screenX, screenY] = gt.gazeToScreen(adjustedX, adjustedY)
    let target: Point = { x: screenX, y: screenY }

    if (gt.usesScreenLerp() && this.lastValidPosition) {
      const lerp = sensitivityToLerp(this.config.sensitivity)
      target = {
        x: this.lastValidPosition.x + lerp * (target.x - this.lastValidPosition.x),
        y: this.lastValidPosition.y + lerp * (target.y - this.lastValidPosition.y),
      }
    }

    target = {
      x: Math.min(window.innerWidth, Math.max(0, target.x)),
      y: Math.min(window.innerHeight, Math.max(0, target.y)),
    }

    this.isTracking = true
    this.showTrackingError = false

    if (isWarmingUp) {
      this.isCursorVisible = false
    } else if (!this.isGazeOutOfBounds || !this.config.enableOutOfBoundsHiding) {
      this.gazePosition = target
      this.isCursorVisible = true
      this.lastValidPosition = target
    }
    this.emit()
  }

  private recenterCursor(): void {
    const now = performance.now()
    if (this.lastRecenterTime > 0 && now - this.lastRecenterTime < BLINK_COOLDOWN_MS) return

    if (this.lastRawGazeX != null && this.lastRawGazeY != null) {
      this.gazeOffsetX = this.lastRawGazeX
      this.gazeOffsetY = this.lastRawGazeY
    }

    this.gazeTracker?.reset()
    this.headPoseTracker.reset()

    const w = window.innerWidth
    const h = window.innerHeight
    this.gazePosition = { x: w / 2, y: h / 2 }
    this.lastValidPosition = this.gazePosition
    this.isCursorVisible = true
    this.isGazeOutOfBounds = false
    this.lastRecenterTime = now
    this.isGazeCentered = false
    this.gazeCenteredStartTime = 0
    this.emit()
  }

  private processBlinkDetection(isBlinking: boolean, now: number): void {
    if (!this.config.enableDoubleBlinkRecenter) return

    if (isBlinking && !this.wasBlinking) {
      this.blinkStartTime = now
    } else if (!isBlinking && this.wasBlinking) {
      const duration = now - this.blinkStartTime
      if (duration >= BLINK_MIN_DURATION_MS) {
        const sinceLast = now - this.lastBlinkEndTime
        if (this.lastBlinkEndTime > 0 && sinceLast <= DOUBLE_BLINK_WINDOW_MS) {
          this.lastBlinkEndTime = 0
          this.recenterCursor()
        } else {
          this.lastBlinkEndTime = now
        }
      }
    }
    this.wasBlinking = isBlinking
    if (this.lastBlinkEndTime > 0 && now - this.lastBlinkEndTime > DOUBLE_BLINK_WINDOW_MS) {
      this.lastBlinkEndTime = 0
    }
  }

  private processHeadBlinkDetection(
    isBlinking: boolean,
    landmarks: LandmarkPoint[],
    now: number,
  ): void {
    if (isBlinking && !this.headWasBlinking) {
      this.headBlinkStartTime = now
    } else if (!isBlinking && this.headWasBlinking) {
      const duration = now - this.headBlinkStartTime
      if (duration >= BLINK_MIN_DURATION_MS) {
        const sinceLast = now - this.headLastBlinkEndTime
        if (this.headLastBlinkEndTime > 0 && sinceLast <= DOUBLE_BLINK_WINDOW_MS) {
          this.headLastBlinkEndTime = 0
          this.headPoseTracker.recenter(landmarks)
          this.headPoseTracker.reset()
        } else {
          this.headLastBlinkEndTime = now
        }
      }
    }
    this.headWasBlinking = isBlinking
    if (this.headLastBlinkEndTime > 0 && now - this.headLastBlinkEndTime > DOUBLE_BLINK_WINDOW_MS) {
      this.headLastBlinkEndTime = 0
    }
  }

  private processAutoRecenter(rawX: number, rawY: number, now: number): void {
    if (!this.config.enableAutoRecenter) return

    const adjustedX = rawX - this.gazeOffsetX
    const adjustedY = rawY - this.gazeOffsetY
    const nearCenter =
      Math.abs(adjustedX) <= CENTER_GAZE_THRESHOLD &&
      Math.abs(adjustedY) <= CENTER_GAZE_THRESHOLD

    if (nearCenter) {
      if (!this.isGazeCentered) {
        this.gazeCenteredStartTime = now
        this.isGazeCentered = true
      } else if (now - this.gazeCenteredStartTime >= AUTO_RECENTER_DURATION_MS) {
        this.recenterCursor()
      }
    } else {
      this.isGazeCentered = false
      this.gazeCenteredStartTime = 0
    }
  }

  private updateGazeOutOfBoundsState(gazeX: number, gazeY: number, now: number): void {
    if (!this.config.enableOutOfBoundsHiding) {
      this.isGazeOutOfBounds = false
      return
    }

    const out =
      Math.abs(gazeX) > GAZE_OUT_OF_BOUNDS_THRESHOLD ||
      Math.abs(gazeY) > GAZE_OUT_OF_BOUNDS_THRESHOLD

    if (out) {
      if (!this.isGazeOutOfBounds) this.gazeOutOfBoundsStartTime = now
      else if (now - this.gazeOutOfBoundsStartTime > OUT_OF_BOUNDS_TIMEOUT_MS) {
        this.isGazeOutOfBounds = true
        this.isCursorVisible = false
      }
    } else {
      this.gazeOutOfBoundsStartTime = 0
      this.isGazeOutOfBounds = false
    }
  }

  private resetRecenterState(): void {
    this.gazeOffsetX = 0
    this.gazeOffsetY = 0
    this.lastRawGazeX = null
    this.lastRawGazeY = null
    this.wasBlinking = false
    this.lastBlinkEndTime = 0
    this.headWasBlinking = false
    this.headLastBlinkEndTime = 0
    this.isGazeCentered = false
    this.gazeCenteredStartTime = 0
    this.gazeOutOfBoundsStartTime = 0
    this.lastValidPosition = null
  }
}

export const trackingManager = new TrackingManager()
