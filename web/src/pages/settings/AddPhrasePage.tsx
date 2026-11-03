import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { insertCustomPhrase } from '../../data/crud'
import { phraseSpeechText } from '../../data/phraseSpeech'
import { useSettings } from '../../settings/settingsStore'
import { prepareSpeech, speak } from '../../tts/speak'

export function AddPhrasePage() {
  const { categoryId = '' } = useParams()
  const navigate = useNavigate()
  const locale = useSettings((s) => s.locale)
  const [text, setText] = useState('')
  const [spoken, setSpoken] = useState('')
  const [saving, setSaving] = useState(false)

  const save = async () => {
    if (!text.trim() || saving) return
    setSaving(true)
    try {
      await insertCustomPhrase(categoryId, text.trim(), spoken)
      navigate(`/settings/edit/categories/${categoryId}`, { replace: true })
    } finally {
      setSaving(false)
    }
  }

  const preview = () => {
    const speech = phraseSpeechText(text, spoken)
    if (!speech.trim()) return
    prepareSpeech()
    speak(speech, locale)
  }

  return (
    <SettingsLayout
      title="Add Phrase"
      backTo={`/settings/edit/categories/${categoryId}`}
      backLabel="← Category"
    >
      <section className="settings-section">
        <label className="stack-label">
          Presented text
          <textarea
            className="text-input phrase-textarea"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="What shows on the button"
            rows={3}
            autoFocus
          />
        </label>
        <p className="hint">This is the label on the phrase button.</p>
      </section>
      <section className="settings-section">
        <label className="stack-label">
          Spoken text
          <textarea
            className="text-input phrase-textarea"
            value={spoken}
            onChange={(e) => setSpoken(e.target.value)}
            placeholder="Same as the button text"
            rows={3}
          />
        </label>
        <p className="hint">What is spoken aloud. Leave blank to say the button text.</p>
        <button type="button" className="secondary-btn" disabled={!text.trim()} onClick={preview}>
          Preview speech
        </button>
      </section>
      <div className="settings-footer-actions">
        <button
          type="button"
          className="primary-btn"
          disabled={!text.trim() || saving}
          onClick={() => void save()}
        >
          Save phrase
        </button>
      </div>
    </SettingsLayout>
  )
}
