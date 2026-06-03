import { useEffect, useRef } from 'react'

const DWELL_SEC = 0.6
const SPLAT_ANIM_SEC = 0.45
const RESPAWN_PAUSE_SEC = 0.55

const SLOTS = ['center', 'topLeft', 'topRight', 'bottomLeft', 'bottomRight'] as const
type Slot = (typeof SLOTS)[number]

type Phase = 'ready' | 'splat' | 'pause'

type Props = {
  targetX: number
  targetY: number
}

function targetRadius(w: number, h: number): number {
  return Math.min(w, h) * 0.2
}

function slotCenter(slot: Slot, w: number, h: number, r: number): { x: number; y: number } {
  const pad = r + Math.min(w, h) * 0.06
  const cx = w / 2
  const cy = h / 2
  switch (slot) {
    case 'center':
      return { x: cx, y: cy }
    case 'topLeft':
      return { x: pad, y: pad }
    case 'topRight':
      return { x: w - pad, y: pad }
    case 'bottomLeft':
      return { x: pad, y: h - pad }
    case 'bottomRight':
      return { x: w - pad, y: h - pad }
  }
}

function pickRandomSlot(exclude?: Slot): Slot {
  const pool = exclude ? SLOTS.filter((s) => s !== exclude) : [...SLOTS]
  return pool[Math.floor(Math.random() * pool.length)]!
}

function hitTarget(tx: number, ty: number, gx: number, gy: number, r: number): boolean {
  const dx = gx - tx
  const dy = gy - ty
  return dx * dx + dy * dy <= r * r
}

function drawBullseye(ctx: CanvasRenderingContext2D, x: number, y: number, r: number) {
  const rings: { frac: number; fill: string; stroke?: string }[] = [
    { frac: 1, fill: '#ffffff', stroke: '#000000' },
    { frac: 0.72, fill: '#ff1744' },
    { frac: 0.48, fill: '#ffffff', stroke: '#000000' },
    { frac: 0.26, fill: '#ff1744' },
    { frac: 0.1, fill: '#000000' },
  ]
  for (const ring of rings) {
    const rad = r * ring.frac
    ctx.beginPath()
    ctx.arc(x, y, rad, 0, Math.PI * 2)
    ctx.fillStyle = ring.fill
    ctx.fill()
    if (ring.stroke) {
      ctx.strokeStyle = ring.stroke
      ctx.lineWidth = Math.max(4, r * 0.04)
      ctx.stroke()
    }
  }
}

function drawPieCharge(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  scale: number,
) {
  const s = scale
  ctx.save()
  ctx.translate(x, y)
  ctx.scale(s, s)

  ctx.fillStyle = '#8d6e63'
  ctx.beginPath()
  ctx.ellipse(0, 8, 42, 14, 0, 0, Math.PI * 2)
  ctx.fill()

  ctx.fillStyle = '#fff8e1'
  ctx.strokeStyle = '#5d4037'
  ctx.lineWidth = 3
  ctx.beginPath()
  ctx.moveTo(-38, 6)
  ctx.quadraticCurveTo(0, -48, 38, 6)
  ctx.quadraticCurveTo(0, 18, -38, 6)
  ctx.closePath()
  ctx.fill()
  ctx.stroke()

  ctx.fillStyle = '#ffffff'
  ctx.beginPath()
  ctx.arc(0, -8, 10, 0, Math.PI * 2)
  ctx.fill()

  ctx.restore()
}

function drawSplat(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  r: number,
  t: number,
) {
  const spread = 0.35 + t * 0.65
  const flatR = r * (1.1 + t * 0.35)

  ctx.save()
  ctx.translate(x, y)
  ctx.scale(1, 0.55 + t * 0.15)

  ctx.fillStyle = '#fff8e1'
  ctx.strokeStyle = '#5d4037'
  ctx.lineWidth = Math.max(3, r * 0.05)
  ctx.beginPath()
  ctx.ellipse(0, 0, flatR, flatR * 0.55, 0, 0, Math.PI * 2)
  ctx.fill()
  ctx.stroke()

  ctx.fillStyle = '#8d6e63'
  ctx.beginPath()
  ctx.ellipse(0, flatR * 0.35, flatR * 0.85, flatR * 0.2, 0, 0, Math.PI * 2)
  ctx.fill()
  ctx.restore()

  const splats = 14
  for (let i = 0; i < splats; i++) {
    const angle = (Math.PI * 2 * i) / splats + 0.2
    const dist = r * spread * (0.85 + (i % 3) * 0.12)
    const blobR = r * (0.12 + (i % 4) * 0.04) * (0.6 + t * 0.5)
    const bx = x + Math.cos(angle) * dist
    const by = y + Math.sin(angle) * dist
    ctx.fillStyle = i % 2 === 0 ? '#ffffff' : '#fff8e1'
    ctx.beginPath()
    ctx.ellipse(bx, by, blobR * 1.3, blobR, angle, 0, Math.PI * 2)
    ctx.fill()
  }
}

