import { Link } from 'react-router-dom'

interface SettingsHubRowProps {
  to: string
  title: string
  icon: string
  iconClass?: string
  subtitle?: string
}

export function SettingsHubRow({ to, title, icon, iconClass, subtitle }: SettingsHubRowProps) {
  return (
    <Link to={to} className="settings-hub-row">
      <span className={`settings-hub-icon ${iconClass ?? ''}`} aria-hidden>
        {icon}
      </span>
      <span className="settings-hub-text">
        <span className="settings-hub-title">{title}</span>
        {subtitle ? <span className="settings-hub-subtitle">{subtitle}</span> : null}
      </span>
      <span className="settings-hub-chevron" aria-hidden>
        ›
      </span>
    </Link>
  )
}
