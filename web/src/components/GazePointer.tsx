interface Props {
  x: number
  y: number
  dwellProgress: number
}

const RING_SIZE = 64
const RING_RADIUS = 28
const CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS

export function GazePointer({ x, y, dwellProgress }: Props) {
  const showRing = dwellProgress > 0
  const dashOffset = CIRCUMFERENCE * (1 - dwellProgress)

  return (
    <div className="gaze-pointer-wrap" style={{ left: x, top: y }} aria-hidden>
      {showRing ? (
        <svg
          className="gaze-dwell-ring"
          width={RING_SIZE}
          height={RING_SIZE}
          viewBox={`0 0 ${RING_SIZE} ${RING_SIZE}`}
        >
          <circle
            className="gaze-dwell-ring-track"
            cx={RING_SIZE / 2}
            cy={RING_SIZE / 2}
            r={RING_RADIUS}
          />
          <circle
            className="gaze-dwell-ring-progress"
            cx={RING_SIZE / 2}
            cy={RING_SIZE / 2}
            r={RING_RADIUS}
            strokeDasharray={CIRCUMFERENCE}
            strokeDashoffset={dashOffset}
          />
        </svg>
      ) : null}
      <div className="gaze-pointer" />
    </div>
  )
}
