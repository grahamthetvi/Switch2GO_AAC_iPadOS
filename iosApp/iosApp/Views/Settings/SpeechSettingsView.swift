import AVFoundation
import SwiftUI

/// Speech rate and English voice settings.
struct SpeechSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    private var englishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    /// Empty when the saved voice is missing, so the screen shows System default.
    private var displayedVoiceIdentifier: String {
        let saved = settings.speechVoiceIdentifier
        guard !saved.isEmpty else { return "" }
        let stillInstalled = englishVoices.contains { $0.identifier == saved }
        return stillInstalled ? saved : ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Speech Rate")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("How fast phrases are spoken")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Slider(
                            value: $settings.speechRate,
                            in: AppSettings.speechRateRange,
                            step: 0.05
                        )
                        .accentColor(.blue)

                        HStack {
                            Text("Slow")
                            Spacer()
                            Text("Normal")
                            Spacer()
                            Text("Fast")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text("\(settings.speechRate, specifier: "%.2f")×")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Button(action: hearSample) {
                        Label("Hear sample", systemImage: "speaker.wave.2.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("English voices on this iPad")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    voiceRow(
                        title: "System default",
                        language: "en-US",
                        quality: nil,
                        identifier: ""
                    )

                    ForEach(englishVoices, id: \.identifier) { voice in
                        Divider()
                        voiceRow(
                            title: voice.name,
                            language: voice.language,
                            quality: qualityLabel(voice.quality),
                            identifier: voice.identifier
                        )
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Speech")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func hearSample() {
        TTSManager.shared.speak("Hello, this is how I sound.")
    }

    private func voiceRow(title: String, language: String, quality: String?, identifier: String) -> some View {
        Button {
            settings.speechVoiceIdentifier = identifier
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Text(language)
                        if let quality {
                            Text("·")
                            Text(quality)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                if displayedVoiceIdentifier == identifier {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .default:
            return "Default"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        @unknown default:
            return "Default"
        }
    }
}

#Preview {
    NavigationStack {
        SpeechSettingsView()
    }
}
