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
  allowedButtonIds: Set<string> | null = null

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
  private readonly exitMargin = 35
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
    if (!this.isButtonAllowed(id)) {
      if (this.buttonFrames.has(id)) this.unregisterButton(id)
      return
    }
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

  setAllowedButtonIds(ids: Set<string> | null): void {
    this.allowedButtonIds = ids
    if (ids) {
      for (const id of [...this.buttonFrames.keys()]) {
        if (!ids.has(id)) this.unregisterButton(id)
      }
    }
    if (this.hoveredButtonId && !this.isButtonAllowed(this.hoveredButtonId)) {
      this.clearHover()
    }
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
    if (this.hoveredButtonId && this.isButtonAllowed(this.hoveredButtonId)) {
      this.activate(this.hoveredButtonId)
    }
  }

  private isButtonAllowed(id: string): boolean {
    if (!this.allowedButtonIds) return true
    return this.allowedButtonIds.has(id)
  }

  private contains(frame: DOMRect, point: Point, pad = 0): boolean {
    return (
      point.x >= frame.x - pad &&
      point.x <= frame.x + frame.width + pad &&
      point.y >= frame.y - pad &&
      point.y <= frame.y + frame.height + pad
    )
  }

  private nearestId(
    hits: { id: string; frame: DOMRect }[],
    point: Point,
  ): string | null {
    if (hits.length === 0) return null
    let best = hits[0]
    let bestDist = Number.POSITIVE_INFINITY
    for (const hit of hits) {
      const cx = hit.frame.x + hit.frame.width / 2
      const cy = hit.frame.y + hit.frame.height / 2
      const d = (point.x - cx) ** 2 + (point.y - cy) ** 2
      if (d < bestDist) {
        bestDist = d
        best = hit
      }
    }
    return best.id
  }

  /** Unpadded containment wins so the left tile cannot steal the right-hand choice. */
  private hitTest(point: Point): string | null {
    const unpadded: { id: string; frame: DOMRect }[] = []
    const padded: { id: string; frame: DOMRect }[] = []

    for (const id of this.orderedButtonIds) {
      if (!this.isButtonAllowed(id)) continue
      const frame = this.buttonFrames.get(id)
      if (!frame) continue
      if (this.contains(frame, point)) {
        unpadded.push({ id, frame })
      } else if (this.contains(frame, point, this.hitTestPadding)) {
        padded.push({ id, frame })
      }
    }

    const unpaddedId = this.nearestId(unpadded, point)
    if (unpaddedId) return unpaddedId

    if (this.hoveredButtonId && this.isButtonAllowed(this.hoveredButtonId)) {
      const current = this.buttonFrames.get(this.hoveredButtonId)
      if (current && this.contains(current, point, this.exitMargin)) {
        return this.hoveredButtonId
      }
    }

    return this.nearestId(padded, point)
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
    const repeat = this.getRepeatSettings()
    if (this.activatedWhileHovering && !repeat.enabled) {
      if (this.dwellProgress !== 1) {
        this.dwellProgress = 1
        this.emitProgress()
      }
      this.stopDwellAnimation()
      return
    }

    const elapsed = performance.now() - this.dwellStartTime
    const dwellMs = this.getDwellTimeMs()
    this.dwellProgress = Math.min(1, elapsed / dwellMs)
    this.emitProgress()
    if (elapsed >= dwellMs) {
      const now = performance.now()
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
