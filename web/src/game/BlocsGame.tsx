import { useEffect, useRef } from 'react'

const COLS = 4
const ROWS = 3
const DWELL_SEC = 0.8
const GRID_GAP = 10
const PADDING = 14
const MAX_RING_RADIUS = 52
const MIN_RING_RADIUS = 8

const BLOCK_COLORS = [
  '#FF1744',
  '#FFEA00',
  '#00E676',
  '#2979FF',
  '#D500F9',
  '#FF6D00',
  '#00B0FF',
  '#76FF03',
  '#F50057',
  '#FFD600',
  '#1DE9B6',
  '#651FFF',
]

type Block = {
  col: number
  row: number
  color: string
  alive: boolean
}

type Particle = {
  x: number
  y: number
  vx: number
  vy: number
  life: number
  maxLife: number
  color: string
  size: number
}

type ConfettiPiece = {
  x: number
  y: number
  vx: number
  vy: number
  rot: number
  vr: number
  color: string
  w: number
  h: number
}

type Props = {
  targetX: number
  targetY: number
  rewardText: string
}

function blockIndex(col: number, row: number): number {
  return row * COLS + col
}

function makeBlocks(): Block[] {
  const blocks: Block[] = []
  for (let row = 0; row < ROWS; row++) {
    for (let col = 0; col < COLS; col++) {
      blocks.push({
        col,
        row,
        color: BLOCK_COLORS[blockIndex(col, row)]!,
        alive: true,
      })
    }
  }
  return blocks
}

function spawnExplosion(
  particles: Particle[],
  cx: number,
  cy: number,
  color: string,
  count = 36,
) {
  for (let i = 0; i < count; i++) {
    const angle = (Math.PI * 2 * i) / count + Math.random() * 0.4
    const speed = 120 + Math.random() * 220
    particles.push({
      x: cx,
      y: cy,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1,
      maxLife: 0.55 + Math.random() * 0.35,
      color,
      size: 4 + Math.random() * 8,
    })
  }
}

function spawnConfetti(pieces: ConfettiPiece[], w: number) {
  for (let i = 0; i < 120; i++) {
    pieces.push({
      x: Math.random() * w,
      y: -20 - Math.random() * 200,
      vx: (Math.random() - 0.5) * 180,
      vy: 80 + Math.random() * 220,
      rot: Math.random() * Math.PI * 2,
      vr: (Math.random() - 0.5) * 8,
      color: BLOCK_COLORS[i % BLOCK_COLORS.length]!,
      w: 8 + Math.random() * 10,
      h: 5 + Math.random() * 8,
    })
  }
}

