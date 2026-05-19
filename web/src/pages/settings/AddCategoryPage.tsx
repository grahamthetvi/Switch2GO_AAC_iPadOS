import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ColorPickerModal } from '../../components/settings/ColorPickerModal'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { SymbolPickerModal } from '../../components/settings/SymbolPickerModal'
import { pickNewCategoryColor } from '../../data/categoryDefaults'
import { insertCustomCategory } from '../../data/crud'
import { hexToCss } from '../../settings/settingsStore'
import { symbolEmoji } from '../../data/symbols'

export function AddCategoryPage() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [colorHex, setColorHex] = useState(() => pickNewCategoryColor())
  const [symbol, setSymbol] = useState('folder')
  const [showColor, setShowColor] = useState(false)
  const [showSymbol, setShowSymbol] = useState(false)
  const [saving, setSaving] = useState(false)

  const save = async () => {
    if (!name.trim() || saving) return
    setSaving(true)
    try {
      const id = await insertCustomCategory(name.trim(), colorHex, symbol)
      navigate(`/settings/edit/categories/${id}`, { replace: true })
    } finally {
      setSaving(false)
    }
  }

  return (
    <SettingsLayout title="Add Category" backTo="/settings/edit/categories">
      <section className="settings-section">
        <label className="stack-label">
          Category name
          <input
            type="text"
            className="text-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="My Sayings"
            autoFocus
          />
        </label>
      </section>

      <section className="settings-section">
        <h2>Appearance</h2>
        <button type="button" className="picker-row" onClick={() => setShowColor(true)}>
          <span>Color</span>
          <span className="picker-preview" style={{ background: hexToCss(colorHex) }} />
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowSymbol(true)}>
          <span>Icon</span>
          <span className="picker-preview emoji-preview">{symbolEmoji(symbol)}</span>
          <span className="picker-chevron">›</span>
        </button>
      </section>

      <div className="settings-footer-actions">
        <button
          type="button"
          className="primary-btn"
          disabled={!name.trim() || saving}
          onClick={() => void save()}
        >
          Save category
        </button>
      </div>

      {showColor ? (
        <ColorPickerModal
          selectedHex={colorHex}
          onSelect={(hex) => {
            setColorHex(hex)
            setShowColor(false)
          }}
          onClose={() => setShowColor(false)}
        />
      ) : null}
      {showSymbol ? (
        <SymbolPickerModal
          selectedSymbol={symbol}
          onSelect={(id) => {
            setSymbol(id)
            setShowSymbol(false)
          }}
          onClose={() => setShowSymbol(false)}
        />
      ) : null}
    </SettingsLayout>
  )
}
