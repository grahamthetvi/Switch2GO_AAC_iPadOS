import type { Locale } from '../i18n/i18n'
import { clampSpeechRate, voiceLangMatchesLocale, type DeviceVoiceInfo } from './speechVoice'

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

export function listNativeVoices(): DeviceVoiceInfo[] {
  if (!isNativeSpeechSupported()) return []
  return speechSynthesis.getVoices().map((voice) => ({
    voiceURI: voice.voiceURI,
    name: voice.name.trim() || voice.lang || voice.voiceURI,
    lang: voice.lang,
  }))
}

function clearVoiceCache(): void {
  voiceCache.clear()
}

if (typeof speechSynthesis !== 'undefined') {
  speechSynthesis.addEventListener('voiceschanged', clearVoiceCache)
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

function pickUtteranceVoice(locale: Locale, voiceURI?: string): SpeechSynthesisVoice | null {
  if (voiceURI) {
    const chosen = speechSynthesis.getVoices().find((voice) => voice.voiceURI === voiceURI)
    if (chosen && voiceLangMatchesLocale(chosen.lang, locale)) return chosen
  }
  return pickVoice(locale)
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

export interface NativeSpeakOptions {
  rate?: number
  voiceURI?: string
}

export function tryNativeSpeak(text: string, locale: Locale, options?: NativeSpeakOptions): boolean {
  if (!isNativeSpeechSupported() || nativeDisabled) return false

  nativeStartedThisUtterance = false
  safeResume()

  if (speechSynthesis.speaking || speechSynthesis.pending) {
    speechSynthesis.cancel()
  }

  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = LOCALE_LANG[locale]
  utterance.rate = clampSpeechRate(options?.rate ?? 1)
  utterance.volume = 1

  const voice = pickUtteranceVoice(locale, options?.voiceURI)
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

export function cancelNativeSpeech(): void {
  if (isNativeSpeechSupported() && (speechSynthesis.speaking || speechSynthesis.pending)) {
    speechSynthesis.cancel()
  }
  stopKeepAlive()
}

/** Choosing a device voice clears a previous failure that turned native speech off. */
export function enableNativeSpeech(): void {
  nativeDisabled = false
}

export function disableNativeSpeech(): void {
  nativeDisabled = true
  cancelNativeSpeech()
}
