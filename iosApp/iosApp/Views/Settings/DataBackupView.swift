import SwiftUI
import UniformTypeIdentifiers

/// Export / import full board backup (categories, phrases, settings, images, media).
struct DataBackupView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var importStep = 0
    @State private var showingImporter = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Save or restore your categories, phrases, styles, images, and media. Backups are primarily for the same iPad app (not interchangeable with the web app yet).")
                    .font(.body)
                    .foregroundColor(.secondary)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Export")
                        .font(.headline)
                    Text("Creates a JSON file you can share or save to Files.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        exportBackup()
                    } label: {
                        Text(isBusy ? "Working…" : "Export Backup")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(isBusy)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Import")
                        .font(.headline)
                    Text("Replaces all categories, phrases, settings, and media on this device.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if importStep == 0 {
                        Button {
                            importStep = 1
                        } label: {
                            Text("Import Backup")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        .disabled(isBusy)
                    } else if importStep == 1 {
                        Text("This will permanently replace your current board. Continue?")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        HStack {
                            Button("Cancel") { importStep = 0 }
                            Button("Continue", role: .destructive) {
                                importStep = 2
                                showingImporter = true
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    settingsHomeAction?() ?? dismiss()
                } label: {
                    Label("Home", systemImage: "house.fill")
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importStep = 0
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importBackup(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
                isBusy = false
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ActivityViewController(activityItems: [exportURL])
            }
        }
    }

    private func exportBackup() {
        isBusy = true
        statusMessage = nil
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try DataBackupManager.writeExportFile()
                DispatchQueue.main.async {
                    exportURL = url
                    showingShareSheet = true
                    statusMessage = "Backup ready to share."
                    errorMessage = nil
                    isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }

    private func importBackup(from url: URL) {
        isBusy = true
        statusMessage = nil
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DataBackupManager.importFromFile(url: url)
                DispatchQueue.main.async {
                    statusMessage = "Backup restored. Returning to home…"
                    isBusy = false
                    NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
                    NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        settingsHomeAction?() ?? dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
