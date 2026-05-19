import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { insertCustomPhrase } from '../../data/crud'

export function AddPhrasePage() {
  const { categoryId = '' } = useParams()
  const navigate = useNavigate()
  const [text, setText] = useState('')
  const [saving, setSaving] = useState(false)

  const save = async () => {
    if (!text.trim() || saving) return
    setSaving(true)
    try {
      await insertCustomPhrase(categoryId, text.trim())
      navigate(`/settings/edit/categories/${categoryId}`, { replace: true })
    } finally {
      setSaving(false)
    }
  }

  return (
    <SettingsLayout
      title="Add Phrase"
      backTo={`/settings/edit/categories/${categoryId}`}
      backLabel="← Category"
    >
      <section className="settings-section">
        <label className="stack-label">
          Phrase text
          <textarea
            className="text-input phrase-textarea"
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="What do you want to say?"
            rows={3}
            autoFocus
          />
        </label>
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
