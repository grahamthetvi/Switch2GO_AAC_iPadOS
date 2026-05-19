import { FaceLandmarker, FilesetResolver } from '@mediapipe/tasks-vision'
import type { FaceLandmarkFrame, LandmarkPoint } from './types'

// Must match installed @mediapipe/tasks-vision version (see package-lock).
const MEDIAPIPE_VERSION = '0.10.21'
const WASM_BASE = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${MEDIAPIPE_VERSION}/wasm`
const MODEL_URL = `${import.meta.env.BASE_URL}models/face_landmarker.task`

/** MediaPipe FaceLandmarker on the main thread (WASM does not load in ESM workers). */
export class FaceLandmarkerClient {
  private landmarker: FaceLandmarker | null = null
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
      this.landmarker = await FaceLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
          delegate: useGPU ? 'GPU' : 'CPU',
        },
        runningMode: 'IMAGE',
        numFaces: 1,
        outputFaceBlendshapes: false,
        outputFacialTransformationMatrixes: true,
      })
    })()

    try {
      await this.initPromise
    } catch (e) {
      this.initPromise = null
      throw e
    }
  }

  async detect(bitmap: ImageBitmap): Promise<FaceLandmarkFrame> {
    if (!this.landmarker || !this.ctx) {
      bitmap.close()
      throw new Error('FaceLandmarker not ready')
    }

    try {
      this.canvas.width = bitmap.width
      this.canvas.height = bitmap.height
      this.ctx.drawImage(bitmap, 0, 0)

      const result = this.landmarker.detect(this.canvas)
      const face = result.faceLandmarks[0]
      if (!face) {
        return {
          landmarks: [],
          frameWidth: this.canvas.width,
          frameHeight: this.canvas.height,
        }
      }

      const landmarks: LandmarkPoint[] = face.map((lm) => ({
        x: lm.x,
        y: lm.y,
        z: lm.z ?? 0,
      }))

      const matrix = result.facialTransformationMatrixes?.[0]?.data
      return {
        landmarks,
        frameWidth: this.canvas.width,
        frameHeight: this.canvas.height,
        facialTransformationMatrix: matrix ? Array.from(matrix) : undefined,
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
