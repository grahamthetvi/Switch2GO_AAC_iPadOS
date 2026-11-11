import Foundation
import AVFoundation
import Combine

/// Manages text-to-speech functionality
class TTSManager: NSObject, ObservableObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    
    /// `var` so a wedged synthesizer can be replaced (see `rebuildSynthesizer`).
    private var synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentText: String = ""
    
    // TTS Settings. speak() takes rate and voice from AppSettings.
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var volume: Float = 1.0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    
    private var phraseQueue: [String] = []
    
    private var utteranceGeneration: UInt64 = 0

    /// The utterance from the latest speak(); used to ignore stale delegate callbacks.
    private var currentUtterance: AVSpeechUtterance?
    private var startWatchdog: DispatchWorkItem?
    /// AVSpeechSynthesizer sometimes accepts speak() and never starts (after an
    /// audio interruption, a media-services reset, or while the camera runs).
    /// If didStart has not arrived by then, rebuild and retry once.
    static let startTimeout: TimeInterval = 2.5

    private override init() {
        super.init()
        synthesizer.delegate = self
        applyVoice(for: AppSettings.shared.resolvedLanguage)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            DebugLog.warn("Audio services were reset; rebuilding speech synthesizer", tag: "TTSManager")
            self.startWatchdog?.cancel()
            self.rebuildSynthesizer()
            self.isSpeaking = false
            self.currentText = ""
            self.phraseQueue.removeAll()
        }
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                if self.synthesizer.isSpeaking {
                    self.synthesizer.pauseSpeaking(at: .word)
                }
            case .ended:
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.configureAudioSession()
                    if self.synthesizer.isPaused {
                        self.synthesizer.continueSpeaking()
                    }
                } else if self.synthesizer.isPaused {
                    // Don't leave a paused phrase that blocks the "speaking" state.
                    self.stop()
                }
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Speak text immediately (interrupts current speech)
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // AVSpeechSynthesizer + AVAudioSession changes must run on the main thread.
        // Defer one turn so session activation settles before enqueueing speech
        // (avoids silent no-ops while the camera capture session is active).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.configureAudioSession()

            self.utteranceGeneration &+= 1
            let generation = self.utteranceGeneration

            if self.synthesizer.isSpeaking || self.synthesizer.isPaused {
                self.synthesizer.stopSpeaking(at: .immediate)
            }

            self.currentText = trimmed
            let utterance = self.createUtterance(from: trimmed)
            DebugLog.info("Speaking: \"\(trimmed)\"", tag: "TTSManager")

            // stopSpeaking's didCancel can race an immediate speak(); defer one
            // turn so the cancelled utterance settles before the new one starts.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.utteranceGeneration == generation else { return }
                self.start(utterance, text: trimmed, generation: generation, isRetry: false)
            }
        }
    }

    private func start(_ utterance: AVSpeechUtterance, text: String, generation: UInt64, isRetry: Bool) {
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isSpeaking = true

        startWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.utteranceGeneration == generation,
                  self.currentUtterance === utterance else { return }
            if isRetry {
                DebugLog.error("Speech did not start after retry: \"\(text)\"", tag: "TTSManager")
                self.isSpeaking = false
                self.currentText = ""
                return
            }
            DebugLog.warn("Speech did not start in \(Self.startTimeout)s; rebuilding synthesizer and retrying", tag: "TTSManager")
            self.rebuildSynthesizer()
            self.configureAudioSession()
            // An utterance cannot be spoken twice; build a fresh one.
            self.start(self.createUtterance(from: text), text: text, generation: generation, isRetry: true)
        }
        startWatchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout, execute: work)
    }

    private func rebuildSynthesizer() {
        let old = synthesizer
        old.delegate = nil
        old.stopSpeaking(at: .immediate)
        let fresh = AVSpeechSynthesizer()
        fresh.delegate = self
        synthesizer = fresh
        currentUtterance = nil
    }
    
    /// Add text to queue (speaks after current finishes)
    func enqueue(_ text: String) {
        guard !text.isEmpty else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.enqueue(text) }
            return
        }

        configureAudioSession()
        
        phraseQueue.append(text)
        
        if !synthesizer.isSpeaking {
            speakNextInQueue()
        }
    }
    
    /// Stop speaking immediately
    func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        utteranceGeneration &+= 1
        startWatchdog?.cancel()
        startWatchdog = nil
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        phraseQueue.removeAll()
        isSpeaking = false
        currentText = ""
    }
    
    /// Pause speaking
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }
    
    /// Resume speaking
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    /// Get available voices, preferring the current AAC language.
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let language = AppSettings.shared.resolvedLanguage
        let prefixes = language.ttsLanguageCodes.map { $0.lowercased() }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let matching = voices.filter { voice in
            let code = voice.language.lowercased()
            return prefixes.contains { code.hasPrefix($0) || code.hasPrefix($0.replacingOccurrences(of: "-", with: "_")) }
        }
        if !matching.isEmpty {
            return matching.sorted { $0.name < $1.name }
        }
        return voices.sorted { $0.name < $1.name }
    }

    /// Pick the best installed voice for an AAC language.
    func applyVoice(for language: AppLanguage) {
        selectedVoice = Self.bestVoice(for: language)
    }

    static func bestVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for code in language.ttsLanguageCodes {
            if let exact = voices.first(where: { $0.language.caseInsensitiveCompare(code) == .orderedSame }) {
                return exact
            }
            let lowered = code.lowercased()
            if let prefix = voices.first(where: { $0.language.lowercased().hasPrefix(lowered) }) {
                return prefix
            }
        }
        return AVSpeechSynthesisVoice(language: language.ttsLanguageCodes.first)
    }

    /// Set voice by identifier
    func setVoice(identifier: String) {
        selectedVoice = AVSpeechSynthesisVoice(identifier: identifier)
    }
    
    /// Maps a 1.0-normal pace multiplier onto Apple's utterance rate, clamped to min/max.
    static func avSpeechRate(fromMultiplier multiplier: Double) -> Float {
        let clampedMultiplier = AppSettings.clampSpeechRate(multiplier)
        let rate = AVSpeechUtteranceDefaultSpeechRate * Float(clampedMultiplier)
        return min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }

    // MARK: - Private Methods

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        let identifier = AppSettings.shared.speechVoiceIdentifier
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        // No chosen voice, or it is not installed on this iPad (e.g. a restored
        // backup): use the AAC language's voice, not always US English.
        if let selectedVoice {
            return selectedVoice
        }
        return Self.bestVoice(for: AppSettings.shared.resolvedLanguage)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
    
    private func createUtterance(from text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Self.avSpeechRate(fromMultiplier: AppSettings.shared.speechRate)
        utterance.volume = volume
        utterance.voice = resolvedVoice()
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        return utterance
    }

    static let audioSessionOptions: AVAudioSession.CategoryOptions = [.duckOthers, .mixWithOthers]

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // mixWithOthers keeps TTS audible while the eye-tracking camera
        // capture session is running. (defaultToSpeaker is only valid with
        // playAndRecord; with playback it made every first attempt fail.)
        let options = Self.audioSessionOptions
        do {
            if session.category != .playback || session.mode != .spokenAudio || session.categoryOptions != options {
                try session.setCategory(.playback, mode: .spokenAudio, options: options)
            }
        } catch {
            DebugLog.error("Failed to set audio session category: \(error)", tag: "TTSManager")
        }
        do {
            try session.setActive(true, options: [])
        } catch {
            DebugLog.error("Failed to activate audio session: \(error)", tag: "TTSManager")
        }
    }
    
    private func speakNextInQueue() {
        guard !phraseQueue.isEmpty else {
            isSpeaking = false
            currentText = ""
            return
        }
        
        let text = phraseQueue.removeFirst()
        currentText = text
        let utterance = createUtterance(from: text)
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, synthesizer === self.synthesizer, utterance === self.currentUtterance else { return }
            self.startWatchdog?.cancel()
            self.startWatchdog = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, synthesizer === self.synthesizer else { return }
            // A finish for an older utterance must not end the current one.
            if let current = self.currentUtterance, current !== utterance { return }
            self.startWatchdog?.cancel()
            self.startWatchdog = nil
            self.currentUtterance = nil
            self.speakNextInQueue()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, synthesizer === self.synthesizer else { return }
            // A cancel for an older utterance must not clear the newer one.
            if let current = self.currentUtterance, current !== utterance { return }
            // A newer speak() may already be in flight after stopSpeaking.
            guard !self.synthesizer.isSpeaking else { return }
            self.isSpeaking = false
            self.currentText = ""
            self.phraseQueue.removeAll()
        }
    }
}
