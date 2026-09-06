import SwiftUI

/// Troubleshooting guide accessible from Settings.
struct TroubleshootingView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text("Having trouble? Check the sections below for common issues and solutions.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // MARK: - Switching Between Tracking Modes
                troubleshootingSection(
                    title: "Switching Between Tracking Modes",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple,
                    steps: [
                        "Tap the gear icon in the top-right corner to open Settings.",
                        "Go to Selection Mode.",
                        "Choose your preferred mode: No Tracking (Touch & Switch), Head Tracking, or Eye Gaze Tracking.",
                        "The change takes effect immediately when you close Settings.",
                        "You can switch between modes at any time -- the app will remember your last choice."
                    ]
                )

                // MARK: - Getting the Right Orientation
                troubleshootingSection(
                    title: "Getting the Right Orientation",
                    icon: "rectangle.landscape.rotate",
                    color: .blue,
                    steps: [
                        "Eye and head tracking work in portrait and either landscape direction.",
                        "The only unsupported position is portrait upside-down, with the front camera at the bottom.",
                        "If the camera is upside down, tracking pauses and the app switches to touch and switch only.",
                        "A banner will appear when you rotate, telling you which modes are available in the current orientation."
                    ]
                )

                // MARK: - Tracking Not Working
                troubleshootingSection(
                    title: "Tracking Not Working",
                    icon: "eye.slash",
                    color: .orange,
                    steps: [
                        "Make sure your face is clearly visible to the front camera -- avoid covering your face or wearing reflective glasses.",
                        "Ensure you have good, even lighting. Avoid backlighting (bright light behind you) as it makes your face harder to detect.",
                        "Check that the front camera is not at the bottom of the iPad (portrait upside-down pauses tracking).",
                        "Try tapping the Recenter Cursor button at the top of Settings if the cursor seems offset.",
                        "If tracking was working before but stopped, try closing and reopening the app.",
                        "For eye gaze tracking, keep your iPad at a comfortable arm's length distance (roughly 40-60 cm / 16-24 inches)."
                    ]
                )

                // MARK: - Switch Control
                troubleshootingSection(
                    title: "Switch Control",
                    icon: "keyboard",
                    color: .blue,
                    steps: [
                        "Enable Switch Control under Settings → Selection Mode → Switch Control.",
                        "Scan & Select: 2 switches (select + next). Switch to Phrase: 2–4 switches matching phrases per page.",
                        "Pair the ESP32 as Switch2GO-XXXX in iPad Settings → Bluetooth before using the app.",
                        "Default keys are 1–4; key mapping in Switch Control must match ESP32/Switch2GO_BLE_Switch firmware.",
                        "If presses are ignored, open Switch Control and confirm the last-press indicator updates when you press a switch."
                    ]
                )
            }
            .padding(.vertical)
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Troubleshooting")
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
                Button("Done") { dismiss() }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func troubleshootingSection(
        title: String,
        icon: String,
        color: Color,
        steps: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.subheadline.bold())
                            .foregroundColor(color)
                            .frame(width: 24, alignment: .trailing)
                        Text(step)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationStack {
        TroubleshootingView()
    }
}
