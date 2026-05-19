import { BLOB_PREFIX } from './phraseStyle'
import { db } from './db'

export async function saveImageBlob(blob: Blob): Promise<string> {
  const id = crypto.randomUUID()
  await db.images.put({ id, blob, created_at: Date.now() })
  return `${BLOB_PREFIX}${id}`
}

export async function getImageBlob(imageRef: string): Promise<Blob | null> {
  if (!imageRef.startsWith(BLOB_PREFIX)) return null
  const id = imageRef.slice(BLOB_PREFIX.length)
  const row = await db.images.get(id)
  return row?.blob ?? null
}

export async function loadImageObjectUrl(imageRef: string): Promise<string | null> {
  const blob = await getImageBlob(imageRef)
  if (!blob) return null
  return URL.createObjectURL(blob)
}

export async function deleteImageByRef(imageRef: string | null | undefined): Promise<void> {
  if (!imageRef?.startsWith(BLOB_PREFIX)) return
  const id = imageRef.slice(BLOB_PREFIX.length)
  await db.images.delete(id)
}

export async function clearAllImages(): Promise<void> {
  await db.images.clear()
}
