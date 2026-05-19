import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { hexToCss, useSettings } from '../../settings/settingsStore'

interface SettingsLayoutProps {
  title: string
  backTo?: string
  backLabel?: string
  children: ReactNode
  actions?: ReactNode
}

export function SettingsLayout({
  title,
  backTo = '/settings',
  backLabel = '← Settings',
  children,
  actions,
}: SettingsLayoutProps) {
  const border = hexToCss(useSettings((s) => s.appBorderColor))

  return (
    <div className="page settings-page" style={{ background: border }}>
      <header className="page-header settings-header">
        <Link to={backTo} className="back-btn">
          {backLabel}
        </Link>
        <h1>{title}</h1>
        <div className="settings-header-actions">{actions ?? null}</div>
      </header>
      {children}
    </div>
  )
}
