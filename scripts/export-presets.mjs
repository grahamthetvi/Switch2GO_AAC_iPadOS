#!/usr/bin/env node
/**
 * Regenerates web/src/data/presets.json from shared PresetData.kt + PresetCategories.
 * Category display metadata (name/color/symbol) is preserved from the existing JSON
 * when the category id already exists; new categories get placeholder metadata.
 *
 * Usage: node scripts/export-presets.mjs
 *    or: ./gradlew :shared:exportWebPresets
 *    or: npm run sync-presets (from web/)
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const presetDataPath = path.join(root, 'shared/src/commonMain/kotlin/com/vocable/data/PresetData.kt')
const categoryPath = path.join(root, 'shared/src/commonMain/kotlin/com/vocable/data/models/Category.kt')
const outPath = path.join(root, 'web/src/data/presets.json')

const CATEGORY_META = {
  preset_routine_activity: {
    name: 'Daily Activities',
    defaultColor: '#FFE53935',
    symbol: 'checklist',
  },
  preset_food_drink: { name: 'Food & Drinks', defaultColor: '#FF1E88E5', symbol: 'food' },
  preset_comfort_state: { name: 'How I Feel', defaultColor: '#FF43A047', symbol: 'heart' },
  preset_play_leisure: { name: 'Fun & Games', defaultColor: '#FFFB8C00', symbol: 'play' },
  preset_positioning: { name: 'Move Me', defaultColor: '#FF8E24AA', symbol: 'move' },
  preset_recents: { name: 'Recently Said', defaultColor: '#FF78909C', symbol: 'clock' },
}

function parseCategories(source) {
  const enumMatch = source.match(/enum class PresetCategories[\s\S]*?\{([\s\S]*?);/)
  if (!enumMatch) throw new Error('Could not find PresetCategories enum')
  const body = enumMatch[1]
  const entries = []
  const re = /(\w+)\("([^"]+)",\s*(\d+)\)/g
  let m
  while ((m = re.exec(body))) {
    entries.push({ enumName: m[1], categoryId: m[2], sortOrder: Number(m[3]) })
  }
  if (!entries.length) throw new Error('No PresetCategories entries parsed')
  return entries
}

function parsePhrases(source) {
  const phrases = []
  const re =
    /PhraseModel\(\s*phraseId\s*=\s*"([^"]+)"\s*,\s*parentCategoryId\s*=\s*PresetCategories\.(\w+)\.id\s*,\s*localizedUtterance\s*=\s*"((?:\\.|[^"\\])*)"\s*,\s*sortOrder\s*=\s*(\d+)/g
  let m
  while ((m = re.exec(source))) {
    phrases.push({
      phraseId: m[1],
      parentEnum: m[2],
      text: m[3].replace(/\\"/g, '"').replace(/\\n/g, '\n'),
      sortOrder: Number(m[4]),
    })
  }
  if (!phrases.length) throw new Error('No PhraseModel entries parsed from PresetData.kt')
  return phrases
}

const categorySource = fs.readFileSync(categoryPath, 'utf8')
const presetSource = fs.readFileSync(presetDataPath, 'utf8')

const categories = parseCategories(categorySource)
const enumToId = Object.fromEntries(categories.map((c) => [c.enumName, c.categoryId]))

let existing = { categories: [], phrases: [] }
if (fs.existsSync(outPath)) {
  existing = JSON.parse(fs.readFileSync(outPath, 'utf8'))
}
const existingById = Object.fromEntries(
  (existing.categories || []).map((c) => [c.categoryId, c]),
)

const outCategories = categories.map((c) => {
  const prev = existingById[c.categoryId]
  const meta = CATEGORY_META[c.categoryId] || {
    name: c.categoryId,
    defaultColor: '#FF78909C',
    symbol: 'folder',
  }
  return {
    categoryId: c.categoryId,
    name: prev?.name ?? meta.name,
    sortOrder: c.sortOrder,
    defaultColor: prev?.defaultColor ?? meta.defaultColor,
    symbol: prev?.symbol ?? meta.symbol,
  }
})

const outPhrases = parsePhrases(presetSource).map((p) => {
  const parentCategoryId = enumToId[p.parentEnum]
  if (!parentCategoryId) {
    throw new Error(`Unknown parent enum PresetCategories.${p.parentEnum}`)
  }
  return {
    phraseId: p.phraseId,
    parentCategoryId,
    text: p.text,
    sortOrder: p.sortOrder,
  }
})

const payload = {
  categories: outCategories,
  phrases: outPhrases,
}

fs.writeFileSync(outPath, `${JSON.stringify(payload, null, 2)}\n`)
console.log(
  `OK: wrote ${outCategories.length} categories and ${outPhrases.length} phrases to ${path.relative(root, outPath)}`,
)
