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
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        
        // Use default system voice
        selectedVoice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    // MARK: - Public Methods
    
    /// Speak text immediately (interrupts current speech)
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        configureAudioSession()
        
        // Stop current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        currentText = text
        let utterance = createUtterance(from: text)
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    /// Add text to queue (speaks after current finishes)
    func enqueue(_ text: String) {
        guard !text.isEmpty else { return }

        configureAudioSession()
        
        phraseQueue.append(text)
        
        if !synthesizer.isSpeaking {
            speakNextInQueue()
        }
    }
    
    /// Stop speaking immediately
    func stop() {
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
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: [])
        } catch {
            DebugLog.error("Failed to configure audio session: \(error)", tag: "TTSManager")
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
            self?.isSpeaking = false
            self?.currentText = ""
            self?.phraseQueue.removeAll()
        }
    }
}
