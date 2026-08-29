import SwiftUI
import Combine
import VocableShared
import AVFoundation

/// Main content view that hosts the AAC interface and gaze tracking overlay.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var phrasePacks: PhrasePackSession
    @StateObject private var gazeManager = GazeTrackingManager()
    @StateObject private var mediaCoordinator = MediaPlaybackCoordinator()
    @StateObject private var gameCoordinator = GamePlaybackCoordinator()
    @StateObject private var settings = AppSettings.shared

    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var orientationBanner: OrientationBannerInfo?
    @State private var currentOrientationText: String = "Unknown"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Main AAC Categories interface
            CategoriesView()
                .environmentObject(gazeManager)
                .environmentObject(mediaCoordinator)
                .environmentObject(gameCoordinator)
                .environmentObject(phrasePacks)

            MediaPlaybackOverlayView(
                coordinator: mediaCoordinator,
                dwellManager: gazeManager.dwellManager,
                gazeManager: gazeManager,
                isTrackingEnabled: appState.isTrackingEnabled
            )

            GameOverlayView(
                coordinator: gameCoordinator,
                dwellManager: gazeManager.dwellManager,
                gazeManager: gazeManager,
                settings: settings,
                isTrackingEnabled: appState.isTrackingEnabled
            )

            // Gaze pointer — hidden when face lost / cursor hidden / body-gesture modes
            if !GazeTrackingManager.isBodyGestureMode(settings.selectionMode)
                && gazeManager.isTracking && gazeManager.isFaceDetected
                && gazeManager.isCursorVisible && appState.isTrackingEnabled
                && mediaCoordinator.phase != .playing
                && gameCoordinator.phase != .playing {
                GazePointerView(
                    position: gazeManager.gazePosition,
                    dwellProgress: gazeManager.dwellManager.dwellProgress,
                    isDwelling: gazeManager.dwellManager.hoveredButtonId != nil
                )
            }

            if settings.selectionMode != "none"
                && !GazeTrackingManager.isBodyGestureMode(settings.selectionMode)
                && settings.enableOutOfBoundsHiding
                && gazeManager.isGazeOutOfBounds {
                GazeOutOfBoundsBanner()
            }

            if settings.selectionMode != "none"
                && settings.showTrackingErrorBanner
                && gazeManager.showTrackingError {
                if GazeTrackingManager.isBodyGestureMode(settings.selectionMode),
                   let message = gazeManager.bodyTrackingErrorMessage {
                    TrackingLostBanner(message: message)
                } else if !GazeTrackingManager.isBodyGestureMode(settings.selectionMode) {
                    TrackingLostBanner()
                }
            }

            if let gameNotice = gameCoordinator.unsupportedGameNotice {
                GameUnsupportedBanner(message: gameNotice) {
                    gameCoordinator.clearUnsupportedGameNotice()
                }
            }

            if let toast = phrasePacks.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .padding()
                }
                .zIndex(30)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if phrasePacks.toastMessage == toast {
                            phrasePacks.toastMessage = nil
                        }
                    }
                }
            }

            // Orientation mode banner (auto-dismisses)
            if let banner = orientationBanner {
                OrientationModeBanner(info: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // Debug Camera Preview
            if settings.showDebugCameraPreview && appState.isTrackingEnabled {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            CameraPreviewView(session: gazeManager.cameraManager.captureSession)
                                .frame(width: 160, height: 120)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                            
                            Text("Feed: \(Int(gazeManager.cameraManager.currentVideoRotationAngle))° | UI: \(currentOrientationText)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                        .padding()
                        Spacer()
                    }
                }
                .zIndex(20)
            }
        }
        .coordinateSpace(name: GazeCoordinateSpace.name)
        .ignoresSafeArea()
        .background(settings.appBorderColor.ignoresSafeArea())
        .background(
            // Invisible UIKit key press interceptor for BLE HID switch input.
            // Catches hardware key events through the responder chain as a
            // fallback when GCKeyboard doesn't detect the ESP32 keyboard.
            KeyPressInterceptorRepresentable(switchManager: gazeManager.switchManager)
                .allowsHitTesting(false)
        )
        // Overlay keeps settings clear of the status bar / Dynamic Island.
        // Explicit window inset is required because .ignoresSafeArea() zeroes
        // SwiftUI safe-area padding for descendants/overlays.
        .overlay(alignment: .topTrailing) {
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
            .padding(.trailing, 16)
            .padding(.top, windowTopSafeInset + 8)
        }
        .tint(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(settings.appBorderColor, lineWidth: 6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .sheet(isPresented: $showSettings) {
            MainSettingsView()
                .environmentObject(appState)
                .environmentObject(gazeManager)
                .environmentObject(phrasePacks)
                .environment(\.settingsHomeAction, {
                    showSettings = false
                })
        }
        .onChange(of: showSettings) { _, isOpen in
            updateModalTracking()
            if isOpen {
                gazeManager.stopTracking()
            } else {
                if !showOnboarding && !phrasePacks.showImportSheet {
                    updateTrackingForSelectionMode()
                }
                if !settings.hasSeenOnboarding {
                    showOnboarding = true
                }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            WelcomeView()
        }
        .onChange(of: showOnboarding) { _, isOpen in
            updateModalTracking()
            if isOpen {
                gazeManager.stopTracking()
            } else {
                if !showSettings && !phrasePacks.showImportSheet {
                    updateTrackingForSelectionMode()
                }
                // Show orientation banner after onboarding if not in the right orientation
                let inTrackingOrientation = CameraManager.isTrackingSupportedOrientation
                showOrientationBanner(trackingSupported: inTrackingOrientation)
            }
        }
        .onChange(of: phrasePacks.showImportSheet) { _, isOpen in
            updateModalTracking()
            if isOpen {
                gazeManager.stopTracking()
            } else if !showSettings && !showOnboarding {
                updateTrackingForSelectionMode()
            }
        }
        .onAppear {
            if !settings.hasSeenOnboarding {
                showOnboarding = true
            }
            updateTrackingForSelectionMode()
            
            // Keep the screen on while the app is active
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                gazeManager.handleScenePhase("active")
            case .inactive:
                gazeManager.handleScenePhase("inactive")
            case .background:
                gazeManager.handleScenePhase("background")
            @unknown default:
                break
            }
        }
        .onChange(of: settings.selectionMode) { _, newMode in
            // Only restart tracking if settings sheet is closed.
            // If settings is open, tracking will restart when the sheet closes.
            if !showSettings {
                // Stop first to ensure a clean pipeline rebuild for the new mode
                gazeManager.stopTracking()
                updateTrackingForSelectionMode()
            }
            if !GameSelectionMode.supportsGames(selectionMode: newMode) {
                gameCoordinator.cancelPending()
                if gameCoordinator.phase == .playing {
                    gameCoordinator.stopEarly()
                }
            } else {
                gameCoordinator.clearUnsupportedGameNotice()
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
            updateOrientationText()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientationText()
        }
        .onAppear {
            updateOrientationText()
        }
        .onDisappear {
            gazeManager.stopTracking()
            
            // Allow the screen to turn off again when the app is no longer active
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: settings.switchControlMode) { _, _ in
            updateSwitchScanningMode()
            gazeManager.applySwitchSettings(settings)
        }
        .onChange(of: settings.symbolCount) { _, _ in
            gazeManager.applySwitchSettings(settings)
            updateSwitchScanningMode()
        }
        // Re-sync phrase button IDs when the grid changes
        .onReceive(
            Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        ) { _ in
            guard settings.switchControlEnabled else { return }
            let ids = gazeManager.dwellManager.getOrderedButtonIds()
            let mgr = gazeManager.switchManager
            if ids != mgr.currentScanButtonIds {
                mgr.setPhraseButtons(ids)
            }
        }
    }

    /// Top safe-area inset from the key window. Needed because the AAC ZStack
    /// uses `.ignoresSafeArea()`, which collapses SwiftUI safe-area padding.
    private var windowTopSafeInset: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            return 59
        }
        let inset = scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.top
            ?? scene.windows.first?.safeAreaInsets.top
            ?? 0
        return inset > 0 ? inset : 59
    }

    private func updateModalTracking() {
        gazeManager.isModalOpen = showSettings || showOnboarding || phrasePacks.showImportSheet
    }

    private func updateTrackingForSelectionMode() {
        let wantsTracking = settings.selectionMode != "none"
        let inTrackingOrientation = CameraManager.isTrackingSupportedOrientation
        let shouldTrack = wantsTracking && inTrackingOrientation

        DebugLog.info("updateTracking: mode=\(settings.selectionMode), orientation=\(inTrackingOrientation ? "OK" : "wrong"), shouldTrack=\(shouldTrack)", tag: "Tracking")

        appState.isTrackingEnabled = shouldTrack
        if shouldTrack {
            gazeManager.startTracking()
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
        gazeManager.applySwitchSettings(settings)

        guard settings.switchControlEnabled else {
            switchMgr.stopScanning()
            return
        }

        switchMgr.setPhraseButtons(buttonIds)

        if settings.switchControlMode == SwitchControlMode.scanning.rawValue {
            switchMgr.startScanning()
        } else {
            switchMgr.stopScanning()
        }
    }
    
    private func updateOrientationText() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            currentOrientationText = "Unknown"
            return
        }
        
        let orientation: UIInterfaceOrientation
        if #available(iOS 18.0, *) {
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }
        
        switch orientation {
        case .portrait: currentOrientationText = "Portrait"
        case .portraitUpsideDown: currentOrientationText = "Portrait Upside Down"
        case .landscapeLeft: currentOrientationText = "Landscape Left"
        case .landscapeRight: currentOrientationText = "Landscape Right"
        case .unknown: currentOrientationText = "Unknown"
        @unknown default: currentOrientationText = "Unknown"
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

/// Banner shown when face/eye or body tracking is not detected.
struct TrackingLostBanner: View {
    var message: String = "Make sure your face is in view and well lit"

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracking lost")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(message)
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

/// Small badge showing external switch device connection state.
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
                ? "Switch device connected"
                : "Switch device not detected"
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
/// when GCKeyboard doesn't detect the BLE keyboard.
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

/// A SwiftUI view that displays the camera feed from an AVCaptureSession.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PhrasePackSession())
}
