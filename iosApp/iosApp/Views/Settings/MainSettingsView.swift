import SwiftUI

/// Main settings screen with all options
struct MainSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @StateObject private var settings = AppSettings.shared

    @State private var debugTapCount = 0
    @State private var showDebugLog = false
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
                            Text("Recenter Cursor")
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

                        Button(action: openImageTool) {
                            settingsRow(
                                title: "Image Tool",
                                icon: "wand.and.stars",
                                color: .green
                            )
                        }
                        
                        Button(action: contactDeveloper) {
                            settingsRow(
                                title: "Contact Developer",
                                icon: "envelope.fill",
                                color: .teal
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
                        }
                    }
                    .padding(.horizontal)
                    
                    // App Version
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .background(settings.appBorderColor)
            .environment(\.colorScheme, settings.preferredColorScheme)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
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
                        Label("Home", systemImage: "house.fill")
                    }
                }
            }
            .toolbarBackground(settings.appBorderColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(navigationColorScheme, for: .navigationBar)
        }
    }
    
    private func settingsRow(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
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
}

#Preview {
    MainSettingsView()
}
