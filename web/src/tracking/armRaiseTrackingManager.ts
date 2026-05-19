import { ArmRaiseDetector, type ArmRaiseState, type ArmSide } from './armRaiseDetector'
import { PoseLandmarkerClient } from './poseLandmarkerClient'

export interface ArmRaiseTrackingState {
  isTracking: boolean
  armState: ArmRaiseState
  showTrackingError: boolean
  errorMessage: string | null
}

type ArmRaiseListener = (side: ArmSide) => void
type StateListener = (state: ArmRaiseTrackingState) => void

const MIN_FRAME_INTERVAL_MS = 1000 / 15
const WARMUP_DURATION_MS = 1500
const TRACKING_LOSS_RESET_MS = 1000

/** Camera + MediaPipe pose loop for left/right arm-raise selection. */
export class ArmRaiseTrackingManager {
  private client = new PoseLandmarkerClient()
  private detector = new ArmRaiseDetector()
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
  private holdMs = 1000
  private margin = 0.08
  private cooldownMs = 1200

  isTracking = false
  armState: ArmRaiseState = { leftRaised: false, rightRaised: false }
  showTrackingError = false
  errorMessage: string | null = null

  private activationListeners = new Set<ArmRaiseListener>()
  private stateListeners = new Set<StateListener>()

  subscribeActivation(listener: ArmRaiseListener): () => void {
    this.activationListeners.add(listener)
    return () => this.activationListeners.delete(listener)
  }

  subscribeState(listener: StateListener): () => void {
    this.stateListeners.add(listener)
    return () => this.stateListeners.delete(listener)
  }

  configure(opts: { useGPU: boolean; holdMs: number; margin?: number; cooldownMs?: number }): void {
    const gpuChanged = this.useGPU !== opts.useGPU
    this.useGPU = opts.useGPU
    this.holdMs = opts.holdMs
    if (opts.margin != null) this.margin = opts.margin
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
    this.client = new PoseLandmarkerClient()
    this.isTracking = false
    this.armState = { leftRaised: false, rightRaised: false }
    this.isProcessingFrame = false
    this.emitState()
  }

  private async reinitClient(): Promise<void> {
    this.client.dispose()
    this.client = new PoseLandmarkerClient()
    try {
      await this.client.init(this.useGPU)
    } catch (e) {
      this.showTrackingError = true
      this.errorMessage = e instanceof Error ? e.message : 'Failed to reinitialize pose tracking'
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

      if (frame.landmarks.length === 0) {
        this.handleNoPose(now)
        return
      }

      if (now - this.lastSuccessfulDetectionTime > TRACKING_LOSS_RESET_MS) {
        this.detector.reset()
      }
      this.lastSuccessfulDetectionTime = now

      const { activation, state } = this.detector.process(
        frame.landmarks,
        null,
        now,
        { margin: this.margin, holdMs: this.holdMs, cooldownMs: this.cooldownMs },
      )
      this.armState = state
      this.showTrackingError = false
      this.errorMessage = null

      if (activation) {
        for (const listener of this.activationListeners) listener(activation)
      }
      this.emitState()
    } catch {
      this.handleNoPose(now)
    } finally {
      this.isProcessingFrame = false
    }
  }

  private handleNoPose(now: number): void {
    const isWarmingUp = now - this.trackingStartTime < WARMUP_DURATION_MS
    this.armState = { leftRaised: false, rightRaised: false }
    if (!isWarmingUp) {
      this.showTrackingError = true
      this.errorMessage = 'Body not detected — step back so your shoulders are visible'
    }
    this.emitState()
  }

  private emitState(): void {
    const state: ArmRaiseTrackingState = {
      isTracking: this.isTracking,
      armState: this.armState,
      showTrackingError: this.showTrackingError,
      errorMessage: this.errorMessage,
    }
    for (const listener of this.stateListeners) listener(state)
  }
}

export const armRaiseTrackingManager = new ArmRaiseTrackingManager()
