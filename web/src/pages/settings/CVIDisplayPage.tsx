import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings } from '../../settings/settingsStore'

const LAYOUT_HINTS: Record<number, string> = {
  1: '1 phrase: full screen',
  2: '2 phrases: left and right',
  3: '3 phrases: 2 top, 1 bottom',
  4: '4 phrases: 2×2 grid',
}

export function CVIDisplayPage() {
  const s = useSettings()

  return (
    <SettingsLayout title="CVI Display">
      <SettingsCard title="Symbols per page" hint="How many phrase buttons appear on each page">
        <div className="symbol-count-stepper">
          <button
            type="button"
            disabled={s.symbolCount <= 1}
            onClick={() => s.setSymbolCount(s.symbolCount - 1)}
          >
            −
          </button>
          <span className="symbol-count-value">{s.symbolCount}</span>
          <button
            type="button"
            disabled={s.symbolCount >= 4}
            onClick={() => s.setSymbolCount(s.symbolCount + 1)}
          >
            +
          </button>
        </div>
        <p className="hint">{LAYOUT_HINTS[s.symbolCount]}</p>
      </SettingsCard>
    </SettingsLayout>
  )
}
