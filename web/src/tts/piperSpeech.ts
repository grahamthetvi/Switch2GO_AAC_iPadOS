import type { TtsSession } from '@mintplex-labs/piper-tts-web'
import type { Locale } from '../i18n/i18n'
import { setTtsStatus } from './status'
import { clampSpeechRate, defaultPiperVoiceId } from './speechVoice'

const ORT_WASM_BASE = `${import.meta.env.BASE_URL}ort/`

let currentAudio: HTMLAudioElement | null = null
let speakQueue: Promise<void> = Promise.resolve()
let ttsSession: TtsSession | null = null

async function getTtsSession(voiceId: string): Promise<TtsSession> {
  const { TtsSession, WASM_BASE } = await import('@mintplex-labs/piper-tts-web')
  if (!ttsSession) {
    ttsSession = await TtsSession.create({
      voiceId,
      wasmPaths: {
        onnxWasm: ORT_WASM_BASE,
        piperData: `${WASM_BASE}.data`,
        piperWasm: `${WASM_BASE}.wasm`,
      },
    })
  } else {
    ttsSession.voiceId = voiceId
  }
  return ttsSession
}

function stopCurrentAudio(): void {
  if (!currentAudio) return
  currentAudio.pause()
  if (currentAudio.src.startsWith('blob:')) {
    URL.revokeObjectURL(currentAudio.src)
  }
  currentAudio = null
}

async function playBlob(blob: Blob, playbackRate: number): Promise<void> {
  stopCurrentAudio()

  const url = URL.createObjectURL(blob)
  const audio = new Audio(url)
  audio.playbackRate = playbackRate
  audio.preservesPitch = true
  currentAudio = audio

  await new Promise<void>((resolve, reject) => {
    audio.onended = () => {
      URL.revokeObjectURL(url)
      if (currentAudio === audio) currentAudio = null
      resolve()
    }
    audio.onerror = () => {
      URL.revokeObjectURL(url)
      if (currentAudio === audio) currentAudio = null
      reject(new Error('Audio playback failed'))
    }
    void audio.play().catch(reject)
  })
}

export function stopPiperSpeech(): void {
  stopCurrentAudio()
}

export interface PiperSpeakOptions {
  voiceId?: string
  playbackRate?: number
}

export function speakWithPiper(
  text: string,
  locale: Locale,
  options?: PiperSpeakOptions,
): Promise<void> {
  const trimmed = text.trim()
  if (!trimmed) return Promise.resolve()

  const requestedVoiceId = options?.voiceId?.trim()
  const voiceId = requestedVoiceId ? requestedVoiceId : defaultPiperVoiceId(locale)
  const playbackRate = clampSpeechRate(options?.playbackRate ?? 1)

  speakQueue = speakQueue
    .catch(() => {})
    .then(async () => {
      setTtsStatus({ state: 'loading', message: 'Preparing speech…' })
      try {
        const session = await getTtsSession(voiceId)
        const blob = await session.predict(trimmed)
        setTtsStatus({ state: 'speaking', message: null })
        await playBlob(blob, playbackRate)
        setTtsStatus({ state: 'idle', message: null })
      } catch (e) {
        const message =
          e instanceof Error ? e.message : 'Speech playback is unavailable on this device'
        setTtsStatus({ state: 'error', message })
        throw e
      }
    })

  return speakQueue
}
