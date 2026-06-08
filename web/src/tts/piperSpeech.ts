import type { TtsSession } from '@mintplex-labs/piper-tts-web'
import type { Locale } from '../i18n/i18n'
import { setTtsStatus } from './status'

const PIPER_VOICE: Record<Locale, string> = {
  en: 'en_US-lessac-medium',
  fr: 'fr_FR-mls-medium',
  es: 'es_ES-davefx-medium',
}

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

async function playBlob(blob: Blob): Promise<void> {
  stopCurrentAudio()

  const url = URL.createObjectURL(blob)
  const audio = new Audio(url)
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

export function speakWithPiper(text: string, locale: Locale): Promise<void> {
  const trimmed = text.trim()
  if (!trimmed) return Promise.resolve()

  speakQueue = speakQueue
    .catch(() => {})
    .then(async () => {
      setTtsStatus({ state: 'loading', message: 'Preparing speech…' })
      try {
        const session = await getTtsSession(PIPER_VOICE[locale])
        const blob = await session.predict(trimmed)
        setTtsStatus({ state: 'speaking', message: null })
        await playBlob(blob)
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
