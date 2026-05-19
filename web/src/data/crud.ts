import { db } from './db'
import { pickNewCategoryColor } from './categoryDefaults'
import { serializePhraseStyle } from './phraseStyle'
import type { CategoryDisplay, PhraseDisplay, PhraseStyle } from './types'

function isPresetId(id: string): boolean {
  return id.startsWith('preset_')
}

function newCustomId(prefix: string): string {
  return `${prefix}_${crypto.randomUUID()}`
}

export async function setCategoryHidden(categoryId: string, hidden: boolean): Promise<void> {
  const h = hidden ? 1 : 0
  if (isPresetId(categoryId)) {
    const row = await db.presetCategory.get(categoryId)
    if (row) await db.presetCategory.put({ ...row, hidden: h })
  } else {
    const row = await db.category.get(categoryId)
    if (row) await db.category.put({ ...row, hidden: h })
  }
}

export async function reorderCategories(orderedIds: string[]): Promise<void> {
  await db.transaction('rw', [db.presetCategory, db.category], async () => {
    for (let i = 0; i < orderedIds.length; i++) {
      const id = orderedIds[i]
      if (isPresetId(id)) {
        const row = await db.presetCategory.get(id)
        if (row) await db.presetCategory.put({ ...row, sort_order: i })
      } else {
        const row = await db.category.get(id)
        if (row) await db.category.put({ ...row, sort_order: i })
      }
    }
  })
}

export async function insertCustomCategory(
  name: string,
  colorHex: number,
  symbolName: string,
): Promise<string> {
  const categoryId = newCustomId('custom')
  const timestamp = Date.now()
  await db.category.put({
    category_id: categoryId,
    creation_date: timestamp,
    localized_name: name,
    hidden: 0,
    sort_order: -timestamp,
    color_hex: colorHex,
    symbol_name: symbolName,
  })
  return categoryId
}

export async function insertCustomCategoryWithDefaults(name: string): Promise<string> {
  return insertCustomCategory(name, pickNewCategoryColor(), 'folder')
}

export async function updateCustomCategoryName(categoryId: string, name: string): Promise<void> {
  const row = await db.category.get(categoryId)
  if (row) await db.category.put({ ...row, localized_name: name })
}

export async function updateCategoryColor(categoryId: string, colorHex: number): Promise<void> {
  if (isPresetId(categoryId)) {
    const row = await db.presetCategory.get(categoryId)
    if (row) await db.presetCategory.put({ ...row, color_hex: colorHex })
  } else {
    const row = await db.category.get(categoryId)
    if (row) await db.category.put({ ...row, color_hex: colorHex })
  }
}

export async function updateCategorySymbol(categoryId: string, symbolName: string): Promise<void> {
  if (isPresetId(categoryId)) {
    const row = await db.presetCategory.get(categoryId)
    if (row) await db.presetCategory.put({ ...row, symbol_name: symbolName })
  } else {
    const row = await db.category.get(categoryId)
    if (row) await db.category.put({ ...row, symbol_name: symbolName })
  }
}

export async function deleteCustomCategory(categoryId: string): Promise<void> {
  await db.transaction('rw', [db.category, db.phrase], async () => {
    await db.phrase.where('parent_category_id').equals(categoryId).delete()
    await db.category.delete(categoryId)
  })
}

export async function insertCustomPhrase(categoryId: string, text: string): Promise<string> {
  const phraseId = newCustomId('custom')
  const timestamp = Date.now()
  const existing = await db.phrase.where('parent_category_id').equals(categoryId).count()
  await db.phrase.put({
    phrase_id: phraseId,
    parent_category_id: categoryId,
    creation_date: timestamp,
    last_spoken_date: null,
    localized_utterance: text,
    sort_order: existing,
    style: null,
  })
  return phraseId
}

export async function updateCustomPhraseText(phraseId: string, text: string): Promise<void> {
  const row = await db.phrase.get(phraseId)
  if (row) await db.phrase.put({ ...row, localized_utterance: text })
}

export async function updatePhraseStyle(phraseId: string, isPreset: boolean, style: PhraseStyle | null): Promise<void> {
  const json = style ? serializePhraseStyle(style) : null
  if (isPreset) {
    const row = await db.presetPhrase.get(phraseId)
    if (row) await db.presetPhrase.put({ ...row, style: json })
  } else {
    const row = await db.phrase.get(phraseId)
    if (row) await db.phrase.put({ ...row, style: json })
  }
}

export async function deleteCustomPhrase(phraseId: string): Promise<void> {
  await db.phrase.delete(phraseId)
}

export async function softDeletePresetPhrase(phraseId: string): Promise<void> {
  const row = await db.presetPhrase.get(phraseId)
  if (row) await db.presetPhrase.put({ ...row, deleted: 1 })
}

export async function reorderPhrases(ordered: { id: string; isPreset: boolean }[]): Promise<void> {
  await db.transaction('rw', [db.presetPhrase, db.phrase], async () => {
    for (let i = 0; i < ordered.length; i++) {
      const { id, isPreset } = ordered[i]
      if (isPreset) {
        const row = await db.presetPhrase.get(id)
        if (row) await db.presetPhrase.put({ ...row, sort_order: i })
      } else {
        const row = await db.phrase.get(id)
        if (row) await db.phrase.put({ ...row, sort_order: i })
      }
    }
  })
}

export type { CategoryDisplay, PhraseDisplay }
