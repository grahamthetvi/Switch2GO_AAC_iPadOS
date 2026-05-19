import { useTranslation } from '../i18n/useTranslation'

interface TrackingFallbackBannerProps {
  message: string
  onUseTouch: () => void
  onRetry?: () => void
}

export function TrackingFallbackBanner({
  message,
  onUseTouch,
  onRetry,
}: TrackingFallbackBannerProps) {
  const { t } = useTranslation()

  return (
    <div className="tracking-fallback" role="alert">
      <p className="tracking-fallback-title">{t('trackingFallbackTitle')}</p>
      <p className="tracking-fallback-message">{message}</p>
      <div className="tracking-fallback-actions">
        <button type="button" className="secondary-btn" onClick={onUseTouch}>
          {t('trackingFallbackTouch')}
        </button>
        {onRetry ? (
          <button type="button" className="text-btn" onClick={onRetry}>
            {t('trackingFallbackRetry')}
          </button>
        ) : null}
      </div>
    </div>
  )
}
