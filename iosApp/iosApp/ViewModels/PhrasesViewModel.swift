import Foundation
import Combine
import SwiftUI
import VocableShared

/// ViewModel for phrases screen
class PhrasesViewModel: ObservableObject {
    @Published var phrases: [PhraseDisplayModel] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var currentPage = 0
    
    private let database: VocableDatabase
    private let categoryId: String
    private var cancellables = Set<AnyCancellable>()
    
    init(categoryId: String, database: VocableDatabase = DatabaseManager.shared.db) {
        self.categoryId = categoryId
        self.database = database
        loadPhrases()
        NotificationCenter.default.publisher(for: .appLanguageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadPhrases() }
            .store(in: &cancellables)
    }
    
    /// Load phrases for category
    func loadPhrases() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var displayModels: [PhraseDisplayModel] = []
            
            // Check if it's Recents category
            if self.categoryId == "preset_recents" {
                var recentItems: [(id: String, text: String, lastSpoken: Int64, isPreset: Bool, style: PhraseStyle?)] = []

                // 1. Spoken preset phrases
                let presetPhrases = self.database.presetPhraseQueries
                    .getAllPresetPhrases()
                    .executeAsList()
                    .filter { $0.last_spoken_date != nil && $0.deleted == 0 }

                for phrase in presetPhrases {
                    guard let spoken = phrase.last_spoken_date?.int64Value else { continue }
                    let phraseText = self.getPhraseText(for: phrase.phrase_id)
                    let parsedStyle = self.parseStyle(from: phrase.style)
                    recentItems.append((id: phrase.phrase_id, text: phraseText, lastSpoken: spoken, isPreset: true, style: parsedStyle))
                }

                // 2. Spoken custom phrases
                let customPhrases = self.database.phraseQueries
                    .getAllPhrases()
                    .executeAsList()
                    .filter { $0.last_spoken_date != nil }

                for phrase in customPhrases {
                    guard let spoken = phrase.last_spoken_date?.int64Value else { continue }
                    let phraseText = phrase.localized_utterance ?? ""
                    let parsedStyle = self.parseStyle(from: phrase.style)
                    recentItems.append((id: phrase.phrase_id, text: phraseText, lastSpoken: spoken, isPreset: false, style: parsedStyle))
                }

                // Sort by lastSpoken descending and take top 8
                recentItems.sort { $0.lastSpoken > $1.lastSpoken }
                let topRecents = recentItems.prefix(8)

                for (idx, item) in topRecents.enumerated() {
                    displayModels.append(PhraseDisplayModel(
                        id: item.id,
                        text: item.text,
                        sortOrder: idx,
                        isPreset: item.isPreset,
                        style: item.style
                    ))
                }
            } else {
                // Get preset phrases for category
                let presets = self.database.presetPhraseQueries
                    .getPresetPhrasesForCategory(parent_category_id: self.categoryId)
                    .executeAsList()
                
                for phrase in presets {
                    let phraseText = self.getPhraseText(for: phrase.phrase_id)
                    let parsedStyle = self.parseStyle(from: phrase.style)
                    displayModels.append(PhraseDisplayModel(
                        id: phrase.phrase_id,
                        text: phraseText,
                        sortOrder: Int(phrase.sort_order),
                        isPreset: true,
                        style: parsedStyle
                    ))
                }
                
                // Get custom phrases for category
                let customs = self.database.phraseQueries
                    .getPhrasesForCategory(parent_category_id: self.categoryId)
                    .executeAsList()
                
                for phrase in customs {
                    let parsedStyle = self.parseStyle(from: phrase.style)
                    displayModels.append(PhraseDisplayModel(
                        id: phrase.phrase_id,
                        text: phrase.localized_utterance ?? "",
                        sortOrder: Int(phrase.sort_order),
                        isPreset: false,
                        style: parsedStyle
                    ))
                }
            }
            
            // Sort by sortOrder
            displayModels.sort { $0.sortOrder < $1.sortOrder }
            
            DispatchQueue.main.async {
                self.phrases = displayModels
                self.isLoading = false
                self.currentPage = 0
            }
        }
    }
    
    /// Mark phrase as spoken
    func markPhraseAsSpoken(phraseId: String) {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let kLong = KotlinLong(value: timestamp)

        DatabaseManager.shared.asyncWrite { [weak self] in
            guard let self = self else { return }

            // Update preset phrase if present
            self.database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: kLong,
                phrase_id: phraseId
            )

            // Update custom phrase if present
            self.database.phraseQueries.updatePhraseLastSpoken(
                last_spoken_date: kLong,
                phrase_id: phraseId
            )

            if self.categoryId == "preset_recents" {
                self.loadPhrases()
            }
        }
    }
    
    /// Get total number of pages based on symbol count
    func totalPages(symbolCount: Int) -> Int {
        guard symbolCount > 0 else { return 1 }
        return (phrases.count + symbolCount - 1) / symbolCount
    }
    
    /// Get phrases for current page
    func phrasesForPage(page: Int, symbolCount: Int) -> [PhraseDisplayModel] {
        let startIndex = page * symbolCount
        let endIndex = min(startIndex + symbolCount, phrases.count)
        guard startIndex < phrases.count else { return [] }
        return Array(phrases[startIndex..<endIndex])
    }
    
    /// Reorder phrases
    func reorderPhrases(from: IndexSet, to: Int) {
        var reordered = phrases
        reordered.move(fromOffsets: from, toOffset: to)
        
        // Update sort orders in database
        for (index, phrase) in reordered.enumerated() {
            updatePhraseSortOrder(phraseId: phrase.id, sortOrder: index, isPreset: phrase.isPreset)
        }
        
        phrases = reordered
    }
    
    private func updatePhraseSortOrder(phraseId: String, sortOrder: Int, isPreset: Bool) {
        DatabaseManager.shared.asyncWrite { [weak self] in
            guard let self = self else { return }

            if isPreset {
                guard let presetPhrase = self.database.presetPhraseQueries
                    .getPresetPhraseById(phrase_id: phraseId)
                    .executeAsOneOrNull() else { return }

                self.database.presetPhraseQueries.insertPresetPhrase(
                    phrase_id: presetPhrase.phrase_id,
                    parent_category_id: presetPhrase.parent_category_id,
                    creation_date: presetPhrase.creation_date,
                    last_spoken_date: presetPhrase.last_spoken_date,
                    sort_order: Int64(sortOrder),
                    deleted: presetPhrase.deleted,
                    style: presetPhrase.style
                )
            } else {
                self.database.phraseQueries.updatePhraseSortOrder(
                    sort_order: Int64(sortOrder),
                    phrase_id: phraseId
                )
            }
        }
    }
    
    /// Get localized phrase text (natural, conversational)
    private func getPhraseText(for phraseId: String) -> String {
        CoreVocabulary.phraseText(for: phraseId, fallback: phraseId)
    }
    
    /// Parse PhraseStyle from JSON string
    private func parseStyle(from json: String?) -> PhraseStyle? {
        guard let jsonString = json, !jsonString.isEmpty else { return nil }
        
        // Use the PhraseStyle extension method for JSON parsing
        return PhraseStyle.fromJSONString(jsonString)
    }
}

/// Display model for a phrase
struct PhraseDisplayModel: Identifiable {
    let id: String
    let text: String
    let sortOrder: Int
    let isPreset: Bool
    let style: PhraseStyle?
}
