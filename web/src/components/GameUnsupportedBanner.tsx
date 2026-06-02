type Props = {
  message: string
  onDismiss: () => void
}

export function GameUnsupportedBanner({ message, onDismiss }: Props) {
  return (
    <div className="tracking-banner error game-unsupported-banner" role="alert">
      <span>{message}</span>
      <button type="button" className="tts-banner-dismiss" onClick={onDismiss}>
        Dismiss
      </button>
    </div>
  )
}
