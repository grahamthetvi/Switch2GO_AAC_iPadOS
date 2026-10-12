import type { Locale } from '../i18n/i18n'

export const SPEECH_RATE_MIN = 0.6
export const SPEECH_RATE_MAX = 1.4
export const SPEECH_RATE_STEP = 0.05
export const DEFAULT_SPEECH_RATE = 1
export const AUTO_SPEECH_VOICE_ID = 'auto'

const DEVICE_PREFIX = 'device:'
const PIPER_PREFIX = 'piper:'

export interface PiperVoiceOption {
  name: string
  voiceId: string
}

export const PIPER_VOICES_BY_LOCALE: Record<Locale, readonly PiperVoiceOption[]> = {
  en: [
    { name: 'Lessac', voiceId: 'en_US-lessac-medium' },
    { name: 'Ryan', voiceId: 'en_US-ryan-medium' },
    { name: 'Amy', voiceId: 'en_US-amy-medium' },
    { name: 'Alba', voiceId: 'en_GB-alba-medium' },
  ],
  fr: [
    { name: 'MLS', voiceId: 'fr_FR-mls-medium' },
    { name: 'Siwis', voiceId: 'fr_FR-siwis-medium' },
    { name: 'Tom', voiceId: 'fr_FR-tom-medium' },
  ],
  es: [
    { name: 'Davefx', voiceId: 'es_ES-davefx-medium' },
    { name: 'Sharvard', voiceId: 'es_ES-sharvard-medium' },
  ],
}

export interface DeviceVoiceInfo {
  voiceURI: string
  name: string
  lang: string
}

export type SpeechVoiceChoice =
  | { kind: 'auto' }
  | { kind: 'device'; voiceURI: string }
  | { kind: 'piper'; voiceId: string }

export function clampSpeechRate(rate: number): number {
  if (!Number.isFinite(rate)) return DEFAULT_SPEECH_RATE
  return Math.min(SPEECH_RATE_MAX, Math.max(SPEECH_RATE_MIN, rate))
}

export function defaultPiperVoiceId(locale: Locale): string {
  return PIPER_VOICES_BY_LOCALE[locale][0].voiceId
}

export function voiceLangMatchesLocale(lang: string, locale: Locale): boolean {
  const normalized = lang.trim().toLowerCase().replaceAll('_', '-')
  return normalized === locale || normalized.startsWith(`${locale}-`)
}

export function deviceVoicesForLocale(
  voices: readonly DeviceVoiceInfo[],
  locale: Locale,
): DeviceVoiceInfo[] {
  const matches = voices.filter(
    (voice) => voice.voiceURI.length > 0 && voiceLangMatchesLocale(voice.lang, locale),
  )
  matches.sort(
    (a, b) =>
      a.name.localeCompare(b.name, locale) ||
      a.lang.localeCompare(b.lang, locale) ||
      a.voiceURI.localeCompare(b.voiceURI),
  )

  const seen = new Set<string>()
  const unique: DeviceVoiceInfo[] = []
  for (const voice of matches) {
    if (seen.has(voice.voiceURI)) continue
    seen.add(voice.voiceURI)
    unique.push(voice)
  }
  return unique
}

export function parseSpeechVoiceId(speechVoiceId: string): SpeechVoiceChoice {
  const id = speechVoiceId.trim()
  if (id.startsWith(DEVICE_PREFIX)) {
    const voiceURI = id.slice(DEVICE_PREFIX.length)
    if (voiceURI.length > 0) return { kind: 'device', voiceURI }
    return { kind: 'auto' }
  }
  if (id.startsWith(PIPER_PREFIX)) {
    const voiceId = id.slice(PIPER_PREFIX.length)
    if (voiceId.length > 0) return { kind: 'piper', voiceId }
    return { kind: 'auto' }
  }
  return { kind: 'auto' }
}

export function deviceSpeechVoiceId(voiceURI: string): string {
  return `${DEVICE_PREFIX}${voiceURI}`
}

export function piperSpeechVoiceId(voiceId: string): string {
  return `${PIPER_PREFIX}${voiceId}`
}

export function canonicalSpeechVoiceId(speechVoiceId: string): string {
  const parsed = parseSpeechVoiceId(speechVoiceId)
  switch (parsed.kind) {
    case 'auto':
      return AUTO_SPEECH_VOICE_ID
    case 'device':
      return deviceSpeechVoiceId(parsed.voiceURI)
    case 'piper':
      return piperSpeechVoiceId(parsed.voiceId)
    default: {
      const unreachable: never = parsed
      return unreachable
    }
  }
}

/** A saved voice for another language is auto until a voice for this locale is chosen. */
export function resolveSpeechVoiceId(
  speechVoiceId: string,
  locale: Locale,
  deviceVoices?: readonly DeviceVoiceInfo[],
): SpeechVoiceChoice {
  const parsed = parseSpeechVoiceId(speechVoiceId)
  switch (parsed.kind) {
    case 'auto':
      return { kind: 'auto' }
    case 'piper':
      if (!PIPER_VOICES_BY_LOCALE[locale].some((voice) => voice.voiceId === parsed.voiceId)) {
        return { kind: 'auto' }
      }
      return parsed
    case 'device': {
      if (deviceVoices == null) return parsed
      const match = deviceVoices.find((voice) => voice.voiceURI === parsed.voiceURI)
      if (match == null || !voiceLangMatchesLocale(match.lang, locale)) return { kind: 'auto' }
      return { kind: 'device', voiceURI: parsed.voiceURI }
    }
    default: {
      const unreachable: never = parsed
      return unreachable
    }
  }
}
