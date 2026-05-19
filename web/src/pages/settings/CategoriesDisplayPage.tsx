import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings } from '../../settings/settingsStore'

const POSITIONS = [1, 2, 3, 4] as const

export function CategoriesDisplayPage() {
  const s = useSettings()

  return (
    <SettingsLayout title="Categories Display">
      <SettingsCard
        title="Position colors"
        hint="Used when a phrase has no custom background (by tile position on the page)"
      >
        {POSITIONS.map((pos) => (
          <label key={pos} className="color-row">
            Position {pos}
            <input
              type="color"
              value={'#' + (s.getSymbolColor(pos) & 0xffffff).toString(16).padStart(6, '0')}
              onChange={(e) => {
                const hex = parseInt(e.target.value.slice(1), 16)
                s.setSymbolColor(pos, 0xff000000 | hex)
              }}
            />
          </label>
        ))}
        <button type="button" className="secondary-btn" onClick={() => s.resetColorsToDefaults()}>
          Reset position colors
        </button>
      </SettingsCard>
      <p className="hint settings-section">
        To change category icons and colors on the home grid, use{' '}
        <strong>Edit Categories & Phrases</strong> from the settings hub.
      </p>
    </SettingsLayout>
  )
}
