import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings } from '../../settings/settingsStore'

const CAMERA_PRESETS = [
  { id: 'center', label: 'Center', yaw: 0, pitch: 0 },
  { id: 'left', label: 'Left', yaw: 4, pitch: 0 },
  { id: 'right', label: 'Right', yaw: -4, pitch: 0 },
] as const

export function HeadTrackingPage() {
  const s = useSettings()

  const applyPreset = (id: string, yaw: number, pitch: number) => {
    s.setHeadCameraPosition(id)
    s.setHeadCameraOffsetYaw(yaw)
    s.setHeadCameraOffsetPitch(pitch)
  }

  return (
    <SettingsLayout title="Head Tracking">
      <SettingsCard title="Camera position preset">
        <div className="btn-group vertical">
          {CAMERA_PRESETS.map((p) => (
            <button
              key={p.id}
              type="button"
              className={s.headCameraPosition === p.id ? 'active' : ''}
              onClick={() => applyPreset(p.id, p.yaw, p.pitch)}
            >
              {p.label}
            </button>
          ))}
        </div>
      </SettingsCard>

      <SettingsCard title="Fine-tune offset">
        <label>
          Yaw offset: {s.headCameraOffsetYaw.toFixed(1)}°
          <input
            type="range"
            min={-15}
            max={15}
            step={0.5}
            value={s.headCameraOffsetYaw}
            onChange={(e) => s.setHeadCameraOffsetYaw(Number(e.target.value))}
          />
        </label>
        <label>
          Pitch offset: {s.headCameraOffsetPitch.toFixed(1)}°
          <input
            type="range"
            min={-15}
            max={15}
            step={0.5}
            value={s.headCameraOffsetPitch}
            onChange={(e) => s.setHeadCameraOffsetPitch(Number(e.target.value))}
          />
        </label>
      </SettingsCard>

      <SettingsCard title="Sensitivity">
        <label>
          Horizontal: {s.headSensitivityX.toFixed(1)}
          <input
            type="range"
            min={1}
            max={4}
            step={0.1}
            value={s.headSensitivityX}
            onChange={(e) => s.setHeadSensitivityX(Number(e.target.value))}
          />
        </label>
        <label>
          Vertical: {s.headSensitivityY.toFixed(1)}
          <input
            type="range"
            min={1}
            max={4}
            step={0.1}
            value={s.headSensitivityY}
            onChange={(e) => s.setHeadSensitivityY(Number(e.target.value))}
          />
        </label>
      </SettingsCard>
    </SettingsLayout>
  )
}
