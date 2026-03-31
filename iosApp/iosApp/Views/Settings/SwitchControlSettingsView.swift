import SwiftUI

/// Settings view for configuring USB HID switch control.
///
/// Allows the user to:
/// - Enable/disable switch control
/// - See USB keyboard connection status
/// - Configure which key each switch sends
/// - Configure which action each physical switch performs
/// - Choose between direct mode (switch + tracking) and scanning mode
struct SwitchControlSettingsView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Coming Soon Banner
                VStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Coming Soon")
                        .font(.title2.bold())
                    Text("USB Switch Control is currently in development and will be available in a future update.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

                // MARK: - Enable Toggle
                enableSection

                if settings.switchControlEnabled {
                    // MARK: - Connection Status
                    connectionStatusSection

                    Divider().padding(.horizontal)

                    // MARK: - How It Works
                    howItWorksSection

                    Divider().padding(.horizontal)

                    // MARK: - Key Mapping
                    keyMappingSection

                    Divider().padding(.horizontal)

                    // MARK: - Control Mode
                    controlModeSection

                    Divider().padding(.horizontal)

                    // MARK: - Switch Action Mapping (not shown in directMapping mode)
                    if settings.switchControlMode != "directMapping" {
                        switchMappingSection
                    } else {
                        directMappingInfoSection
                    }

                    // MARK: - Scanning Mode Options
                    if settings.switchControlMode == "scanning" {
                        scanningOptionsSection
                    }
                }
            }
            .padding(.vertical)
            .disabled(true)
            .opacity(0.7)
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Switch Control")
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
        .onChange(of: settings.switchControlEnabled) { _, enabled in
            gazeManager.setSwitchControlEnabled(enabled)
        }
        .onChange(of: settings.switchControlMode) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchScanInterval) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchKey1) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchKey2) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchKey3) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchKey4) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $settings.switchControlEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USB Switch Control")
                            .font(.headline)
                        Text("Use Tapio or a compatible USB HID switch interface")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        let mgr = gazeManager.switchManager

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(mgr.isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: mgr.isConnected ? "checkmark.circle.fill" : "cable.connector")
                        .font(.title)
                        .foregroundColor(mgr.isConnected ? .green : .orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mgr.isConnected ? "Connected" : "Not Connected")
                        .font(.title3.bold())
                        .foregroundColor(mgr.isConnected ? .green : .secondary)

                    if let name = mgr.connectedDeviceName {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Connect Tapio via USB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            // Last switch event feedback
            if let event = mgr.lastSwitchEvent, event.isPress {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("Last press: Switch \(event.switchIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                SetupStepRow(
                    number: 1,
                    icon: "cpu",
                    text: "Tapio is a USB switch interface that connects to your iPad via USB cable. An open-source Arduino-based alternative is also in development."
                )

                SetupStepRow(
                    number: 2,
                    icon: "power.circle",
                    text: "Connect your adaptive switches to Tapio using standard 3.5mm jacks. When pressed, Tapio sends a keypress over USB to the app."
                )

                SetupStepRow(
                    number: 3,
                    icon: "app.badge",
                    text: "This app listens for those keypresses. In Direct Switch-to-Phrase mode, Switch 1 → Phrase 1, Switch 2 → Phrase 2, etc."
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Text("No Bluetooth pairing needed — just plug in the USB cable and go.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Key Mapping

    private var keyMappingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Mapping")
                .font(.headline)
                .padding(.horizontal)

            Text("Configure which keyboard key each switch sends. Default: keys 1, 2, 3, 4. Must match your Tapio or switch device configuration.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                SwitchKeyPicker(label: "Switch 1", selection: $settings.switchKey1)
                SwitchKeyPicker(label: "Switch 2", selection: $settings.switchKey2)
                SwitchKeyPicker(label: "Switch 3", selection: $settings.switchKey3)
                SwitchKeyPicker(label: "Switch 4", selection: $settings.switchKey4)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Control Mode

    private var controlModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Control Mode")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                SwitchModeButton(
                    title: "Direct Switch-to-Phrase",
                    description: "Each switch activates a specific phrase tile by position: Switch 1 → Phrase 1 (top-left), Switch 2 → Phrase 2, etc.",
                    icon: "square.grid.2x2",
                    isSelected: settings.switchControlMode == "directMapping"
                ) {
                    settings.switchControlMode = "directMapping"
                }

                SwitchModeButton(
                    title: "Direct (with Tracking)",
                    description: "Eye or head tracking moves the cursor. Switch press activates the highlighted button.",
                    icon: "eye.fill",
                    isSelected: settings.switchControlMode == "direct"
                ) {
                    settings.switchControlMode = "direct"
                }

                SwitchModeButton(
                    title: "Auto-Scan",
                    description: "Buttons are highlighted automatically in sequence. Switch press selects the current one.",
                    icon: "arrow.right.arrow.left",
                    isSelected: settings.switchControlMode == "scanning"
                ) {
                    settings.switchControlMode = "scanning"
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Switch Mapping

    private var switchMappingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Switch Actions")
                .font(.headline)
                .padding(.horizontal)

            Text("Assign what each physical switch does when pressed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                SwitchActionPicker(label: "Switch 1", selection: $settings.switchAction1)
                SwitchActionPicker(label: "Switch 2", selection: $settings.switchAction2)
                SwitchActionPicker(label: "Switch 3", selection: $settings.switchAction3)
                SwitchActionPicker(label: "Switch 4", selection: $settings.switchAction4)
            }
            .padding(.horizontal)
            .onChange(of: settings.switchAction1) { _, _ in gazeManager.applySwitchSettings(settings) }
            .onChange(of: settings.switchAction2) { _, _ in gazeManager.applySwitchSettings(settings) }
            .onChange(of: settings.switchAction3) { _, _ in gazeManager.applySwitchSettings(settings) }
            .onChange(of: settings.switchAction4) { _, _ in gazeManager.applySwitchSettings(settings) }
        }
    }

    // MARK: - Direct Mapping Info

    private var directMappingInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Switch-to-Phrase Mapping")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(1...4, id: \.self) { switchNum in
                    HStack(spacing: 12) {
                        Image(systemName: "\(switchNum).circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 36)
                        Text("Switch \(switchNum)")
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        Text("Phrase \(switchNum) (\(positionName(switchNum)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            Text("Set the number of phrases per page (Settings → Edit Categories) to match the number of switches you want to use.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    private func positionName(_ position: Int) -> String {
        switch position {
        case 1: return "top-left"
        case 2: return "top-right"
        case 3: return "bottom-left"
        case 4: return "bottom-right"
        default: return "position \(position)"
        }
    }

    // MARK: - Scanning Options

    private var scanningOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.horizontal)

            Text("Scanning Speed")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                HStack {
                    Text("Auto-step interval")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1fs", settings.switchScanInterval))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.blue)
                }
                Slider(value: $settings.switchScanInterval, in: 0.5...5.0, step: 0.25)
                    .tint(.blue)
                HStack {
                    Text("Fast")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Slow")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

private struct SetupStepRow: View {
    let number: Int
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.body)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SwitchModeButton: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

private struct SwitchActionPicker: View {
    let label: String
    @Binding var selection: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 80, alignment: .leading)

            Picker(label, selection: $selection) {
                ForEach(SwitchAction.allCases) { action in
                    Label(action.displayName, systemImage: action.systemImage)
                        .tag(action.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)

            Spacer()

            Image(systemName: currentActionIcon)
                .foregroundColor(.blue)
                .frame(width: 24)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var currentActionIcon: String {
        (SwitchAction(rawValue: selection) ?? .select).systemImage
    }
}

private struct SwitchKeyPicker: View {
    let label: String
    @Binding var selection: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 80, alignment: .leading)

            Picker(label, selection: $selection) {
                ForEach(SwitchKeyMapping.allMappings) { mapping in
                    Text(mapping.displayName)
                        .tag(mapping.hidUsageCode)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)

            Spacer()

            Text(SwitchKeyMapping.displayName(for: selection))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        SwitchControlSettingsView()
            .environmentObject(GazeTrackingManager())
    }
}
