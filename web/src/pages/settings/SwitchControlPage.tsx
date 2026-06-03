import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'

export function SwitchControlPage() {
  return (
    <SettingsLayout title="Switch Control">
      <SettingsCard>
        <p>
          The iPad app supports <strong>USB and Bluetooth</strong> switch interfaces that send
          keyboard keys. This web app uses your <strong>keyboard</strong> instead.
        </p>
      </SettingsCard>

      <SettingsCard title="Switch to Phrase (2–4 keys)">
        <p className="hint">
          On the phrases screen, press <strong>1</strong>–<strong>4</strong> to speak the phrase in
          that grid position (matches symbols per page).
        </p>
      </SettingsCard>

      <SettingsCard title="Scan &amp; Select (iPad only)">
        <p className="hint">
          On iPad, enable <strong>Scan &amp; Select</strong> in Switch Control settings: switch 1
          selects the highlighted phrase, switch 2 moves to the next. Requires a two-switch HID
          device.
        </p>
      </SettingsCard>
    </SettingsLayout>
  )
}
