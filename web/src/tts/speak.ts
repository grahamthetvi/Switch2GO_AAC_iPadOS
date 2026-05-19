let preferredVoice: SpeechSynthesisVoice | null = null
let warmedUp = false
let warmUpPromise: Promise<void> | null = null
let keepAliveTimer: ReturnType<typeof setInterval> | null = null

const KEEP_ALIVE_MS = 12_000
const SPEECH_RATE = 0.95

function pickVoice(): SpeechSynthesisVoice | null {
  if (preferredVoice) return preferredVoice
  const voices = speechSynthesis.getVoices()
  preferredVoice =
    voices.find((v) => v.lang.startsWith('en') && v.localService) ??
    voices.find((v) => v.lang.startsWith('en')) ??
    voices[0] ??
    null
  return preferredVoice
}

function preloadVoices(): void {
  if (typeof speechSynthesis === 'undefined') return
  pickVoice()
}

function startKeepAlive(): void {
  if (keepAliveTimer || typeof speechSynthesis === 'undefined') return
  keepAliveTimer = setInterval(() => {
    if (speechSynthesis.speaking || speechSynthesis.pending) return
    const utterance = new SpeechSynthesisUtterance('\u200B')
    utterance.volume = 0
    const voice = pickVoice()
    if (voice) utterance.voice = voice
    utterance.rate = SPEECH_RATE
    speechSynthesis.speak(utterance)
  }, KEEP_ALIVE_MS)
}

function runWarmUp(): Promise<void> {
  if (warmedUp) return Promise.resolve()
  if (warmUpPromise) return warmUpPromise

  warmUpPromise = new Promise((resolve) => {
    if (typeof speechSynthesis === 'undefined') {
      resolve()
      return
    }

    const finish = () => {
      warmedUp = true
      startKeepAlive()
      resolve()
    }

    const utterance = new SpeechSynthesisUtterance(' ')
    utterance.volume = 0
    const voice = pickVoice()
    if (voice) utterance.voice = voice
    utterance.rate = SPEECH_RATE
    utterance.onend = finish
    utterance.onerror = finish
    speechSynthesis.speak(utterance)
  })

  return warmUpPromise
}

export function initTts(): void {
  if (typeof speechSynthesis === 'undefined') return
  preloadVoices()
  speechSynthesis.addEventListener('voiceschanged', () => {
    preferredVoice = null
    preloadVoices()
  })
}

function speakNow(text: string): void {
  speechSynthesis.cancel()
  const utterance = new SpeechSynthesisUtterance(text)
  const voice = pickVoice()
  if (voice) utterance.voice = voice
  utterance.rate = SPEECH_RATE
  speechSynthesis.speak(utterance)
}

export function speak(text: string): void {
  if (!text.trim() || typeof speechSynthesis === 'undefined') return

  if (!warmedUp) {
    void runWarmUp().then(() => speakNow(text))
    return
  }

  speakNow(text)
}
