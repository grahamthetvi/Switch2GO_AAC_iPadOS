/** Phrase tile styling (ARGB integers match iOS/KMP JSON). */
export interface PhraseStyle {
  backgroundColor?: number
  textColor?: number
  fontSize?: number
  bold?: boolean
  borderWidth?: number
  borderColor?: number
  imageRef?: string | null
}

export interface ImageRow {
  id: string
  blob: Blob
  created_at: number
}

export interface PresetCategoryRow {
  category_id: string
  hidden: number
  sort_order: number
  deleted: number
  color_hex: number | null
  symbol_name: string | null
}

export interface PresetPhraseRow {
  phrase_id: string
  parent_category_id: string
  creation_date: number
  last_spoken_date: number | null
  sort_order: number
  deleted: number
  style: string | null
}

export interface CategoryRow {
  category_id: string
  creation_date: number
  localized_name: string
  hidden: number
  sort_order: number
  color_hex: number | null
  symbol_name: string | null
}

export interface PhraseRow {
  phrase_id: string
  parent_category_id: string | null
  creation_date: number
  last_spoken_date: number | null
  localized_utterance: string | null
  sort_order: number
  style: string | null
}

export interface CategoryDisplay {
  id: string
  name: string
  sortOrder: number
  isPreset: boolean
  hidden: boolean
  colorHex: number | null
  symbolName: string | null
}

export interface PhraseDisplay {
  id: string
  text: string
  sortOrder: number
  isPreset: boolean
  style: PhraseStyle | null
}

export const RECENTS_CATEGORY_ID = 'preset_recents'
