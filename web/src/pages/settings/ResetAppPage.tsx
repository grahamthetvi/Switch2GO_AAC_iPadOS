import { useState } from 'react'
import { resetDatabaseToDefaults } from '../../data/seed'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings } from '../../settings/settingsStore'

export function ResetAppPage() {
  const s = useSettings()
  const [step, setStep] = useState(0)

  const runReset = async () => {
    s.resetToDefaults()
    await resetDatabaseToDefaults()
    window.location.href = import.meta.env.BASE_URL
  }

  return (
    <SettingsLayout title="Reset App">
      <section className="settings-section reset-page">
        <p className="empty-state-title">⚠️ Reset app</p>
        <p className="hint">
          This deletes all custom categories and phrases, restores presets, and resets all settings.
          Phrase images stored on this device are also removed. This cannot be undone.
        </p>
        <ul className="reset-list hint">
          <li>All custom categories and phrases</li>
          <li>Custom phrase images</li>
          <li>Symbol count and colors</li>
          <li>All settings to defaults</li>
        </ul>

        {step === 0 ? (
          <button type="button" className="danger-btn" onClick={() => setStep(1)}>
            Reset app…
          </button>
        ) : step === 1 ? (
          <button type="button" className="danger-btn" onClick={() => setStep(2)}>
            Are you sure? Continue…
          </button>
        ) : (
          <button type="button" className="danger-btn" onClick={() => void runReset()}>
            Yes, reset everything
          </button>
        )}
        {step > 0 ? (
          <button type="button" className="secondary-btn" onClick={() => setStep(0)}>
            Cancel
          </button>
        ) : null}
      </section>
    </SettingsLayout>
  )
}
