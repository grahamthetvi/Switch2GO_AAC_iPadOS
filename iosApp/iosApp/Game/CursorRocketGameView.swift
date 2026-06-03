import SwiftUI

/// Immutable snapshot of rocket state for a single animation frame.
struct RocketFrame {
    let position: CGPoint
    let angle: Angle
    let exhaustIntensity: CGFloat
}

/// Simulation engine that advances rocket motion toward a target.
final class RocketEngine {
    private var position: CGPoint = .zero
    private var angle: Angle = .degrees(-90)
    private var lastTarget: CGPoint = .zero
    private var lastSampleTime: Date?
    private var didSeedPosition = false

    private let stillSpeed: CGFloat = 28
    private let lerp: CGFloat = 0.12
    private let maxExhaustSpeed: CGFloat = 400

    func frame(at now: Date, target: CGPoint, bounds: CGSize) -> RocketFrame {
        let dt: CGFloat
        if let lastSampleTime {
            dt = max(0.001, CGFloat(now.timeIntervalSince(lastSampleTime)))
        } else {
            dt = 1.0 / 60.0
        }

        let dx = target.x - lastTarget.x
        let dy = target.y - lastTarget.y
        let speed = hypot(dx, dy) / dt

        var pos = position
        if !didSeedPosition || pos == .zero {
            pos = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            didSeedPosition = true
        }

        pos.x += (target.x - pos.x) * lerp
        pos.y += (target.y - pos.y) * lerp

        let moveDx = target.x - pos.x
        let moveDy = target.y - pos.y
        if hypot(moveDx, moveDy) > 2 {
            angle = Angle(radians: Double(atan2(moveDy, moveDx)) + .pi / 2)
        }

        lastTarget = target
        lastSampleTime = now
        position = pos

        let exhaustIntensity: CGFloat
        if speed <= stillSpeed {
            exhaustIntensity = 0
        } else {
            exhaustIntensity = min(1, (speed - stillSpeed) / (maxExhaustSpeed - stillSpeed))
        }

        return RocketFrame(position: pos, angle: angle, exhaustIntensity: exhaustIntensity)
    }
}

/// Rocket that follows gaze or touch; exhaust scales with movement speed.
struct CursorRocketGameView: View {
    let target: CGPoint

    @State private var engine = RocketEngine()

    private let rocketSize: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let frame = engine.frame(at: timeline.date, target: target, bounds: geo.size)

