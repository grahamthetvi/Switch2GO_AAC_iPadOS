import SwiftUI
import AVFoundation

private let dwellDuration: TimeInterval = 0.6
private let splatAnimDuration: TimeInterval = 0.45
private let respawnPauseDuration: TimeInterval = 0.55

private enum TargetSlot: CaseIterable {
    case center, topLeft, topRight, bottomLeft, bottomRight
}

private enum PiePhase {
    case ready, splat, pause
}

private struct PieCrazyFrame {
    let slot: TargetSlot
    let phase: PiePhase
    let targetCenter: CGPoint
    let targetRadius: CGFloat
    let dwellProgress: CGFloat
    let splatProgress: CGFloat
    let showCharge: Bool
}

/// Synthesized splat reward (mirrors web Web Audio splat).
private enum PieCrazySound {
    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?

    static func playSplat() {
        let sampleRate = 44100.0
        let duration = 0.32
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-t * 12)
            let noise = Float.random(in: -1...1) * Float(env) * 0.55
            let tone = Float(sin(2 * .pi * (320 - 240 * t) * t)) * Float(env) * 0.35
            channel[i] = noise + tone
        }

        let eng = engine ?? AVAudioEngine()
        let node = player ?? AVAudioPlayerNode()
        if engine == nil {
            engine = eng
            player = node
            eng.attach(node)
            eng.connect(node, to: eng.mainMixerNode, format: format)
            try? eng.start()
        }
        node.scheduleBuffer(buffer, at: nil, options: [])
        if !node.isPlaying { node.play() }
    }
}

/// Eye-gaze practice: dwell on bullseye targets to splat cream pies.
fileprivate final class PieCrazyEngine {
    private var slot: TargetSlot = TargetSlot.allCases.randomElement()!
    private var phase: PiePhase = .ready
    private var dwellElapsed: TimeInterval = 0
    private var splatStartedAt: Date?
    private var pauseStartedAt: Date?
    private var lastTick: Date?

    func frame(at now: Date, gaze: CGPoint, size: CGSize) -> PieCrazyFrame {
        let dt: TimeInterval
        if let lastTick {
            dt = min(0.05, max(0.001, now.timeIntervalSince(lastTick)))
        } else {
            dt = 1.0 / 60.0
        }
        self.lastTick = now

        let r = Self.targetRadius(size: size)
        let center = Self.slotCenter(slot, size: size, radius: r)

        switch phase {
        case .ready:
            if Self.hitTarget(center: center, radius: r, gaze: gaze) {
                dwellElapsed += dt
                if dwellElapsed >= dwellDuration {
                    PieCrazySound.playSplat()
                    phase = .splat
                    splatStartedAt = now
                    dwellElapsed = 0
                }
            } else {
                dwellElapsed = 0
            }
        case .splat:
            if let splatStartedAt, now.timeIntervalSince(splatStartedAt) >= splatAnimDuration {
                phase = .pause
                pauseStartedAt = now
            }
        case .pause:
            if let pauseStartedAt, now.timeIntervalSince(pauseStartedAt) >= respawnPauseDuration {
                slot = Self.pickRandomSlot(excluding: slot)
                phase = .ready
                dwellElapsed = 0
                splatStartedAt = nil
                self.pauseStartedAt = nil
            }
        }

        let dwellProgress = phase == .ready ? CGFloat(min(1, dwellElapsed / dwellDuration)) : 0
        let splatProgress: CGFloat
        if phase == .splat, let splatStartedAt {
            splatProgress = CGFloat(min(1, now.timeIntervalSince(splatStartedAt) / splatAnimDuration))
        } else if phase == .pause {
            splatProgress = 1
        } else {
            splatProgress = 0
        }

        return PieCrazyFrame(
            slot: slot,
            phase: phase,
            targetCenter: center,
            targetRadius: r,
            dwellProgress: dwellProgress,
            splatProgress: splatProgress,
            showCharge: phase == .ready && dwellProgress > 0
        )
    }

    private static func targetRadius(size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.2
    }

    private static func slotCenter(_ slot: TargetSlot, size: CGSize, radius: CGFloat) -> CGPoint {
        let pad = radius + min(size.width, size.height) * 0.06
        let cx = size.width / 2
        let cy = size.height / 2
        switch slot {
        case .center: return CGPoint(x: cx, y: cy)
        case .topLeft: return CGPoint(x: pad, y: pad)
        case .topRight: return CGPoint(x: size.width - pad, y: pad)
        case .bottomLeft: return CGPoint(x: pad, y: size.height - pad)
        case .bottomRight: return CGPoint(x: size.width - pad, y: size.height - pad)
        }
    }

    private static func pickRandomSlot(excluding: TargetSlot) -> TargetSlot {
        let pool = TargetSlot.allCases.filter { $0 != excluding }
        return pool.randomElement() ?? .center
    }

    private static func hitTarget(center: CGPoint, radius: CGFloat, gaze: CGPoint) -> Bool {
        let dx = gaze.x - center.x
        let dy = gaze.y - center.y
        return dx * dx + dy * dy <= radius * radius
    }
}

