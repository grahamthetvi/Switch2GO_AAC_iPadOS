import presets from './presets.json'
import { db } from './db'

const SEED_KEY = 'switch2go_db_seeded_v1'

export async function ensureDatabaseSeeded(): Promise<void> {
  const count = await db.presetCategory.count()
  if (count > 0) return

  await db.transaction('rw', db.presetCategory, db.presetPhrase, async () => {
    for (const cat of presets.categories) {
      await db.presetCategory.put({
        category_id: cat.categoryId,
        hidden: 0,
        sort_order: cat.sortOrder,
        deleted: 0,
        color_hex: null,
        symbol_name: cat.symbol,
      })
    }
    for (const phrase of presets.phrases) {
      await db.presetPhrase.put({
        phrase_id: phrase.phraseId,
        parent_category_id: phrase.parentCategoryId,
        creation_date: 0,
        last_spoken_date: null,
        sort_order: phrase.sortOrder,
        deleted: 0,
        style: null,
      })
    }
  })

  localStorage.setItem(SEED_KEY, '1')
}

export async function resetDatabaseToDefaults(): Promise<void> {
  await db.transaction(
    'rw',
    [db.category, db.phrase, db.presetCategory, db.presetPhrase, db.images, db.media],
    async () => {
      await db.category.clear()
      await db.phrase.clear()
      await db.presetCategory.clear()
      await db.presetPhrase.clear()
      await db.images.clear()
      await db.media.clear()
    },
  )
  await ensureDatabaseSeeded()
}
