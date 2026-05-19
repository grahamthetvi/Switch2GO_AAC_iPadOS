import en from './locales/en.json'
import es from './locales/es.json'
import fr from './locales/fr.json'

export type Locale = 'en' | 'fr' | 'es'

const bundles: Record<Locale, typeof en> = { en, fr, es }

export const LOCALE_OPTIONS: { id: Locale; labelKey: keyof typeof en }[] = [
  { id: 'en', labelKey: 'languageEnglish' },
  { id: 'fr', labelKey: 'languageFrench' },
  { id: 'es', labelKey: 'languageSpanish' },
]

function getNested(obj: Record<string, unknown>, path: string): string | undefined {
  const parts = path.split('.')
  let cur: unknown = obj
  for (const p of parts) {
    if (cur == null || typeof cur !== 'object') return undefined
    cur = (cur as Record<string, unknown>)[p]
  }
  return typeof cur === 'string' ? cur : undefined
}

export function translate(locale: Locale, key: string, vars?: Record<string, string | number>): string {
  const raw = getNested(bundles[locale] as Record<string, unknown>, key)
    ?? getNested(bundles.en as Record<string, unknown>, key)
    ?? key
  if (!vars) return raw
  return raw.replace(/\{\{(\w+)\}\}/g, (_, name: string) => String(vars[name] ?? ''))
}

export function localizedCategoryName(locale: Locale, categoryId: string, fallback: string): string {
  return translate(locale, `categories.${categoryId}`) || fallback
}

export function localizedPhraseText(locale: Locale, phraseId: string, fallback: string): string {
  return translate(locale, `phrases.${phraseId}`) || fallback
}
