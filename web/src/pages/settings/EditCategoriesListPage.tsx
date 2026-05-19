import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ReorderButtons } from '../../components/settings/ReorderButtons'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { setCategoryHidden, reorderCategories } from '../../data/crud'
import { loadCategoriesForEdit } from '../../data/repository'
import type { CategoryDisplay } from '../../data/types'
import { symbolEmoji } from '../../data/symbols'
import { useSettings } from '../../settings/settingsStore'

const LAYOUT_HINTS: Record<number, string> = {
  1: '1 phrase: full screen',
  2: '2 phrases: left and right',
  3: '3 phrases: 2 top, 1 bottom',
  4: '4 phrases: 2×2 grid',
}

export function EditCategoriesListPage() {
  const navigate = useNavigate()
  const settings = useSettings()
  const [categories, setCategories] = useState<CategoryDisplay[]>([])
  const [loading, setLoading] = useState(true)
  const [reorderMode, setReorderMode] = useState(false)

  const refresh = useCallback(async () => {
    setLoading(true)
    setCategories(await loadCategoriesForEdit())
    setLoading(false)
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const moveCategory = async (index: number, direction: -1 | 1) => {
    const next = index + direction
    if (next < 0 || next >= categories.length) return
    const ids = categories.map((c) => c.id)
    ;[ids[index], ids[next]] = [ids[next], ids[index]]
    await reorderCategories(ids)
    await refresh()
  }

  const toggleHidden = async (cat: CategoryDisplay) => {
    await setCategoryHidden(cat.id, !cat.hidden)
    await refresh()
  }

  return (
    <SettingsLayout
      title="Edit Categories"
      backTo="/settings"
      actions={
        <button type="button" className="text-btn" onClick={() => setReorderMode((v) => !v)}>
          {reorderMode ? 'Done' : 'Reorder'}
        </button>
      }
    >
      <section className="settings-section edit-inline-section">
        <h2>Symbols per page</h2>
        <div className="symbol-count-stepper">
          <button
            type="button"
            disabled={settings.symbolCount <= 1}
            onClick={() => settings.setSymbolCount(settings.symbolCount - 1)}
            aria-label="Decrease"
          >
            −
          </button>
          <span className="symbol-count-value">{settings.symbolCount}</span>
          <button
            type="button"
            disabled={settings.symbolCount >= 4}
            onClick={() => settings.setSymbolCount(settings.symbolCount + 1)}
            aria-label="Increase"
          >
            +
          </button>
        </div>
        <p className="hint">{LAYOUT_HINTS[settings.symbolCount] ?? `${settings.symbolCount} phrases`}</p>
      </section>

      {loading ? (
        <p className="status">Loading…</p>
      ) : categories.length === 0 ? (
        <div className="empty-state">
          <p className="empty-state-title">No categories</p>
          <p className="hint">Add a custom category to get started.</p>
        </div>
      ) : (
        <ul className="edit-list">
          {categories.map((cat, index) => (
            <li key={cat.id} className="edit-list-row">
              {reorderMode ? (
                <ReorderButtons
                  canMoveUp={index > 0}
                  canMoveDown={index < categories.length - 1}
                  onMoveUp={() => void moveCategory(index, -1)}
                  onMoveDown={() => void moveCategory(index, 1)}
                />
              ) : (
                <span className="edit-list-icon" aria-hidden>
                  {symbolEmoji(cat.symbolName)}
                </span>
              )}
              <button
                type="button"
                className="edit-list-main"
                onClick={() => navigate(`/settings/edit/categories/${cat.id}`)}
              >
                <span className="edit-list-title">{cat.name}</span>
                {cat.isPreset ? <span className="edit-list-badge">Preset</span> : null}
              </button>
              <label className="toggle-label" title={cat.hidden ? 'Hidden' : 'Visible'}>
                <input
                  type="checkbox"
                  checked={!cat.hidden}
                  onChange={() => void toggleHidden(cat)}
                />
                <span className="toggle-text">{cat.hidden ? 'Hidden' : 'Show'}</span>
              </label>
            </li>
          ))}
        </ul>
      )}

      <div className="settings-footer-actions">
        <Link to="/settings/edit/categories/new" className="primary-btn">
          + Add category
        </Link>
      </div>
    </SettingsLayout>
  )
}
