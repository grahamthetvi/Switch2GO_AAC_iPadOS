import { useCallback } from 'react'
import { useSettings } from '../settings/settingsStore'
import { translate, type Locale } from './i18n'

export function useTranslation() {
  const locale = useSettings((s) => s.locale)
  const setLocale = useSettings((s) => s.setLocale)

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => translate(locale, key, vars),
    [locale],
  )

  return { t, locale, setLocale }
}

export function useLocale(): Locale {
  return useSettings((s) => s.locale)
}
