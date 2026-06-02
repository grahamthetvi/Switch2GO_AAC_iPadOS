import SwiftUI

/// Rocket that follows gaze or touch; exhaust when moving, off when mostly still.
struct CursorRocketGameView: View {
    let target: CGPoint

    @State private var rocketPosition: CGPoint = .zero
    @State private var rocketAngle: Angle = .degrees(-90)
    @State private var showExhaust = false
    @State private var lastTarget: CGPoint = .zero
    @State private var lastSampleTime: Date = .init()
    @State private var didSeedPosition = false

    private let stillSpeed: CGFloat = 28
    private let lerp: CGFloat = 0.12
    private let rocketSize: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let _ = stepSimulation(now: now, bounds: geo.size)

                Canvas { context, size in
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

                    var transform = CGAffineTransform.identity
                    transform = transform.translatedBy(x: rocketPosition.x, y: rocketPosition.y)
                    transform = transform.rotated(by: CGFloat(rocketAngle.radians))
                    context.concatenate(transform)

                    if showExhaust {
                        var flame = Path()
                        flame.move(to: CGPoint(x: -14, y: rocketSize * 0.4))
                        flame.addLine(to: CGPoint(x: 0, y: rocketSize * 0.95))
                        flame.addLine(to: CGPoint(x: 14, y: rocketSize * 0.4))
                        flame.closeSubpath()
                        context.fill(flame, with: .linearGradient(
                            Gradient(colors: [.yellow, .orange, .orange.opacity(0)]),
                            startPoint: CGPoint(x: 0, y: rocketSize * 0.35),
                            endPoint: CGPoint(x: 0, y: rocketSize * 0.95)
                        ))
                    }

                    var body = Path()
                    body.move(to: CGPoint(x: 0, y: -rocketSize * 0.45))
                    body.addLine(to: CGPoint(x: rocketSize * 0.22, y: rocketSize * 0.35))
                    body.addLine(to: CGPoint(x: rocketSize * 0.12, y: rocketSize * 0.35))
                    body.addLine(to: CGPoint(x: rocketSize * 0.12, y: rocketSize * 0.42))
                    body.addLine(to: CGPoint(x: -rocketSize * 0.12, y: rocketSize * 0.42))
                    body.addLine(to: CGPoint(x: -rocketSize * 0.12, y: rocketSize * 0.35))
                    body.addLine(to: CGPoint(x: -rocketSize * 0.22, y: rocketSize * 0.35))
                    body.closeSubpath()
                    context.fill(body, with: .color(.init(white: 0.88)))

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: -rocketSize * 0.1,
                            y: -rocketSize * 0.18,
                            width: rocketSize * 0.2,
                            height: rocketSize * 0.2
                        )),
                        with: .color(Color(red: 0.31, green: 0.76, blue: 0.97))
                    )
                }
            }
            .onAppear {
                if !didSeedPosition {
                    rocketPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    lastTarget = target
                    didSeedPosition = true
                }
            }
        }
        .ignoresSafeArea()
    }

    private func stepSimulation(now: Date, bounds: CGSize) -> Bool {
        let dt = max(0.001, now.timeIntervalSince(lastSampleTime))
        let dx = target.x - lastTarget.x
        let dy = target.y - lastTarget.y
        let speed = hypot(dx, dy) / CGFloat(dt)

        var pos = rocketPosition
        if !didSeedPosition || pos == .zero {
            pos = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        }
        pos.x += (target.x - pos.x) * lerp
        pos.y += (target.y - pos.y) * lerp

        let moveDx = target.x - pos.x
        let moveDy = target.y - pos.y
        var angle = rocketAngle
        if hypot(moveDx, moveDy) > 2 {
            angle = Angle(radians: Double(atan2(moveDy, moveDx)) + .pi / 2)
        }

        lastTarget = target
        lastSampleTime = now
        rocketPosition = pos
        rocketAngle = angle
        showExhaust = speed > stillSpeed
        return true
    }
}
