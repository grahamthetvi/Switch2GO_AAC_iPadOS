import { useRef, useState } from 'react'
import { deleteMediaByRef, saveMediaBlob } from '../../data/media'
import { MEDIA_TYPE_AUDIO, MEDIA_TYPE_VIDEO } from '../../data/phraseStyle'

type Props = {
  mediaType: 'video' | 'audio'
  currentMediaRef?: string | null
  onSelect: (mediaRef: string | null, mediaType: 'video' | 'audio' | null) => void
  onClose: () => void
}

export function MediaPickerModal({ mediaType, currentMediaRef, onSelect, onClose }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [error, setError] = useState<string | null>(null)

  const accept = mediaType === 'video' ? 'video/mp4,video/quicktime,video/*' : 'audio/*'

  const handleFile = async (file: File | undefined) => {
    if (!file) return
    setError(null)
    try {
      if (currentMediaRef) await deleteMediaByRef(currentMediaRef)
      const ref = await saveMediaBlob(file, file.type || (mediaType === 'video' ? 'video/mp4' : 'audio/mpeg'))
      onSelect(ref, mediaType === 'video' ? MEDIA_TYPE_VIDEO : MEDIA_TYPE_AUDIO)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not save media.')
    }
  }

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div className="modal-panel" role="dialog" onClick={(e) => e.stopPropagation()}>
        <h2>{mediaType === 'video' ? 'Attach video' : 'Attach audio'}</h2>
        {error ? <p className="error-text">{error}</p> : null}
        <input
          ref={inputRef}
          type="file"
          accept={accept}
          hidden
          onChange={(e) => void handleFile(e.target.files?.[0])}
        />
        <button type="button" onClick={() => inputRef.current?.click()}>
          Choose file
        </button>
        <button
          type="button"
          onClick={() => {
            void (async () => {
              if (currentMediaRef) await deleteMediaByRef(currentMediaRef)
              onSelect(null, null)
              onClose()
            })()
          }}
        >
          Remove media
        </button>
        <button type="button" className="text-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
