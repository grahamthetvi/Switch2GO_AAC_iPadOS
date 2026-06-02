import Foundation
import Combine
import VocableShared

/// Arms delayed phrase media playback and drives fullscreen overlay state.
final class MediaPlaybackCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case armed
        case playing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activePhrase: PhraseDisplayModel?
    @Published var isPaused: Bool = false
    @Published var showCenterControls: Bool = false
    @Published var showExitControl: Bool = false

    private var armedPhrase: PhraseDisplayModel?
    private var idleWorkItem: DispatchWorkItem?
    private let settings = AppSettings.shared

    func onPhraseSelected(_ phrase: PhraseDisplayModel) {
        idleWorkItem?.cancel()
        idleWorkItem = nil

        guard phrase.style?.triggersDelayedPlayback() == true else {
            if phase == .armed {
                phase = .idle
                armedPhrase = nil
            }
            return
        }

        if phase == .playing {
            return
        }

        if armedPhrase?.id == phrase.id, phase == .armed {
            return
        }

        armedPhrase = phrase
        phase = .armed

        let work = DispatchWorkItem { [weak self] in
            self?.beginPlayback()
        }
        idleWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settings.mediaPlaybackDelay,
            execute: work
        )
    }

    func cancelPending() {
        idleWorkItem?.cancel()
        idleWorkItem = nil
        if phase == .armed {
            phase = .idle
            armedPhrase = nil
        }
    }

    func beginPlayback() {
        guard let phrase = armedPhrase,
              phrase.style?.triggersDelayedPlayback() == true else {
            phase = .idle
            return
        }
        idleWorkItem = nil
        armedPhrase = nil
        activePhrase = phrase
        isPaused = false
        showCenterControls = false
        showExitControl = false
        phase = .playing
        TTSManager.shared.stop()
    }

    func togglePlayPause() {
        isPaused.toggle()
    }

    func stopEarly() {
        tearDown()
    }

    func onNaturalEnd() {
        tearDown()
    }

    private func tearDown() {
        idleWorkItem?.cancel()
        idleWorkItem = nil
        armedPhrase = nil
        activePhrase = nil
        isPaused = false
        showCenterControls = false
        showExitControl = false
        phase = .idle
    }
}
