import type { Locale } from '../i18n/i18n'
import { useSettings } from '../settings/settingsStore'
import {
  disableNativeSpeech,
  getNativeVoiceCount,
  isNativeSpeechDisabled,
  isNativeSpeechSupported,
  nativeSpeakStarted,
  primeNativeSpeech,
  shouldPreferNativeSpeech,
  tryNativeSpeak,
} from './nativeSpeech'
import { speakWithPiper, stopPiperSpeech } from './piperSpeech'
import { setTtsStatus } from './status'

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

  const activeLocale = locale ?? useSettings.getState().locale
  primeNativeSpeech()
  setTtsStatus({ state: 'speaking', message: null })

  if (!shouldPreferNativeSpeech()) {
    void speakWithPiper(trimmed, activeLocale).catch(() => {})
    return
  }

  const nativeAttempted = tryNativeSpeak(trimmed, activeLocale)
  if (!nativeAttempted) {
    void speakWithPiper(trimmed, activeLocale).catch(() => {})
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
    void speakWithPiper(trimmed, activeLocale).catch(() => {})
  }, NATIVE_START_TIMEOUT_MS)
}

export function stopSpeech(): void {
  if (isNativeSpeechSupported() && (speechSynthesis.speaking || speechSynthesis.pending)) {
    speechSynthesis.cancel()
  }
  stopPiperSpeech()
  setTtsStatus({ state: 'idle', message: null })
}

export function getSpeechDiagnostics(): {
  nativeSupported: boolean
  nativeVoiceCount: number
  usingPiperFallback: boolean
} {
  return {
    nativeSupported: isNativeSpeechSupported(),
    nativeVoiceCount: getNativeVoiceCount(),
    usingPiperFallback: isNativeSpeechDisabled() || getNativeVoiceCount() === 0,
  }
}
