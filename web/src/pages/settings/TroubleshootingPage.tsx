import { Link } from 'react-router-dom'
import { SettingsLayout } from '../../components/settings/SettingsLayout'
import { useTranslation } from '../../i18n/useTranslation'

function TroubleshootingSection({
  title,
  icon,
  iconClass,
  steps,
}: {
  title: string
  icon: string
  iconClass: string
  steps: string[]
}) {
  return (
    <section className="troubleshooting-section">
      <h2 className="troubleshooting-heading">
        <span className={`troubleshooting-icon ${iconClass}`} aria-hidden>
          {icon}
        </span>
        {title}
      </h2>
      <ol className="troubleshooting-steps">
        {steps.map((step, i) => (
          <li key={step.slice(0, 24)}>
            <span className="troubleshooting-step-num">{i + 1}.</span>
            {step}
          </li>
        ))}
      </ol>
    </section>
  )
}

export function TroubleshootingPage() {
  const { t } = useTranslation()

  return (
    <SettingsLayout title={t('troubleshooting')} backTo="/settings" backLabel={t('settingsBack')} actions={<Link to="/settings" className="text-btn">{t('done')}</Link>}>
      <p className="settings-intro">{t('troubleshootingGuide.intro')}</p>

      <TroubleshootingSection
        title={t('troubleshootingGuide.modesTitle')}
        icon="🔄"
        iconClass="icon-purple"
        steps={[
          t('troubleshootingGuide.modes1'),
          t('troubleshootingGuide.modes2'),
          t('troubleshootingGuide.modes3'),
          t('troubleshootingGuide.modes4'),
          t('troubleshootingGuide.modes5'),
          t('troubleshootingGuide.modes6'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.orientationTitle')}
        icon="📐"
        iconClass="icon-blue"
        steps={[
          t('troubleshootingGuide.orientation1'),
          t('troubleshootingGuide.orientation2'),
          t('troubleshootingGuide.orientation3'),
          t('troubleshootingGuide.orientation4'),
          t('troubleshootingGuide.orientation5'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.trackingTitle')}
        icon="👁"
        iconClass="icon-orange"
        steps={[
          t('troubleshootingGuide.tracking1'),
          t('troubleshootingGuide.tracking2'),
          t('troubleshootingGuide.tracking3'),
          t('troubleshootingGuide.tracking4'),
          t('troubleshootingGuide.tracking5'),
          t('troubleshootingGuide.tracking6'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.bodySelectionTitle')}
        icon="🙋"
        iconClass="icon-mint"
        steps={[
          t('troubleshootingGuide.bodySelection1'),
          t('troubleshootingGuide.bodySelection2'),
          t('troubleshootingGuide.bodySelection3'),
          t('troubleshootingGuide.bodySelection4'),
          t('troubleshootingGuide.bodySelection5'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.mediaTitle')}
        icon="▶"
        iconClass="icon-indigo"
        steps={[
          t('troubleshootingGuide.media1'),
          t('troubleshootingGuide.media2'),
          t('troubleshootingGuide.media3'),
          t('troubleshootingGuide.media4'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.switchTitle')}
        icon="⌨"
        iconClass="icon-orange"
        steps={[
          t('troubleshootingGuide.switch1'),
          t('troubleshootingGuide.switch2'),
          t('troubleshootingGuide.switch3'),
          t('troubleshootingGuide.switch4'),
        ]}
      />
      <TroubleshootingSection
        title={t('troubleshootingGuide.safariTitle')}
        icon="📱"
        iconClass="icon-teal"
        steps={[
          t('troubleshootingGuide.safariIntro'),
          t('troubleshootingGuide.safariEye'),
          t('troubleshootingGuide.safariHead'),
          t('troubleshootingGuide.safariArm'),
          t('troubleshootingGuide.safariDwell'),
          t('troubleshootingGuide.safariCameraDeny'),
          t('troubleshootingGuide.safariTouch'),
        ]}
      />
    </SettingsLayout>
  )
}
