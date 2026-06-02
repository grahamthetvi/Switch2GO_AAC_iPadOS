import { MEDIA_BLOB_PREFIX } from './phraseStyle'
import { db } from './db'

const MAX_BYTES = 100 * 1024 * 1024

export async function saveMediaBlob(blob: Blob, mime: string): Promise<string> {
  if (blob.size > MAX_BYTES) {
    throw new Error('Media file is too large (max 100 MB).')
  }
  const id = crypto.randomUUID()
  await db.media.put({ id, blob, mime, created_at: Date.now() })
  return `${MEDIA_BLOB_PREFIX}${id}`
}

export async function getMediaBlob(mediaRef: string): Promise<Blob | null> {
  if (!mediaRef.startsWith(MEDIA_BLOB_PREFIX)) return null
  const id = mediaRef.slice(MEDIA_BLOB_PREFIX.length)
  const row = await db.media.get(id)
  return row?.blob ?? null
}

export async function loadMediaObjectUrl(mediaRef: string): Promise<string | null> {
  const blob = await getMediaBlob(mediaRef)
  if (!blob) return null
  return URL.createObjectURL(blob)
}

export async function deleteMediaByRef(mediaRef: string | null | undefined): Promise<void> {
  if (!mediaRef?.startsWith(MEDIA_BLOB_PREFIX)) return
  const id = mediaRef.slice(MEDIA_BLOB_PREFIX.length)
  await db.media.delete(id)
}

export async function clearAllMedia(): Promise<void> {
  await db.media.clear()
}
