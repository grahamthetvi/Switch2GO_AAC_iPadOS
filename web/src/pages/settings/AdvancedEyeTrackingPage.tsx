import { SettingsCard } from '../../components/settings/SettingsCard'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import {
  useSettings,
  type EyeSelection,
  type SmoothingMode,
  type TrackingMode,
} from '../../settings/settingsStore'

const SMOOTHING: { id: SmoothingMode; label: string }[] = [
  { id: 'simple', label: 'Simple' },
  { id: 'kalman', label: 'Kalman filter' },
  { id: 'adaptive', label: 'Adaptive Kalman (recommended)' },
  { id: 'combined', label: 'Combined' },
  { id: 'none', label: 'None' },
]

const GAZE_LEVELS = [1, 1.25, 1.5, 1.75, 2] as const

export function AdvancedEyeTrackingPage() {
  const s = useSettings()

  return (
    <SettingsLayout title="Advanced Eye Tracking">
      <SettingsCard title="GPU acceleration">
        <label className="toggle-row">
          <span>Use GPU (faster, may use more battery)</span>
          <input type="checkbox" checked={s.useGPU} onChange={(e) => s.setUseGPU(e.target.checked)} />
        </label>
        <p className="hint">Changing GPU may require reloading the page to reinitialize tracking.</p>
      </SettingsCard>

      <SettingsCard title="Tracking method" hint="2D is faster; 3D uses an eyeball model for improved accuracy">
        <div className="btn-group">
          {(['2D', '3D'] as TrackingMode[]).map((mode) => (
            <button
              key={mode}
              type="button"
              className={s.trackingMode === mode ? 'active' : ''}
              onClick={() => s.setTrackingMode(mode)}
            >
              {mode === '2D' ? '2D iris' : '3D eyeball'}
            </button>
          ))}
        </div>
      </SettingsCard>

      <SettingsCard title="Smoothing mode">
        <ul className="option-list inline">
          {SMOOTHING.map(({ id, label }) => (
            <li key={id}>
              <button
                type="button"
                className={`option-list-btn${s.smoothingMode === id ? ' selected' : ''}`}
                onClick={() => s.setSmoothingMode(id)}
              >
                {label}
              </button>
            </li>
          ))}
        </ul>
        <p className="hint">Adaptive Kalman is recommended for most users. Combined adds extra smoothing on top.</p>
      </SettingsCard>

      <SettingsCard title="Eye selection">
        <div className="btn-group vertical">
          {(
            [
              ['both', 'Both eyes'],
              ['left', 'Left eye only'],
              ['right', 'Right eye only'],
            ] as [EyeSelection, string][]
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              className={s.eyeSelection === id ? 'active' : ''}
              onClick={() => s.setEyeSelection(id)}
            >
              {label}
            </button>
          ))}
        </div>
      </SettingsCard>

      <SettingsCard title="Gaze amplification" hint="Eye gaze mode only">
        <div className="btn-group vertical">
          {GAZE_LEVELS.map((v) => (
            <button
              key={v}
              type="button"
              className={s.gazeAmplification === v ? 'active' : ''}
              onClick={() => s.setGazeAmplification(v)}
            >
              {v === 1 ? '1.0× (normal)' : `${v}×`}
            </button>
          ))}
        </div>
      </SettingsCard>

      <SettingsCard title="Behavior">
        <label className="toggle-row">
          <span>Hide cursor when gaze is away</span>
          <input
            type="checkbox"
            checked={s.enableOutOfBoundsHiding}
            onChange={(e) => s.setEnableOutOfBoundsHiding(e.target.checked)}
          />
        </label>
        <label className="toggle-row">
          <span>Show banner when face not detected</span>
          <input
            type="checkbox"
            checked={s.showTrackingErrorBanner}
            onChange={(e) => s.setShowTrackingErrorBanner(e.target.checked)}
          />
        </label>
        <label className="toggle-row">
          <span>Double-blink to recenter (when supported)</span>
          <input
            type="checkbox"
            checked={s.enableDoubleBlinkRecenter}
            onChange={(e) => s.setEnableDoubleBlinkRecenter(e.target.checked)}
          />
        </label>
        <label className="toggle-row">
          <span>Auto-recenter when gaze is centered</span>
          <input
            type="checkbox"
            checked={s.enableAutoRecenter}
            onChange={(e) => s.setEnableAutoRecenter(e.target.checked)}
          />
        </label>
        <label className="toggle-row">
          <span>Head pose compensation (turn off if you look by moving your head)</span>
          <input
            type="checkbox"
            checked={s.enableHeadPoseCompensation}
            onChange={(e) => s.setEnableHeadPoseCompensation(e.target.checked)}
          />
        </label>
        <label className="toggle-row">
          <span>Debug camera preview</span>
          <input
            type="checkbox"
            checked={s.showDebugCameraPreview}
            onChange={(e) => s.setShowDebugCameraPreview(e.target.checked)}
          />
        </label>
      </SettingsCard>
    </SettingsLayout>
  )
}
