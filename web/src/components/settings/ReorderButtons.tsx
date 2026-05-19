interface ReorderButtonsProps {
  onMoveUp: () => void
  onMoveDown: () => void
  canMoveUp: boolean
  canMoveDown: boolean
}

export function ReorderButtons({ onMoveUp, onMoveDown, canMoveUp, canMoveDown }: ReorderButtonsProps) {
  return (
    <div className="reorder-btns">
      <button type="button" disabled={!canMoveUp} onClick={onMoveUp} aria-label="Move up">
        ↑
      </button>
      <button type="button" disabled={!canMoveDown} onClick={onMoveDown} aria-label="Move down">
        ↓
      </button>
    </div>
  )
}
