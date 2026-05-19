import { useRef } from 'react'
import { EMOJI_PREFIX } from '../../data/phraseStyle'
import { saveImageBlob } from '../../data/images'
import { EmojiPickerModal } from './EmojiPickerModal'

interface ImagePickerModalProps {
  selectedImageRef: string | null | undefined
  onSelect: (imageRef: string | null) => void
  onClose: () => void
  showEmojiPicker: boolean
  onShowEmojiPicker: (show: boolean) => void
}

export function ImagePickerModal({
  selectedImageRef,
  onSelect,
  onClose,
  showEmojiPicker,
  onShowEmojiPicker,
}: ImagePickerModalProps) {
  const fileRef = useRef<HTMLInputElement>(null)

  const pickFile = async (file: File | undefined) => {
    if (!file || !file.type.startsWith('image/')) return
    const ref = await saveImageBlob(file)
    onSelect(ref)
    onClose()
  }

  if (showEmojiPicker) {
    return (
      <EmojiPickerModal
        onSelect={(emoji) => {
          onSelect(`${EMOJI_PREFIX}${emoji}`)
          onClose()
        }}
        onClose={() => onShowEmojiPicker(false)}
      />
    )
  }

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="image-picker-title"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id="image-picker-title">Image or emoji</h2>
        <div className="image-picker-options">
          <button type="button" className="picker-row" onClick={() => onSelect(null)}>
            <span>None</span>
            {!selectedImageRef ? <span className="check-mark">✓</span> : null}
          </button>
          <button type="button" className="picker-row" onClick={() => onShowEmojiPicker(true)}>
            <span>Use emoji</span>
            <span className="picker-chevron">›</span>
          </button>
          <button type="button" className="picker-row" onClick={() => fileRef.current?.click()}>
            <span>Upload image</span>
            <span className="picker-chevron">›</span>
          </button>
          <a
            href="https://switch2goaac.org/index.html#image-tool"
            target="_blank"
            rel="noopener noreferrer"
            className="picker-row link-row"
          >
            <span>Open image tool</span>
            <span className="picker-chevron">↗</span>
          </a>
        </div>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(e) => void pickFile(e.target.files?.[0])}
        />
        <button type="button" className="modal-close-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
