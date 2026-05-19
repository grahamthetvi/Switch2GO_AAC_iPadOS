import type { FaceLandmarkFrame } from './types'
import type { WorkerOutMessage } from './worker/faceLandmarker.worker'

const WASM_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/wasm'
const MODEL_URL = `${import.meta.env.BASE_URL}models/face_landmarker.task`

/** Runs MediaPipe FaceLandmarker off the main thread. */
export class FaceLandmarkerClient {
  private worker: Worker | null = null
  private ready = false
  private initPromise: Promise<void> | null = null
  private nextFrameId = 0
  private pending = new Map<
    number,
    { resolve: (frame: FaceLandmarkFrame) => void; reject: (err: Error) => void }
  >()

  async init(useGPU: boolean): Promise<void> {
    if (this.initPromise) return this.initPromise

    this.initPromise = new Promise<void>((resolve, reject) => {
      this.disposeWorker()
      this.worker = new Worker(new URL('./worker/faceLandmarker.worker.ts', import.meta.url), {
        type: 'module',
      })

      const onMessage = (event: MessageEvent<WorkerOutMessage>) => {
        const msg = event.data
        if (msg.type === 'ready') {
          this.ready = true
          this.worker?.removeEventListener('message', onMessage)
          resolve()
        } else if (msg.type === 'error' && msg.frameId == null) {
          this.worker?.removeEventListener('message', onMessage)
          reject(new Error(msg.message))
        }
      }

      this.worker.addEventListener('message', onMessage)
      this.worker.addEventListener('message', (event: MessageEvent<WorkerOutMessage>) => {
        this.handleMessage(event.data)
      })

      this.worker.postMessage({
        type: 'init',
        useGPU,
        modelUrl: MODEL_URL,
        wasmBase: WASM_BASE,
      })
    })

    return this.initPromise
  }

  async detect(bitmap: ImageBitmap): Promise<FaceLandmarkFrame> {
    if (!this.worker || !this.ready) {
      bitmap.close()
      throw new Error('FaceLandmarker worker not ready')
    }

    const frameId = this.nextFrameId++
    return new Promise<FaceLandmarkFrame>((resolve, reject) => {
      this.pending.set(frameId, { resolve, reject })
      this.worker!.postMessage(
        { type: 'detect', frameId, bitmap, timestamp: performance.now() },
        [bitmap],
      )
    })
  }

  dispose(): void {
    this.pending.forEach(({ reject }) => reject(new Error('Worker disposed')))
    this.pending.clear()
    if (this.worker) {
      this.worker.postMessage({ type: 'dispose' })
      this.worker.terminate()
    }
    this.worker = null
    this.ready = false
    this.initPromise = null
  }

  private disposeWorker(): void {
    if (this.worker) {
      this.worker.postMessage({ type: 'dispose' })
      this.worker.terminate()
    }
    this.worker = null
    this.ready = false
  }

  private handleMessage(msg: WorkerOutMessage): void {
    if (msg.type === 'ready') return
    if (msg.type === 'error') {
      if (msg.frameId != null) {
        const pending = this.pending.get(msg.frameId)
        if (pending) {
          this.pending.delete(msg.frameId)
          pending.reject(new Error(msg.message))
        }
      }
      return
    }

    const pending = this.pending.get(msg.frameId)
    if (!pending) return
    this.pending.delete(msg.frameId)

    pending.resolve({
      landmarks: msg.landmarks,
      frameWidth: msg.frameWidth,
      frameHeight: msg.frameHeight,
      facialTransformationMatrix: msg.facialTransformationMatrix,
    })
  }
}
