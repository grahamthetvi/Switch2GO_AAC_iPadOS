import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ColorPickerModal } from '../../components/settings/ColorPickerModal'
import { ReorderButtons } from '../../components/settings/ReorderButtons'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { SymbolPickerModal } from '../../components/settings/SymbolPickerModal'
import { getDefaultCategoryColor, getDefaultCategorySymbol } from '../../data/categoryDefaults'
import {
  deleteCustomCategory,
  reorderPhrases,
  updateCategoryColor,
  updateCategorySymbol,
  updateCustomCategoryName,
} from '../../data/crud'
import { getCategoryById, loadPhrasesForEdit } from '../../data/repository'
import type { CategoryDisplay, PhraseDisplay } from '../../data/types'
import { RECENTS_CATEGORY_ID } from '../../data/types'
import { hexToCss } from '../../settings/settingsStore'
import { symbolEmoji } from '../../data/symbols'

export function EditCategoryDetailPage() {
  const { categoryId = '' } = useParams()
  const navigate = useNavigate()
  const [category, setCategory] = useState<CategoryDisplay | null>(null)
  const [phrases, setPhrases] = useState<PhraseDisplay[]>([])
  const [name, setName] = useState('')
  const [colorHex, setColorHex] = useState<number>(0xff00acc1)
  const [symbol, setSymbol] = useState('folder')
  const [showColor, setShowColor] = useState(false)
  const [showSymbol, setShowSymbol] = useState(false)
  const [reorderMode, setReorderMode] = useState(false)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    setLoading(true)
    const cat = await getCategoryById(categoryId)
    setCategory(cat)
    if (cat) {
      setName(cat.name)
      setColorHex(cat.colorHex ?? getDefaultCategoryColor(cat.id))
      setSymbol(cat.symbolName ?? getDefaultCategorySymbol(cat.id))
      if (cat.id !== RECENTS_CATEGORY_ID) {
        setPhrases(await loadPhrasesForEdit(cat.id))
      } else {
        setPhrases(await loadPhrasesForEdit(RECENTS_CATEGORY_ID))
      }
    }
    setLoading(false)
  }, [categoryId])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const displayColor = () => hexToCss(colorHex)

  const saveName = async (value: string) => {
    if (!category || category.isPreset) return
    setName(value)
    await updateCustomCategoryName(category.id, value)
  }

  const applyColor = async (hex: number) => {
    if (!category) return
    setColorHex(hex)
    await updateCategoryColor(category.id, hex)
  }

  const applySymbol = async (sym: string) => {
    if (!category) return
    setSymbol(sym)
    await updateCategorySymbol(category.id, sym)
  }

  const movePhrase = async (index: number, direction: -1 | 1) => {
    const next = index + direction
    if (next < 0 || next >= phrases.length) return
    const ordered = [...phrases]
    ;[ordered[index], ordered[next]] = [ordered[next], ordered[index]]
    await reorderPhrases(ordered.map((p) => ({ id: p.id, isPreset: p.isPreset })))
    setPhrases(ordered)
  }

  const deleteCategory = async () => {
    if (!category || category.isPreset) return
    if (!confirm(`Delete "${category.name}" and all its phrases?`)) return
    await deleteCustomCategory(category.id)
    navigate('/settings/edit/categories', { replace: true })
  }

  if (loading) {
    return (
      <SettingsLayout title="Edit Category" backTo="/settings/edit/categories">
        <p className="status">Loading…</p>
      </SettingsLayout>
    )
  }

  if (!category) {
    return (
      <SettingsLayout title="Edit Category" backTo="/settings/edit/categories">
        <p className="status error">Category not found</p>
      </SettingsLayout>
    )
  }

  const isRecents = category.id === RECENTS_CATEGORY_ID

  return (
    <SettingsLayout
      title="Edit Category"
      backTo="/settings/edit/categories"
      actions={
        !isRecents ? (
          <button type="button" className="text-btn" onClick={() => setReorderMode((v) => !v)}>
            {reorderMode ? 'Done' : 'Reorder'}
          </button>
        ) : null
      }
    >
      <section className="settings-section">
        <h2>Category name</h2>
        {category.isPreset ? (
          <>
            <p className="readonly-field">{category.name}</p>
            <p className="hint">Preset categories cannot be renamed</p>
          </>
        ) : (
          <input
            type="text"
            className="text-input"
            value={name}
            onChange={(e) => void saveName(e.target.value)}
          />
        )}
      </section>

      <section className="settings-section">
        <h2>Appearance</h2>
        <button type="button" className="picker-row" onClick={() => setShowColor(true)}>
          <span>Color</span>
          <span className="picker-preview" style={{ background: displayColor() }} />
          <span className="picker-chevron">›</span>
        </button>
        <button type="button" className="picker-row" onClick={() => setShowSymbol(true)}>
          <span>Icon</span>
          <span className="picker-preview emoji-preview">{symbolEmoji(symbol)}</span>
          <span className="picker-chevron">›</span>
        </button>
      </section>

      <section className="settings-section">
        <div className="section-header-row">
          <h2>Phrases</h2>
          {!isRecents ? (
            <Link
              to={`/settings/edit/categories/${categoryId}/phrases/new`}
              className="text-btn"
            >
              + Add
            </Link>
          ) : null}
        </div>
        {isRecents ? (
          <p className="hint">Recently spoken phrases appear here automatically.</p>
        ) : phrases.length === 0 ? (
          <div className="empty-state compact">
            <p className="empty-state-title">No phrases yet</p>
            <p className="hint">Add phrases to this category.</p>
            <Link
              to={`/settings/edit/categories/${categoryId}/phrases/new`}
              className="primary-btn inline"
            >
              + Add phrase
            </Link>
          </div>
        ) : (
          <ul className="edit-list">
            {phrases.map((phrase, index) => (
              <li key={phrase.id} className="edit-list-row">
                {reorderMode ? (
                  <ReorderButtons
                    canMoveUp={index > 0}
                    canMoveDown={index < phrases.length - 1}
                    onMoveUp={() => void movePhrase(index, -1)}
                    onMoveDown={() => void movePhrase(index, 1)}
                  />
                ) : null}
                <Link
                  to={`/settings/edit/phrases/${phrase.id}?preset=${phrase.isPreset ? '1' : '0'}&category=${categoryId}`}
                  className="edit-list-main link"
                >
                  <span className="edit-list-title">{phrase.text}</span>
                  {phrase.isPreset ? <span className="edit-list-badge">Preset</span> : null}
                  {phrase.style ? <span className="edit-list-badge style">Styled</span> : null}
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      {!category.isPreset ? (
        <section className="settings-section danger">
          <button type="button" className="danger-btn" onClick={() => void deleteCategory()}>
            Delete category
          </button>
        </section>
      ) : (
        <p className="hint settings-section">Preset categories cannot be deleted</p>
      )}

      {showColor ? (
        <ColorPickerModal
          selectedHex={colorHex}
          onSelect={(hex) => {
            void applyColor(hex)
            setShowColor(false)
          }}
          onClose={() => setShowColor(false)}
        />
      ) : null}
      {showSymbol ? (
        <SymbolPickerModal
          selectedSymbol={symbol}
          onSelect={(sym) => {
            void applySymbol(sym)
            setShowSymbol(false)
          }}
          onClose={() => setShowSymbol(false)}
        />
      ) : null}
    </SettingsLayout>
  )
}
