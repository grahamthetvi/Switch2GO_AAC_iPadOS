import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import {
  deleteCustomPhrase,
  softDeletePresetPhrase,
  updateCustomPhraseText,
  updatePhraseSpokenText,
} from '../../data/crud'
import { phraseSpeechText } from '../../data/phraseSpeech'
import { loadPhraseById } from '../../data/repository'
import type { PhraseDisplay } from '../../data/types'
import { useSettings } from '../../settings/settingsStore'
import { prepareSpeech, speak } from '../../tts/speak'

export function EditPhraseDetailPage() {
  const { phraseId = '' } = useParams()
  const [searchParams] = useSearchParams()
  const isPreset = searchParams.get('preset') === '1'
  const categoryId = searchParams.get('category') ?? ''
  const navigate = useNavigate()
  const locale = useSettings((s) => s.locale)

  const [phrase, setPhrase] = useState<PhraseDisplay | null>(null)
  const [text, setText] = useState('')
  const [spoken, setSpoken] = useState('')
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    setLoading(true)
    const found = await loadPhraseById(phraseId, isPreset)
    if (found) {
      setPhrase(found)
      setText(found.text)
      setSpoken(found.spokenText ?? '')
    } else {
      setPhrase(null)
    }
    setLoading(false)
  }, [isPreset, phraseId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const saveText = async (value: string) => {
    if (!phrase || phrase.isPreset) return
    setText(value)
    await updateCustomPhraseText(phrase.id, value)
  }

  const saveSpoken = async (value: string) => {
    if (!phrase) return
    setSpoken(value)
    await updatePhraseSpokenText(phrase.id, phrase.isPreset, value)
  }

  const preview = () => {
    if (!phrase) return
    const presented = phrase.isPreset ? phrase.text : text
    const speech = phraseSpeechText(presented, spoken)
    if (!speech.trim()) return
    prepareSpeech()
    speak(speech, locale)
  }

  const remove = async () => {
    if (!phrase) return
    const label = phrase.text
    if (!confirm(`Remove "${label}" from this category?`)) return
    if (phrase.isPreset) {
      await softDeletePresetPhrase(phrase.id)
    } else {
      await deleteCustomPhrase(phrase.id)
    }
    if (categoryId) {
      navigate(`/settings/edit/categories/${categoryId}`, { replace: true })
    } else {
      navigate('/settings/edit/categories', { replace: true })
    }
  }

  const backTo = categoryId
    ? `/settings/edit/categories/${categoryId}`
    : '/settings/edit/categories'

  if (loading) {
    return (
      <SettingsLayout title="Edit Phrase" backTo={backTo}>
        <p className="status">Loading…</p>
      </SettingsLayout>
    )
  }

  if (!phrase) {
    return (
      <SettingsLayout title="Edit Phrase" backTo={backTo}>
        <p className="status error">Phrase not found</p>
      </SettingsLayout>
    )
  }

  const presented = phrase.isPreset ? phrase.text : text

  return (
    <SettingsLayout title="Edit Phrase" backTo={backTo} backLabel="← Category">
      <section className="settings-section">
        <h2>Presented text</h2>
        {phrase.isPreset ? (
          <>
            <p className="readonly-field">{phrase.text}</p>
            <p className="hint">Preset button text comes from the app and cannot be edited.</p>
          </>
        ) : (
          <>
            <textarea
              className="text-input phrase-textarea"
              value={text}
              onChange={(e) => void saveText(e.target.value)}
              rows={3}
            />
            <p className="hint">This is the label on the phrase button.</p>
          </>
        )}
      </section>

      <section className="settings-section">
        <h2>Spoken text</h2>
        <textarea
          className="text-input phrase-textarea"
          value={spoken}
          onChange={(e) => void saveSpoken(e.target.value)}
          placeholder="Same as the button text"
          rows={3}
        />
        <p className="hint">What is spoken aloud. Leave blank to say the button text.</p>
        <button
          type="button"
          className="secondary-btn"
          disabled={!presented.trim()}
          onClick={preview}
        >
          Preview speech
        </button>
      </section>

      <section className="settings-section">
        <h2>Style</h2>
        <Link
          to={`/settings/edit/phrases/${phraseId}/style?preset=${phrase.isPreset ? '1' : '0'}&category=${categoryId}`}
          className="primary-btn inline"
        >
          Edit style (colors, border, image)
        </Link>
        {phrase.style ? <p className="hint">This phrase has custom styling.</p> : null}
      </section>

      <section className="settings-section">
        {phrase.isPreset ? (
          <>
            <button type="button" className="danger-btn secondary-danger" onClick={() => void remove()}>
              Hide preset phrase
            </button>
            <p className="hint">Hides this phrase from the category. Reset the app to restore presets.</p>
          </>
        ) : (
          <button type="button" className="danger-btn" onClick={() => void remove()}>
            Delete phrase
          </button>
        )}
      </section>
    </SettingsLayout>
  )
}
