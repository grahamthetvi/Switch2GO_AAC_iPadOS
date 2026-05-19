import type { Locale } from '../i18n/i18n'
import { setTtsStatus } from './status'

const PIPER_VOICE: Record<Locale, string> = {
  en: 'en_US-lessac-medium',
  fr: 'fr_FR-mls-medium',
  es: 'es_ES-davefx-medium',
}

let currentAudio: HTMLAudioElement | null = null
let speakQueue: Promise<void> = Promise.resolve()

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
        const { predict } = await import('@mintplex-labs/piper-tts-web')
        const blob = await predict({
          text: trimmed,
          voiceId: PIPER_VOICE[locale],
        })
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
