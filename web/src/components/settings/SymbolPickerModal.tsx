import { CATEGORY_SYMBOLS } from '../../data/symbols'

interface SymbolPickerModalProps {
  selectedSymbol: string
  onSelect: (symbolId: string) => void
  onClose: () => void
}

export function SymbolPickerModal({ selectedSymbol, onSelect, onClose }: SymbolPickerModalProps) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel modal-panel-wide"
        role="dialog"
        aria-modal="true"
        aria-labelledby="symbol-picker-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="symbol-picker-title">Choose icon</h2>
        <div className="symbol-grid">
          {CATEGORY_SYMBOLS.map((sym) => (
            <button
              key={sym.id}
              type="button"
              className={`symbol-btn${sym.id === selectedSymbol ? ' selected' : ''}`}
              title={sym.label}
              onClick={() => onSelect(sym.id)}
            >
              <span className="symbol-btn-emoji">{sym.emoji}</span>
            </button>
          ))}
        </div>
        <button type="button" className="modal-close-btn" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  )
}
