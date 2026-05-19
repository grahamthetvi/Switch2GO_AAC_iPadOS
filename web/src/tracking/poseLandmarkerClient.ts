import { FilesetResolver, PoseLandmarker } from '@mediapipe/tasks-vision'
import type { LandmarkPoint } from './types'

const MEDIAPIPE_VERSION = '0.10.21'
const WASM_BASE = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${MEDIAPIPE_VERSION}/wasm`
const MODEL_URL = `${import.meta.env.BASE_URL}models/pose_landmarker_lite.task`

export interface PoseLandmarkFrame {
  landmarks: LandmarkPoint[]
  frameWidth: number
  frameHeight: number
}

/** MediaPipe PoseLandmarker for upper-body / arm pose (main thread). */
export class PoseLandmarkerClient {
  private landmarker: PoseLandmarker | null = null
  private canvas = document.createElement('canvas')
  private ctx = this.canvas.getContext('2d')
  private initPromise: Promise<void> | null = null

  async init(useGPU: boolean): Promise<void> {
    if (this.initPromise) return this.initPromise

    this.initPromise = (async () => {
      this.disposeLandmarker()
      if (!this.ctx) {
        throw new Error('Canvas 2D context unavailable')
      }

      const vision = await FilesetResolver.forVisionTasks(WASM_BASE)
      this.landmarker = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
          delegate: useGPU ? 'GPU' : 'CPU',
        },
        runningMode: 'IMAGE',
        numPoses: 1,
        outputSegmentationMasks: false,
      })
    })()

    try {
      await this.initPromise
    } catch (e) {
      this.initPromise = null
      throw e
    }
  }

  async detect(bitmap: ImageBitmap): Promise<PoseLandmarkFrame> {
    if (!this.landmarker || !this.ctx) {
      bitmap.close()
      throw new Error('PoseLandmarker not ready')
    }

    try {
      this.canvas.width = bitmap.width
      this.canvas.height = bitmap.height
      this.ctx.drawImage(bitmap, 0, 0)

      const result = this.landmarker.detect(this.canvas)
      const pose = result.landmarks[0]
      if (!pose) {
        return {
          landmarks: [],
          frameWidth: this.canvas.width,
          frameHeight: this.canvas.height,
        }
      }

      const landmarks: LandmarkPoint[] = pose.map((lm) => ({
        x: lm.x,
        y: lm.y,
        z: lm.z ?? 0,
      }))

      return {
        landmarks,
        frameWidth: this.canvas.width,
        frameHeight: this.canvas.height,
      }
    } finally {
      bitmap.close()
    }
  }

  dispose(): void {
    this.disposeLandmarker()
    this.initPromise = null
  }

  private disposeLandmarker(): void {
    this.landmarker?.close()
    this.landmarker = null
  }
}
