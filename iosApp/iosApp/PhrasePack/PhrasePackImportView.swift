import SwiftUI

/// Teacher-only confirmation for importing a `.switch2go` pack. Gaze/scanning must be paused by the host.
struct PhrasePackImportView: View {
    @EnvironmentObject var phrasePacks: PhrasePackSession
    @Environment(\.dismiss) private var dismiss

    @State private var renameText = ""
    @State private var showingCollision = false
    @State private var collision: PhrasePackNameCollision = .none
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var showingRenameField = false

    var body: some View {
        NavigationStack {
            Group {
                if let error = phrasePacks.loadError, phrasePacks.preview == nil {
                    ContentUnavailableView(
                        "Could not open phrase pack",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let preview = phrasePacks.preview {
                    previewList(preview)
                } else {
                    ProgressView("Reading phrase pack...")
                }
            }
            .navigationTitle("Import Phrase Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        phrasePacks.dismissImport()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .alert("Could not import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingCollision) {
                collisionSheet
            }
        }
        .interactiveDismissDisabled(isImporting)
    }

    @ViewBuilder
    private func previewList(_ preview: PhrasePackPreview) -> some View {
        List {
            Section("This pack") {
                LabeledContent("Name", value: preview.manifest.displayName)
                LabeledContent("Phrases", value: "\(preview.manifest.phrases.count)")
                if preview.videoCount > 0 {
                    LabeledContent("Videos", value: "\(preview.videoCount)")
                }
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: preview.fileSize, countStyle: .file))
            }

            Section {
                Text("This will create an additional copy of this board. Existing phrases are not replaced. Identical labels (for example two buttons named Water) are both kept.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if preview.exceedsEmailLimit {
                Section {
                    Text("This file is larger than 24.75 MB. School email may reject it. Use AirDrop or Files if sending it onward.")
                        .foregroundColor(.orange)
                }
            }

            if preview.unknownInteractiveCount > 0 {
                Section {
                    Text("Some interactive activities require an updated version of Switch2GO. Phrase text and colors will still import.")
                        .foregroundColor(.orange)
                }
            }

            Section {
                Button {
                    beginImport(preview: preview)
                } label: {
                    if isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Import")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isImporting)

                Button("Skip", role: .cancel) {
                    phrasePacks.dismissImport()
                    dismiss()
                }
                .disabled(isImporting)
            }
        }
    }

    private var collisionSheet: some View {
        NavigationStack {
            List {
                switch collision {
                case .custom(let id, let name):
                    Section {
                        Text("A category named \"\(name)\" already exists. Importing will add another copy unless you merge into the existing category.")
                    }
                    Section {
                        Button("Create another copy") {
                            showingCollision = false
                            commit(destination: .createNew(name: phrasePacks.preview?.manifest.category.name ?? name))
                        }
                        Button("Merge into \"\(name)\"") {
                            showingCollision = false
                            commit(destination: .merge(categoryId: id))
                        }
                        Button("Rename incoming category") {
                            showingRenameField = true
                            renameText = uniqueCopyName(name)
                        }
                        Button("Cancel", role: .cancel) {
                            showingCollision = false
                        }
                    }
                case .preset(let displayName):
                    Section {
                        Text("\"\(displayName)\" is a built-in board and cannot be changed by a phrase pack. Rename the incoming category or cancel.")
                    }
                    Section {
                        Button("Rename incoming category") {
                            showingRenameField = true
                            renameText = uniqueCopyName(displayName)
                        }
                        Button("Cancel", role: .cancel) {
                            showingCollision = false
                        }
                    }
                case .none:
                    EmptyView()
                }

                if showingRenameField {
                    Section("New name") {
                        TextField("Category name", text: $renameText)
                        Button("Import with this name") {
                            showingCollision = false
                            showingRenameField = false
                            commit(destination: .createNew(name: renameText))
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Category name")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func beginImport(preview: PhrasePackPreview) {
        let proposed = preview.manifest.category.name
        let hit = PhrasePackImporter.collision(for: proposed)
        switch hit {
        case .none:
            commit(destination: .createNew(name: proposed))
        case .custom, .preset:
            collision = hit
            showingRenameField = false
            showingCollision = true
        }
    }

    private func commit(destination: PhrasePackDestination) {
        guard let preview = phrasePacks.preview else { return }
        if case .createNew(let name) = destination {
            let again = PhrasePackImporter.collision(for: name)
            if case .preset = again {
                collision = again
                showingCollision = true
                return
            }
            if case .custom = again, CoreVocabulary.normalizeName(name) == CoreVocabulary.normalizeName(preview.manifest.category.name) {
                // Teacher already confirmed creating another copy with the same name.
            } else if case .custom = again {
                collision = again
                showingCollision = true
                return
            }
        }
        isImporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try PhrasePackImporter.importPack(fileURL: preview.fileURL, destination: destination)
                DispatchQueue.main.async {
                    isImporting = false
                    phrasePacks.noteImported(categoryId: result.categoryId, droppedInteractive: result.droppedInteractive)
                    phrasePacks.dismissImport()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func uniqueCopyName(_ name: String) -> String {
        "\(name) Copy"
    }
}
