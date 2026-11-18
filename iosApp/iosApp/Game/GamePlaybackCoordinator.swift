import Foundation
import Combine
import VocableShared

/// Arms delayed phrase games and drives fullscreen game overlay state.
final class GamePlaybackCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case armed
        case playing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var activePhrase: PhraseDisplayModel?
    @Published var showExitControl: Bool = false
    @Published var unsupportedGameNotice: String?

    private var armedPhrase: PhraseDisplayModel?
    private var idleWorkItem: DispatchWorkItem?
    private var noticeDismissWorkItem: DispatchWorkItem?
    private let settings = AppSettings.shared

    func clearUnsupportedGameNotice() {
        noticeDismissWorkItem?.cancel()
        noticeDismissWorkItem = nil
        unsupportedGameNotice = nil
    }

    func onPhraseSelected(_ phrase: PhraseDisplayModel) {
        if phase == .playing {
            return
        }

        guard phrase.style?.triggersDelayedGame() == true else {
            idleWorkItem?.cancel()
            idleWorkItem = nil
            if phase == .armed {
                phase = .idle
                armedPhrase = nil
            }
            return
        }

        guard GameSelectionMode.supportsGames(selectionMode: settings.selectionMode) else {
            idleWorkItem?.cancel()
            idleWorkItem = nil
            showUnsupportedGameNotice()
            if phase == .armed {
                phase = .idle
                armedPhrase = nil
            }
            return
        }
        clearUnsupportedGameNotice()

        // Same contract as media playback: a live countdown for this phrase
        // survives repeat-dwell ticks. Canceling it first, then returning,
        // armed the game and never launched it.
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
            self?.beginGame()
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

    func beginGame() {
        guard let phrase = armedPhrase,
              phrase.style?.triggersDelayedGame() == true,
              GameSelectionMode.supportsGames(selectionMode: settings.selectionMode) else {
            phase = .idle
            return
        }
        idleWorkItem = nil
        armedPhrase = nil
        activePhrase = phrase
        showExitControl = false
        phase = .playing
        TTSManager.shared.stop()
    }

    func stopEarly() {
        tearDown()
    }

    private func tearDown() {
        idleWorkItem?.cancel()
        idleWorkItem = nil
        armedPhrase = nil
        activePhrase = nil
        showExitControl = false
        phase = .idle
    }

    private func showUnsupportedGameNotice() {
        unsupportedGameNotice = GameSelectionMode.unsupportedMessage(
            selectionMode: settings.selectionMode
        )
        noticeDismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.unsupportedGameNotice = nil
        }
        noticeDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: work)
    }
}
