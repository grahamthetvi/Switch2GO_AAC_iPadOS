import type { ReactNode } from 'react'

interface SettingsCardProps {
  title?: string
  hint?: string
  children: ReactNode
}

export function SettingsCard({ title, hint, children }: SettingsCardProps) {
  return (
    <section className="settings-card">
      {title ? <h2 className="settings-card-title">{title}</h2> : null}
      {hint ? <p className="hint settings-card-hint">{hint}</p> : null}
      {children}
    </section>
  )
}
