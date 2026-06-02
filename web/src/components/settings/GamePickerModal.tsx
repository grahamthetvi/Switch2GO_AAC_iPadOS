import { GAME_TYPE_CURSOR_ROCKET } from '../../data/phraseStyle'

const GAME_OPTIONS = [
  {
    id: GAME_TYPE_CURSOR_ROCKET,
    title: 'Rocket cursor follower',
    description: 'A rocket follows your gaze; flames when you move, quiet when still.',
  },
] as const

type Props = {
  currentGameType?: string | null
  onSelect: (gameType: string | null) => void
  onClose: () => void
}

export function GamePickerModal({ currentGameType, onSelect, onClose }: Props) {
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-labelledby="game-picker-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="game-picker-title">Attach game</h2>
        <p className="hint">
          After this phrase is selected, the game starts if no other phrase is chosen within the
          delay set in Timing &amp; Sensitivity.
        </p>
        <ul className="game-picker-list">
          {GAME_OPTIONS.map((opt) => (
            <li key={opt.id}>
              <button
                type="button"
                className={`picker-row game-picker-option${currentGameType === opt.id ? ' selected' : ''}`}
                onClick={() => {
                  onSelect(opt.id)
                  onClose()
                }}
              >
                <span className="game-picker-option-title">{opt.title}</span>
                <span className="game-picker-option-desc">{opt.description}</span>
              </button>
            </li>
          ))}
        </ul>
        {currentGameType ? (
          <button
            type="button"
            className="danger-btn"
            onClick={() => {
              onSelect(null)
              onClose()
            }}
          >
            Remove game
          </button>
        ) : null}
        <button type="button" className="secondary-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
