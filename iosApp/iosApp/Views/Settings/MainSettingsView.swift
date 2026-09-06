import SwiftUI

/// Main settings screen with all options
struct MainSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @StateObject private var settings = AppSettings.shared

    @State private var debugTapCount = 0
    // We use @AppStorage here so the debug menu stays unlocked across sessions
    // once the user unlocks it by tapping 10 times.
    @AppStorage("isDeveloperModeUnlocked") private var showDebugLog = false
    @State private var lastDebugTap = Date.distantPast
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Button(action: {
                        NotificationCenter.default.post(name: Notification.Name("RecenterGaze"), object: nil)
                    }) {
                        HStack {
                            Image(systemName: "crosshair")
                                .font(.title3)
                                .foregroundColor(.white)
                            Text(l10n: "Recenter Cursor")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.9))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Settings Options Grid
                    VStack(spacing: 12) {
                        NavigationLink(destination: EditCategoriesListView()) {
                            settingsRow(
                                title: "Edit Categories & Phrases",
                                icon: "folder.fill",
                                color: .blue
                            )
                        }

                        NavigationLink(destination: LanguageSettingsView()) {
                            settingsRow(
                                title: "Language",
                                icon: "globe",
                                color: .mint,
                                subtitle: settings.followsSystemLanguage
                                    ? L("Use iPad language")
                                    : settings.resolvedLanguage.nativeName
                            )
                        }

                        NavigationLink(destination: PhrasePackSettingsView()) {
                            settingsRow(
                                title: "Phrase Packs",
                                icon: "square.and.arrow.up.on.square",
                                color: .teal
                            )
                        }
                        
                        NavigationLink(destination: TimingSensitivityView()) {
                            settingsRow(
                                title: "Timing & Sensitivity",
                                icon: "timer",
                                color: .orange
                            )
                        }

                        NavigationLink(destination: AppBorderColorView()) {
                            settingsRow(
                                title: "App Border Color",
                                icon: "square.on.square",
                                color: .indigo
                            )
                        }
                        
                        NavigationLink(destination: SelectionModeView()) {
                            settingsRow(
                                title: "Selection Mode",
                                icon: "hand.point.up.left.fill",
                                color: .purple
                            )
                        }
                        
                        NavigationLink(destination: AdvancedEyeTrackingView()) {
                            settingsRow(
                                title: "Advanced Eye Tracking",
                                icon: "eye.fill",
                                color: .green
                            )
                        }
                        
                        NavigationLink(destination: DataBackupView()) {
                            settingsRow(
                                title: "Backup & Restore",
                                icon: "externaldrive.fill",
                                color: .teal
                            )
                        }

                        NavigationLink(destination: ResetAppView()) {
                            settingsRow(
                                title: "Reset App",
                                icon: "arrow.counterclockwise",
                                color: .red
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Info Section
                    VStack(spacing: 12) {
                        Button(action: {
                            AppSettings.shared.hasSeenOnboarding = false
                            dismiss()
                        }) {
                            settingsRow(
                                title: "Show Welcome Guide",
                                icon: "book.fill",
                                color: .blue
                            )
                        }

                        NavigationLink(destination: TroubleshootingView()) {
                            settingsRow(
                                title: "Troubleshooting",
                                icon: "wrench.and.screwdriver.fill",
                                color: .orange
                            )
                        }

                        NavigationLink(destination: PrivacyPolicyView()) {
                            settingsRow(
                                title: "Privacy Policy",
                                icon: "hand.raised.fill",
                                color: .gray
                            )
                        }

                        NavigationLink(destination: ThirdPartyNoticesView()) {
                            settingsRow(
                                title: "Open-Source Licenses",
                                icon: "doc.text.fill",
                                color: .gray
                            )
                        }

                        Button(action: openImageTool) {
                            settingsRow(
                                title: "Image Tool",
                                icon: "wand.and.stars",
                                color: .green
                            )
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS_Explanation_and_Support/index.html") {
                                openURL(url)
                            }
                        }) {
                            settingsRow(
                                title: "Get Support",
                                icon: "questionmark.circle.fill",
                                color: .blue,
                                subtitle: "Privacy policy, app features, support, and create phrase images (Wikimedia or upload with outline)."
                            )
                        }

                        if showDebugLog {
                            NavigationLink(destination: DebugLogView()) {
                                settingsRow(
                                    title: "Debug Log",
                                    icon: "ladybug.fill",
                                    color: .red
                                )
                            }
                            
                            Toggle(isOn: $settings.showDebugCameraPreview) {
                                HStack {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .frame(width: 40)
                                    Text("Debug Camera Preview")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            Toggle(isOn: $settings.enableTrackingDiagnostics) {
                                HStack {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .frame(width: 40)
                                    Text("Tracking Diagnostics")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .frame(width: 40)
                                    Text("Camera Feed Rotation")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                Picker("Rotation (Override)", selection: $settings.debugCameraRotation) {
                                    Text("Auto").tag(-1.0)
                                    Text("0°").tag(0.0)
                                    Text("90°").tag(90.0)
                                    Text("180°").tag(180.0)
                                    Text("270°").tag(270.0)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: settings.debugCameraRotation) { _, _ in
                                    NotificationCenter.default.post(name: NSNotification.Name("DebugCameraRotationChanged"), object: nil)
                                }
                                
                                Text(L("Current Device Orientation: %@", currentOrientationString()))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // App Version
                    Text(L("Version %@", appVersion))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .background(settings.appBorderColor)
            .environment(\.colorScheme, settings.preferredColorScheme)
            .navigationTitle(Text(l10n: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(l10n: "Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(navigationColorScheme == .dark ? .white : .black)
                        .onTapGesture {
                            let now = Date()
                            if now.timeIntervalSince(lastDebugTap) > 3 {
                                debugTapCount = 0
                            }
                            lastDebugTap = now
                            debugTapCount += 1
                            if debugTapCount >= 10 {
                                showDebugLog = true
                                debugTapCount = 0
                            }
                        }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        settingsHomeAction?() ?? dismiss()
                    }) {
                        Label(L("Home"), systemImage: "house.fill")
                    }
                }
            }
            .toolbarBackground(settings.appBorderColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(navigationColorScheme, for: .navigationBar)
        }
    }
    
    private func settingsRow(title: String, icon: String, color: Color, subtitle: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            if let subtitle = subtitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n: title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(l10n: subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(l10n: title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func contactDeveloper() {
        let email = "grahamthetvi@icloud.com"
        let subject = "Feedback for Switch2Go iOS \(appVersion)"
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            openURL(url)
        }
    }

    private func openImageTool() {
        guard let url = URL(string: "https://switch2goaac.org/index.html#image-tool") else { return }
        openURL(url)
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var navigationColorScheme: ColorScheme {
        settings.preferredColorScheme
    }
    
    private func currentOrientationString() -> String {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            return "Unknown"
        }
        
        let orientation: UIInterfaceOrientation
        if #available(iOS 18.0, *) {
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }
        
        switch orientation {
        case .portrait: return "Portrait (Camera Top)"
        case .portraitUpsideDown: return "Portrait Upside Down (Camera Bottom)"
        case .landscapeLeft: return "Landscape Left (Camera Right)"
        case .landscapeRight: return "Landscape Right (Camera Left)"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    MainSettingsView()
}
