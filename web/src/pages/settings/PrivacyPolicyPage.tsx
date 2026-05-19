import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'

export function PrivacyPolicyPage() {
  const { t } = useTranslation()
  const [text, setText] = useState('')
  const [error, setError] = useState(false)

  useEffect(() => {
    const url = `${import.meta.env.BASE_URL}privacy-policy.txt`
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
      title={t('privacyPolicy')}
      backTo="/settings"
      backLabel={t('settingsBack')}
      actions={<Link to="/settings" className="text-btn">{t('done')}</Link>}
    >
      <div className="privacy-policy-body">
        {error ? (
          <p className="settings-intro">
            Privacy policy is unavailable offline.{' '}
            <a href="https://switch2goaac.org" target="_blank" rel="noopener noreferrer">
              switch2goaac.org
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
