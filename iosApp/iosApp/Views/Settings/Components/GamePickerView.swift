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
                    Text("After this phrase is selected, the game starts if no other phrase is chosen within the delay in Timing & Sensitivity. Games work with eye gaze, head tracking, or touch only.")
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

                    Button {
                        onGameSelected(PhraseGameTypeId.blocs)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Blocs")
                                    .font(.headline)
                                Spacer()
                                if currentGameType == PhraseGameTypeId.blocs {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("Dwell on bright blocks to break them and reveal your phrase. Eye-gaze training with particles and confetti.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        onGameSelected(PhraseGameTypeId.pieCrazy)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Pie Crazy")
                                    .font(.headline)
                                Spacer()
                                if currentGameType == PhraseGameTypeId.pieCrazy {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("Huge bullseye targets in five screen positions. Dwell to splat a cream pie with synthesized reward sound.")
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
