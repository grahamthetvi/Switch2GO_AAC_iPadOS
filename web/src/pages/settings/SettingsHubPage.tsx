import { Link } from 'react-router-dom'
import { SettingsHubRow } from '../../components/settings/SettingsHubRow'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'
import { useSettings } from '../../settings/settingsStore'
import { useTracking } from '../../tracking/TrackingContext'

export function SettingsHubPage() {
  const { t } = useTranslation()
  const { recenterCursor } = useTracking()
  const requestOnboarding = useSettings((s) => s.requestOnboarding)

  return (
    <SettingsLayout title={t('settings')} backTo="/" backLabel={t('settingsHome')}>
      <div className="settings-hub">
        <button type="button" className="settings-recenter-btn" onClick={recenterCursor}>
          <span aria-hidden>◎</span> {t('recenterCursor')}
        </button>

        <SettingsHubRow
          to="/settings/edit/categories"
          title={t('editCategoriesPhrases')}
          icon="📂"
          iconClass="icon-blue"
        />
        <SettingsHubRow
          to="/settings/timing"
          title={t('timingSensitivity')}
          icon="⏱"
          iconClass="icon-orange"
        />
        <SettingsHubRow
          to="/settings/selection"
          title={t('selectionMode')}
          icon="👆"
          iconClass="icon-purple"
        />
        <SettingsHubRow
          to="/settings/cvi"
          title={t('cviDisplay')}
          icon="🔲"
          iconClass="icon-teal"
          subtitle={t('cviDisplaySubtitle')}
        />
        <SettingsHubRow
          to="/settings/categories-display"
          title={t('categoriesDisplay')}
          icon="🎨"
          iconClass="icon-pink"
          subtitle={t('categoriesDisplaySubtitle')}
        />
        <SettingsHubRow
          to="/settings/border-color"
          title={t('appBorderColor')}
          icon="🖼"
          iconClass="icon-indigo"
        />
        <SettingsHubRow
          to="/settings/eye-tracking"
          title={t('advancedEyeTracking')}
          icon="👁"
          iconClass="icon-green"
        />
        <SettingsHubRow
          to="/settings/head-tracking"
          title={t('headTracking')}
          icon="🙂"
          iconClass="icon-orange"
        />
        <SettingsHubRow
          to="/settings/switch-control"
          title={t('switchControl')}
          icon="⌨"
          iconClass="icon-gray"
          subtitle={t('switchControlSubtitle')}
        />
        <SettingsHubRow to="/settings/language" title={t('language')} icon="🌐" iconClass="icon-teal" />
        <SettingsHubRow
          to="/settings/reset"
          title={t('resetApp')}
          icon="↺"
          iconClass="icon-red"
        />

        <hr className="settings-hub-divider" />

        <button type="button" className="settings-hub-row" onClick={requestOnboarding}>
          <span className="settings-hub-icon icon-blue" aria-hidden>
            📖
          </span>
          <span className="settings-hub-text">
            <span className="settings-hub-title">{t('showWelcomeGuide')}</span>
          </span>
          <span className="settings-hub-chevron" aria-hidden>
            ›
          </span>
        </button>
        <SettingsHubRow
          to="/settings/backup"
          title={t('dataBackup.title')}
          icon="💾"
          iconClass="icon-teal"
          subtitle={t('dataBackup.hubSubtitle')}
        />
        <SettingsHubRow
          to="/settings/troubleshooting"
          title={t('troubleshooting')}
          icon="🔧"
          iconClass="icon-orange"
        />
        <SettingsHubRow
          to="/settings/privacy"
          title={t('privacyPolicy')}
          icon="🛡"
          iconClass="icon-gray"
        />

        <a
          href="https://switch2goaac.org/index.html#image-tool"
          target="_blank"
          rel="noopener noreferrer"
          className="settings-hub-row"
        >
          <span className="settings-hub-icon icon-green" aria-hidden>
            ✨
          </span>
          <span className="settings-hub-text">
            <span className="settings-hub-title">{t('imageTool')}</span>
          </span>
          <span className="settings-hub-chevron" aria-hidden>
            ↗
          </span>
        </a>
        <a
          href="https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS_Explanation_and_Support/index.html"
          target="_blank"
          rel="noopener noreferrer"
          className="settings-hub-row"
        >
          <span className="settings-hub-icon icon-blue" aria-hidden>
            ?
          </span>
          <span className="settings-hub-text">
            <span className="settings-hub-title">{t('getSupport')}</span>
            <span className="settings-hub-subtitle">{t('getSupportSubtitle')}</span>
          </span>
          <span className="settings-hub-chevron" aria-hidden>
            ↗
          </span>
        </a>
      </div>

      <p className="privacy-note">
        {t('privacyShort')}{' '}
        <Link to="/">{t('returnToCategories')}</Link>
      </p>
    </SettingsLayout>
  )
}
