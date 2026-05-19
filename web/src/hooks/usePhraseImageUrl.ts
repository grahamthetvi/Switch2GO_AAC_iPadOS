import { useEffect, useState } from 'react'
import { loadImageObjectUrl } from '../data/images'
import { isBlobImageRef } from '../data/phraseStyle'

export function usePhraseImageUrl(imageRef: string | null | undefined): string | null {
  const [url, setUrl] = useState<string | null>(null)

  useEffect(() => {
    if (!imageRef || !isBlobImageRef(imageRef)) {
      setUrl(null)
      return
    }
    let revoked: string | null = null
    let cancelled = false
    void loadImageObjectUrl(imageRef).then((objectUrl) => {
      if (cancelled) {
        if (objectUrl) URL.revokeObjectURL(objectUrl)
        return
      }
      revoked = objectUrl
      setUrl(objectUrl)
    })
    return () => {
      cancelled = true
      if (revoked) URL.revokeObjectURL(revoked)
    }
  }, [imageRef])

  return url
}
