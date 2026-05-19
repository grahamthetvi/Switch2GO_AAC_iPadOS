import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useSettings, type SelectionMode } from '../../settings/settingsStore'
import { requestCameraAccess } from '../../tracking/cameraAccess'

const MODES: { id: SelectionMode; title: string; description: string; icon: string }[] = [
  {
    id: 'face',
    title: 'Head tracking',
    description: 'Use head movements to control the cursor',
    icon: '🙂',
  },
  {
    id: 'eyeGaze',
    title: 'Eye gaze tracking',
    description: 'Use eye movements to control the cursor (more precise)',
    icon: '👁',
  },
  {
    id: 'armRaise',
    title: 'Arm raise selection',
    description: 'Raise your left or right arm to choose the left or right phrase (2-symbol layout)',
    icon: '🙋',
  },
  {
    id: 'none',
    title: 'Touch only',
    description: 'Use touch only, no head or eye tracking',
    icon: '👆',
  },
]

export function SelectionModePage() {
  const s = useSettings()

  const selectMode = async (mode: SelectionMode) => {
    if (mode === 'none') {
      s.setSelectionMode('none')
      return
    }
    try {
      await requestCameraAccess()
    } catch {
      return
    }
    s.setSelectionMode(mode)
  }

  return (
    <SettingsLayout title="Selection Mode">
      <p className="hint settings-intro">Choose how you want to control the app</p>
      {MODES.map((mode) => (
        <button
          key={mode.id}
          type="button"
          className={`selection-mode-btn${s.selectionMode === mode.id ? ' selected' : ''}`}
          onClick={() => void selectMode(mode.id)}
        >
          <span className="selection-mode-icon" aria-hidden>
            {mode.icon}
          </span>
          <span className="selection-mode-text">
            <strong>{mode.title}</strong>
            <span>{mode.description}</span>
          </span>
          {s.selectionMode === mode.id ? <span className="check-mark">✓</span> : null}
        </button>
      ))}

      <SettingsCard title="Switch control (web)">
        <p className="hint">
          On the web app, use keyboard keys <strong>1</strong>–<strong>4</strong> to select phrase
          tiles on the current page (same positions as on iPad). USB switch hardware is not
          supported in the browser.
        </p>
      </SettingsCard>
    </SettingsLayout>
  )
}
