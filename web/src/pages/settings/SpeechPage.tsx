import { useEffect, useState } from 'react'
import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'
import { useSettings } from '../../settings/settingsStore'
import { enableNativeSpeech, listNativeVoices } from '../../tts/nativeSpeech'
import { speak } from '../../tts/speak'
import {
  AUTO_SPEECH_VOICE_ID,
  PIPER_VOICES_BY_LOCALE,
  SPEECH_RATE_MAX,
  SPEECH_RATE_MIN,
  SPEECH_RATE_STEP,
  clampSpeechRate,
  deviceSpeechVoiceId,
  deviceVoicesForLocale,
  parseSpeechVoiceId,
  piperSpeechVoiceId,
  resolveSpeechVoiceId,
  type DeviceVoiceInfo,
} from '../../tts/speechVoice'

export function SpeechPage() {
  const { t, locale } = useTranslation()
  const speechRate = useSettings((s) => s.speechRate)
  const speechVoiceId = useSettings((s) => s.speechVoiceId)
  const setSpeechRate = useSettings((s) => s.setSpeechRate)
  const setSpeechVoiceId = useSettings((s) => s.setSpeechVoiceId)
  const [deviceVoices, setDeviceVoices] = useState<DeviceVoiceInfo[]>(() =>
    deviceVoicesForLocale(listNativeVoices(), locale),
  )
  const [voicesReady, setVoicesReady] = useState(
    () => typeof speechSynthesis === 'undefined' || listNativeVoices().length > 0,
  )

  useEffect(() => {
    const refresh = () => {
      const voices = listNativeVoices()
      setDeviceVoices(deviceVoicesForLocale(voices, locale))
      if (voices.length > 0 || typeof speechSynthesis === 'undefined') {
        setVoicesReady(true)
      }
    }
    refresh()
    if (typeof speechSynthesis === 'undefined') return
    const onVoicesChanged = () => {
      setVoicesReady(true)
      setDeviceVoices(deviceVoicesForLocale(listNativeVoices(), locale))
    }
    speechSynthesis.addEventListener('voiceschanged', onVoicesChanged)
    return () => speechSynthesis.removeEventListener('voiceschanged', onVoicesChanged)
  }, [locale])

  const rate = clampSpeechRate(speechRate)
  const resolved = resolveSpeechVoiceId(
    speechVoiceId,
    locale,
    voicesReady ? deviceVoices : undefined,
  )

  function chooseVoice(id: string): void {
    setSpeechVoiceId(id)
    if (parseSpeechVoiceId(id).kind === 'device') {
      enableNativeSpeech()
    }
  }

  return (
    <SettingsLayout title={t('speech')} backTo="/settings" backLabel={t('settingsBack')}>
      <SettingsCard title={t('speechRate')} hint={t('speechRateHint')}>
        <div className="speech-rate-labels">
          <span>{t('speechRateSlow')}</span>
          <span>{t('speechRateNormal')}</span>
          <span>{t('speechRateFast')}</span>
        </div>
        <input
          className="speech-rate-slider"
          type="range"
          min={SPEECH_RATE_MIN}
          max={SPEECH_RATE_MAX}
          step={SPEECH_RATE_STEP}
          value={rate}
          aria-label={t('speechRate')}
          onChange={(e) => setSpeechRate(Number(e.target.value))}
        />
        <p className="settings-value">{t('speechRateValue', { rate: rate.toFixed(2) })}</p>
      </SettingsCard>

      <SettingsCard title={t('speechVoice')} hint={t('speechVoiceAutoHint')}>
        <ul className="option-list speech-voice-list">
          <VoiceOption
            label={t('speechVoiceAuto')}
            selected={resolved.kind === 'auto'}
            onSelect={() => chooseVoice(AUTO_SPEECH_VOICE_ID)}
          />
        </ul>

        <h3 className="settings-subheading">{t('speechDeviceVoices')}</h3>
        {voicesReady && deviceVoices.length === 0 ? (
          <p className="hint">{t('speechDeviceVoicesEmpty')}</p>
        ) : (
          <ul className="option-list speech-voice-list">
            {deviceVoices.map((voice) => (
              <VoiceOption
                key={voice.voiceURI}
                label={voice.name}
                meta={voice.lang}
                selected={resolved.kind === 'device' && resolved.voiceURI === voice.voiceURI}
                onSelect={() => chooseVoice(deviceSpeechVoiceId(voice.voiceURI))}
              />
            ))}
          </ul>
        )}

        <h3 className="settings-subheading">{t('speechPiperVoices')}</h3>
        <ul className="option-list speech-voice-list">
          {PIPER_VOICES_BY_LOCALE[locale].map((voice) => (
            <VoiceOption
              key={voice.voiceId}
              label={voice.name}
              meta={t('speechBuiltIn')}
              selected={resolved.kind === 'piper' && resolved.voiceId === voice.voiceId}
              onSelect={() => chooseVoice(piperSpeechVoiceId(voice.voiceId))}
            />
          ))}
        </ul>

        <button type="button" className="secondary-btn" onClick={() => speak(t('speechSample'))}>
          {t('speechHearSample')}
        </button>
      </SettingsCard>
    </SettingsLayout>
  )
}

function VoiceOption({
  label,
  meta,
  selected,
  onSelect,
}: {
  label: string
  meta?: string
  selected: boolean
  onSelect: () => void
}) {
  return (
    <li>
      <button
        type="button"
        className={`option-list-btn${selected ? ' selected' : ''}`}
        aria-pressed={selected}
        onClick={onSelect}
      >
        <span>
          {label}
          {selected ? <span className="check-mark"> ✓</span> : null}
        </span>
        {meta ? <span className="speech-voice-meta">{meta}</span> : null}
      </button>
    </li>
  )
}
