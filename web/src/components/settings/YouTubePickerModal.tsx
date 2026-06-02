import { useState } from 'react'
import { MEDIA_TYPE_YOUTUBE } from '../../data/phraseStyle'
import { normalizeYouTubeMediaRef } from '../../data/youtube'

type Props = {
  currentMediaRef?: string | null
  onSelect: (mediaRef: string | null, mediaType: typeof MEDIA_TYPE_YOUTUBE | null) => void
  onClose: () => void
}

export function YouTubePickerModal({ currentMediaRef, onSelect, onClose }: Props) {
  const [input, setInput] = useState('')
  const [error, setError] = useState<string | null>(null)

  const attach = () => {
    setError(null)
    const normalized = normalizeYouTubeMediaRef(input.trim())
    if (!normalized) {
      setError('Paste a valid YouTube link or 11-character video ID.')
      return
    }
    onSelect(normalized, MEDIA_TYPE_YOUTUBE)
    onClose()
  }

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div className="modal-panel" role="dialog" onClick={(e) => e.stopPropagation()}>
        <h2>Attach YouTube video</h2>
        <p className="settings-hint">
          Paste a YouTube link or video ID. Playback uses the same fullscreen gaze controls as
          uploaded video.
        </p>
        {currentMediaRef ? <p className="settings-value">Current: {currentMediaRef}</p> : null}
        {error ? <p className="error-text">{error}</p> : null}
        <label className="stack-label">
          YouTube URL or video ID
          <input
            type="url"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="https://www.youtube.com/watch?v=…"
            autoFocus
          />
        </label>
        <button type="button" onClick={attach}>
          Attach YouTube video
        </button>
        <button
          type="button"
          onClick={() => {
            onSelect(null, null)
            onClose()
          }}
        >
          Remove YouTube video
        </button>
        <button type="button" className="text-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
