import { useEffect, useRef, type ReactNode } from 'react'
import { useDwellStatus, useTrackingActions } from '../tracking/TrackingContext'

interface Props {
  id: string
  onActivate: () => void
  onSpeak?: () => void
  children: ReactNode
  className?: string
  style?: React.CSSProperties
}

export function DwellSelectable({ id, onActivate, onSpeak, children, className, style }: Props) {
  const ref = useRef<HTMLButtonElement>(null)
  const { dwell } = useTrackingActions()
  const { dwellProgress, hoveredButtonId, trackingActive } = useDwellStatus()

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const updateFrame = () => {
      const rect = el.getBoundingClientRect()
      dwell.registerButton(id, rect)
    }

    updateFrame()
    const ro = new ResizeObserver(updateFrame)
    ro.observe(el)
    window.addEventListener('scroll', updateFrame, true)
    window.addEventListener('resize', updateFrame)

    return () => {
      ro.disconnect()
      window.removeEventListener('scroll', updateFrame, true)
      window.removeEventListener('resize', updateFrame)
      dwell.unregisterButton(id)
    }
  }, [id, dwell])

  useEffect(() => {
    return dwell.subscribe((buttonId) => {
      if (buttonId === id) {
        onSpeak?.()
        onActivate()
      }
    })
  }, [id, dwell, onActivate, onSpeak])

  const isHovered = hoveredButtonId === id
  const progress = isHovered ? dwellProgress : 0

  return (
    <button
      ref={ref}
      type="button"
      className={className}
      onPointerDown={() => onSpeak?.()}
      onClick={onActivate}
      data-dwell-id={id}
      style={{
        position: 'relative',
        overflow: 'hidden',
        ...style,
      }}
    >
      {children}
      {trackingActive && isHovered && progress > 0 && (
        <span
          className="dwell-ring"
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: 'inherit',
            boxShadow: `inset 0 0 0 4px rgba(255,255,255,${0.3 + progress * 0.5})`,
            pointerEvents: 'none',
          }}
          aria-hidden
        />
      )}
    </button>
  )
}
