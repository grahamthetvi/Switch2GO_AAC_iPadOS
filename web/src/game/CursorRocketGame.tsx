import { useEffect, useRef } from 'react'

const STILL_SPEED_PX_PER_SEC = 28
const LERP = 0.12
const ROCKET_SIZE = 56

type Props = {
  targetX: number
  targetY: number
}

/** Rocket that follows the gaze/cursor; exhaust hides when mostly still. */
export function CursorRocketGame({ targetX, targetY }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stateRef = useRef({
    x: targetX,
    y: targetY,
    angle: -Math.PI / 2,
    showExhaust: false,
    lastTargetX: targetX,
    lastTargetY: targetY,
    lastTime: performance.now(),
  })
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const resize = () => {
      const dpr = window.devicePixelRatio || 1
      const w = window.innerWidth
      const h = window.innerHeight
      canvas.width = w * dpr
      canvas.height = h * dpr
      canvas.style.width = `${w}px`
      canvas.style.height = `${h}px`
      const ctx = canvas.getContext('2d')
      if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    resize()
    window.addEventListener('resize', resize)

    let raf = 0
    const draw = (now: number) => {
      const ctx = canvas.getContext('2d')
      if (!ctx) return

      const w = window.innerWidth
      const h = window.innerHeight
      const s = stateRef.current
      const dt = Math.max(0.001, (now - s.lastTime) / 1000)
      s.lastTime = now

      const dx = targetX - s.lastTargetX
      const dy = targetY - s.lastTargetY
      s.lastTargetX = targetX
      s.lastTargetY = targetY
      const speed = Math.hypot(dx, dy) / dt
      s.showExhaust = speed > STILL_SPEED_PX_PER_SEC

      s.x += (targetX - s.x) * LERP
      s.y += (targetY - s.y) * LERP

      const moveDx = targetX - s.x
      const moveDy = targetY - s.y
      if (Math.hypot(moveDx, moveDy) > 2) {
        s.angle = Math.atan2(moveDy, moveDx) + Math.PI / 2
      }

      ctx.clearRect(0, 0, w, h)
      ctx.fillStyle = '#0a0a1a'
      ctx.fillRect(0, 0, w, h)

      // Stars
      ctx.fillStyle = 'rgba(255,255,255,0.35)'
      for (let i = 0; i < 40; i++) {
        const sx = ((i * 97) % w) + ((i * 13) % 7)
        const sy = ((i * 53) % h) + ((i * 29) % 11)
        ctx.fillRect(sx, sy, 2, 2)
      }

      ctx.save()
      ctx.translate(s.x, s.y)
      ctx.rotate(s.angle)

      if (s.showExhaust) {
        const flameGrad = ctx.createLinearGradient(0, ROCKET_SIZE * 0.35, 0, ROCKET_SIZE * 0.95)
        flameGrad.addColorStop(0, '#ffeb3b')
        flameGrad.addColorStop(0.5, '#ff9800')
        flameGrad.addColorStop(1, 'rgba(255,87,34,0)')
        ctx.fillStyle = flameGrad
        ctx.beginPath()
        ctx.moveTo(-14, ROCKET_SIZE * 0.4)
        ctx.lineTo(0, ROCKET_SIZE * 0.95)
        ctx.lineTo(14, ROCKET_SIZE * 0.4)
        ctx.closePath()
        ctx.fill()
      }

      // Body
      ctx.fillStyle = '#e0e0e0'
      ctx.beginPath()
      ctx.moveTo(0, -ROCKET_SIZE * 0.45)
      ctx.lineTo(ROCKET_SIZE * 0.22, ROCKET_SIZE * 0.35)
      ctx.lineTo(ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.35)
      ctx.lineTo(ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.42)
      ctx.lineTo(-ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.42)
      ctx.lineTo(-ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.35)
      ctx.lineTo(-ROCKET_SIZE * 0.22, ROCKET_SIZE * 0.35)
      ctx.closePath()
      ctx.fill()

      // Window
      ctx.fillStyle = '#4fc3f7'
      ctx.beginPath()
      ctx.arc(0, -ROCKET_SIZE * 0.08, ROCKET_SIZE * 0.1, 0, Math.PI * 2)
      ctx.fill()

      // Fins
      ctx.fillStyle = '#b71c1c'
      ctx.beginPath()
      ctx.moveTo(-ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.35)
      ctx.lineTo(-ROCKET_SIZE * 0.28, ROCKET_SIZE * 0.5)
      ctx.lineTo(-ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.42)
      ctx.closePath()
      ctx.fill()
      ctx.beginPath()
      ctx.moveTo(ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.35)
      ctx.lineTo(ROCKET_SIZE * 0.28, ROCKET_SIZE * 0.5)
      ctx.lineTo(ROCKET_SIZE * 0.12, ROCKET_SIZE * 0.42)
      ctx.closePath()
      ctx.fill()

      ctx.restore()
      raf = requestAnimationFrame(draw)
    }

    raf = requestAnimationFrame(draw)
    return () => {
      window.removeEventListener('resize', resize)
      cancelAnimationFrame(raf)
    }
  }, [targetX, targetY])

  return <canvas ref={canvasRef} className="game-canvas" aria-hidden />
}
