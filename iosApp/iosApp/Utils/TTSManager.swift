import Foundation
import AVFoundation
import Combine

/// Manages text-to-speech functionality
class TTSManager: NSObject, ObservableObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentText: String = ""
    
    // TTS Settings
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var volume: Float = 1.0
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    
    private var phraseQueue: [String] = []
    
    private var utteranceGeneration: UInt64 = 0

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
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                if self.synthesizer.isSpeaking {
                    self.synthesizer.pauseSpeaking(at: .word)
                }
            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.configureAudioSession()
                    if self.synthesizer.isPaused {
                        self.synthesizer.continueSpeaking()
                    }
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
                self.synthesizer.speak(utterance)
                self.isSpeaking = true
            }
        }
    }
    
    /// Add text to queue (speaks after current finishes)
    func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.configureAudioSession()
            self.phraseQueue.append(trimmed)
            if !self.synthesizer.isSpeaking {
                self.speakNextInQueue()
            }
        }
    }
    
    /// Stop speaking immediately
    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.utteranceGeneration &+= 1
            self.synthesizer.stopSpeaking(at: .immediate)
            self.phraseQueue.removeAll()
            self.isSpeaking = false
            self.currentText = ""
        }
    }
    
    /// Pause speaking
    func pause() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.synthesizer.isSpeaking {
                self.synthesizer.pauseSpeaking(at: .word)
            }
        }
    }
    
    /// Resume speaking
    func resume() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.synthesizer.isPaused {
                self.synthesizer.continueSpeaking()
            }
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
    
    // MARK: - Private Methods
    
    private func createUtterance(from text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.voice = selectedVoice
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        return utterance
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // mixWithOthers keeps TTS audible while the eye-tracking camera
            // capture session owns the shared audio session.
            // defaultToSpeaker matters on iPhone; harmless on iPad.
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers, .defaultToSpeaker]
            )
            try session.setActive(true, options: [])
        } catch {
            DebugLog.error("Failed to configure audio session: \(error)", tag: "TTSManager")
            // Fallback without defaultToSpeaker for older route configurations.
            do {
                try session.setCategory(
                    .playback,
                    mode: .spokenAudio,
                    options: [.duckOthers, .mixWithOthers]
                )
                try session.setActive(true, options: [])
            } catch {
                DebugLog.error("Audio session fallback failed: \(error)", tag: "TTSManager")
            }
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
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.speakNextInQueue()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // A newer speak() may already be in flight after stopSpeaking.
            guard !self.synthesizer.isSpeaking else { return }
            self.isSpeaking = false
            self.currentText = ""
            self.phraseQueue.removeAll()
        }
    }
}
