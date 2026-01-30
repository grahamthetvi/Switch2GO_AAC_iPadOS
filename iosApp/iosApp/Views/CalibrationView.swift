import SwiftUI
import VocableShared

struct CalibrationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var currentPointIndex = 0
    @State private var isCalibrating = false
    @State private var calibrationComplete = false
    @State private var countdown = 3

    // 9-point calibration grid positions (normalized 0-1)
    let calibrationPoints: [(CGFloat, CGFloat)] = [
        (0.1, 0.1), (0.5, 0.1), (0.9, 0.1),  // Top row
        (0.1, 0.5), (0.5, 0.5), (0.9, 0.5),  // Middle row
        (0.1, 0.9), (0.5, 0.9), (0.9, 0.9)   // Bottom row
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()

                if !isCalibrating && !calibrationComplete {
                    // Instructions screen
                    VStack(spacing: 24) {
                        Text("Eye Tracking Calibration")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Look at each dot as it appears on screen.\nKeep your head still during calibration.")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 40)

                        Button(action: startCalibration) {
                            Text("Start Calibration")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }

                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    }
                } else if isCalibrating {
                    // Calibration in progress
                    VStack {
                        Text("Point \(currentPointIndex + 1) of \(calibrationPoints.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 40)

                        Spacer()
                    }

                    // Calibration point
                    CalibrationDot(
                        position: CGPoint(
                            x: calibrationPoints[currentPointIndex].0 * geometry.size.width,
                            y: calibrationPoints[currentPointIndex].1 * geometry.size.height
                        ),
                        countdown: countdown
                    )
                } else if calibrationComplete {
                    // Calibration complete
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)

                        Text("Calibration Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Eye tracking is now ready to use.")
                            .font(.title3)
                            .foregroundColor(.gray)

                        Button(action: { dismiss() }) {
                            Text("Done")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                }
            }
        }
    }

    private func startCalibration() {
        isCalibrating = true
        currentPointIndex = 0

        // Start the calibration process using VocableShared
        appState.eyeTrackingManager.startCalibration()

        calibrateNextPoint()
    }

    private func calibrateNextPoint() {
        countdown = 3

        // Countdown timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()

                // Record calibration point using VocableShared
                let point = calibrationPoints[currentPointIndex]
                appState.eyeTrackingManager.recordCalibrationPoint(
                    screenX: Float(point.0),
                    screenY: Float(point.1)
                )

                // Move to next point or finish
                if currentPointIndex < calibrationPoints.count - 1 {
                    currentPointIndex += 1
                    calibrateNextPoint()
                } else {
                    // Finalize calibration
                    appState.eyeTrackingManager.finishCalibration()
                    isCalibrating = false
                    calibrationComplete = true
                }
            }
        }
    }
}

struct CalibrationDot: View {
    let position: CGPoint
    let countdown: Int

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Outer ring (countdown indicator)
            Circle()
                .stroke(Color.blue, lineWidth: 4)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(opacity)

            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)

            // Countdown number
            if countdown > 0 {
                Text("\(countdown)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .offset(y: 45)
            }
        }
        .position(position)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                scale = 1.2
                opacity = 0.7
            }
        }
    }
}

#Preview {
    CalibrationView()
        .environmentObject(AppState())
}
