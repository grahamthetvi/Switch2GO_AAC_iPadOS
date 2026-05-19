import { GestureRecognizerClient } from './gestureRecognizerClient'
import {
  HandGestureDetector,
  type HandGestureState,
  type HandSide,
} from './handGestureDetector'

export interface HandGestureTrackingState {
  isTracking: boolean
  handState: HandGestureState
  showTrackingError: boolean
  errorMessage: string | null
}

type HandGestureListener = (side: HandSide) => void
type StateListener = (state: HandGestureTrackingState) => void

const MIN_FRAME_INTERVAL_MS = 1000 / 15
const WARMUP_DURATION_MS = 1500
const TRACKING_LOSS_RESET_MS = 1000

/** Camera + MediaPipe gesture loop for left/right hand open/close selection. */
export class HandGestureTrackingManager {
  private client = new GestureRecognizerClient()
  private detector = new HandGestureDetector()
  private video: HTMLVideoElement | null = null
  private stream: MediaStream | null = null
  private rafId: number | null = null
  private captureCanvas = document.createElement('canvas')
  private captureCtx = this.captureCanvas.getContext('2d')

  private isProcessingFrame = false
  private lastFrameProcessedTime = 0
  private trackingStartTime = 0
  private lastSuccessfulDetectionTime = 0

  private useGPU = false
  private minScore = 0.55
  private stableFrames = 3
  private cooldownMs = 1200

  isTracking = false
  handState: HandGestureState = { leftPose: null, rightPose: null }
  showTrackingError = false
  errorMessage: string | null = null

  private activationListeners = new Set<HandGestureListener>()
  private stateListeners = new Set<StateListener>()

  subscribeActivation(listener: HandGestureListener): () => void {
    this.activationListeners.add(listener)
    return () => this.activationListeners.delete(listener)
  }

  subscribeState(listener: StateListener): () => void {
    this.stateListeners.add(listener)
    return () => this.stateListeners.delete(listener)
  }

  configure(opts: {
    useGPU: boolean
    minScore?: number
    stableFrames?: number
    cooldownMs?: number
  }): void {
    const gpuChanged = this.useGPU !== opts.useGPU
    this.useGPU = opts.useGPU
    if (opts.minScore != null) this.minScore = opts.minScore
    if (opts.stableFrames != null) this.stableFrames = opts.stableFrames
    if (opts.cooldownMs != null) this.cooldownMs = opts.cooldownMs
    if (gpuChanged && this.isTracking) {
      void this.reinitClient()
    }
  }

  async start(videoEl: HTMLVideoElement): Promise<void> {
    this.video = videoEl
    try {
      await this.client.init(this.useGPU)

      if (!this.stream) {
        this.stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
          audio: false,
        })
      }
      videoEl.srcObject = this.stream
      await videoEl.play()

      this.trackingStartTime = performance.now()
      this.lastSuccessfulDetectionTime = this.trackingStartTime
      this.isTracking = true
      this.showTrackingError = false
      this.errorMessage = null
      this.detector.reset()
      this.loop()
      this.emitState()
    } catch (e) {
      this.showTrackingError = true
      this.errorMessage = e instanceof Error ? e.message : 'Camera access denied'
      this.isTracking = false
      this.emitState()
      throw e
    }
  }

  stop(): void {
    if (this.rafId != null) cancelAnimationFrame(this.rafId)
    this.rafId = null
    this.stream?.getTracks().forEach((t) => t.stop())
    this.stream = null
    if (this.video) this.video.srcObject = null
    this.client.dispose()
    this.client = new GestureRecognizerClient()
    this.isTracking = false
    this.handState = { leftPose: null, rightPose: null }
    this.isProcessingFrame = false
    this.emitState()
  }

  private async reinitClient(): Promise<void> {
    this.client.dispose()
    this.client = new GestureRecognizerClient()
    try {
      await this.client.init(this.useGPU)
    } catch (e) {
      this.showTrackingError = true
      this.errorMessage =
        e instanceof Error ? e.message : 'Failed to reinitialize hand gesture tracking'
      this.emitState()
    }
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

      if (frame.hands.length === 0) {
        this.handleNoHands(now)
        return
      }

      if (now - this.lastSuccessfulDetectionTime > TRACKING_LOSS_RESET_MS) {
        this.detector.reset()
      }
      this.lastSuccessfulDetectionTime = now

      const { activation, state } = this.detector.process(frame.hands, now, {
        minScore: this.minScore,
        stableFrames: this.stableFrames,
        cooldownMs: this.cooldownMs,
      })
      this.handState = state
      this.showTrackingError = false
      this.errorMessage = null

      if (activation) {
        for (const listener of this.activationListeners) listener(activation)
      }
      this.emitState()
    } catch {
      this.handleNoHands(now)
    } finally {
      this.isProcessingFrame = false
    }
  }

  private handleNoHands(now: number): void {
    const isWarmingUp = now - this.trackingStartTime < WARMUP_DURATION_MS
    this.handState = { leftPose: null, rightPose: null }
    if (!isWarmingUp) {
      this.showTrackingError = true
      this.errorMessage = 'Hands not detected — hold your hands in view of the camera'
    }
    this.emitState()
  }

  private emitState(): void {
    const state: HandGestureTrackingState = {
      isTracking: this.isTracking,
      handState: this.handState,
      showTrackingError: this.showTrackingError,
      errorMessage: this.errorMessage,
    }
    for (const listener of this.stateListeners) listener(state)
  }
}

export const handGestureTrackingManager = new HandGestureTrackingManager()
