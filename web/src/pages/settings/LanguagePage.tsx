import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { LOCALE_OPTIONS } from '../../i18n/i18n'
import { useTranslation } from '../../i18n/useTranslation'

export function LanguagePage() {
  const { t, locale, setLocale } = useTranslation()

  return (
    <SettingsLayout title={t('language')} backTo="/settings" backLabel={t('settingsBack')}>
      <ul className="option-list" style={{ padding: '0 16px 24px' }}>
        {LOCALE_OPTIONS.map((opt) => (
          <li key={opt.id}>
            <button
              type="button"
              className={`option-list-btn${locale === opt.id ? ' selected' : ''}`}
              onClick={() => setLocale(opt.id)}
            >
              {t(opt.labelKey)}
              {locale === opt.id && <span className="check-mark"> ✓</span>}
            </button>
          </li>
        ))}
      </ul>
    </SettingsLayout>
  )
}
