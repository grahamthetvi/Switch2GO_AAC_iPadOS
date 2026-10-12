import type { Locale } from '../i18n/i18n'
import { useSettings } from '../settings/settingsStore'
import {
  cancelNativeSpeech,
  disableNativeSpeech,
  isNativeSpeechDisabled,
  isNativeSpeechSupported,
  listNativeVoices,
  nativeSpeakStarted,
  primeNativeSpeech,
  shouldPreferNativeSpeech,
  tryNativeSpeak,
} from './nativeSpeech'
import { speakWithPiper, stopPiperSpeech, type PiperSpeakOptions } from './piperSpeech'
import { setTtsStatus } from './status'
import { clampSpeechRate, defaultPiperVoiceId, resolveSpeechVoiceId } from './speechVoice'

const NATIVE_START_TIMEOUT_MS = 450

export { getTtsStatus, subscribeTtsStatus, clearTtsError } from './status'

export function isSpeechSupported(): boolean {
  return isNativeSpeechSupported() || typeof Audio !== 'undefined'
}

/** Call during user gestures so speech works for touch and later selection modes. */
export function prepareSpeech(): void {
  primeNativeSpeech()
}

export function speak(text: string, locale?: Locale): void {
  const trimmed = text.trim()
  if (!trimmed) return

  const settings = useSettings.getState()
  const activeLocale = locale ?? settings.locale
  const playbackRate = clampSpeechRate(settings.speechRate)
  const choice = resolveSpeechVoiceId(settings.speechVoiceId, activeLocale, listNativeVoices())
  const piperOptions: PiperSpeakOptions = {
    playbackRate,
    voiceId: choice.kind === 'piper' ? choice.voiceId : defaultPiperVoiceId(activeLocale),
  }

  primeNativeSpeech()
  setTtsStatus({ state: 'speaking', message: null })

  if (choice.kind === 'piper' || !shouldPreferNativeSpeech()) {
    cancelNativeSpeech()
    void speakWithPiper(trimmed, activeLocale, piperOptions).catch(() => {})
    return
  }

  const nativeAttempted = tryNativeSpeak(trimmed, activeLocale, {
    rate: playbackRate,
    voiceURI: choice.kind === 'device' ? choice.voiceURI : undefined,
  })
  if (!nativeAttempted) {
    void speakWithPiper(trimmed, activeLocale, piperOptions).catch(() => {})
    return
  }

  window.setTimeout(() => {
    if (nativeSpeakStarted() || isNativeSpeechDisabled()) {
      if (nativeSpeakStarted()) {
        setTtsStatus({ state: 'idle', message: null })
      }
      return
    }

    disableNativeSpeech()
    void speakWithPiper(trimmed, activeLocale, piperOptions).catch(() => {})
  }, NATIVE_START_TIMEOUT_MS)
}

export function stopSpeech(): void {
  cancelNativeSpeech()
  stopPiperSpeech()
  setTtsStatus({ state: 'idle', message: null })
}
