import { localizedCategoryName, localizedPhraseText } from '../i18n/i18n'
import { useSettings } from '../settings/settingsStore'
import presets from './presets.json'
import { db } from './db'
import { parsePhraseStyle } from './phraseStyle'
import type { CategoryDisplay, PhraseDisplay, PhraseStyle } from './types'
import { RECENTS_CATEGORY_ID } from './types'

function presetCategoryLabel(categoryId: string): string {
  const fallback = PRESET_NAMES[categoryId] ?? categoryId
  return localizedCategoryName(useSettings.getState().locale, categoryId, fallback)
}

function presetPhraseLabel(phraseId: string): string {
  const fallback = PRESET_PHRASE_TEXT[phraseId] ?? phraseId
  return localizedPhraseText(useSettings.getState().locale, phraseId, fallback)
}

const PRESET_NAMES: Record<string, string> = Object.fromEntries(
  presets.categories.map((c) => [c.categoryId, c.name]),
)

const PRESET_PHRASE_TEXT: Record<string, string> = Object.fromEntries(
  presets.phrases.map((p) => [p.phraseId, p.text]),
)

export function getPresetCategoryName(categoryId: string): string {
  return PRESET_NAMES[categoryId] ?? categoryId
}

export function getPresetPhraseText(phraseId: string): string {
  return PRESET_PHRASE_TEXT[phraseId] ?? phraseId
}

const parseStyle = parsePhraseStyle

/** All categories for settings editor (includes hidden). */
export async function loadCategoriesForEdit(): Promise<CategoryDisplay[]> {
  const presetRows = await db.presetCategory.filter((r) => r.deleted === 0).toArray()
  const customRows = await db.category.toArray()

  const display: CategoryDisplay[] = [
    ...presetRows.map((r) => ({
      id: r.category_id,
      name: presetCategoryLabel(r.category_id),
      sortOrder: r.sort_order,
      isPreset: true,
      hidden: r.hidden === 1,
      colorHex: r.color_hex,
      symbolName: r.symbol_name,
    })),
    ...customRows.map((r) => ({
      id: r.category_id,
      name: r.localized_name,
      sortOrder: r.sort_order,
      isPreset: false,
      hidden: r.hidden === 1,
      colorHex: r.color_hex,
      symbolName: r.symbol_name,
    })),
  ]

  return display.sort((a, b) => a.sortOrder - b.sortOrder)
}

export async function getCategoryById(categoryId: string): Promise<CategoryDisplay | null> {
  const all = await loadCategoriesForEdit()
  return all.find((c) => c.id === categoryId) ?? null
}

export async function loadCategories(): Promise<CategoryDisplay[]> {
  const presetRows = await db.presetCategory
    .where('hidden')
    .equals(0)
    .filter((r) => r.deleted === 0)
    .toArray()

  const customRows = await db.category.where('hidden').equals(0).toArray()

  const display: CategoryDisplay[] = [
    ...presetRows.map((r) => ({
      id: r.category_id,
      name: presetCategoryLabel(r.category_id),
      sortOrder: r.sort_order,
      isPreset: true,
      hidden: r.hidden === 1,
      colorHex: r.color_hex,
      symbolName: r.symbol_name,
    })),
    ...customRows.map((r) => ({
      id: r.category_id,
      name: r.localized_name,
      sortOrder: r.sort_order,
      isPreset: false,
      hidden: r.hidden === 1,
      colorHex: r.color_hex,
      symbolName: r.symbol_name,
    })),
  ]

  return display.sort((a, b) => a.sortOrder - b.sortOrder)
}

/** Phrases for settings editor (same as main grid, recents included). */
export async function loadPhrasesForEdit(categoryId: string): Promise<PhraseDisplay[]> {
  return loadPhrases(categoryId)
}

export async function loadPhrases(categoryId: string): Promise<PhraseDisplay[]> {
  if (categoryId === RECENTS_CATEGORY_ID) {
    const recentPresets = await db.presetPhrase
      .filter((p) => p.deleted === 0 && p.last_spoken_date != null)
      .toArray()
    const recentCustom = await db.phrase.filter((p) => p.last_spoken_date != null).toArray()

    type RecentRow = {
      id: string
      text: string
      sortOrder: number
      isPreset: boolean
      style: PhraseStyle | null
      lastSpoken: number
    }

    const combined: RecentRow[] = [
      ...recentPresets.map((p) => ({
        id: p.phrase_id,
        text: presetPhraseLabel(p.phrase_id),
        sortOrder: p.sort_order,
        isPreset: true,
        style: parseStyle(p.style),
        lastSpoken: p.last_spoken_date ?? 0,
      })),
      ...recentCustom.map((p) => ({
        id: p.phrase_id,
        text: p.localized_utterance ?? '',
        sortOrder: p.sort_order,
        isPreset: false,
        style: parseStyle(p.style),
        lastSpoken: p.last_spoken_date ?? 0,
      })),
    ]

    combined.sort((a, b) => b.lastSpoken - a.lastSpoken)
    return combined.slice(0, 8).map(({ lastSpoken: _, ...rest }) => rest)
  }

  const presetRows = await db.presetPhrase
    .where('parent_category_id')
    .equals(categoryId)
    .filter((p) => p.deleted === 0)
    .toArray()

  const customRows = await db.phrase.where('parent_category_id').equals(categoryId).toArray()

  const display: PhraseDisplay[] = [
    ...presetRows.map((p) => ({
      id: p.phrase_id,
      text: presetPhraseLabel(p.phrase_id),
      sortOrder: p.sort_order,
      isPreset: true,
      style: parseStyle(p.style),
    })),
    ...customRows.map((p) => ({
      id: p.phrase_id,
      text: p.localized_utterance ?? '',
      sortOrder: p.sort_order,
      isPreset: false,
      style: parseStyle(p.style),
    })),
  ]

  return display.sort((a, b) => a.sortOrder - b.sortOrder)
}

export async function markPhraseSpoken(phraseId: string, isPreset: boolean): Promise<void> {
  const now = Date.now()
  if (isPreset) {
    const row = await db.presetPhrase.get(phraseId)
    if (row) {
      await db.presetPhrase.put({ ...row, last_spoken_date: now })
    }
    return
  }
  const custom = await db.phrase.get(phraseId)
  if (custom) {
    await db.phrase.put({ ...custom, last_spoken_date: now })
    return
  }
  const preset = await db.presetPhrase.get(phraseId)
  if (preset) {
    await db.presetPhrase.put({ ...preset, last_spoken_date: now })
  }
}

export function getPresetCategoryColor(categoryId: string): string {
  const cat = presets.categories.find((c) => c.categoryId === categoryId)
  return cat?.defaultColor ?? '#FF78909C'
}
