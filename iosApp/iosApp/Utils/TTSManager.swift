import Foundation
import AVFoundation
import Combine

/// Manages text-to-speech functionality
class TTSManager: NSObject, ObservableObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    
    private var synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentText: String = ""
    
    // TTS Settings
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var volume: Float = 1.0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    
    private var phraseQueue: [String] = []
    
    private var utteranceGeneration: UInt64 = 0
    private var activeUtterance: AVSpeechUtterance?
    private var activeUtteranceDidStart = false
    private var activeUtteranceRetryCount = 0
    private var utteranceStartWatchdogWorkItem: DispatchWorkItem?
    private var utteranceWatchdogWorkItem: DispatchWorkItem?
    private var isAudioSessionConfigured = false

    private override init() {
        super.init()
        synthesizer.delegate = self
        selectedVoice = AVSpeechSynthesisVoice(language: "en-US")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    deinit {
        utteranceStartWatchdogWorkItem?.cancel()
        utteranceWatchdogWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.isAudioSessionConfigured = false
                if self.synthesizer.isSpeaking {
                    self.synthesizer.pauseSpeaking(at: .word)
                }
            case .ended:
                self.configureAudioSession(force: true)
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume), self.synthesizer.isPaused {
                        self.synthesizer.continueSpeaking()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAudioSessionConfigured = false
            if self.isSpeaking {
                self.configureAudioSession(force: true)
            }
        }
    }

    @objc private func handleMediaServicesWereReset(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            DebugLog.warn("Media services were reset — recreating AVSpeechSynthesizer", tag: "TTSManager")
            self.utteranceStartWatchdogWorkItem?.cancel()
            self.utteranceStartWatchdogWorkItem = nil
            self.utteranceWatchdogWorkItem?.cancel()
            self.utteranceWatchdogWorkItem = nil
            self.utteranceGeneration &+= 1
            self.activeUtterance = nil
            self.activeUtteranceDidStart = false
            self.activeUtteranceRetryCount = 0
            self.phraseQueue.removeAll()
            self.isSpeaking = false
            self.currentText = ""
            self.isAudioSessionConfigured = false

            self.synthesizer.delegate = nil
            let newSynthesizer = AVSpeechSynthesizer()
            newSynthesizer.delegate = self
            self.synthesizer = newSynthesizer

            self.configureAudioSession(force: true)
        }
    }
    
    // MARK: - Public Methods
    
    /// Speak text immediately (interrupts current speech)
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if Thread.isMainThread {
            performSpeak(trimmed)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performSpeak(trimmed)
            }
        }
    }

    private func performSpeak(_ trimmed: String) {
        configureAudioSession()

        utteranceGeneration &+= 1
        let generation = utteranceGeneration

        phraseQueue.removeAll()

        let wasActive = (activeUtterance != nil || synthesizer.isSpeaking || synthesizer.isPaused)
        if wasActive {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = createUtterance(from: trimmed)
        activeUtterance = utterance
        activeUtteranceDidStart = false
        activeUtteranceRetryCount = 0
        currentText = trimmed
        isSpeaking = true
        DebugLog.info("Speaking: \"\(trimmed)\"", tag: "TTSManager")

        scheduleUtteranceWatchdog(for: utterance, text: trimmed, generation: generation)
        synthesizer.speak(utterance)
    }
    
    /// Add text to queue (speaks after current finishes)
    func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let work = { [weak self] in
            guard let self else { return }
            self.configureAudioSession()
            self.phraseQueue.append(trimmed)

            if !self.isSpeaking && self.activeUtterance == nil && !self.synthesizer.isSpeaking {
                self.speakNextInQueue()
            }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
    
    /// Stop speaking immediately
    func stop() {
        let work = { [weak self] in
            guard let self else { return }
            self.utteranceStartWatchdogWorkItem?.cancel()
            self.utteranceStartWatchdogWorkItem = nil
            self.utteranceWatchdogWorkItem?.cancel()
            self.utteranceWatchdogWorkItem = nil
            self.utteranceGeneration &+= 1
            self.activeUtterance = nil
            self.activeUtteranceDidStart = false
            self.activeUtteranceRetryCount = 0
            self.synthesizer.stopSpeaking(at: .immediate)
            self.phraseQueue.removeAll()
            self.isSpeaking = false
            self.currentText = ""
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
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
            configureAudioSession()
            synthesizer.continueSpeaking()
        }
    }
    
    /// Get all available voices for current language
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }
    
    /// Set voice by identifier
    func setVoice(identifier: String) {
        selectedVoice = AVSpeechSynthesisVoice(identifier: identifier)
    }

    /// Ensures the shared AVAudioSession is configured and active for playback
    /// alongside the camera capture session. Called before TTS and media clip playback.
    func ensureAudioSessionActive() {
        configureAudioSession(force: false)
    }
    
    // MARK: - Private Methods
    
    private func createUtterance(from text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.voice = selectedVoice
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        return utterance
    }

    private func configureAudioSession(force: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        if !force && isAudioSessionConfigured && session.category == .playback {
            return
        }
        do {
            // mixWithOthers keeps TTS and media clips audible while the eye-tracking
            // camera capture session runs. Note: .defaultToSpeaker is only valid with
            // .playAndRecord and throws OSStatus -50 if passed to .playback.
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers]
            )
            try session.setActive(true, options: [])
            isAudioSessionConfigured = true
        } catch {
            DebugLog.error("Failed to configure audio session: \(error)", tag: "TTSManager")
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true, options: [])
                isAudioSessionConfigured = true
            } catch {
                DebugLog.error("Audio session fallback failed: \(error)", tag: "TTSManager")
            }
        }
    }
    
    private func speakNextInQueue() {
        guard !phraseQueue.isEmpty else {
            utteranceStartWatchdogWorkItem?.cancel()
            utteranceStartWatchdogWorkItem = nil
            utteranceWatchdogWorkItem?.cancel()
            utteranceWatchdogWorkItem = nil
            activeUtterance = nil
            activeUtteranceDidStart = false
            activeUtteranceRetryCount = 0
            isSpeaking = false
            currentText = ""
            return
        }
        
        let text = phraseQueue.removeFirst()
        utteranceGeneration &+= 1
        let generation = utteranceGeneration
        let utterance = createUtterance(from: text)
        activeUtterance = utterance
        activeUtteranceDidStart = false
        activeUtteranceRetryCount = 0
        currentText = text
        isSpeaking = true
        scheduleUtteranceWatchdog(for: utterance, text: text, generation: generation)
        synthesizer.speak(utterance)
    }

    private func scheduleUtteranceWatchdog(
        for utterance: AVSpeechUtterance,
        text: String,
        generation: UInt64
    ) {
        utteranceStartWatchdogWorkItem?.cancel()
        utteranceWatchdogWorkItem?.cancel()

        // Fast start-watchdog (~0.35s): on iOS 16–18, calling stopSpeaking(at: .immediate)
        // followed synchronously by speak(utterance) can flush AVSpeechSynthesizer's queue
        // and silently drop the new utterance without firing didStart/didFinish/didCancel.
        let startWatchdog = DispatchWorkItem { [weak self] in
            guard let self,
                  self.utteranceGeneration == generation,
                  self.activeUtterance === utterance else { return }
            if !self.activeUtteranceDidStart
                && !self.synthesizer.isSpeaking
                && !self.synthesizer.isPaused
                && self.activeUtteranceRetryCount < 1 {
                self.activeUtteranceRetryCount += 1
                DebugLog.warn("TTS start-watchdog retrying silently dropped utterance for \"\(text)\"", tag: "TTSManager")
                let retryUtterance = self.createUtterance(from: text)
                self.activeUtterance = retryUtterance
                self.configureAudioSession()
                self.scheduleUtteranceWatchdog(for: retryUtterance, text: text, generation: generation)
                self.synthesizer.speak(retryUtterance)
            }
        }
        utteranceStartWatchdogWorkItem = startWatchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: startWatchdog)

        let timeout = max(8.0, min(30.0, Double(text.count) * 0.2 + 4.0))
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.utteranceGeneration == generation,
                  self.activeUtterance === utterance else { return }
            if !self.synthesizer.isSpeaking && !self.synthesizer.isPaused {
                DebugLog.warn("TTS watchdog recovered stuck utterance state for \"\(text)\"", tag: "TTSManager")
                self.speakNextInQueue()
            }
        }
        utteranceWatchdogWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, utterance === self.activeUtterance else { return }
            self.activeUtteranceDidStart = true
            self.utteranceStartWatchdogWorkItem?.cancel()
            self.utteranceStartWatchdogWorkItem = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard utterance === self.activeUtterance else { return }
            self.speakNextInQueue()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard utterance === self.activeUtterance else { return }

            // If stopSpeaking(at: .immediate) from the prior utterance bled into
            // the newly queued utterance before it could start, retry once with a
            // fresh AVSpeechUtterance on the next main-queue turn.
            if !self.activeUtteranceDidStart,
               self.activeUtteranceRetryCount < 1,
               !self.currentText.isEmpty {
                self.activeUtteranceRetryCount += 1
                let retryText = self.currentText
                let generation = self.utteranceGeneration
                let retryUtterance = self.createUtterance(from: retryText)
                self.activeUtterance = retryUtterance
                self.configureAudioSession()
                self.scheduleUtteranceWatchdog(for: retryUtterance, text: retryText, generation: generation)
                self.synthesizer.speak(retryUtterance)
                return
            }

            self.utteranceStartWatchdogWorkItem?.cancel()
            self.utteranceStartWatchdogWorkItem = nil
            self.utteranceWatchdogWorkItem?.cancel()
            self.utteranceWatchdogWorkItem = nil
            self.activeUtterance = nil
            self.activeUtteranceDidStart = false
            self.activeUtteranceRetryCount = 0
            self.isSpeaking = false
            self.currentText = ""
            self.phraseQueue.removeAll()
        }
    }
}
