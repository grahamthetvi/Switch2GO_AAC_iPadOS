import SwiftUI

private let cols = 4
private let rows = 3
private let dwellDuration: TimeInterval = 0.8
private let gridGap: CGFloat = 10
private let padding: CGFloat = 14
private let maxRingRadius: CGFloat = 52
private let minRingRadius: CGFloat = 8

private let blockColors: [Color] = [
    Color(red: 1, green: 0.09, blue: 0.27),
    Color(red: 1, green: 0.92, blue: 0),
    Color(red: 0, green: 0.9, blue: 0.46),
    Color(red: 0.16, green: 0.47, blue: 1),
    Color(red: 0.83, green: 0, blue: 0.98),
    Color(red: 1, green: 0.43, blue: 0),
    Color(red: 0, green: 0.69, blue: 1),
    Color(red: 0.46, green: 1, blue: 0.01),
    Color(red: 0.96, green: 0, blue: 0.34),
    Color(red: 1, green: 0.84, blue: 0),
    Color(red: 0.11, green: 0.91, blue: 0.71),
    Color(red: 0.4, green: 0.12, blue: 1),
]

struct BlocCell: Identifiable {
    let id: Int
    let col: Int
    let row: Int
    let color: Color
    var alive: Bool
}

struct BlocParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var color: Color
    var size: CGFloat
}

struct ConfettiPiece {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var rot: CGFloat
    var vr: CGFloat
    var color: Color
    var w: CGFloat
    var h: CGFloat
}

struct BlocsFrame {
    let blocks: [BlocCell]
    let particles: [BlocParticle]
    let confetti: [ConfettiPiece]
    let dwellProgress: CGFloat
    let showRing: Bool
    let ringAt: CGPoint
    let won: Bool
    let winPulse: CGFloat
    let rewardLabel: String
}

/// Simulation for the Blocs dwell-and-break game.
final class BlocsEngine {
    private var blocks: [BlocCell] = BlocsEngine.makeBlocks()
    private var particles: [BlocParticle] = []
    private var confetti: [ConfettiPiece] = []
    private var dwellBlockId: Int?
    private var dwellElapsed: TimeInterval = 0
    private var won = false
    private var winStartedAt: Date?
    private var lastTick: Date?
    private var rewardText = ""

    func setRewardText(_ text: String) {
        guard text != rewardText else { return }
        rewardText = text
        reset()
    }

    func reset() {
        blocks = Self.makeBlocks()
        particles = []
        confetti = []
        dwellBlockId = nil
        dwellElapsed = 0
        won = false
        winStartedAt = nil
        lastTick = nil
    }

    func frame(at now: Date, target: CGPoint, size: CGSize) -> BlocsFrame {
        let dt: TimeInterval
        if let lastTick {
            dt = min(0.05, max(0.001, now.timeIntervalSince(lastTick)))
        } else {
            dt = 1.0 / 60.0
        }
        self.lastTick = now

        let trimmed = rewardText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rewardLabel = trimmed.isEmpty ? "⭐" : trimmed

        if !won {
            var hovered: Int?
            for block in blocks where block.alive {
                let r = Self.blockRect(col: block.col, row: block.row, size: size)
                if r.contains(target) {
                    hovered = block.id
                    break
                }
            }

            if let hovered, hovered == dwellBlockId {
                dwellElapsed += dt
                if dwellElapsed >= dwellDuration {
                    if let idx = blocks.firstIndex(where: { $0.id == hovered }) {
                        let b = blocks[idx]
                        blocks[idx].alive = false
                        let r = Self.blockRect(col: b.col, row: b.row, size: size)
                        Self.spawnExplosion(particles: &particles, cx: r.midX, cy: r.midY, color: b.color)
                    }
                    dwellBlockId = nil
                    dwellElapsed = 0
                }
            } else if let hovered {
                dwellBlockId = hovered
                dwellElapsed = 0
            } else {
                dwellBlockId = nil
                dwellElapsed = 0
            }
        }

        if blocks.filter(\.alive).count == 0, !won {
            won = true
            winStartedAt = now
            Self.spawnConfetti(pieces: &confetti, width: size.width)
        }

        particles = Self.updateParticles(particles, dt: CGFloat(dt))
        confetti = Self.updateConfetti(confetti, dt: CGFloat(dt), height: size.height, width: size.width)

        let dwellProgress = dwellBlockId != nil ? CGFloat(min(1, dwellElapsed / dwellDuration)) : 0
        let winPulse: CGFloat
        if let winStartedAt {
            winPulse = 0.92 + 0.08 * CGFloat(sin(now.timeIntervalSince(winStartedAt) / 0.28))
        } else {
            winPulse = 1
        }

        return BlocsFrame(
            blocks: blocks,
            particles: particles,
            confetti: confetti,
            dwellProgress: dwellProgress,
            showRing: !won && dwellBlockId != nil,
            ringAt: target,
            won: won,
            winPulse: winPulse,
            rewardLabel: rewardLabel
        )
    }

    private static func makeBlocks() -> [BlocCell] {
        (0..<(cols * rows)).map { i in
            BlocCell(
                id: i,
                col: i % cols,
                row: i / cols,
                color: blockColors[i % blockColors.count],
                alive: true
            )
        }
    }

