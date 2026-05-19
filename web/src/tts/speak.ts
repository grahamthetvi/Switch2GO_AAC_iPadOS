import type { Locale } from '../i18n/i18n'
import { useSettings } from '../settings/settingsStore'

const LOCALE_LANG: Record<Locale, string> = {
  en: 'en-US',
  fr: 'fr-FR',
  es: 'es-ES',
}

const voiceCache = new Map<string, SpeechSynthesisVoice | null>()
let speechPrimed = false

function getSpeechSynthesis(): SpeechSynthesis | null {
  if (typeof speechSynthesis === 'undefined') return null
  return speechSynthesis
}

function getVoices(): SpeechSynthesisVoice[] {
  const synth = getSpeechSynthesis()
  if (!synth) return []
  return synth.getVoices()
}

function clearVoiceCache(): void {
  voiceCache.clear()
}

function pickVoice(locale: Locale): SpeechSynthesisVoice | null {
  const langTag = LOCALE_LANG[locale]
  if (voiceCache.has(langTag)) return voiceCache.get(langTag) ?? null

  const langPrefix = langTag.split('-')[0]
  const voices = getVoices()
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

if (typeof speechSynthesis !== 'undefined') {
  speechSynthesis.onvoiceschanged = clearVoiceCache
}

export function isSpeechSupported(): boolean {
  return getSpeechSynthesis() != null && typeof SpeechSynthesisUtterance !== 'undefined'
}

/** Prime speech after a user gesture so later programmatic phrase speech works (iOS Safari). */
export function prepareSpeech(): void {
  const synth = getSpeechSynthesis()
  if (!synth) return

  void getVoices()
  if (synth.paused) synth.resume()

  if (speechPrimed) return
  speechPrimed = true

  const utterance = new SpeechSynthesisUtterance('\u200b')
  utterance.volume = 0.01
  utterance.rate = 2
  synth.speak(utterance)
}

export function speak(text: string, locale?: Locale): void {
  const trimmed = text.trim()
  if (!trimmed || !isSpeechSupported()) return

  const synth = getSpeechSynthesis()
  if (!synth) return

  if (synth.paused) synth.resume()

  const activeLocale = locale ?? useSettings.getState().locale
  const langTag = LOCALE_LANG[activeLocale]

  synth.cancel()

  const utterance = new SpeechSynthesisUtterance(trimmed)
  utterance.lang = langTag
  utterance.rate = 0.95
  utterance.volume = 1

  const voice = pickVoice(activeLocale)
  if (voice) utterance.voice = voice

  utterance.onerror = (event) => {
    if (event.error === 'interrupted' || event.error === 'canceled') return
    console.warn('[TTS]', event.error, trimmed)
  }

  synth.speak(utterance)

  // Chrome occasionally leaves synthesis paused until resume is called again.
  window.setTimeout(() => {
    if ((synth.pending || synth.speaking) && synth.paused) synth.resume()
  }, 100)
}
