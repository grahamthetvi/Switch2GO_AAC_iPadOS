import Dexie, { type Table } from 'dexie'
import type {
  CategoryRow,
  ImageRow,
  MediaRow,
  PhraseRow,
  PresetCategoryRow,
  PresetPhraseRow,
} from './types'

export class Switch2GoDatabase extends Dexie {
  presetCategory!: Table<PresetCategoryRow, string>
  presetPhrase!: Table<PresetPhraseRow, string>
  category!: Table<CategoryRow, string>
  phrase!: Table<PhraseRow, string>
  images!: Table<ImageRow, string>
  media!: Table<MediaRow, string>

  constructor() {
    super('switch2go')
    this.version(1).stores({
      presetCategory: 'category_id',
      presetPhrase: 'phrase_id, parent_category_id, last_spoken_date',
      category: 'category_id, sort_order',
      phrase: 'phrase_id, parent_category_id, last_spoken_date, sort_order',
    })
    this.version(2).stores({
      presetCategory: 'category_id',
      presetPhrase: 'phrase_id, parent_category_id, last_spoken_date',
      category: 'category_id, sort_order',
      phrase: 'phrase_id, parent_category_id, last_spoken_date, sort_order',
      images: 'id',
    })
    this.version(3).stores({
      presetCategory: 'category_id',
      presetPhrase: 'phrase_id, parent_category_id, last_spoken_date',
      category: 'category_id, sort_order',
      phrase: 'phrase_id, parent_category_id, last_spoken_date, sort_order',
      images: 'id',
      media: 'id',
    })
  }
}

export const db = new Switch2GoDatabase()