/** Eye-gaze training: dwell on blocks to break them and reveal the phrase reward. */
export function BlocsGame({ targetX, targetY, rewardText }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const stateRef = useRef({
    blocks: makeBlocks(),
    particles: [] as Particle[],
    confetti: [] as ConfettiPiece[],
    dwellBlock: -1,
    dwellElapsed: 0,
    won: false,
    winStartedAt: 0,
    lastTime: performance.now(),
  })

  useEffect(() => {
    stateRef.current.blocks = makeBlocks()
    stateRef.current.particles = []
    stateRef.current.confetti = []
    stateRef.current.dwellBlock = -1
    stateRef.current.dwellElapsed = 0
    stateRef.current.won = false
    stateRef.current.winStartedAt = 0
  }, [rewardText])

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

      const gridW = w - PADDING * 2
      const gridH = h - PADDING * 2
      const cellW = (gridW - GRID_GAP * (COLS - 1)) / COLS
      const cellH = (gridH - GRID_GAP * (ROWS - 1)) / ROWS

      const blockRect = (col: number, row: number) => ({
        x: PADDING + col * (cellW + GRID_GAP),
        y: PADDING + row * (cellH + GRID_GAP),
        w: cellW,
        h: cellH,
      })

      const aliveCount = s.blocks.filter((b) => b.alive).length
      if (aliveCount === 0 && !s.won) {
        s.won = true
        s.winStartedAt = now
        spawnConfetti(s.confetti, w)
      }

      if (!s.won) {
        let hovered = -1
        for (let i = 0; i < s.blocks.length; i++) {
          const b = s.blocks[i]!
          if (!b.alive) continue
          const r = blockRect(b.col, b.row)
          if (
            targetX >= r.x &&
            targetX <= r.x + r.w &&
            targetY >= r.y &&
            targetY <= r.y + r.h
          ) {
            hovered = i
            break
          }
        }

        if (hovered === s.dwellBlock && hovered >= 0) {
          s.dwellElapsed += dt
          if (s.dwellElapsed >= DWELL_SEC) {
            const block = s.blocks[hovered]!
            block.alive = false
            const r = blockRect(block.col, block.row)
            spawnExplosion(
              s.particles,
              r.x + r.w / 2,
              r.y + r.h / 2,
              block.color,
            )
            s.dwellBlock = -1
            s.dwellElapsed = 0
          }
        } else if (hovered >= 0) {
          s.dwellBlock = hovered
          s.dwellElapsed = 0
        } else {
          s.dwellBlock = -1
          s.dwellElapsed = 0
        }
      }

      for (let i = s.particles.length - 1; i >= 0; i--) {
        const p = s.particles[i]!
        p.life -= dt / p.maxLife
        if (p.life <= 0) {
          s.particles.splice(i, 1)
          continue
        }
        p.x += p.vx * dt
        p.y += p.vy * dt
        p.vy += 420 * dt
        p.vx *= 1 - dt * 1.2
      }

      for (const c of s.confetti) {
        c.x += c.vx * dt
        c.y += c.vy * dt
        c.vy += 280 * dt
        c.rot += c.vr * dt
        if (c.y > h + 40) {
          c.y = -30
          c.x = Math.random() * w
        }
      }

      ctx.fillStyle = '#000000'
      ctx.fillRect(0, 0, w, h)

      const rewardSize = Math.min(w, h) * 0.14
      ctx.fillStyle = '#ffffff'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.font = `bold ${rewardSize}px system-ui, -apple-system, sans-serif`
      const displayReward = rewardText.trim() || '⭐'
      ctx.fillText(displayReward, w / 2, h / 2)

      for (const b of s.blocks) {
        if (!b.alive) continue
        const r = blockRect(b.col, b.row)
        ctx.fillStyle = b.color
        ctx.fillRect(r.x, r.y, r.w, r.h)
        ctx.strokeStyle = 'rgba(0,0,0,0.35)'
        ctx.lineWidth = 3
        ctx.strokeRect(r.x + 1.5, r.y + 1.5, r.w - 3, r.h - 3)
      }

      if (!s.won && s.dwellBlock >= 0) {
        const progress = Math.min(1, s.dwellElapsed / DWELL_SEC)
        const radius = MIN_RING_RADIUS + (MAX_RING_RADIUS - MIN_RING_RADIUS) * progress
        ctx.save()
        ctx.translate(targetX, targetY)
        ctx.beginPath()
        ctx.arc(0, 0, radius, 0, Math.PI * 2)
        ctx.strokeStyle = 'rgba(255,255,255,0.25)'
        ctx.lineWidth = 6
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(0, 0, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress)
        ctx.strokeStyle = '#ffffff'
        ctx.lineWidth = 8
        ctx.lineCap = 'round'
        ctx.stroke()
        ctx.restore()
      }

      for (const p of s.particles) {
        ctx.globalAlpha = Math.max(0, p.life)
        ctx.fillStyle = p.color
        ctx.beginPath()
        ctx.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2)
        ctx.fill()
      }
      ctx.globalAlpha = 1

      if (s.won) {
        for (const c of s.confetti) {
          ctx.save()
          ctx.translate(c.x, c.y)
          ctx.rotate(c.rot)
          ctx.fillStyle = c.color
          ctx.fillRect(-c.w / 2, -c.h / 2, c.w, c.h)
          ctx.restore()
        }

        const pulse = 0.92 + 0.08 * Math.sin((now - s.winStartedAt) / 280)
        const titleSize = Math.min(w, h) * 0.12 * pulse
        ctx.fillStyle = '#FFEA00'
        ctx.strokeStyle = '#000000'
        ctx.lineWidth = Math.max(4, titleSize * 0.06)
        ctx.font = `900 ${titleSize}px system-ui, -apple-system, sans-serif`
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.strokeText('Great Job!', w / 2, h * 0.38)
        ctx.fillText('Great Job!', w / 2, h * 0.38)

        ctx.fillStyle = '#ffffff'
        ctx.font = `bold ${rewardSize * 1.1}px system-ui, -apple-system, sans-serif`
        ctx.fillText(displayReward, w / 2, h * 0.58)
      }

      raf = requestAnimationFrame(draw)
    }

    raf = requestAnimationFrame(draw)
    return () => {
      window.removeEventListener('resize', resize)
      cancelAnimationFrame(raf)
    }
  }, [targetX, targetY, rewardText])

  return <canvas ref={canvasRef} className="game-canvas" aria-hidden />
}
