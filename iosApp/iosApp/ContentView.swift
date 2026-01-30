import SwiftUI
import VocableShared

/// Main content view that hosts the AAC interface and gaze tracking overlay.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gazeManager = GazeTrackingManager()

    @State private var showSettings = false
    @State private var showCalibration = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Main AAC grid interface
                AACGridView()
                    .environmentObject(gazeManager)

                // Gaze pointer overlay (only when tracking)
                if gazeManager.isTracking && appState.isTrackingEnabled {
                    GazePointerView(position: gazeManager.gazePosition)
                }

                // Calibration prompt for first launch
                if !appState.isCalibrated {
                    CalibrationPromptOverlay {
                        showCalibration = true
                    }
                }
            }
            .navigationTitle("Switch2Go")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCalibration = true
                    } label: {
                        Image(systemName: "scope")
                            .font(.title2)
                    }
                    .accessibilityLabel("Calibration")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showCalibration) {
                CalibrationView()
                    .environmentObject(appState)
                    .environmentObject(gazeManager)
            }
        }
        .onAppear {
            if appState.isTrackingEnabled {
                gazeManager.startTracking()
            }
        }
        .onDisappear {
            gazeManager.stopTracking()
        }
    }
}

/// Overlay shown when calibration is needed.
struct CalibrationPromptOverlay: View {
    let onCalibrate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "eye.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Eye Tracking Setup")
                .font(.title)
                .fontWeight(.bold)

            Text("To use hands-free control, please complete the eye tracking calibration.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Start Calibration") {
                onCalibrate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

/// Gaze pointer overlay showing where the user is looking.
struct GazePointerView: View {
    let position: CGPoint

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 60)

            // Inner circle
            Circle()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 30, height: 30)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
        }
        .position(position)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.1), value: position)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
