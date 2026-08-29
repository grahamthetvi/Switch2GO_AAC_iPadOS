import SwiftUI
import UniformTypeIdentifiers

/// Settings hub for importing `.switch2go` packs from Files. Export lives on each category.
struct PhrasePackSettingsView: View {
    @EnvironmentObject var phrasePacks: PhrasePackSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @StateObject private var settings = AppSettings.shared
    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        List {
            Section {
                Text("A phrase pack is a .switch2go file a teacher can send by email, AirDrop, or Files. Importing adds a copy of the category and its phrases. Built-in boards are never overwritten.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Import") {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import from Files", systemImage: "square.and.arrow.down")
                }

                Text("To import from Mail or AirDrop, open the .switch2go attachment and choose Switch2GO. Guided Access or Single App Mode blocks Mail and AirDrop; turn those off first, or use Import from Files.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if UIAccessibility.isGuidedAccessEnabled {
                Section {
                    Text("Guided Access is on. Mail and AirDrop are blocked until you exit Guided Access (triple-click the side or home button). Import from Files still works if the pack is already on this iPad.")
                        .foregroundColor(.orange)
                }
            }

            Section("Export") {
                Text("Open Edit Categories & Phrases, choose a category, then tap Export Category. Recently Said cannot be exported.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Phrase Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.switch2goPhrasePack, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                phrasePacks.handleIncomingFile(url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Could not open file", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
