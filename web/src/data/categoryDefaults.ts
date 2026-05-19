import presets from './presets.json'

const PRESET_DEFAULT_COLORS: Record<string, number> = {
  preset_routine_activity: 0xffe53935,
  preset_food_drink: 0xff1e88e5,
  preset_comfort_state: 0xff43a047,
  preset_play_leisure: 0xfffb8c00,
  preset_positioning: 0xff8e24aa,
  preset_recents: 0xfff06292,
}

const PRESET_DEFAULT_SYMBOLS: Record<string, string> = Object.fromEntries(
  presets.categories.map((c) => [c.categoryId, c.symbol]),
)

export const NEW_CATEGORY_COLOR_PALETTE: number[] = [
  0xffe53935, 0xff1e88e5, 0xff43a047, 0xfffb8c00, 0xff8e24aa, 0xff00acc1,
  0xfff06292, 0xffffee58, 0xff26a69a, 0xff673ab7,
]

export function getDefaultCategoryColor(categoryId: string): number {
  const fromPreset = presets.categories.find((c) => c.categoryId === categoryId)
  if (fromPreset?.defaultColor) {
    return parseInt(fromPreset.defaultColor.replace('#', ''), 16)
  }
  return PRESET_DEFAULT_COLORS[categoryId] ?? 0xff00acc1
}

export function getDefaultCategorySymbol(categoryId: string): string {
  return PRESET_DEFAULT_SYMBOLS[categoryId] ?? 'folder'
}

export function pickNewCategoryColor(): number {
  return NEW_CATEGORY_COLOR_PALETTE[Math.floor(Math.random() * NEW_CATEGORY_COLOR_PALETTE.length)]
}
