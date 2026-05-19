import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings } from '../../settings/settingsStore'

export function TimingSensitivityPage() {
  const s = useSettings()

  return (
    <SettingsLayout title="Timing & Sensitivity">
      <SettingsCard
        title="Hover time"
        hint="How long to dwell on a button before selection"
      >
        <input
          type="range"
          min={0.5}
          max={5}
          step={0.1}
          value={s.dwellTime}
          onChange={(e) => s.setDwellTime(Number(e.target.value))}
        />
        <p className="settings-value">{s.dwellTime.toFixed(1)} seconds</p>
      </SettingsCard>

      <SettingsCard title="Repeat hover activation">
        <label className="toggle-row">
          <span>If enabled, keeping the cursor on a button activates it again</span>
          <input
            type="checkbox"
            checked={s.enableRepeatDwell}
            onChange={(e) => s.setEnableRepeatDwell(e.target.checked)}
          />
        </label>
        {s.enableRepeatDwell ? (
          <>
            <p className="hint">Repeat delay</p>
            <input
              type="range"
              min={0.5}
              max={5}
              step={0.1}
              value={s.repeatDwellDelay}
              onChange={(e) => s.setRepeatDwellDelay(Number(e.target.value))}
            />
            <p className="settings-value">{s.repeatDwellDelay.toFixed(1)} seconds</p>
          </>
        ) : null}
      </SettingsCard>

      <SettingsCard title="Cursor sensitivity" hint="Pointer movement speed">
        <div className="btn-group">
          {(['Low', 'Medium', 'High'] as const).map((label, level) => (
            <button
              key={label}
              type="button"
              className={s.sensitivity === level ? 'active' : ''}
              onClick={() => s.setSensitivity(level)}
            >
              {label}
            </button>
          ))}
        </div>
      </SettingsCard>
    </SettingsLayout>
  )
}
