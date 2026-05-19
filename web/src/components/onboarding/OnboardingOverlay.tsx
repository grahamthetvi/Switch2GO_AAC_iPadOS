import { useState } from 'react'
import { useTranslation } from '../../i18n/useTranslation'
import { useSettings } from '../../settings/settingsStore'
import { OnboardingSlide } from './OnboardingSlide'

const TOTAL_PAGES = 8

export function OnboardingOverlay() {
  const { t } = useTranslation()
  const setHasSeenOnboarding = useSettings((s) => s.setHasSeenOnboarding)
  const clearOnboardingRequest = useSettings((s) => s.clearOnboardingRequest)
  const [page, setPage] = useState(0)

  const finish = () => {
    setHasSeenOnboarding(true)
    clearOnboardingRequest()
  }

  const slides = [
    <OnboardingSlide
      key="welcome"
      icon="💬"
      iconClass="onboarding-icon-blue"
      title={t('onboarding.welcomeTitle')}
      paragraphs={[t('onboarding.welcomeP1'), t('onboarding.welcomeP2'), t('onboarding.welcomeP3')]}
    />,
    <OnboardingSlide
      key="orientation"
      icon="📱"
      iconClass="onboarding-icon-orange"
      title={t('onboarding.orientationTitle')}
      paragraphs={[t('onboarding.orientationP1'), t('onboarding.orientationP2'), t('onboarding.orientationP3')]}
    />,
    <OnboardingSlide
      key="navigation"
      icon="👆"
      iconClass="onboarding-icon-green"
      title={t('onboarding.navigationTitle')}
      paragraphs={[
        t('onboarding.navigationP1'),
        t('onboarding.navigationP2'),
        t('onboarding.navigationP3'),
        t('onboarding.navigationP4'),
        t('onboarding.navigationP5'),
        t('onboarding.navigationP6'),
      ]}
    />,
    <OnboardingSlide
      key="imageTool"
      icon="🖼"
      iconClass="onboarding-icon-purple"
      title={t('onboarding.imageToolTitle')}
      paragraphs={[
        t('onboarding.imageToolP1'),
        t('onboarding.imageToolP2'),
        t('onboarding.imageToolP3'),
        t('onboarding.imageToolP4'),
      ]}
    />,
    <OnboardingSlide
      key="cviFriendly"
      icon="👁"
      iconClass="onboarding-icon-red"
      title={t('onboarding.cviFriendlyTitle')}
      paragraphs={[
        t('onboarding.cviFriendlyP1'),
        t('onboarding.cviFriendlyP2'),
        t('onboarding.cviFriendlyP3'),
        t('onboarding.cviFriendlyP4'),
        t('onboarding.cviFriendlyP5'),
      ]}
    />,
    <OnboardingSlide
      key="cviDisplay"
      icon="🔲"
      iconClass="onboarding-icon-teal"
      title={t('onboarding.cviDisplayTitle')}
      paragraphs={[t('onboarding.cviDisplayP1'), t('onboarding.cviDisplayP2'), t('onboarding.cviDisplayP3')]}
    />,
    <OnboardingSlide
      key="switch"
      icon="⌨"
      iconClass="onboarding-icon-orange"
      title={t('onboarding.switchTitle')}
      paragraphs={[t('onboarding.switchP1'), t('onboarding.switchP2'), t('onboarding.switchP3')]}
    />,
    <div key="privacy" className="onboarding-slide onboarding-privacy-slide">
      <span className="onboarding-icon onboarding-icon-green" aria-hidden>
        🔒
      </span>
      <h2 className="onboarding-title">{t('onboarding.privacyTitle')}</h2>
      <div className="onboarding-privacy-quotes">
        {[t('onboarding.privacyP1'), t('onboarding.privacyP2'), t('onboarding.privacyP3'), t('onboarding.privacyP4'), t('onboarding.privacyP5')].map(
          (text) => (
            <blockquote key={text.slice(0, 24)} className="onboarding-privacy-quote">
              {text}
            </blockquote>
          ),
        )}
      </div>
      <p className="onboarding-privacy-footnote">{t('onboarding.privacyP6')}</p>
    </div>,
  ]

  return (
    <div className="onboarding-overlay" role="dialog" aria-modal="true" aria-label={t('onboarding.welcomeTitle')}>
      <div className="onboarding-panel">
        <div className="onboarding-content">{slides[page]}</div>

        <div className="onboarding-footer">
          <div className="onboarding-dots" aria-hidden>
            {Array.from({ length: TOTAL_PAGES }, (_, i) => (
              <span key={i} className={`onboarding-dot${i === page ? ' active' : ''}`} />
            ))}
          </div>

          <div className="onboarding-nav">
            {page > 0 && (
              <button type="button" className="onboarding-btn secondary" onClick={() => setPage((p) => p - 1)}>
                {t('onboardingBack')}
              </button>
            )}
            <button
              type="button"
              className="onboarding-btn primary"
              onClick={() => {
                if (page < TOTAL_PAGES - 1) setPage((p) => p + 1)
                else finish()
              }}
            >
              {page < TOTAL_PAGES - 1 ? t('onboardingNext') : t('onboardingAgree')}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

