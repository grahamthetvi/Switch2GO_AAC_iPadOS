import SwiftUI
import AVFoundation
import Combine
import VocableShared

private let mediaPlayPauseButtonId = "media_playpause"
private let mediaExitButtonId = "media_exit"
private let mediaPlaybackAllowedButtons: Set<String> = [mediaPlayPauseButtonId, mediaExitButtonId]

/// Fullscreen video/audio playback with gaze dwell controls.
struct MediaPlaybackOverlayView: View {
    @ObservedObject var coordinator: MediaPlaybackCoordinator
    @ObservedObject var dwellManager: DwellSelectionManager
    @ObservedObject var gazeManager: GazeTrackingManager
    var isTrackingEnabled: Bool
    @StateObject private var playerHolder = MediaPlayerHolder()
    @StateObject private var youtubeHolder = YouTubePlayerHolder()

    var body: some View {
        if coordinator.phase == .playing, let phrase = coordinator.activePhrase {
            ZStack {
                Color.black.ignoresSafeArea()

                if phrase.style?.isYouTube() == true {
                    youtubeContent(phrase: phrase)
                } else if phrase.style?.isVideo() == true {
                    videoContent(phrase: phrase)
                } else {
                    audioContent(phrase: phrase)
                }

                mediaGazeZones

                if isTrackingEnabled
                    && !GazeTrackingManager.isBodyGestureMode(AppSettings.shared.selectionMode)
                    && gazeManager.isTracking
                    && gazeManager.isCursorVisible {
                    GazePointerView(
                        position: gazeManager.gazePosition,
                        dwellProgress: dwellManager.dwellProgress,
                        isDwelling: dwellManager.hoveredButtonId != nil
                    )
                    .allowsHitTesting(false)
                }

                if coordinator.showCenterControls {
                    centerPlayPauseButton
                }

                if coordinator.showExitControl {
                    exitButton
                }
            }
            .contentShape(Rectangle())
            .zIndex(50)
            .onAppear {
                dwellManager.setAllowedButtonIds(mediaPlaybackAllowedButtons)
                dwellManager.clearAllButtons()
                preparePlayback(for: phrase)
            }
            .onDisappear {
                dwellManager.setAllowedButtonIds(nil)
                teardownPlayback()
            }
            .onChange(of: coordinator.isPaused) { _, paused in
                if phrase.style?.isYouTube() == true {
                    youtubeHolder.setPaused(paused)
                } else {
                    playerHolder.setPaused(paused)
                }
            }
            .onChange(of: coordinator.phase) { _, newPhase in
                if newPhase != .playing {
                    teardownPlayback()
                }
            }
        }
    }

    private func preparePlayback(for phrase: PhraseDisplayModel) {
        if phrase.style?.isYouTube() == true {
            guard let ref = phrase.style?.mediaRef,
                  PhraseStyle.companion.extractYouTubeVideoId(ref: ref) != nil else {
                coordinator.onNaturalEnd()
                return
            }
            youtubeHolder.onEnded = { [coordinator] in
                coordinator.onNaturalEnd()
            }
        } else {
            playerHolder.prepare(phrase: phrase, coordinator: coordinator)
        }
    }

    private func teardownPlayback() {
        youtubeHolder.stop()
        youtubeHolder.detach()
        playerHolder.teardown()
    }

