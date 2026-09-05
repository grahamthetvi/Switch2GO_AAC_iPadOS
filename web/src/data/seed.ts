import presets from './presets.json'
import { db } from './db'

const SEED_KEY = 'switch2go_db_seeded_v1'
const SEED_VERSION_KEY = 'switch2go_db_seed_version'
/** Bump when presets.json gains new category/phrase IDs that existing DBs should receive. */
export const CURRENT_SEED_VERSION = 2

async function insertMissingPresets(): Promise<number> {
  let inserted = 0
  await db.transaction('rw', db.presetCategory, db.presetPhrase, async () => {
    for (const cat of presets.categories) {
      const existing = await db.presetCategory.get(cat.categoryId)
      if (existing) continue
      await db.presetCategory.put({
        category_id: cat.categoryId,
        hidden: 0,
        sort_order: cat.sortOrder,
        deleted: 0,
        color_hex: null,
        symbol_name: cat.symbol,
      })
      inserted += 1
    }
    for (const phrase of presets.phrases) {
      const existing = await db.presetPhrase.get(phrase.phraseId)
      if (existing) continue
      await db.presetPhrase.put({
        phrase_id: phrase.phraseId,
        parent_category_id: phrase.parentCategoryId,
        creation_date: 0,
        last_spoken_date: null,
        sort_order: phrase.sortOrder,
        deleted: 0,
        style: null,
      })
      inserted += 1
    }
  })
  return inserted
}

export async function ensureDatabaseSeeded(): Promise<void> {
  const count = await db.presetCategory.count()
  const seedVersion = Number(localStorage.getItem(SEED_VERSION_KEY) ?? '0')

  if (count === 0) {
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
    localStorage.setItem(SEED_VERSION_KEY, String(CURRENT_SEED_VERSION))
    return
  }

  // Existing DB: insert any new preset IDs without wiping styles/customizations.
  if (seedVersion < CURRENT_SEED_VERSION) {
    const inserted = await insertMissingPresets()
    localStorage.setItem(SEED_KEY, '1')
    localStorage.setItem(SEED_VERSION_KEY, String(CURRENT_SEED_VERSION))
    if (inserted > 0) {
      console.info(`[seed] inserted ${inserted} missing preset rows`)
    }
  }
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
  localStorage.removeItem(SEED_KEY)
  localStorage.removeItem(SEED_VERSION_KEY)
  await ensureDatabaseSeeded()
}
