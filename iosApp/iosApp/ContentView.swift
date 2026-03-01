import SwiftUI
import Combine
import VocableShared

/// Main content view that hosts the AAC interface and gaze tracking overlay.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gazeManager = GazeTrackingManager()
    @StateObject private var settings = AppSettings.shared

    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showTrackingTip = false
    @State private var hasShownTrackingTip = false
    @State private var orientationBanner: OrientationBannerInfo?

    var body: some View {
        ZStack {
            // Main AAC Categories interface
            CategoriesView()
                .environmentObject(gazeManager)

            // Gaze pointer overlay (only when tracking)
            if gazeManager.isTracking && gazeManager.isCursorVisible && appState.isTrackingEnabled {
                GazePointerView(
                    position: gazeManager.gazePosition,
                    dwellProgress: gazeManager.dwellManager.dwellProgress,
                    isDwelling: gazeManager.dwellManager.hoveredButtonId != nil
                )
            }

            if settings.selectionMode != "none" && settings.enableOutOfBoundsHiding && gazeManager.isGazeOutOfBounds {
                GazeOutOfBoundsBanner()
            }

            if settings.selectionMode != "none" && settings.showTrackingErrorBanner && gazeManager.showTrackingError {
                TrackingLostBanner()
            }

            // Orientation mode banner (auto-dismisses)
            if let banner = orientationBanner {
                OrientationModeBanner(info: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // Floating controls (top-right to avoid nav bar overlap)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue.opacity(0.85))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .accessibilityLabel("Settings")

                        if settings.switchControlEnabled {
                            SwitchControlStatusBadge(switchManager: gazeManager.switchManager)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .background(settings.appBorderColor.ignoresSafeArea())
        .background(
            // Invisible UIKit key press interceptor for USB HID switch input.
            // Catches hardware key events through the responder chain as a
            // fallback when GCKeyboard doesn't detect the USB device.
            KeyPressInterceptorRepresentable(switchManager: gazeManager.switchManager)
                .allowsHitTesting(false)
        )
        .tint(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(settings.appBorderColor, lineWidth: 6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .alert("Tracking Tip", isPresented: $showTrackingTip) {
            Button("Got It") { }
        } message: {
            Text("If dwell selection isn't responding, try rotating your iPad to portrait and then back to landscape. This resets the tracking system and usually fixes it.")
        }
        .sheet(isPresented: $showSettings) {
            MainSettingsView()
                .environmentObject(appState)
                .environmentObject(gazeManager)
                .environment(\.settingsHomeAction, {
                    showSettings = false
                })
        }
        .onChange(of: showSettings) { _, isOpen in
            gazeManager.isSettingsOpen = isOpen
            if isOpen {
                // Pause tracking while the settings menu is open
                gazeManager.stopTracking()
            } else {
                // Resume tracking when settings is dismissed
                updateTrackingForSelectionMode()
                // Check if user requested to re-show onboarding
                if !settings.hasSeenOnboarding {
                    showOnboarding = true
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            WelcomeView()
        }
        .onAppear {
            if !settings.hasSeenOnboarding {
                showOnboarding = true
            }
            updateTrackingForSelectionMode()
        }
        .onChange(of: settings.selectionMode) { _, newMode in
            // Only restart tracking if settings sheet is closed.
            // If settings is open, tracking will restart when the sheet closes.
            if !showSettings {
                // Stop first to ensure a clean pipeline rebuild for the new mode
                gazeManager.stopTracking()
                updateTrackingForSelectionMode()
            }
        }
        .onChange(of: settings.switchControlEnabled) { _, _ in
            updateTrackingForSelectionMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RecenterGaze"))) { _ in
            gazeManager.recenter()
        }
        .onReceive(NotificationCenter.default.publisher(for: GazeTrackingManager.orientationTrackingChanged)) { notification in
            let trackingSupported = notification.object as? Bool ?? false
            showOrientationBanner(trackingSupported: trackingSupported)
        }
        .onDisappear {
            gazeManager.stopTracking()
        }
        // Re-sync button IDs for directMapping/scanning when buttons re-register
        .onReceive(
            Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        ) { _ in
            if settings.switchControlEnabled &&
               (settings.switchControlMode == "directMapping" || settings.switchControlMode == "scanning") {
                let ids = gazeManager.dwellManager.getOrderedButtonIds()
                let mgr = gazeManager.switchManager
                // Only update if the list actually changed
                if ids != mgr.currentScanButtonIds {
                    mgr.setScanButtons(ids)
                }
            }
        }
    }

    private func updateTrackingForSelectionMode() {
        let wantsTracking = settings.selectionMode != "none"
        let inTrackingOrientation = CameraManager.isTrackingSupportedOrientation
        let shouldTrack = wantsTracking && inTrackingOrientation

        DebugLog.info("updateTracking: mode=\(settings.selectionMode), orientation=\(inTrackingOrientation ? "OK" : "wrong"), shouldTrack=\(shouldTrack)", tag: "Tracking")

        appState.isTrackingEnabled = shouldTrack
        if shouldTrack {
            gazeManager.startTracking()
            if !hasShownTrackingTip {
                hasShownTrackingTip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showTrackingTip = true
                }
            }
        } else {
            gazeManager.stopTracking()
        }

        // Start/stop scanning mode based on switch control settings
        updateSwitchScanningMode()
    }

    private func showOrientationBanner(trackingSupported: Bool) {
        DebugLog.info("Orientation changed: tracking \(trackingSupported ? "supported" : "NOT supported")", tag: "Orientation")
        let info: OrientationBannerInfo
        if trackingSupported {
            info = OrientationBannerInfo(
                icon: "eye",
                title: "Head & Eye Tracking Active",
                subtitle: "Gaze cursor, dwell selection, switch, and touch controls available",
                color: .blue
            )
        } else {
            info = OrientationBannerInfo(
                icon: "hand.tap",
                title: "Touch & Switch Only",
                subtitle: "Rotate to landscape (home button right) for head/eye tracking",
                color: .orange
            )
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            orientationBanner = info
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [info] in
            withAnimation(.easeInOut(duration: 0.3)) {
                // Only dismiss if the banner hasn't changed
                if orientationBanner?.title == info.title {
                    orientationBanner = nil
                }
            }
        }
    }

    private func updateSwitchScanningMode() {
        let switchMgr = gazeManager.switchManager
        let buttonIds = gazeManager.dwellManager.getOrderedButtonIds()

        if settings.switchControlEnabled && settings.switchControlMode == "scanning" {
            switchMgr.setScanButtons(buttonIds)
            switchMgr.startScanningMode()
        } else if settings.switchControlEnabled && settings.switchControlMode == "directMapping" {
            // Direct mapping needs the button list so switch N can map to phrase N
            switchMgr.setScanButtons(buttonIds)
            switchMgr.stopScanningMode() // No auto-stepping in direct mapping
        } else {
            switchMgr.stopScanningMode()
        }
    }
}

/// Banner shown when gaze is out of bounds (user looking away from screen).
struct GazeOutOfBoundsBanner: View {
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash")
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gaze out of bounds")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Look back at the screen to resume")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .padding(.top, 20)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.opacity)
    }
}

/// Banner shown when face/eye tracking is not detected.
struct TrackingLostBanner: View {
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "face.dashed")
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracking lost")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Make sure your face is in view and well lit")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
            .padding(.top, 80)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.opacity)
    }
}

