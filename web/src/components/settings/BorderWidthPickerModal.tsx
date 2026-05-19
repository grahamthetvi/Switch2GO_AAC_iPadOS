import { BORDER_WIDTH_OPTIONS } from '../../data/phraseStyle'

interface BorderWidthPickerModalProps {
  selectedWidth: number
  onSelect: (width: number) => void
  onClose: () => void
}

export function BorderWidthPickerModal({
  selectedWidth,
  onSelect,
  onClose,
}: BorderWidthPickerModalProps) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="border-width-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="border-width-title">Border thickness</h2>
        <ul className="option-list">
          {BORDER_WIDTH_OPTIONS.map(({ dp, label }) => (
            <li key={dp}>
              <button
                type="button"
                className={`option-list-btn${dp === selectedWidth ? ' selected' : ''}`}
                onClick={() => onSelect(dp)}
              >
                {label}
              </button>
            </li>
          ))}
        </ul>
        <button type="button" className="modal-close-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
