import SwiftUI
import VocableShared

/// Full-screen calibration view for eye tracking setup.
struct CalibrationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var calibrationManager = CalibrationManager()

    @State private var currentPointIndex = 0
    @State private var isCollecting = false
    @State private var isComplete = false
    @State private var showInstructions = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()

                if showInstructions {
                    InstructionsView {
                        showInstructions = false
                        calibrationManager.generateCalibrationPoints(
                            screenWidth: geometry.size.width,
                            screenHeight: geometry.size.height
                        )
                    }
                } else if isComplete {
                    CalibrationCompleteView(
                        accuracy: calibrationManager.accuracy
                    ) {
                        appState.markCalibrated()
                        dismiss()
                    }
                } else {
                    // Calibration target
                    if let point = calibrationManager.calibrationPoints[safe: currentPointIndex] {
                        CalibrationTargetView(
                            position: point,
                            isCollecting: isCollecting,
                            progress: calibrationManager.collectionProgress
                        )
                    }

                    // Bottom controls
                    VStack {
                        Spacer()

                        VStack(spacing: 16) {
                            Text("Look at the circle")
                                .font(.title2)
                                .foregroundColor(.white)

                            Text("Point \(currentPointIndex + 1) of \(calibrationManager.calibrationPoints.count)")
                                .foregroundColor(.gray)

                            Button(isCollecting ? "Collecting..." : "Collect Point") {
                                startCollection()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCollecting)

                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.gray)
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .statusBarHidden()
    }

    private func startCollection() {
        isCollecting = true

        calibrationManager.collectSamples(from: gazeManager) { success in
            isCollecting = false

            if success {
                if currentPointIndex < calibrationManager.calibrationPoints.count - 1 {
                    // Move to next point
                    withAnimation {
                        currentPointIndex += 1
                    }
                } else {
                    // All points collected, compute calibration
                    calibrationManager.computeCalibration { result in
                        if result {
                            withAnimation {
                                isComplete = true
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Instructions shown before calibration begins.
struct InstructionsView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "eye.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Eye Tracking Calibration")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(number: 1, text: "Position your device at a comfortable distance")
                InstructionRow(number: 2, text: "Look directly at each circle as it appears")
                InstructionRow(number: 3, text: "Keep your head still during collection")
                InstructionRow(number: 4, text: "Wait for each point to complete")
            }
            .padding()

            Button("Begin Calibration") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue.opacity(0.2)))

            Text(text)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

/// The calibration target circle.
struct CalibrationTargetView: View {
    let position: CGPoint
    let isCollecting: Bool
    let progress: Double

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 80, height: 80)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCollecting ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            // Inner circle
            Circle()
                .fill(isCollecting ? Color.green : Color.white)
                .frame(width: 20, height: 20)
        }
        .position(position)
        .animation(.easeInOut(duration: 0.3), value: position)
    }
}

/// Shown when calibration is complete.
struct CalibrationCompleteView: View {
    let accuracy: Double
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Calibration Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                Text("Accuracy")
                    .foregroundColor(.gray)

                Text("\(Int(accuracy * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(accuracyColor)
            }

            Text(accuracyMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var accuracyColor: Color {
        switch accuracy {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .yellow
        default: return .orange
        }
    }

    private var accuracyMessage: String {
        switch accuracy {
        case 0.9...1.0: return "Excellent! Eye tracking should work very well."
        case 0.7..<0.9: return "Good calibration. You may want to recalibrate in better lighting."
        default: return "Consider recalibrating for better accuracy."
        }
    }
}

/// Safe array subscript extension.
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    CalibrationView()
        .environmentObject(AppState())
        .environmentObject(GazeTrackingManager())
}