let sharedAudioCtx: AudioContext | null = null

function playSplatSound() {
  try {
    const ctx = sharedAudioCtx ?? new AudioContext()
    sharedAudioCtx = ctx
    if (ctx.state === 'suspended') void ctx.resume()

    const now = ctx.currentTime
    const duration = 0.18
    const sampleCount = Math.floor(ctx.sampleRate * duration)
    const buffer = ctx.createBuffer(1, sampleCount, ctx.sampleRate)
    const data = buffer.getChannelData(0)
    for (let i = 0; i < sampleCount; i++) {
      const env = Math.exp(-i / sampleCount * 10)
      data[i] = (Math.random() * 2 - 1) * env
    }
    const noise = ctx.createBufferSource()
    noise.buffer = buffer
    const noiseFilter = ctx.createBiquadFilter()
    noiseFilter.type = 'bandpass'
    noiseFilter.frequency.value = 900
    const noiseGain = ctx.createGain()
    noiseGain.gain.setValueAtTime(0.55, now)
    noiseGain.gain.exponentialRampToValueAtTime(0.001, now + duration)
    noise.connect(noiseFilter)
    noiseFilter.connect(noiseGain)
    noiseGain.connect(ctx.destination)
    noise.start(now)
    noise.stop(now + duration + 0.05)

    const osc = ctx.createOscillator()
    osc.type = 'triangle'
    osc.frequency.setValueAtTime(320, now)
    osc.frequency.exponentialRampToValueAtTime(80, now + 0.28)
    const oscGain = ctx.createGain()
    oscGain.gain.setValueAtTime(0.4, now)
    oscGain.gain.exponentialRampToValueAtTime(0.001, now + 0.32)
    osc.connect(oscGain)
    oscGain.connect(ctx.destination)
    osc.start(now)
    osc.stop(now + 0.35)
  } catch {
    /* Web Audio unavailable */
  }
}

/** Eye-gaze practice: dwell on bullseye targets to splat pies. */
export function PieCrazyGame({ targetX, targetY }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stateRef = useRef({
    slot: pickRandomSlot() as Slot,
    phase: 'ready' as Phase,
    dwellElapsed: 0,
    splatStartedAt: 0,
    pauseStartedAt: 0,
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
      const dt = Math.min(0.05, Math.max(0.001, (now - s.lastTime) / 1000))
      s.lastTime = now

      const r = targetRadius(w, h)
      const center = slotCenter(s.slot, w, h, r)

      if (s.phase === 'ready') {
        const hovering = hitTarget(center.x, center.y, targetX, targetY, r)
        if (hovering) {
          s.dwellElapsed += dt
          if (s.dwellElapsed >= DWELL_SEC) {
            playSplatSound()
            s.phase = 'splat'
            s.splatStartedAt = now
            s.dwellElapsed = 0
          }
        } else {
          s.dwellElapsed = 0
        }
      } else if (s.phase === 'splat') {
        if ((now - s.splatStartedAt) / 1000 >= SPLAT_ANIM_SEC) {
          s.phase = 'pause'
          s.pauseStartedAt = now
        }
      } else if (s.phase === 'pause') {
        if ((now - s.pauseStartedAt) / 1000 >= RESPAWN_PAUSE_SEC) {
          s.slot = pickRandomSlot(s.slot)
          s.phase = 'ready'
          s.dwellElapsed = 0
        }
      }

      const dwellProgress =
        s.phase === 'ready' ? Math.min(1, s.dwellElapsed / DWELL_SEC) : 0
      const splatT =
        s.phase === 'splat'
          ? Math.min(1, (now - s.splatStartedAt) / 1000 / SPLAT_ANIM_SEC)
          : s.phase === 'pause'
            ? 1
            : 0

      ctx.fillStyle = '#000000'
      ctx.fillRect(0, 0, w, h)

      if (s.phase === 'ready') {
        drawBullseye(ctx, center.x, center.y, r)
        if (dwellProgress > 0) {
          const chargeScale = 0.35 + dwellProgress * 0.95
          drawPieCharge(ctx, targetX, targetY, chargeScale)
          ctx.save()
          ctx.translate(targetX, targetY)
          ctx.beginPath()
          ctx.arc(0, 0, 18 + dwellProgress * 40, 0, Math.PI * 2)
          ctx.strokeStyle = 'rgba(255,255,255,0.35)'
          ctx.lineWidth = 5
          ctx.stroke()
          ctx.beginPath()
          ctx.arc(0, 0, 18 + dwellProgress * 40, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * dwellProgress)
          ctx.strokeStyle = '#ffffff'
          ctx.lineWidth = 7
          ctx.lineCap = 'round'
          ctx.stroke()
          ctx.restore()
        }
      } else {
        drawSplat(ctx, center.x, center.y, r, splatT)
      }

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
