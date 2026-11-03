/** Blank spoken text means the button label is what gets spoken. */
export function normalizeSpokenText(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? ''
  return trimmed.length === 0 ? null : trimmed
}

export function phraseSpeechText(presented: string, spoken: string | null | undefined): string {
  return normalizeSpokenText(spoken) ?? presented
}
