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

    var body: some View {
        if coordinator.phase == .playing, let phrase = coordinator.activePhrase {
            ZStack {
                Color.black.ignoresSafeArea()

                gameContent(phrase: phrase)

                gameGazeZones

                if GameSelectionMode.usesGaze(selectionMode: settings.selectionMode),
                   isTrackingEnabled,
                   gazeManager.isTracking,
                   gazeManager.isCursorVisible {
                    GazePointerView(
                        position: gazeManager.gazePosition,
                        dwellProgress: dwellManager.dwellProgress,
                        isDwelling: dwellManager.hoveredButtonId != nil
                    )
                    .allowsHitTesting(false)
                }

                if GameSelectionMode.usesTouch(selectionMode: settings.selectionMode) || coordinator.showExitControl {
                    exitButton
                }
            }
            .contentShape(Rectangle())
            .zIndex(50)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { touchTarget = $0.location }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        touchTarget = value.location
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
                }
            }
        }
    }

    @ViewBuilder
    private func gameContent(phrase: PhraseDisplayModel) -> some View {
        GeometryReader { geo in
            let defaultCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let gazeTarget: CGPoint? = {
                guard GameSelectionMode.usesGaze(selectionMode: settings.selectionMode),
                      isTrackingEnabled,
                      gazeManager.isTracking,
                      gazeManager.isCursorVisible else { return nil }
                return gazeManager.gazePosition
            }()
            let target = gazeTarget ?? touchTarget ?? defaultCenter

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
            .onChange(of: dwellManager.activationToken) { _, _ in
                guard dwellManager.activatedButtonId == id else { return }
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
