const EMOJIS = [
  '😀', '😊', '🙂', '😢', '😡', '😴', '🤒', '🤕', '👍', '👎', '✋', '🙏',
  '❤️', '💙', '💚', '⭐', '🔔', '🍎', '🍕', '🥤', '🚽', '🛏️', '🎮', '📺',
  '🏠', '🚗', '✈️', '🐶', '🐱', '🌞', '🌧️', '❓', '❗', '➕', '➖', '✅',
]

interface EmojiPickerModalProps {
  onSelect: (emoji: string) => void
  onClose: () => void
}

export function EmojiPickerModal({ onSelect, onClose }: EmojiPickerModalProps) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel modal-panel-wide"
        role="dialog"
        aria-modal="true"
        aria-labelledby="emoji-picker-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="emoji-picker-title">Choose emoji</h2>
        <div className="symbol-grid emoji-grid">
          {EMOJIS.map((emoji) => (
            <button key={emoji} type="button" className="symbol-btn" onClick={() => onSelect(emoji)}>
              <span className="symbol-btn-emoji">{emoji}</span>
            </button>
          ))}
        </div>
        <button type="button" className="modal-close-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
