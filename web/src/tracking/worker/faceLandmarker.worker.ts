import { FaceLandmarker, FilesetResolver } from '@mediapipe/tasks-vision'
import type { LandmarkPoint } from '../types'

export interface WorkerInitMessage {
  type: 'init'
  useGPU: boolean
  modelUrl: string
  wasmBase: string
}

export interface WorkerDetectMessage {
  type: 'detect'
  frameId: number
  bitmap: ImageBitmap
  timestamp: number
}

export interface WorkerDisposeMessage {
  type: 'dispose'
}

export type WorkerInMessage = WorkerInitMessage | WorkerDetectMessage | WorkerDisposeMessage

export interface WorkerReadyMessage {
  type: 'ready'
}

export interface WorkerResultMessage {
  type: 'result'
  frameId: number
  landmarks: LandmarkPoint[]
  frameWidth: number
  frameHeight: number
  facialTransformationMatrix?: number[]
}

export interface WorkerErrorMessage {
  type: 'error'
  frameId?: number
  message: string
}

export type WorkerOutMessage = WorkerReadyMessage | WorkerResultMessage | WorkerErrorMessage

let landmarker: FaceLandmarker | null = null
let canvas: OffscreenCanvas | null = null
let ctx: OffscreenCanvasRenderingContext2D | null = null

async function handleInit(msg: WorkerInitMessage): Promise<void> {
  landmarker?.close()
  landmarker = null

  const vision = await FilesetResolver.forVisionTasks(msg.wasmBase)
  landmarker = await FaceLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath: msg.modelUrl,
      delegate: msg.useGPU ? 'GPU' : 'CPU',
    },
    runningMode: 'IMAGE',
    numFaces: 1,
    outputFaceBlendshapes: false,
    outputFacialTransformationMatrixes: true,
  })

  canvas = new OffscreenCanvas(640, 480)
  ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('OffscreenCanvas 2D context unavailable')
  self.postMessage({ type: 'ready' } satisfies WorkerReadyMessage)
}

function handleDetect(msg: WorkerDetectMessage): void {
  if (!landmarker || !canvas || !ctx) {
    const err: WorkerErrorMessage = { type: 'error', frameId: msg.frameId, message: 'Landmarker not initialized' }
    self.postMessage(err)
    return
  }

  try {
    canvas.width = msg.bitmap.width
    canvas.height = msg.bitmap.height
    ctx.drawImage(msg.bitmap, 0, 0)
    msg.bitmap.close()

    const result = landmarker.detect(canvas)
    const face = result.faceLandmarks[0]
    if (!face) {
      const out: WorkerResultMessage = {
        type: 'result',
        frameId: msg.frameId,
        landmarks: [],
        frameWidth: canvas.width,
        frameHeight: canvas.height,
      }
      self.postMessage(out)
      return
    }

    const landmarks: LandmarkPoint[] = face.map((lm) => ({
      x: lm.x,
      y: lm.y,
      z: lm.z ?? 0,
    }))

    const matrix = result.facialTransformationMatrixes?.[0]?.data
    const out: WorkerResultMessage = {
      type: 'result',
      frameId: msg.frameId,
      landmarks,
      frameWidth: canvas.width,
      frameHeight: canvas.height,
      facialTransformationMatrix: matrix ? Array.from(matrix) : undefined,
    }
    self.postMessage(out)
  } catch (e) {
    const err: WorkerErrorMessage = {
      type: 'error',
      frameId: msg.frameId,
      message: e instanceof Error ? e.message : 'Detection failed',
    }
    self.postMessage(err)
  }
}

function handleDispose(): void {
  landmarker?.close()
  landmarker = null
  canvas = null
  ctx = null
}

self.onmessage = (event: MessageEvent<WorkerInMessage>) => {
  const msg = event.data
  if (msg.type === 'init') {
    handleInit(msg).catch((e) => {
      const err: WorkerErrorMessage = {
        type: 'error',
        message: e instanceof Error ? e.message : 'Worker init failed',
      }
      self.postMessage(err)
    })
  } else if (msg.type === 'detect') {
    handleDetect(msg)
  } else if (msg.type === 'dispose') {
    handleDispose()
  }
}
