import SwiftUI
import VocableShared

/// Picker for attaching a delayed-start game to a phrase.
struct GamePickerView: View {
    let currentGameType: String?
    let onGameSelected: (String?) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("After this phrase is selected, the game starts if no other phrase is chosen within the delay in Timing & Sensitivity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Games") {
                    Button {
                        onGameSelected(PhraseStyle.companion.GAME_TYPE_CURSOR_ROCKET)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Rocket cursor follower")
                                    .font(.headline)
                                Spacer()
                                if currentGameType == PhraseStyle.companion.GAME_TYPE_CURSOR_ROCKET {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("A rocket follows your gaze; flames when you move, quiet when still.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if currentGameType != nil {
                    Section {
                        Button("Remove game", role: .destructive) {
                            onGameSelected(nil)
                        }
                    }
                }
            }
            .navigationTitle("Attach Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
