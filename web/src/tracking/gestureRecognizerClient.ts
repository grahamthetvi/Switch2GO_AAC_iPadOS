import { FilesetResolver, GestureRecognizer } from '@mediapipe/tasks-vision'
import type { LandmarkPoint } from './types'

const MEDIAPIPE_VERSION = '0.10.21'
const WASM_BASE = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${MEDIAPIPE_VERSION}/wasm`
const MODEL_URL = `${import.meta.env.BASE_URL}models/gesture_recognizer.task`

export type DetectedHandSide = 'left' | 'right'

export interface DetectedHandGesture {
  side: DetectedHandSide
  gestureName: string
  score: number
  landmarks: LandmarkPoint[]
}

export interface GestureRecognizerFrame {
  hands: DetectedHandGesture[]
  frameWidth: number
  frameHeight: number
}

/** MediaPipe GestureRecognizer for open/closed hand detection (main thread). */
export class GestureRecognizerClient {
  private recognizer: GestureRecognizer | null = null
  private canvas = document.createElement('canvas')
  private ctx = this.canvas.getContext('2d')
  private initPromise: Promise<void> | null = null

  async init(useGPU: boolean): Promise<void> {
    if (this.initPromise) return this.initPromise

    this.initPromise = (async () => {
      this.disposeRecognizer()
      if (!this.ctx) {
        throw new Error('Canvas 2D context unavailable')
      }

      const vision = await FilesetResolver.forVisionTasks(WASM_BASE)
      this.recognizer = await GestureRecognizer.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
          delegate: useGPU ? 'GPU' : 'CPU',
        },
        runningMode: 'IMAGE',
        numHands: 2,
        cannedGesturesClassifierOptions: {
          scoreThreshold: 0.5,
        },
      })
    })()

    try {
      await this.initPromise
    } catch (e) {
      this.initPromise = null
      throw e
    }
  }

  async detect(bitmap: ImageBitmap): Promise<GestureRecognizerFrame> {
    if (!this.recognizer || !this.ctx) {
      bitmap.close()
      throw new Error('GestureRecognizer not ready')
    }

    try {
      this.canvas.width = bitmap.width
      this.canvas.height = bitmap.height
      this.ctx.drawImage(bitmap, 0, 0)

      const result = this.recognizer.recognize(this.canvas)
      const hands: DetectedHandGesture[] = []

      for (let i = 0; i < result.landmarks.length; i++) {
        const sideLabel = result.handedness[i]?.[0]?.categoryName ?? ''
        const side: DetectedHandSide = sideLabel.toLowerCase() === 'right' ? 'right' : 'left'
        const topGesture = result.gestures[i]?.[0]
        const landmarks: LandmarkPoint[] = result.landmarks[i].map((lm) => ({
          x: lm.x,
          y: lm.y,
          z: lm.z ?? 0,
        }))

        hands.push({
          side,
          gestureName: topGesture?.categoryName ?? 'None',
          score: topGesture?.score ?? 0,
          landmarks,
        })
      }

      return {
        hands,
        frameWidth: this.canvas.width,
        frameHeight: this.canvas.height,
      }
    } finally {
      bitmap.close()
    }
  }

  dispose(): void {
    this.disposeRecognizer()
    this.initPromise = null
  }

  private disposeRecognizer(): void {
    this.recognizer?.close()
    this.recognizer = null
  }
}
