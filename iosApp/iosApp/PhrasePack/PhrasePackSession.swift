import Foundation
import Combine

/// Holds teacher-facing phrase-pack import state. Tracking should pause while [showImportSheet] is true.
final class PhrasePackSession: ObservableObject {
    @Published var showImportSheet = false
    @Published var preview: PhrasePackPreview?
    @Published var loadError: String?
    @Published var importedCategoryId: String?
    @Published var toastMessage: String?

    func handleIncomingFile(_ url: URL) {
        do {
            let sandboxURL = try PhrasePackImporter.copyIncomingFileToSandbox(url)
            preview = try PhrasePackImporter.preview(fileURL: sandboxURL)
            loadError = nil
            showImportSheet = true
        } catch {
            preview = nil
            loadError = error.localizedDescription
            showImportSheet = true
            DebugLog.error("Phrase pack open failed: \(error.localizedDescription)", tag: "PhrasePack")
        }
    }

    func dismissImport() {
        showImportSheet = false
        preview = nil
        loadError = nil
    }

    func noteImported(categoryId: String, droppedInteractive: Bool) {
        importedCategoryId = categoryId
        if droppedInteractive {
            toastMessage = "Some interactive activities require an updated version of Switch2GO."
        }
        NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
    }
}
