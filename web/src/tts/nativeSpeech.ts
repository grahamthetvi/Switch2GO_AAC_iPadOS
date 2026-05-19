import type { Locale } from '../i18n/i18n'

const LOCALE_LANG: Record<Locale, string> = {
  en: 'en-US',
  fr: 'fr-FR',
  es: 'es-ES',
}

const voiceCache = new Map<string, SpeechSynthesisVoice | null>()

let speechPrimed = false
let keepAliveTimer: ReturnType<typeof setInterval> | null = null
let nativeStartedThisUtterance = false
let nativeDisabled = false

export function isNativeSpeechSupported(): boolean {
  return typeof speechSynthesis !== 'undefined' && typeof SpeechSynthesisUtterance !== 'undefined'
}

export function isNativeSpeechDisabled(): boolean {
  return nativeDisabled
}

export function getNativeVoiceCount(): number {
  if (!isNativeSpeechSupported()) return 0
  return speechSynthesis.getVoices().length
}

function clearVoiceCache(): void {
  voiceCache.clear()
}

if (typeof speechSynthesis !== 'undefined') {
  speechSynthesis.onvoiceschanged = clearVoiceCache
}

function safeResume(): void {
  if (!isNativeSpeechSupported()) return
  try {
    if ('paused' in speechSynthesis && speechSynthesis.paused) {
      speechSynthesis.resume()
    }
  } catch {
    // Safari iOS may not implement resume().
  }
}

function stopKeepAlive(): void {
  if (keepAliveTimer != null) {
    clearInterval(keepAliveTimer)
    keepAliveTimer = null
  }
}

function startKeepAlive(): void {
  stopKeepAlive()
  keepAliveTimer = setInterval(() => {
    if (!isNativeSpeechSupported()) {
      stopKeepAlive()
      return
    }
    if (!speechSynthesis.speaking && !speechSynthesis.pending) {
      stopKeepAlive()
      return
    }
    safeResume()
  }, 250)
}

function pickVoice(locale: Locale): SpeechSynthesisVoice | null {
  const langTag = LOCALE_LANG[locale]
  if (voiceCache.has(langTag)) return voiceCache.get(langTag) ?? null

  const langPrefix = langTag.split('-')[0]
  const voices = speechSynthesis.getVoices()
  const voice =
    voices.find((v) => v.lang === langTag && v.localService) ??
    voices.find((v) => v.lang === langTag) ??
    voices.find((v) => v.lang.startsWith(langPrefix) && v.localService) ??
    voices.find((v) => v.lang.startsWith(langPrefix)) ??
    voices.find((v) => v.lang.startsWith('en')) ??
    voices[0] ??
    null

  voiceCache.set(langTag, voice)
  return voice
}

/** Unlock browser speech during a user gesture (required on iOS Safari). */
export function primeNativeSpeech(): void {
  if (!isNativeSpeechSupported()) return

  void speechSynthesis.getVoices()
  safeResume()

  if (!speechPrimed) {
    speechPrimed = true
    speechSynthesis.speak(new SpeechSynthesisUtterance(''))
  }
}

export function shouldPreferNativeSpeech(): boolean {
  if (!isNativeSpeechSupported() || nativeDisabled) return false
  return getNativeVoiceCount() > 0 || !nativeDisabled
}

export function tryNativeSpeak(text: string, locale: Locale): boolean {
  if (!isNativeSpeechSupported() || nativeDisabled) return false

  nativeStartedThisUtterance = false
  safeResume()

  if (speechSynthesis.speaking || speechSynthesis.pending) {
    speechSynthesis.cancel()
  }

  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = LOCALE_LANG[locale]
  utterance.rate = 0.95
  utterance.volume = 1

  const voice = pickVoice(locale)
  if (voice) utterance.voice = voice

  utterance.onstart = () => {
    nativeStartedThisUtterance = true
    startKeepAlive()
  }

  utterance.onend = () => stopKeepAlive()
  utterance.onerror = (event) => {
    stopKeepAlive()
    if (event.error === 'interrupted' || event.error === 'canceled') return
    nativeDisabled = true
  }

  speechSynthesis.speak(utterance)
  window.setTimeout(() => safeResume(), 100)
  return true
}

export function nativeSpeakStarted(): boolean {
  return nativeStartedThisUtterance
}

export function disableNativeSpeech(): void {
  nativeDisabled = true
  if (isNativeSpeechSupported() && (speechSynthesis.speaking || speechSynthesis.pending)) {
    speechSynthesis.cancel()
  }
  stopKeepAlive()
}
