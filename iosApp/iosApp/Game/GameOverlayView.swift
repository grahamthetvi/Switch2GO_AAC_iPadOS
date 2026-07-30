import SwiftUI
import Combine
import VocableShared

private let gameExitButtonId = "game_exit"
private let gameAllowedButtons: Set<String> = [gameExitButtonId]

/// Fullscreen game overlay with gaze dwell exit (top-left).
struct GameOverlayView: View {
    @ObservedObject var coordinator: GamePlaybackCoordinator
    @ObservedObject var dwellManager: DwellSelectionManager
    @ObservedObject var gazeManager: GazeTrackingManager
    @ObservedObject var settings: AppSettings
    var isTrackingEnabled: Bool

    @State private var touchTarget: CGPoint?
    @State private var touchRevealedExit = false

    var body: some View {
        if coordinator.phase == .playing, let phrase = coordinator.activePhrase {
            GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                gameContent(phrase: phrase, overlaySize: geo.size)

                gameGazeZones

                if GameSelectionMode.usesGaze(selectionMode: settings.selectionMode),
                   isTrackingEnabled,
                   gazeManager.isTracking,
                   gazeManager.isFaceDetected,
                   gazeManager.isCursorVisible {
                    GazePointerView(
                        position: gazeManager.gazePosition,
                        dwellProgress: dwellManager.dwellProgress,
                        isDwelling: dwellManager.hoveredButtonId != nil
                    )
                    .allowsHitTesting(false)
                }

                if coordinator.showExitControl || touchRevealedExit {
                    exitButton
                }
            }
            .contentShape(Rectangle())
            .zIndex(50)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchTarget = value.location
                        updateTouchReveal(at: value.location, in: geo.size, safeTop: geo.safeAreaInsets.top)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        touchTarget = value.location
                        updateTouchReveal(at: value.location, in: geo.size, safeTop: geo.safeAreaInsets.top)
                    }
            )
            .onAppear {
                dwellManager.setAllowedButtonIds(gameAllowedButtons)
                dwellManager.clearAllButtons()
            }
            .onDisappear {
                dwellManager.setAllowedButtonIds(nil)
            }
            .onChange(of: coordinator.phase) { _, newPhase in
                if newPhase != .playing {
                    touchTarget = nil
                    touchRevealedExit = false
                }
            }
            }
        }
    }

    private func updateTouchReveal(at location: CGPoint, in size: CGSize, safeTop: CGFloat) {
        if PlaybackOverlayControlZones.containsExit(location, in: size, safeTop: safeTop) {
            touchRevealedExit = true
        } else if !PlaybackOverlayControlZones.containsCenter(location, in: size) {
            touchRevealedExit = false
        }
    }

    @ViewBuilder
    private func gameContent(phrase: PhraseDisplayModel, overlaySize: CGSize) -> some View {
        GeometryReader { geo in
            let defaultCenter = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
            let gazeTarget: CGPoint? = {
                guard GameSelectionMode.usesGaze(selectionMode: settings.selectionMode),
                      isTrackingEnabled,
                      gazeManager.isTracking,
                      gazeManager.isFaceDetected,
                      gazeManager.isCursorVisible else { return nil }
                return gazeManager.gazePosition
            }()
            let target = touchTarget ?? gazeTarget ?? defaultCenter

            if phrase.style?.isCursorRocketGame() == true {
                CursorRocketGameView(target: target)
            } else if phrase.style?.isBlocsGameType() == true {
                let emoji = PhraseStyle.companion.extractEmoji(ref: phrase.style?.imageRef)
                let reward = (emoji?.isEmpty == false ? emoji : nil) ?? phrase.text
                BlocsGameView(target: target, rewardText: reward)
            } else if phrase.style?.isPieCrazyGameType() == true {
                PieCrazyGameView(target: target)
            } else {
                Text("Game unavailable")
                    .foregroundColor(.white)
            }
        }
    }

    private var exitButton: some View {
        VStack {
            HStack {
                Button {
                    coordinator.stopEarly()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                        .shadow(radius: 6)
                }
                .buttonStyle(.plain)
                .padding(24)
                .accessibilityLabel("Exit game")
                Spacer()
            }
            Spacer()
        }
    }

    private var gameGazeZones: some View {
        GeometryReader { geo in
            let globalOrigin = geo.frame(in: .global).origin
            let size = geo.size
            let exitFrame = CGRect(
                x: globalOrigin.x,
                y: globalOrigin.y + geo.safeAreaInsets.top,
                width: size.width * 0.15,
                height: size.height * 0.15
            )

            GameGazeZoneRegistrar(
                id: gameExitButtonId,
                frame: exitFrame,
                dwellManager: dwellManager,
                coordinator: coordinator
            )
        }
        .allowsHitTesting(false)
    }
}

private struct GameGazeZoneRegistrar: View {
    let id: String
    let frame: CGRect
    @ObservedObject var dwellManager: DwellSelectionManager
    @ObservedObject var coordinator: GamePlaybackCoordinator

    var body: some View {
        Color.clear
            .onAppear { register() }
            .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
                register()
            }
            .onChange(of: dwellManager.hoveredButtonId) { _, hovered in
                coordinator.showExitControl = hovered == id
            }
            .onChange(of: dwellManager.lastActivation) { _, activation in
                guard let activation, activation.buttonId == id else { return }
                coordinator.stopEarly()
            }
            .onDisappear {
                dwellManager.unregisterButton(id: id)
            }
    }

    private func register() {
        dwellManager.registerButton(id: id, frame: frame)
    }
}
