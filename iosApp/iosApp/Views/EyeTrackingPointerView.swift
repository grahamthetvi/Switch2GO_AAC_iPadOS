import SwiftUI
import Combine

/// Overlay view that displays the eye tracking pointer/cursor
struct EyeTrackingPointerView: View {
    @EnvironmentObject var appState: AppState
    @State private var pointerPosition: CGPoint = CGPoint(x: 200, y: 200)
    @State private var dwellProgress: CGFloat = 0
    @State private var isVisible: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dwell progress ring
                Circle()
                    .trim(from: 0, to: dwellProgress)
                    .stroke(Color.blue, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .position(pointerPosition)
                    .opacity(dwellProgress > 0 ? 1 : 0)

                // Pointer dot
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .shadow(color: .blue.opacity(0.5), radius: 8)
                    .position(pointerPosition)
                    .opacity(isVisible ? 1 : 0.3)
            }
            .onReceive(appState.eyeTrackingManager.$gazePoint) { point in
                guard let point = point else { return }

                // Convert normalized coordinates to screen coordinates
                let screenX = CGFloat(point.x) * geometry.size.width
                let screenY = CGFloat(point.y) * geometry.size.height

                // Smooth animation to new position
                withAnimation(.easeOut(duration: 0.1)) {
                    pointerPosition = CGPoint(x: screenX, y: screenY)
                }
            }
            .onReceive(appState.eyeTrackingManager.$dwellProgress) { progress in
                withAnimation(.linear(duration: 0.1)) {
                    dwellProgress = CGFloat(progress)
                }
            }
            .onReceive(appState.eyeTrackingManager.$isTracking) { tracking in
                isVisible = tracking
            }
        }
        .allowsHitTesting(false) // Allow touches to pass through
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        EyeTrackingPointerView()
    }
    .environmentObject(AppState())
}
