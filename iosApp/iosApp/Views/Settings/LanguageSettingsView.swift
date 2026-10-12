import SwiftUI

/// In-app language picker. Changes UI chrome, preset vocabulary, VoiceOver, and TTS.
struct LanguageSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    var body: some View {
        List {
            Section {
                languageRow(
                    title: L("Use iPad language"),
                    subtitle: L("Currently: %@", AppLanguage.fromSystem().nativeName),
                    selected: settings.followsSystemLanguage
                ) {
                    settings.appLanguageOverride = ""
                }
            } footer: {
                Text(l10n: "language.follow_system.footer")
            }

            Section {
                ForEach(AppLanguage.allCases) { language in
                    languageRow(
                        title: language.nativeName,
                        subtitle: nil,
                        selected: !settings.followsSystemLanguage && settings.resolvedLanguage == language
                    ) {
                        settings.appLanguageOverride = language.rawValue
                    }
                }
            } header: {
                Text(l10n: "Languages")
            }
        }
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle(Text(l10n: "Language"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label(L("Home"), systemImage: "house.fill")
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func languageRow(title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
