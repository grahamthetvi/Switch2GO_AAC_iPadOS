import { extractEmojiFromRef } from '../../data/phraseStyle'
import { usePhraseImageUrl } from '../../hooks/usePhraseImageUrl'

interface PhraseMediaProps {
  imageRef?: string | null
}

export function PhraseMedia({ imageRef }: PhraseMediaProps) {
  const emoji = extractEmojiFromRef(imageRef)
  const imageUrl = usePhraseImageUrl(imageRef)

  if (emoji) {
    return <span className="phrase-emoji">{emoji}</span>
  }
  if (imageUrl) {
    return <img src={imageUrl} alt="" className="phrase-image" />
  }
  return null
}
