import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import {
  deleteCustomPhrase,
  softDeletePresetPhrase,
  updateCustomPhraseText,
} from '../../data/crud'
import { getPresetPhraseText, loadPhrasesForEdit } from '../../data/repository'
import type { PhraseDisplay } from '../../data/types'

export function EditPhraseDetailPage() {
  const { phraseId = '' } = useParams()
  const [searchParams] = useSearchParams()
  const isPreset = searchParams.get('preset') === '1'
  const categoryId = searchParams.get('category') ?? ''
  const navigate = useNavigate()

  const [phrase, setPhrase] = useState<PhraseDisplay | null>(null)
  const [text, setText] = useState('')
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    setLoading(true)
    if (categoryId) {
      const list = await loadPhrasesForEdit(categoryId)
      const found = list.find((p) => p.id === phraseId)
      if (found) {
        setPhrase(found)
        setText(found.text)
      }
    } else if (isPreset) {
      setPhrase({
        id: phraseId,
        text: getPresetPhraseText(phraseId),
        sortOrder: 0,
        isPreset: true,
        style: null,
      })
      setText(getPresetPhraseText(phraseId))
    }
    setLoading(false)
  }, [categoryId, isPreset, phraseId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const saveText = async (value: string) => {
    if (!phrase || phrase.isPreset) return
    setText(value)
    await updateCustomPhraseText(phrase.id, value)
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

  return (
    <SettingsLayout title="Edit Phrase" backTo={backTo} backLabel="← Category">
      <section className="settings-section">
        <h2>Phrase text</h2>
        {phrase.isPreset ? (
          <>
            <p className="readonly-field">{phrase.text}</p>
            <p className="hint">Preset phrase text comes from the app bundle and cannot be edited.</p>
          </>
        ) : (
          <textarea
            className="text-input phrase-textarea"
            value={text}
            onChange={(e) => void saveText(e.target.value)}
            rows={3}
          />
        )}
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
