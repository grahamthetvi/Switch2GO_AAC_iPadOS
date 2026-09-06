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
                    title: "Switching Between Input Modes",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple,
                    steps: [
                        "Tap the gear icon in the top-right corner to open Settings.",
                        "Go to Selection Mode.",
                        "Choose your preferred mode: Touch Only, Head Tracking, Eye Gaze Tracking, Arm Raise Selection, or Hand Gesture Selection.",
                        "The change takes effect immediately when you close Settings.",
                        "You can switch between modes at any time — the app will remember your last choice.",
                        "External switches are configured separately under Selection Mode → Switch Control and can stay enabled alongside any mode."
                    ]
                )

                // MARK: - Getting the Right Orientation
                troubleshootingSection(
                    title: "Getting the Right Orientation",
                    icon: "rectangle.landscape.rotate",
                    color: .blue,
                    steps: [
                        "Eye and head tracking require landscape orientation.",
                        "Hold your iPad horizontally with the home button (or USB-C port) on the right side.",
                        "The front-facing camera should be on the left side, facing you.",
                        "If you rotate to portrait or the wrong landscape direction, tracking will pause and the app will switch to touch-only mode.",
                        "A banner will appear when you rotate, telling you which modes are available in the current orientation.",
                        "Arm raise and hand gesture modes still need your upper body visible to the camera, but they are not limited to one landscape direction like eye gaze."
                    ]
                )

                // MARK: - Tracking Not Working
                troubleshootingSection(
                    title: "Eye & Head Tracking Not Working",
                    icon: "eye.slash",
                    color: .orange,
                    steps: [
                        "Make sure your face is clearly visible to the front camera — avoid covering your face or wearing reflective glasses.",
                        "Ensure you have good, even lighting. Avoid backlighting (bright light behind you) as it makes your face harder to detect.",
                        "Check that you are in the correct landscape orientation (home button / USB-C on the right).",
                        "Try tapping the Recenter Cursor button at the top of Settings if the cursor seems offset.",
                        "If tracking was working before but stopped, try closing and reopening the app.",
                        "For eye gaze tracking, keep your iPad at a comfortable arm's length distance (roughly 40–60 cm / 16–24 inches)."
                    ]
                )

                // MARK: - Arm Raise & Hand Gestures
                troubleshootingSection(
                    title: "Arm Raise & Hand Gestures",
                    icon: "figure.wave",
                    color: .mint,
                    steps: [
                        "Both modes only work when exactly 2 phrases appear on screen. Set Symbols per page to 2 under Settings → Categories Display → CVI Display Settings.",
                        "If you see a hint that the layout is wrong, paginate to a page with two phrases or reduce the symbol count.",
                        "Stand or sit where your shoulders, arms, and hands are visible to the front camera — not just your face.",
                        "Arm raise: hold the raise steady for a moment. Lower both arms before trying again.",
                        "Hand gesture: try open-then-close or close-then-open on the left or right hand. Keep the other hand out of the way when possible.",
                        "If detection is inconsistent, improve lighting and move farther back so more of your upper body is in frame."
                    ]
                )

                // MARK: - Phrase Packs & Backup
                troubleshootingSection(
                    title: "Phrase Packs & Backup",
                    icon: "square.and.arrow.up.on.square",
                    color: .teal,
                    steps: [
                        "Import .switch2go packs from Settings → Phrase Packs → Import from Files.",
                        "To open a pack from Mail or AirDrop, tap the attachment and choose Switch2GO. Guided Access blocks Mail and AirDrop — turn it off first or copy the file to Files.",
                        "Export a category from Settings → Edit Categories & Phrases → choose a category → Export Category. Recently Said cannot be exported.",
                        "Importing adds a copy of the category; built-in preset boards are never overwritten.",
                        "Backup & Restore is under Settings → Backup & Restore. Import replaces all local data — export a backup first if you want to keep the current board."
                    ]
                )

                // MARK: - Media & Games
                troubleshootingSection(
                    title: "Videos, Audio, YouTube & Games",
                    icon: "play.rectangle.fill",
                    color: .indigo,
                    steps: [
                        "Attach media from Settings → Edit Categories & Phrases → Edit Style on a phrase.",
                        "Videos must be 20 seconds or shorter. Longer files are rejected.",
                        "Media and games start after a short delay so another phrase can be selected first. Change the delay in Settings → Timing & Sensitivity.",
                        "Only one attachment type is active per phrase — video, audio, YouTube, or game.",
                        "If playback does not start, make sure the phrase was fully selected (dwell completed or switch pressed) and wait for the delay to finish."
                    ]
                )

                // MARK: - Switch Control
                troubleshootingSection(
                    title: "Switch Control (Input)",
                    icon: "keyboard",
                    color: .blue,
                    steps: [
                        "Enable Switch Control under Settings → Selection Mode → Switch Control.",
                        "Scan & Select: 2 switches (select + next). Switch to Phrase: 2–4 switches matching phrases per page.",
                        "Pair the ESP32 as Switch2GO-XXXX in iPad Settings → Bluetooth before using the app.",
                        "Default keys are 1–4; key mapping in Switch Control must match ESP32/Switch2GO_BLE_Switch firmware.",
                        "If presses are ignored, open Switch Control and confirm the last-press indicator updates when you press a switch.",
                        "After updating ESP32 firmware, Forget Switch2GO-XXXX in Bluetooth settings and pair again."
                    ]
                )

                // MARK: - Environmental Control
                troubleshootingSection(
                    title: "Environmental Control (PowerLink Output)",
                    icon: "poweroutlet.type.b",
                    color: .green,
                    steps: [
                        "Wire GPIO 26 on the ESP32 through a relay or optocoupler to the PowerLink jack on your fan, light, or appliance.",
                        "Pair Switch2GO-XXXX in iPad Settings → Bluetooth, then open Settings → Selection Mode → Switch Control → Connect ESP32 output.",
                        "Turn on “Send switch output” in the Phrase Style Editor for the phrase that should toggle the device.",
                        "When the phrase is selected (by touch, gaze, switch, arm raise, or gesture), the ESP32 sends a pulse to the PowerLink.",
                        "If the fan or light does not toggle, confirm Switch Control shows “Ready to send switch output.” Older firmware without the output service must be reflashed, then Forget Device and pair again.",
                        "Switch input (keys 1–4) and switch output (PowerLink pulse) use the same ESP32 but are set up in different parts of Switch Control."
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
