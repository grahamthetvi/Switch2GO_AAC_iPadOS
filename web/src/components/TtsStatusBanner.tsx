import { useEffect, useState } from 'react'
import { clearTtsError, getTtsStatus, subscribeTtsStatus } from '../tts/speak'

export function TtsStatusBanner() {
  const [status, setStatus] = useState(getTtsStatus)

  useEffect(() => subscribeTtsStatus(setStatus), [])

  if (status.state === 'idle' || status.state === 'speaking') return null

  const isError = status.state === 'error'

  return (
    <div className={`tracking-banner${isError ? ' error' : ''}`} role="status">
      <span>{status.message ?? (status.state === 'loading' ? 'Preparing speech…' : '')}</span>
      {isError ? (
        <button type="button" className="tts-banner-dismiss" onClick={clearTtsError}>
          Dismiss
        </button>
      ) : null}
    </div>
  )
}
