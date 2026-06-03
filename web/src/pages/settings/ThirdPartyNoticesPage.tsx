import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'

export function ThirdPartyNoticesPage() {
  const { t } = useTranslation()
  const [text, setText] = useState('')
  const [error, setError] = useState(false)

  useEffect(() => {
    const url = `${import.meta.env.BASE_URL}third-party-notices.txt`
    fetch(url)
      .then((r) => {
        if (!r.ok) throw new Error('fetch failed')
        return r.text()
      })
      .then(setText)
      .catch(() => setError(true))
  }, [])

  return (
    <SettingsLayout
      title={t('openSourceLicenses')}
      backTo="/settings"
      backLabel={t('settingsBack')}
      actions={<Link to="/settings" className="text-btn">{t('done')}</Link>}
    >
      <div className="privacy-policy-body">
        {error ? (
          <p className="settings-intro">
            {t('openSourceLicensesUnavailable')}{' '}
            <a
              href="https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS/blob/main/THIRD_PARTY_NOTICES.md"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
          </p>
        ) : text ? (
          <pre className="privacy-policy-text">{text}</pre>
        ) : (
          <p className="status">{t('loading')}</p>
        )}
      </div>
    </SettingsLayout>
  )
}