                Canvas { context, size in
                    drawBackground(context: &context, size: size)
                    drawRocket(context: &context, frame: frame)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.04, green: 0.04, blue: 0.1))
        )

        for i in 0..<40 {
            let sx = CGFloat((i * 97) % max(Int(size.width), 1))
            let sy = CGFloat((i * 53) % max(Int(size.height), 1))
            context.fill(
                Path(ellipseIn: CGRect(x: sx, y: sy, width: 2, height: 2)),
                with: .color(.white.opacity(0.35))
            )
        }
    }

    private func drawRocket(context: inout GraphicsContext, frame: RocketFrame) {
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: frame.position.x, y: frame.position.y)
        transform = transform.rotated(by: CGFloat(frame.angle.radians))
        context.concatenate(transform)

        if frame.exhaustIntensity > 0 {
            drawExhaust(context: &context, intensity: frame.exhaustIntensity)
        }

        drawFins(context: &context)
        drawBody(context: &context)
        drawStripe(context: &context)
        drawNoseCone(context: &context)
        drawWindow(context: &context)
    }

    private func drawExhaust(context: inout GraphicsContext, intensity: CGFloat) {
        let flameLength = rocketSize * (0.45 + 0.55 * intensity)
        let flameWidth = 10 + 8 * intensity

        var outerFlame = Path()
        outerFlame.move(to: CGPoint(x: -flameWidth, y: rocketSize * 0.38))
        outerFlame.addLine(to: CGPoint(x: 0, y: flameLength))
        outerFlame.addLine(to: CGPoint(x: flameWidth, y: rocketSize * 0.38))
        outerFlame.closeSubpath()
        context.fill(outerFlame, with: .linearGradient(
            Gradient(colors: [
                Color.orange.opacity(0.9),
                Color.red.opacity(0.6),
                Color.red.opacity(0),
            ]),
            startPoint: CGPoint(x: 0, y: rocketSize * 0.35),
            endPoint: CGPoint(x: 0, y: flameLength)
        ))

        var innerFlame = Path()
        innerFlame.move(to: CGPoint(x: -flameWidth * 0.45, y: rocketSize * 0.4))
        innerFlame.addLine(to: CGPoint(x: 0, y: flameLength * 0.82))
        innerFlame.addLine(to: CGPoint(x: flameWidth * 0.45, y: rocketSize * 0.4))
        innerFlame.closeSubpath()
        context.fill(innerFlame, with: .linearGradient(
            Gradient(colors: [.yellow, .orange, .orange.opacity(0)]),
            startPoint: CGPoint(x: 0, y: rocketSize * 0.38),
            endPoint: CGPoint(x: 0, y: flameLength * 0.82)
        ))
    }

    private func drawBody(context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 0, y: -rocketSize * 0.08))
        body.addLine(to: CGPoint(x: rocketSize * 0.2, y: rocketSize * 0.38))
        body.addLine(to: CGPoint(x: rocketSize * 0.11, y: rocketSize * 0.38))
        body.addLine(to: CGPoint(x: rocketSize * 0.11, y: rocketSize * 0.44))
        body.addLine(to: CGPoint(x: -rocketSize * 0.11, y: rocketSize * 0.44))
        body.addLine(to: CGPoint(x: -rocketSize * 0.11, y: rocketSize * 0.38))
        body.addLine(to: CGPoint(x: -rocketSize * 0.2, y: rocketSize * 0.38))
        body.closeSubpath()
        context.fill(body, with: .color(Color(white: 0.92)))

        context.stroke(body, with: .color(Color(white: 0.75)), lineWidth: 1)
    }

    private func drawNoseCone(context: inout GraphicsContext) {
        var nose = Path()
        nose.move(to: CGPoint(x: 0, y: -rocketSize * 0.48))
        nose.addLine(to: CGPoint(x: rocketSize * 0.14, y: -rocketSize * 0.08))
        nose.addLine(to: CGPoint(x: -rocketSize * 0.14, y: -rocketSize * 0.08))
        nose.closeSubpath()
        context.fill(nose, with: .color(Color(red: 0.85, green: 0.15, blue: 0.15)))
    }

    private func drawStripe(context: inout GraphicsContext) {
        let stripeRect = CGRect(
            x: -rocketSize * 0.2,
            y: rocketSize * 0.08,
            width: rocketSize * 0.4,
            height: rocketSize * 0.07
        )
        context.fill(Path(stripeRect), with: .color(Color(red: 0.85, green: 0.15, blue: 0.15)))
    }

    private func drawWindow(context: inout GraphicsContext) {
        let windowRect = CGRect(
            x: -rocketSize * 0.11,
            y: -rocketSize * 0.22,
            width: rocketSize * 0.22,
            height: rocketSize * 0.22
        )
        context.fill(Path(ellipseIn: windowRect), with: .color(Color(white: 0.2)))
        context.stroke(Path(ellipseIn: windowRect), with: .color(Color(white: 0.55)), lineWidth: 2)

        let highlightRect = CGRect(
            x: -rocketSize * 0.06,
            y: -rocketSize * 0.18,
            width: rocketSize * 0.08,
            height: rocketSize * 0.08
        )
        context.fill(Path(ellipseIn: highlightRect), with: .color(Color(red: 0.45, green: 0.82, blue: 0.98).opacity(0.85)))
    }

    private func drawFins(context: inout GraphicsContext) {
        var leftFin = Path()
        leftFin.move(to: CGPoint(x: -rocketSize * 0.11, y: rocketSize * 0.34))
        leftFin.addLine(to: CGPoint(x: -rocketSize * 0.3, y: rocketSize * 0.52))
        leftFin.addLine(to: CGPoint(x: -rocketSize * 0.11, y: rocketSize * 0.44))
        leftFin.closeSubpath()
        context.fill(leftFin, with: .color(Color(red: 0.7, green: 0.1, blue: 0.1)))
        context.stroke(leftFin, with: .color(Color(red: 0.45, green: 0.05, blue: 0.05)), lineWidth: 1)

        var rightFin = Path()
        rightFin.move(to: CGPoint(x: rocketSize * 0.11, y: rocketSize * 0.34))
        rightFin.addLine(to: CGPoint(x: rocketSize * 0.3, y: rocketSize * 0.52))
        rightFin.addLine(to: CGPoint(x: rocketSize * 0.11, y: rocketSize * 0.44))
        rightFin.closeSubpath()
        context.fill(rightFin, with: .color(Color(red: 0.7, green: 0.1, blue: 0.1)))
        context.stroke(rightFin, with: .color(Color(red: 0.45, green: 0.05, blue: 0.05)), lineWidth: 1)
    }
}
