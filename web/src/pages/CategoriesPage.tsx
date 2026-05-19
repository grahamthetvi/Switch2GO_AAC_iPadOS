import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { CategorySymbol } from '../components/CategorySymbol'
import { DwellSelectable } from '../components/DwellSelectable'
import { getPresetCategoryColor, loadCategories } from '../data/repository'
import type { CategoryDisplay } from '../data/types'
import { useTranslation } from '../i18n/useTranslation'
import { hexToCss, useSettings } from '../settings/settingsStore'
import { useTracking } from '../tracking/TrackingContext'

export function CategoriesPage() {
  const { t, locale } = useTranslation()
  const [categories, setCategories] = useState<CategoryDisplay[]>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const settings = useSettings()
  const navigate = useNavigate()
  const { dwell } = useTracking()

  const refresh = useCallback(async () => {
    setLoading(true)
    setLoadError(null)
    try {
      setCategories(await loadCategories())
    } catch (e) {
      setLoadError(e instanceof Error ? e.message : 'Failed to load categories')
      setCategories([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh, locale])

  useEffect(() => {
    dwell.clearAllButtons()
    return () => dwell.clearAllButtons()
  }, [dwell])

  const borderColor = hexToCss(settings.appBorderColor)

  return (
    <div className="page" style={{ background: borderColor }}>
      <header className="page-header">
        <h1>{t('appName')}</h1>
        <Link to="/settings" className="icon-btn" aria-label={t('settings')}>
          ⚙
        </Link>
      </header>

      {loadError ? (
        <p className="status error">{loadError}</p>
      ) : loading ? (
        <p className="status">{t('loadingCategories')}</p>
      ) : categories.length === 0 ? (
        <div className="empty-state">
          <p className="empty-state-title">{t('emptyCategoriesTitle')}</p>
          <p className="hint">{t('emptyCategoriesHint')}</p>
          <Link to="/settings/edit/categories" className="primary-btn inline">
            {t('editCategories')}
          </Link>
        </div>
      ) : (
        <div className="grid grid-categories">
          {categories.map((cat) => {
            const bg =
              cat.colorHex != null
                ? hexToCss(cat.colorHex)
                : getPresetCategoryColor(cat.id)
            const go = () => navigate(`/phrases/${cat.id}`)
            return (
              <DwellSelectable
                key={cat.id}
                id={`cat_${cat.id}`}
                className="tile category-tile"
                style={{ background: bg }}
                onActivate={go}
              >
                <CategorySymbol symbolId={cat.symbolName} />
                <span className="tile-label">{cat.name}</span>
              </DwellSelectable>
            )
          })}
        </div>
      )}
    </div>
  )
}
