export type DwellListener = (buttonId: string) => void
export type DwellProgressListener = (progress: number, hoveredButtonId: string | null) => void

export interface Point {
  x: number
  y: number
}

export class DwellSelectionManager {
  hoveredButtonId: string | null = null
  dwellProgress = 0
  isEnabled = true

  private buttonFrames = new Map<string, DOMRect>()
  private orderedButtonIds: string[] = []
  private dwellStartTime: number | null = null
  private lastActivationTime = 0
  private activatedWhileHovering = false
  private exitGraceTimer: ReturnType<typeof setTimeout> | null = null
  private animationFrame: number | null = null
  private listeners = new Set<DwellListener>()
  private progressListeners = new Set<DwellProgressListener>()

  private readonly hitTestPadding = 16
  private readonly exitGracePeriod = 250
  private readonly activationCooldown = 500

  constructor(
    private getDwellTimeMs: () => number,
    private getRepeatSettings: () => { enabled: boolean; delayMs: number },
  ) {}

  subscribe(listener: DwellListener): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  subscribeProgress(listener: DwellProgressListener): () => void {
    this.progressListeners.add(listener)
    listener(this.dwellProgress, this.hoveredButtonId)
    return () => this.progressListeners.delete(listener)
  }

  registerButton(id: string, frame: DOMRect): void {
    if (frame.width <= 1 || frame.height <= 1) return
    const isNew = !this.buttonFrames.has(id)
    this.buttonFrames.set(id, frame)
    if (isNew) this.orderedButtonIds.push(id)
  }

  unregisterButton(id: string): void {
    this.buttonFrames.delete(id)
    this.orderedButtonIds = this.orderedButtonIds.filter((x) => x !== id)
    if (this.hoveredButtonId === id) this.clearHover()
  }

  clearAllButtons(): void {
    this.buttonFrames.clear()
    this.orderedButtonIds = []
    this.clearHover()
  }

  updateGazePosition(point: Point | null): void {
    if (!this.isEnabled || !point) {
      this.scheduleExitGrace()
      return
    }
    const hitId = this.hitTest(point)
    if (hitId) {
      if (this.exitGraceTimer) {
        clearTimeout(this.exitGraceTimer)
        this.exitGraceTimer = null
      }
      if (hitId !== this.hoveredButtonId) {
        this.hoveredButtonId = hitId
        this.dwellStartTime = performance.now()
        this.dwellProgress = 0
        this.activatedWhileHovering = false
        this.lastActivationTime = 0
        this.emitProgress()
      }
      this.tickDwell()
    } else {
      this.scheduleExitGrace()
    }
  }

  activateHoveredButton(): void {
    if (this.hoveredButtonId) this.activate(this.hoveredButtonId)
  }

  private hitTest(point: Point): string | null {
    for (const id of this.orderedButtonIds) {
      const frame = this.buttonFrames.get(id)
      if (!frame) continue
      const padded = new DOMRect(
        frame.x - this.hitTestPadding,
        frame.y - this.hitTestPadding,
        frame.width + this.hitTestPadding * 2,
        frame.height + this.hitTestPadding * 2,
      )
      if (
        point.x >= padded.left &&
        point.x <= padded.right &&
        point.y >= padded.top &&
        point.y <= padded.bottom
      ) {
        return id
      }
    }
    return null
  }

  private scheduleExitGrace(): void {
    if (this.exitGraceTimer || !this.hoveredButtonId) return
    this.exitGraceTimer = setTimeout(() => this.clearHover(), this.exitGracePeriod)
  }

  private clearHover(): void {
    if (this.exitGraceTimer) {
      clearTimeout(this.exitGraceTimer)
      this.exitGraceTimer = null
    }
    this.hoveredButtonId = null
    this.dwellStartTime = null
    this.dwellProgress = 0
    this.activatedWhileHovering = false
    this.lastActivationTime = 0
    this.stopDwellAnimation()
    this.emitProgress()
  }

  private emitProgress(): void {
    for (const listener of this.progressListeners) {
      listener(this.dwellProgress, this.hoveredButtonId)
    }
  }

  private stopDwellAnimation(): void {
    if (this.animationFrame != null) {
      cancelAnimationFrame(this.animationFrame)
      this.animationFrame = null
    }
  }

  private scheduleDwellAnimation(): void {
    if (this.animationFrame != null) return
    this.animationFrame = requestAnimationFrame(() => {
      this.animationFrame = null
      if (this.hoveredButtonId && this.dwellStartTime != null) {
        this.tickDwell()
      }
    })
  }

  private tickDwell(): void {
    if (!this.hoveredButtonId || this.dwellStartTime == null) return
    const elapsed = performance.now() - this.dwellStartTime
    const dwellMs = this.getDwellTimeMs()
    this.dwellProgress = Math.min(1, elapsed / dwellMs)
    this.emitProgress()
    if (elapsed >= dwellMs) {
      const now = performance.now()
      const repeat = this.getRepeatSettings()
      const minGap = this.activatedWhileHovering && repeat.enabled
        ? repeat.delayMs
        : this.activationCooldown
      const canActivate =
        !this.activatedWhileHovering || (repeat.enabled && now - this.lastActivationTime >= minGap)
      if (canActivate && now - this.lastActivationTime >= minGap) {
        this.activate(this.hoveredButtonId)
        this.lastActivationTime = now
        this.activatedWhileHovering = true
        this.dwellStartTime = performance.now()
        this.dwellProgress = 0
        this.emitProgress()
      }
    }
    this.scheduleDwellAnimation()
  }

  private activate(id: string): void {
    for (const listener of this.listeners) listener(id)
  }
}
