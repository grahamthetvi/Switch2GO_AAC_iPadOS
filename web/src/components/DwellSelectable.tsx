import { useEffect, useRef, type ReactNode } from 'react'
import { useTracking } from '../tracking/TrackingContext'

interface Props {
  id: string
  onActivate: () => void
  children: ReactNode
  className?: string
  style?: React.CSSProperties
}

export function DwellSelectable({ id, onActivate, children, className, style }: Props) {
  const ref = useRef<HTMLButtonElement>(null)
  const { dwell, tracking } = useTracking()

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
      if (buttonId === id) onActivate()
    })
  }, [id, dwell, onActivate])

  const isHovered = dwell.hoveredButtonId === id
  const progress = isHovered ? dwell.dwellProgress : 0
  const trackingActive = tracking.isTracking && tracking.isCursorVisible

  return (
    <button
      ref={ref}
      type="button"
      className={className}
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
