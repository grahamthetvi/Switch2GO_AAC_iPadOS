import { ColorPickerModal } from '../../components/settings/ColorPickerModal'
import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { NEW_CATEGORY_COLOR_PALETTE } from '../../data/categoryDefaults'
import { hexToCss, useSettings } from '../../settings/settingsStore'
import { useState } from 'react'

export function AppBorderColorPage() {
  const s = useSettings()
  const [showPicker, setShowPicker] = useState(false)

  return (
    <SettingsLayout title="App Border Color">
      <SettingsCard hint="Background color around categories and phrases (full screen)">
        <button
          type="button"
          className="picker-row"
          onClick={() => setShowPicker(true)}
        >
          <span>Border color</span>
          <span className="picker-preview large" style={{ background: hexToCss(s.appBorderColor) }} />
          <span className="picker-chevron">›</span>
        </button>
        <div className="color-swatch-grid compact">
          {NEW_CATEGORY_COLOR_PALETTE.map((hex) => (
            <button
              key={hex}
              type="button"
              className={`color-swatch${hex === s.appBorderColor ? ' selected' : ''}`}
              style={{ background: hexToCss(hex) }}
              onClick={() => s.setAppBorderColor(hex)}
              aria-label="Pick color"
            />
          ))}
        </div>
      </SettingsCard>
      {showPicker ? (
        <ColorPickerModal
          selectedHex={s.appBorderColor}
          onSelect={(hex) => {
            s.setAppBorderColor(hex)
            setShowPicker(false)
          }}
          onClose={() => setShowPicker(false)}
        />
      ) : null}
    </SettingsLayout>
  )
}
