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
        // A clip that is already playing must not have its end timer disturbed.
        if phase == .playing {
            return
        }

        guard phrase.style?.triggersDelayedPlayback() == true else {
            idleWorkItem?.cancel()
            idleWorkItem = nil
            if phase == .armed {
                phase = .idle
                armedPhrase = nil
            }
            return
        }

        // Repeat dwell calls this again every second. Canceling a live timer
        // here, then returning, left the phrase armed forever. Keeping the
        // original countdown lets the clip start after mediaPlaybackDelay.
        if phase == .armed, armedPhrase?.id == phrase.id, idleWorkItem != nil {
            armedPhrase = phrase
            return
        }

        idleWorkItem?.cancel()
        idleWorkItem = nil

        armedPhrase = phrase
        phase = .armed

        let delay = max(0.0, settings.mediaPlaybackDelay)
        let work = DispatchWorkItem { [weak self] in
            self?.beginPlayback()
        }
        idleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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
