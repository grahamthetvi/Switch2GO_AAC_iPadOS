import SwiftUI

/// Settings for the ESP32 BLE HID switch interface (keyboard keys 1–4).
struct SwitchControlSettingsView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    private var mode: SwitchControlMode {
        SwitchControlMode.migrated(from: settings.switchControlMode)
    }

    private var phraseSlotCount: Int {
        min(max(settings.symbolCount, 2), 4)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                enableSection
                environmentalControlSection

                if settings.switchControlEnabled {
                    connectionStatusSection
                    Divider().padding(.horizontal)
                    controlModeSection
                    Divider().padding(.horizontal)

                    if mode == .scanning {
                        scanningModeSection
                    } else {
                        directPhraseModeSection
                    }

                    Divider().padding(.horizontal)
                    keyMappingSection
                    Divider().padding(.horizontal)
                    howItWorksSection
                }
            }
            .padding(.vertical)
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Switch Control")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { settingsHomeAction?() ?? dismiss() }) {
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
        .onChange(of: settings.symbolCount) { _, _ in
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.switchKey1) { _, _ in gazeManager.applySwitchSettings(settings) }
        .onChange(of: settings.switchKey2) { _, _ in gazeManager.applySwitchSettings(settings) }
        .onChange(of: settings.switchKey3) { _, _ in gazeManager.applySwitchSettings(settings) }
        .onChange(of: settings.switchKey4) { _, _ in gazeManager.applySwitchSettings(settings) }
    }

    // MARK: - Enable

    private var enableSection: some View {
        Toggle(isOn: $settings.switchControlEnabled) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("External Switches")
                        .font(.headline)
                    Text("ESP32 Bluetooth switch interface (Switch2GO-XXXX)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Environmental control (iPad → ESP32 → PowerLink)

    private var environmentalControlSection: some View {
        EnvironmentalControlCard(output: gazeManager.switchOutputManager)
    }

    // MARK: - Connection

    private var connectionStatusSection: some View {
        let mgr = gazeManager.switchManager

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(mgr.isConnected ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: mgr.isConnected ? "checkmark.circle.fill" : "keyboard")
                        .font(.title)
                        .foregroundColor(mgr.isConnected ? .green : .orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mgr.isConnected ? "Receiving input" : "Waiting for switch")
                        .font(.title3.bold())
                        .foregroundColor(mgr.isConnected ? .green : .secondary)

                    Text(connectionHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            if let event = mgr.lastSwitchEvent, event.isPress {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text(mgr.lastEventDescription(for: event))
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

    private var connectionHint: String {
        if gazeManager.switchManager.isConnected {
            return "Press a switch to test. Keys must match mapping below."
        }
        return "Pair Switch2GO-XXXX in iPad Settings → Bluetooth, then press a wired switch (or use BOOT multi-tap)."
    }

    // MARK: - Mode picker

    private var controlModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Control Mode")
                .font(.headline)
                .padding(.horizontal)

            ForEach(SwitchControlMode.allCases) { item in
                SwitchModeButton(
                    title: item.displayName,
                    description: item.detail,
                    icon: item.systemImage,
                    isSelected: mode == item
                ) {
                    settings.switchControlMode = item.rawValue
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Scanning (2 switches)

    private var scanningModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan & Select (2 switches)")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                roleRow(title: "Switch 1", role: "Select", detail: "Activates the highlighted phrase")
                roleRow(title: "Switch 2", role: "Next", detail: "Moves highlight to the next phrase")
            }
            .padding(.horizontal)

            Text("Scanning speed")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            VStack(spacing: 8) {
                HStack {
                    Text("Auto-highlight interval")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1fs", settings.switchScanInterval))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.blue)
                }
                Slider(value: $settings.switchScanInterval, in: 0.5...5.0, step: 0.25)
                    .tint(.blue)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func roleRow(title: String, role: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(role)
                    .font(.subheadline.bold())
                    .foregroundColor(.blue)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Direct phrase (2–4 switches)

    private var directPhraseModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Switch to Phrase (\(phraseSlotCount) switches)")
                .font(.headline)
                .padding(.horizontal)

            Text("Uses \(phraseSlotCount) phrases per page from Display settings. Each switch speaks one tile (left-to-right, top-to-bottom).")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(1...phraseSlotCount, id: \.self) { slot in
                    HStack(spacing: 12) {
                        Image(systemName: "\(slot).circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Switch \(slot)")
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        Text("Phrase \(slot) (\(positionName(slot)))")
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

    // MARK: - Key mapping

    private var keyMappingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Mapping")
                .font(.headline)
                .padding(.horizontal)

            Text(keyMappingFooter)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                if mode == .scanning {
                    SwitchKeyPicker(label: "Select switch", selection: $settings.switchKey1)
                    SwitchKeyPicker(label: "Next switch", selection: $settings.switchKey2)
                } else {
                    ForEach(1...phraseSlotCount, id: \.self) { slot in
                        SwitchKeyPicker(
                            label: "Switch \(slot)",
                            selection: keyBinding(for: slot)
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var keyMappingFooter: String {
        if mode == .scanning {
            return "Default: keys 1 and 2. Must match your switch device firmware."
        }
        return "Default: keys 1–\(phraseSlotCount). Must match your switch device firmware."
    }

    private func keyBinding(for slot: Int) -> Binding<Int> {
        switch slot {
        case 1: return $settings.switchKey1
        case 2: return $settings.switchKey2
        case 3: return $settings.switchKey3
        default: return $settings.switchKey4
        }
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                SetupStepRow(
                    number: 1,
                    icon: "antenna.radiowaves.left.and.right",
                    text: "Flash ESP32/Switch2GO_BLE_Switch and wire up to four switches (GPIO 12, 13, 14, 27)."
                )
                SetupStepRow(
                    number: 2,
                    icon: "keyboard",
                    text: "Pair Switch2GO-XXXX in iPad Settings → Bluetooth (not inside this app)."
                )
                SetupStepRow(
                    number: 3,
                    icon: "hand.tap",
                    text: mode == .scanning
                        ? "Use two switches to scan and select phrases."
                        : "Use one switch per phrase on screen (\(phraseSlotCount) total)."
                )
                SetupStepRow(
                    number: 4,
                    icon: "poweroutlet.type.b",
                    text: "For a fan or light: wire GPIO 26 through a relay or optocoupler to the PowerLink jack. Enable “Send switch output” on that phrase. After a firmware update, Forget Device and pair again."
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting views

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
            }
            Text(text)
                .font(.subheadline)
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

private struct SwitchKeyPicker: View {
    let label: String
    @Binding var selection: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.bold())
                .frame(minWidth: 100, alignment: .leading)
            Picker(label, selection: $selection) {
                ForEach(SwitchKeyMapping.allMappings) { mapping in
                    Text(mapping.displayName).tag(mapping.hidUsageCode)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
            Spacer()
            Text(SwitchKeyMapping.displayName(for: selection))
                .font(.caption)
                .foregroundColor(.secondary)
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

private struct EnvironmentalControlCard: View {
    @ObservedObject var output: ESP32SwitchOutputManager
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Control")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(output.isReady ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Image(systemName: output.isReady ? "poweroutlet.type.b.fill" : "poweroutlet.type.b")
                            .font(.title)
                            .foregroundColor(output.isReady ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(output.isReady ? "ESP32 output connected" : "ESP32 output")
                            .font(.title3.bold())
                            .foregroundColor(output.isReady ? .green : .primary)
                        Text(output.connectedDeviceName ?? output.state.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                Text("When a phrase with “Send switch output” is selected, the iPad pulses GPIO 26 on the ESP32. Wire that pin through a relay or optocoupler to the PowerLink switch jack.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Connect") {
                        output.startScanning()
                    }
                    .buttonStyle(.borderedProminent)

                    if output.isReady || settings.switchOutputPeripheralUUID != nil {
                        Button("Disconnect", role: .destructive) {
                            output.disconnect()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("Test pulse") {
                    _ = output.sendPulse()
                }
                .disabled(!output.isReady)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