    static func blockRect(col: Int, row: Int, size: CGSize) -> CGRect {
        let gridW = size.width - padding * 2
        let gridH = size.height - padding * 2
        let cellW = (gridW - gridGap * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (gridH - gridGap * CGFloat(rows - 1)) / CGFloat(rows)
        return CGRect(
            x: padding + CGFloat(col) * (cellW + gridGap),
            y: padding + CGFloat(row) * (cellH + gridGap),
            width: cellW,
            height: cellH
        )
    }

    private static func spawnExplosion(particles: inout [BlocParticle], cx: CGFloat, cy: CGFloat, color: Color) {
        for i in 0..<36 {
            let angle = (CGFloat.pi * 2 * CGFloat(i)) / 36 + CGFloat.random(in: -0.2...0.2)
            let speed = CGFloat.random(in: 120...340)
            particles.append(BlocParticle(
                x: cx,
                y: cy,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                life: 1,
                maxLife: CGFloat.random(in: 0.55...0.9),
                color: color,
                size: CGFloat.random(in: 4...12)
            ))
        }
    }

    private static func spawnConfetti(pieces: inout [ConfettiPiece], width: CGFloat) {
        for i in 0..<120 {
            pieces.append(ConfettiPiece(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: -220 ... -20),
                vx: CGFloat.random(in: -90...90),
                vy: CGFloat.random(in: 80...300),
                rot: CGFloat.random(in: 0...(CGFloat.pi * 2)),
                vr: CGFloat.random(in: -4...4),
                color: blockColors[i % blockColors.count],
                w: CGFloat.random(in: 8...18),
                h: CGFloat.random(in: 5...13)
            ))
        }
    }

    private static func updateParticles(_ particles: [BlocParticle], dt: CGFloat) -> [BlocParticle] {
        particles.compactMap { p in
            var q = p
            q.life -= dt / q.maxLife
            guard q.life > 0 else { return nil }
            q.x += q.vx * dt
            q.y += q.vy * dt
            q.vy += 420 * dt
            q.vx *= 1 - dt * 1.2
            return q
        }
    }

    private static func updateConfetti(
        _ pieces: [ConfettiPiece],
        dt: CGFloat,
        height: CGFloat,
        width: CGFloat
    ) -> [ConfettiPiece] {
        pieces.map { c in
            var q = c
            q.x += q.vx * dt
            q.y += q.vy * dt
            q.vy += 280 * dt
            q.rot += q.vr * dt
            if q.y > height + 40 {
                q.y = -30
                q.x = CGFloat.random(in: 0...width)
            }
            return q
        }
    }
}

/// Eye-gaze training: dwell on colored blocks to break them and reveal the phrase reward.
struct BlocsGameView: View {
    let target: CGPoint
    let rewardText: String

    @State private var engine = BlocsEngine()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let frame = engine.frame(at: timeline.date, target: target, size: geo.size)

                Canvas { context, size in
                    drawScene(context: &context, size: size, frame: frame)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            engine.setRewardText(rewardText)
        }
        .onChange(of: rewardText) { _, newValue in
            engine.setRewardText(newValue)
        }
    }

    private func drawScene(context: inout GraphicsContext, size: CGSize, frame: BlocsFrame) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

        let rewardSize = min(size.width, size.height) * 0.14
        context.draw(
            Text(frame.rewardLabel)
                .font(.system(size: rewardSize, weight: .bold))
                .foregroundColor(.white),
            at: CGPoint(x: size.width / 2, y: size.height / 2),
            anchor: .center
        )

        for block in frame.blocks where block.alive {
            let r = BlocsEngine.blockRect(col: block.col, row: block.row, size: size)
            context.fill(Path(r), with: .color(block.color))
            context.stroke(Path(r.insetBy(dx: 1.5, dy: 1.5)), with: .color(.black.opacity(0.35)), lineWidth: 3)
        }

        if frame.showRing {
            let radius = minRingRadius + (maxRingRadius - minRingRadius) * frame.dwellProgress
            var track = Path()
            track.addEllipse(in: CGRect(
                x: frame.ringAt.x - radius,
                y: frame.ringAt.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(track, with: .color(.white.opacity(0.25)), lineWidth: 6)

            var arc = Path()
            arc.addArc(
                center: frame.ringAt,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * Double(frame.dwellProgress)),
                clockwise: false
            )
            context.stroke(arc, with: .color(.white), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        }

        for p in frame.particles {
            let r = CGRect(
                x: p.x - p.size * p.life,
                y: p.y - p.size * p.life,
                width: p.size * p.life * 2,
                height: p.size * p.life * 2
            )
            context.fill(Path(ellipseIn: r), with: .color(p.color.opacity(Double(p.life))))
        }

        if frame.won {
            for c in frame.confetti {
                var pieceContext = context
                pieceContext.concatenate(
                    CGAffineTransform(translationX: c.x, y: c.y).rotated(by: c.rot)
                )
                pieceContext.fill(
                    Path(CGRect(x: -c.w / 2, y: -c.h / 2, width: c.w, height: c.h)),
                    with: .color(c.color)
                )
            }

            let titleSize = min(size.width, size.height) * 0.12 * frame.winPulse
            context.draw(
                Text("Great Job!")
                    .font(.system(size: titleSize, weight: .black))
                    .foregroundColor(Color(red: 1, green: 0.92, blue: 0)),
                at: CGPoint(x: size.width / 2, y: size.height * 0.38),
                anchor: .center
            )
            context.draw(
                Text(frame.rewardLabel)
                    .font(.system(size: rewardSize * 1.1, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: size.width / 2, y: size.height * 0.58),
                anchor: .center
            )
        }
    }
}
