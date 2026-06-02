import { db } from './db'
import type {
  CategoryRow,
  ImageRow,
  MediaRow,
  PhraseRow,
  PresetCategoryRow,
  PresetPhraseRow,
} from './types'

export const BACKUP_FORMAT_VERSION = 1
const SETTINGS_STORAGE_KEY = 'switch2go-settings'

export interface BackupImageEntry {
  id: string
  created_at: number
  mime: string
  data: string
}

export interface BackupMediaEntry {
  id: string
  created_at: number
  mime: string
  data: string
}

export interface BackupPayload {
  version: typeof BACKUP_FORMAT_VERSION
  exportedAt: string
  settings: unknown
  presetCategory: PresetCategoryRow[]
  presetPhrase: PresetPhraseRow[]
  category: CategoryRow[]
  phrase: PhraseRow[]
  images: BackupImageEntry[]
  media?: BackupMediaEntry[]
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      const result = reader.result
      if (typeof result !== 'string') {
        reject(new Error('Failed to encode image'))
        return
      }
      const comma = result.indexOf(',')
      resolve(comma >= 0 ? result.slice(comma + 1) : result)
    }
    reader.onerror = () => reject(reader.error ?? new Error('Failed to read image'))
    reader.readAsDataURL(blob)
  })
}

function base64ToBlob(data: string, mime: string): Blob {
  const binary = atob(data)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return new Blob([bytes], { type: mime || 'application/octet-stream' })
}

export async function buildBackupPayload(): Promise<BackupPayload> {
  const [presetCategory, presetPhrase, category, phrase, images, media] = await Promise.all([
    db.presetCategory.toArray(),
    db.presetPhrase.toArray(),
    db.category.toArray(),
    db.phrase.toArray(),
    db.images.toArray(),
    db.media.toArray(),
  ])

  const imageEntries: BackupImageEntry[] = await Promise.all(
    images.map(async (row) => ({
      id: row.id,
      created_at: row.created_at,
      mime: row.blob.type || 'image/png',
      data: await blobToBase64(row.blob),
    })),
  )

  const mediaEntries: BackupMediaEntry[] = await Promise.all(
    media.map(async (row) => ({
      id: row.id,
      created_at: row.created_at,
      mime: row.mime || row.blob.type || 'application/octet-stream',
      data: await blobToBase64(row.blob),
    })),
  )

  let settings: unknown = null
  try {
    const raw = localStorage.getItem(SETTINGS_STORAGE_KEY)
    if (raw) settings = JSON.parse(raw) as unknown
  } catch {
    settings = null
  }

  return {
    version: BACKUP_FORMAT_VERSION,
    exportedAt: new Date().toISOString(),
    settings,
    presetCategory,
    presetPhrase,
    category,
    phrase,
    images: imageEntries,
    media: mediaEntries,
  }
}

export async function exportBackupBlob(): Promise<Blob> {
  const payload = await buildBackupPayload()
  return new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
}

export function backupFilename(): string {
  const stamp = new Date().toISOString().slice(0, 10)
  return `switch2go-backup-${stamp}.json`
}

function isBackupPayload(value: unknown): value is BackupPayload {
  if (!value || typeof value !== 'object') return false
  const o = value as Record<string, unknown>
  return (
    o.version === BACKUP_FORMAT_VERSION &&
    typeof o.exportedAt === 'string' &&
    Array.isArray(o.presetCategory) &&
    Array.isArray(o.presetPhrase) &&
    Array.isArray(o.category) &&
    Array.isArray(o.phrase) &&
    Array.isArray(o.images)
  )
}

export async function importBackupPayload(payload: BackupPayload): Promise<void> {
  const imageRows: ImageRow[] = payload.images.map((img) => ({
    id: img.id,
    created_at: img.created_at,
    blob: base64ToBlob(img.data, img.mime),
  }))

  const mediaRows: MediaRow[] = (payload.media ?? []).map((m) => ({
    id: m.id,
    created_at: m.created_at,
    mime: m.mime,
    blob: base64ToBlob(m.data, m.mime),
  }))

  await db.transaction(
    'rw',
    [db.presetCategory, db.presetPhrase, db.category, db.phrase, db.images, db.media],
    async () => {
      await db.presetCategory.clear()
      await db.presetPhrase.clear()
      await db.category.clear()
      await db.phrase.clear()
      await db.images.clear()
      await db.media.clear()

      if (payload.presetCategory.length) await db.presetCategory.bulkPut(payload.presetCategory)
      if (payload.presetPhrase.length) await db.presetPhrase.bulkPut(payload.presetPhrase)
      if (payload.category.length) await db.category.bulkPut(payload.category)
      if (payload.phrase.length) await db.phrase.bulkPut(payload.phrase)
      if (imageRows.length) await db.images.bulkPut(imageRows)
      if (mediaRows.length) await db.media.bulkPut(mediaRows)
    },
  )

  if (payload.settings != null) {
    localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(payload.settings))
  }
}

export async function importBackupFromFile(file: File): Promise<void> {
  const text = await file.text()
  let parsed: unknown
  try {
    parsed = JSON.parse(text) as unknown
  } catch {
    throw new Error('Invalid backup file: not valid JSON')
  }

  if (!isBackupPayload(parsed)) {
    throw new Error('Invalid backup file: unsupported format or version')
  }

  await importBackupPayload(parsed)
}