/// Gaze pointer overlay showing where the user is looking,
/// with dwell progress ring when hovering over a button.
struct GazePointerView: View {
    let position: CGPoint
    var dwellProgress: Double = 0
    var isDwelling: Bool = false

    var body: some View {
        ZStack {
            // Dwell progress ring (shown when hovering a button)
            if isDwelling {
                Circle()
                    .trim(from: 0, to: dwellProgress)
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }

            // Outer glow
            Circle()
                .fill((isDwelling ? Color.green : Color.blue).opacity(0.2))
                .frame(width: 60, height: 60)

            // Inner circle
            Circle()
                .fill((isDwelling ? Color.green : Color.blue).opacity(0.6))
                .frame(width: 30, height: 30)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
        }
        .position(position)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.08), value: position)
    }
}

/// Small badge showing USB switch control connection state.
struct SwitchControlStatusBadge: View {
    @ObservedObject var switchManager: SwitchControlManager

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(switchManager.isConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            Image(systemName: "keyboard")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((switchManager.isConnected ? Color.green : Color.orange).opacity(0.7))
        )
        .accessibilityLabel(
            switchManager.isConnected
                ? "USB switch connected"
                : "USB switch disconnected"
        )
    }
}

/// Data for the orientation mode banner.
struct OrientationBannerInfo: Equatable {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    static func == (lhs: OrientationBannerInfo, rhs: OrientationBannerInfo) -> Bool {
        lhs.title == rhs.title
    }
}

/// Banner shown when the device orientation changes to inform the user
/// which interaction modes are available in the current orientation.
struct OrientationModeBanner: View {
    let info: OrientationBannerInfo

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: info.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(info.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(info.color.opacity(0.85))
            .cornerRadius(12)
            .padding(.top, 20)
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}

/// SwiftUI wrapper that embeds the key press interceptor into the view hierarchy.
/// Catches hardware key events through UIKit's responder chain as a fallback
/// when GCKeyboard doesn't detect the USB HID device.
struct KeyPressInterceptorRepresentable: UIViewControllerRepresentable {
    let switchManager: SwitchControlManager

    func makeUIViewController(context: Context) -> KeyPressInterceptorViewController {
        let vc = KeyPressInterceptorViewController()
        vc.switchManager = switchManager
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: KeyPressInterceptorViewController, context: Context) {
        uiViewController.switchManager = switchManager
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