    @ViewBuilder
    private func youtubeContent(phrase: PhraseDisplayModel) -> some View {
        if let ref = phrase.style?.mediaRef,
           let videoId = PhraseStyle.companion.extractYouTubeVideoId(ref: ref) {
            YouTubePlayerView(videoId: videoId, holder: youtubeHolder)
                .ignoresSafeArea()
        } else {
            Text("YouTube video unavailable")
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private func videoContent(phrase: PhraseDisplayModel) -> some View {
        if let player = playerHolder.player {
            ChromelessVideoPlayerView(player: player)
                .ignoresSafeArea()
        } else {
            Text("Video unavailable")
                .foregroundColor(.white)
        }
    }

    private func audioContent(phrase: PhraseDisplayModel) -> some View {
        PhraseFullscreenContent(phrase: phrase)
    }

    private var centerPlayPauseButton: some View {
        Button {
            coordinator.togglePlayPause()
        } label: {
            Image(systemName: coordinator.isPaused ? "play.circle.fill" : "pause.circle.fill")
                .font(.system(size: 88))
                .foregroundColor(.white)
                .shadow(radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(coordinator.isPaused ? "Play" : "Pause")
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
                .accessibilityLabel("Exit playback")
                Spacer()
            }
            Spacer()
        }
    }

    private var mediaGazeZones: some View {
        GeometryReader { geo in
            let globalOrigin = geo.frame(in: .global).origin
            let size = geo.size
            let centerFrame = CGRect(
                x: globalOrigin.x + size.width * 0.35,
                y: globalOrigin.y + size.height * 0.35,
                width: size.width * 0.3,
                height: size.height * 0.3
            )
            let exitFrame = CGRect(
                x: globalOrigin.x,
                y: globalOrigin.y + geo.safeAreaInsets.top,
                width: size.width * 0.15,
                height: size.height * 0.15
            )

            MediaGazeZoneRegistrar(
                id: mediaPlayPauseButtonId,
                frame: centerFrame,
                dwellManager: dwellManager,
                coordinator: coordinator,
                controlKind: .center
            )
            MediaGazeZoneRegistrar(
                id: mediaExitButtonId,
                frame: exitFrame,
                dwellManager: dwellManager,
                coordinator: coordinator,
                controlKind: .exit
            )
        }
        .allowsHitTesting(false)
    }
}

private enum MediaGazeControlKind {
    case center
    case exit
}

private struct MediaGazeZoneRegistrar: View {
    let id: String
    let frame: CGRect
    @ObservedObject var dwellManager: DwellSelectionManager
    @ObservedObject var coordinator: MediaPlaybackCoordinator
    let controlKind: MediaGazeControlKind

    var body: some View {
        Color.clear
            .onAppear { register() }
            .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
                register()
            }
            .onChange(of: dwellManager.hoveredButtonId) { _, hovered in
                switch controlKind {
                case .center:
                    coordinator.showCenterControls = hovered == id
                case .exit:
                    coordinator.showExitControl = hovered == id
                }
            }
            .onChange(of: dwellManager.activationToken) { _, _ in
                guard dwellManager.activatedButtonId == id else { return }
                switch controlKind {
                case .center:
                    coordinator.togglePlayPause()
                case .exit:
                    coordinator.stopEarly()
                }
            }
            .onDisappear {
                dwellManager.unregisterButton(id: id)
            }
    }

    private func register() {
        dwellManager.registerButton(id: id, frame: frame)
    }
}

/// Renders AVPlayer video with no system playback chrome.
struct ChromelessVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// Large phrase layout for audio fullscreen playback.
struct PhraseFullscreenContent: View {
    let phrase: PhraseDisplayModel

    var body: some View {
        GeometryReader { geometry in
            let hasImage = phrase.style?.imageRef?.isEmpty == false
            VStack(spacing: 24) {
                if hasImage, let style = phrase.style, let imageRef = style.imageRef, !imageRef.isEmpty {
                    CachedAsyncImage(imageRef: imageRef, renderSize: min(geometry.size.width, geometry.size.height) * 0.5)
                        .frame(maxWidth: geometry.size.width * 0.85)
                        .frame(maxHeight: geometry.size.height * 0.45)
                }
                Text(phrase.text)
                    .font(fullscreenFont(in: geometry.size))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
        }
        .ignoresSafeArea()
    }

    private var backgroundColor: Color {
        if let style = phrase.style, let bg = style.backgroundColor {
            return Color(hex: bg.uint32Value)
        }
        return .black
    }

    private var textColor: Color {
        if let style = phrase.style, let tc = style.textColor {
            return Color(hex: tc.uint32Value)
        }
        return .white
    }

    private func fullscreenFont(in size: CGSize) -> Font {
        let sp = phrase.style?.effectiveTextSize() ?? 18
        let scale = max(2.5, min(6.0, size.height / 120))
        let weight: Font.Weight = (phrase.style?.isBold == true) ? .bold : .medium
        return .system(size: CGFloat(sp) * scale, weight: weight)
    }
}

/// Owns AVPlayer lifecycle for overlay playback.
final class MediaPlayerHolder: ObservableObject {
    @Published var player: AVPlayer?

    private var endObserver: NSObjectProtocol?

    func prepare(phrase: PhraseDisplayModel, coordinator: MediaPlaybackCoordinator) {
        teardown()
        guard let ref = phrase.style?.mediaRef,
              let url = MediaStorage.resolveURL(mediaRef: ref) else {
            DispatchQueue.main.async {
                coordinator.onNaturalEnd()
            }
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        player = avPlayer

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            coordinator.onNaturalEnd()
        }

        avPlayer.play()
    }

    func setPaused(_ paused: Bool) {
        guard let player else { return }
        if paused {
            player.pause()
        } else {
            player.play()
        }
    }

    func teardown() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
    }
}
