import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'

export function SwitchControlPage() {
  return (
    <SettingsLayout title="Switch Control">
      <SettingsCard>
        <p>
          The iPad app supports USB switches (e.g. Tapio). <strong>Web browsers cannot access USB
          HID switches</strong> the same way.
        </p>
        <p className="hint">On this web app you can use the keyboard instead:</p>
        <ul className="reset-list">
          <li>
            <strong>1</strong> — first phrase on the page
          </li>
          <li>
            <strong>2</strong> — second phrase
          </li>
          <li>
            <strong>3</strong> — third phrase
          </li>
          <li>
            <strong>4</strong> — fourth phrase
          </li>
        </ul>
        <p className="hint">
          Open a category, then press the number key matching the tile position. Works with the
          on-screen phrase grid layout (1–4 symbols per page).
        </p>
      </SettingsCard>
    </SettingsLayout>
  )
}