struct PieCrazyGameView: View {
    let target: CGPoint

    @State private var engine = PieCrazyEngine()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let frame = engine.frame(at: timeline.date, gaze: target, size: geo.size)
                Canvas { context, size in
                    drawScene(context: &context, size: size, frame: frame, gaze: target)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func drawScene(
        context: inout GraphicsContext,
        size: CGSize,
        frame: PieCrazyFrame,
        gaze: CGPoint
    ) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

        if frame.phase == .ready {
            drawBullseye(context: &context, center: frame.targetCenter, radius: frame.targetRadius)
            if frame.showCharge {
                let scale = 0.35 + frame.dwellProgress * 0.95
                drawPieCharge(context: &context, at: gaze, scale: scale)
                let ringR = 18 + frame.dwellProgress * 40
                var track = Path()
                track.addEllipse(in: CGRect(
                    x: gaze.x - ringR, y: gaze.y - ringR,
                    width: ringR * 2, height: ringR * 2
                ))
                context.stroke(track, with: .color(.white.opacity(0.35)), lineWidth: 5)
                var arc = Path()
                arc.addArc(
                    center: gaze,
                    radius: ringR,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * Double(frame.dwellProgress)),
                    clockwise: false
                )
                context.stroke(arc, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
        } else {
            drawSplat(context: &context, center: frame.targetCenter, radius: frame.targetRadius, t: frame.splatProgress)
        }
    }

    private func drawBullseye(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rings: [(CGFloat, Color, Bool)] = [
            (1.0, .white, true),
            (0.72, Color(red: 1, green: 0.09, blue: 0.27), false),
            (0.48, .white, true),
            (0.26, Color(red: 1, green: 0.09, blue: 0.27), false),
            (0.1, .black, false),
        ]
        for (frac, color, stroke) in rings {
            let r = radius * frac
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            if stroke {
                context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: max(4, radius * 0.04))
            }
        }
    }

    private func drawPieCharge(context: inout GraphicsContext, at point: CGPoint, scale: CGFloat) {
        var pieContext = context
        pieContext.concatenate(
            CGAffineTransform(translationX: point.x, y: point.y).scaledBy(x: scale, y: scale)
        )
        pieContext.fill(
            Path(ellipseIn: CGRect(x: -42, y: -2, width: 84, height: 28)),
            with: .color(Color(red: 0.55, green: 0.43, blue: 0.39))
        )
        var cream = Path()
        cream.move(to: CGPoint(x: -38, y: 6))
        cream.addQuadCurve(to: CGPoint(x: 38, y: 6), control: CGPoint(x: 0, y: -48))
        cream.addQuadCurve(to: CGPoint(x: -38, y: 6), control: CGPoint(x: 0, y: 18))
        cream.closeSubpath()
        pieContext.fill(cream, with: .color(Color(red: 1, green: 0.97, blue: 0.88)))
        pieContext.stroke(cream, with: .color(Color(red: 0.36, green: 0.25, blue: 0.22)), lineWidth: 3)
        pieContext.fill(
            Path(ellipseIn: CGRect(x: -10, y: -18, width: 20, height: 20)),
            with: .color(.white)
        )
    }

    private func drawSplat(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, t: CGFloat) {
        let spread = 0.35 + t * 0.65
        let flatR = radius * (1.1 + t * 0.35)

        var flatContext = context
        flatContext.concatenate(
            CGAffineTransform(translationX: center.x, y: center.y)
                .scaledBy(x: 1, y: 0.55 + t * 0.15)
        )
        let pieRect = CGRect(x: -flatR, y: -flatR * 0.55, width: flatR * 2, height: flatR * 1.1)
        flatContext.fill(Path(ellipseIn: pieRect), with: .color(Color(red: 1, green: 0.97, blue: 0.88)))
        flatContext.stroke(Path(ellipseIn: pieRect), with: .color(Color(red: 0.36, green: 0.25, blue: 0.22)), lineWidth: max(3, radius * 0.05))

        let splats = 14
        for i in 0..<splats {
            let angle = (CGFloat.pi * 2 * CGFloat(i)) / CGFloat(splats) + 0.2
            let dist = radius * spread * (0.85 + CGFloat(i % 3) * 0.12)
            let blobR = radius * (0.12 + CGFloat(i % 4) * 0.04) * (0.6 + t * 0.5)
            let bx = center.x + cos(angle) * dist
            let by = center.y + sin(angle) * dist
            let blobRect = CGRect(x: bx - blobR * 1.3, y: by - blobR, width: blobR * 2.6, height: blobR * 2)
            context.fill(
                Path(ellipseIn: blobRect),
                with: .color(i % 2 == 0 ? .white : Color(red: 1, green: 0.97, blue: 0.88))
            )
        }
    }
}
