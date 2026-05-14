import SwiftUI
import VocableShared

/// Advanced Eye Tracking Settings
struct AdvancedEyeTrackingView: View {
    @StateObject private var settings = AppSettings.shared
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var showingResetConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // GPU Toggle
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPU Acceleration")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Toggle(isOn: $settings.useGPU) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use GPU")
                                .font(.headline)
                            Text("Faster processing but may drain battery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Tracking Method
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tracking Method")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        trackingModeButton(mode: "2D", label: "2D Iris")
                        trackingModeButton(mode: "3D", label: "3D Eyeball")
                    }
                    
                    Text("2D is faster, 3D is more accurate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Smoothing Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Smoothing Mode")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        smoothingButton(mode: "simple", label: "Simple")
                        smoothingButton(mode: "kalman", label: "Kalman Filter")
                        smoothingButton(mode: "adaptive", label: "Adaptive Kalman (Recommended)")
                        smoothingButton(mode: "combined", label: "Combined")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Eye Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Eye Selection")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        eyeSelectionButton(mode: "both", label: "Both Eyes")
                        eyeSelectionButton(mode: "left", label: "Left Eye Only")
                        eyeSelectionButton(mode: "right", label: "Right Eye Only")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Gaze Amplification
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gaze Amplification")
                        .font(.title3)
                        .fontWeight(.bold)

                    VStack(spacing: 8) {
                        amplificationButton(value: 1.0, label: "1.0x (Normal)")
                        amplificationButton(value: 1.25, label: "1.25x")
                        amplificationButton(value: 1.5, label: "1.5x")
                        amplificationButton(value: 1.75, label: "1.75x")
                        amplificationButton(value: 2.0, label: "2.0x (High)")
                    }

                    Text("Amplify gaze movement for users with limited range. Eye gaze mode only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Behavior Toggles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behavior")
                        .font(.title3)
                        .fontWeight(.bold)

                    Toggle(isOn: $settings.enableOutOfBoundsHiding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hide Cursor When Gaze Is Away")
                                .font(.headline)
                            Text("Hide pointer if you look away from the screen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    Toggle(isOn: $settings.showTrackingErrorBanner) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Tracking Lost Banner")
                                .font(.headline)
                            Text("Display a warning if no face is detected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    Toggle(isOn: $settings.enableDoubleBlinkRecenter) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Double‑Blink to Recenter")
                                .font(.headline)
                            Text("Recenter the cursor with a double blink")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    Toggle(isOn: $settings.enableAutoRecenter) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto‑Recenter When Centered")
                                .font(.headline)
                            Text("Recenter after looking straight ahead. Eye gaze mode only.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // MARK: - Head Tracking Settings

                VStack(alignment: .leading, spacing: 12) {
                    Text("Head Tracking")
                        .font(.title3)
                        .fontWeight(.bold)

                    // Camera position preset
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Camera Position")
                            .font(.headline)

                        HStack(spacing: 8) {
                            cameraPositionButton(position: "left", label: "Left")
                            cameraPositionButton(position: "center", label: "Center")
                            cameraPositionButton(position: "right", label: "Right")
                            cameraPositionButton(position: "custom", label: "Custom")
                        }

                        Text("iPad cameras are typically on the left in landscape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    // camera position block was here, removed the Calibrate button that followed it

                    // Sensitivity sliders
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Horizontal Sensitivity: \(String(format: "%.1f", settings.headSensitivityX))")
                            .font(.headline)
                        Slider(value: $settings.headSensitivityX, in: 1.0...4.0, step: 0.5)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vertical Sensitivity: \(String(format: "%.1f", settings.headSensitivityY))")
                            .font(.headline)
                        Slider(value: $settings.headSensitivityY, in: 1.0...4.0, step: 0.5)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    if settings.headCameraPosition == "custom" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Offset")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Yaw: \(String(format: "%.1f", settings.headCameraOffsetYaw))°  Pitch: \(String(format: "%.1f", settings.headCameraOffsetPitch))°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Reset Calibration
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    Label("Reset Calibration", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .alert("Reset Calibration?", isPresented: $showingResetConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        resetCalibration()
                    }
                } message: {
                    Text("This will clear your current calibration data. You'll need to recalibrate.")
                }
            }
            .padding()
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Advanced Eye Tracking")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func trackingModeButton(mode: String, label: String) -> some View {
        Button(action: {
            settings.trackingMode = mode
        }) {
            Text(label)
                .font(.headline)
                .foregroundColor(settings.trackingMode == mode ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(settings.trackingMode == mode ? Color.blue : Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
        }
    }
    
    private func smoothingButton(mode: String, label: String) -> some View {
        Button(action: {
            settings.smoothingMode = mode
        }) {
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundColor(settings.smoothingMode == mode ? .white : .primary)
                
                Spacer()
                
                if settings.smoothingMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(settings.smoothingMode == mode ? Color.blue : Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private func eyeSelectionButton(mode: String, label: String) -> some View {
        Button(action: {
            settings.eyeSelection = mode
        }) {
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundColor(settings.eyeSelection == mode ? .white : .primary)
                
                Spacer()
                
                if settings.eyeSelection == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(settings.eyeSelection == mode ? Color.blue : Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }

    private func amplificationButton(value: Double, label: String) -> some View {
        Button(action: {
            settings.gazeAmplification = value
        }) {
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundColor(settings.gazeAmplification == value ? .white : .primary)

                Spacer()

                if settings.gazeAmplification == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(settings.gazeAmplification == value ? Color.blue : Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private func cameraPositionButton(position: String, label: String) -> some View {
        Button(action: {
            gazeManager.applyHeadCameraPreset(position)
        }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(settings.headCameraPosition == position ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(settings.headCameraPosition == position ? Color.blue : Color(UIColor.quaternarySystemFill))
                .cornerRadius(8)
        }
    }

    private func resetCalibration() {
        let storage = StorageKt.createStorage()
        _ = storage.deleteCalibrationData(mode: "polynomial")
        _ = storage.deleteCalibrationData(mode: "affine")
        storage.saveBoolean(key: "hasCalibration", value: false)
        
        gazeManager.resetGazeCalibration()
        
        DebugLog.info("Calibration data cleared", tag: "AdvancedEyeTrackingView")
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        AdvancedEyeTrackingView()
            .environmentObject(GazeTrackingManager())
    }
}
