import { hexToCss } from '../../settings/settingsStore'
import { NEW_CATEGORY_COLOR_PALETTE } from '../../data/categoryDefaults'

interface ColorPickerModalProps {
  selectedHex: number
  onSelect: (hex: number) => void
  onClose: () => void
}

export function ColorPickerModal({ selectedHex, onSelect, onClose }: ColorPickerModalProps) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="color-picker-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="color-picker-title">Choose color</h2>
        <div className="color-swatch-grid">
          {NEW_CATEGORY_COLOR_PALETTE.map((hex) => (
            <button
              key={hex}
              type="button"
              className={`color-swatch${hex === selectedHex ? ' selected' : ''}`}
              style={{ background: hexToCss(hex) }}
              aria-label={`Color ${hex.toString(16)}`}
              onClick={() => onSelect(hex)}
            />
          ))}
        </div>
        <label className="color-custom">
          Custom
          <input
            type="color"
            value={'#' + (selectedHex & 0xffffff).toString(16).padStart(6, '0')}
            onChange={(e) => {
              const rgb = parseInt(e.target.value.slice(1), 16)
              onSelect(0xff000000 | rgb)
            }}
          />
        </label>
        <button type="button" className="modal-close-btn" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  )
}
