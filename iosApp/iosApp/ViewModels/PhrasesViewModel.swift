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
    }
    
    /// Load phrases for category
    func loadPhrases() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var displayModels: [PhraseDisplayModel] = []
            
            // Check if it's Recents category
            if self.categoryId == "preset_recents" {
                // Get recent phrases from preset phrases
                let recentPresets = self.database.presetPhraseQueries
                    .getAllPresetPhrases()
                    .executeAsList()
                    .filter { $0.last_spoken_date != nil }
                    .sorted { ($0.last_spoken_date?.int64Value ?? 0) > ($1.last_spoken_date?.int64Value ?? 0) }
                    .prefix(8)
                
                for phrase in recentPresets {
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
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Update last spoken date
            self.database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: KotlinLong(value: timestamp),
                phrase_id: phraseId
            )
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
        DispatchQueue.global(qos: .background).async { [weak self] in
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
    
    /// Get localized phrase text
    private func getPhraseText(for phraseId: String) -> String {
        // Map of phrase IDs to text (from Android strings.xml)
        let phraseTexts: [String: String] = [
            // General
            "preset_please": "Please",
            "preset_thank_you": "Thank you",
            "preset_yes": "Yes",
            "preset_no": "No",
            "preset_maybe": "Maybe",
            "preset_please_wait": "Please wait",
            "preset_i_dont_know": "I don't know",
            "preset_i_didnt_mean_say_that": "I didn't mean to say that",
            "preset_be_patient": "Please be patient",
            // Basic Needs
            "preset_need_restroom": "I need to go to the restroom",
            "preset_im_thirsty": "I am thirsty",
            "preset_im_hungry": "I am hungry",
            "preset_im_cold": "I am cold",
            "preset_im_hot": "I am hot",
            "preset_im_tired": "I am tired",
            "preset_im_fine": "I am fine",
            "preset_im_good": "I am good",
            "preset_im_uncomfortable": "I am uncomfortable",
            "preset_im_in_pain": "I am in pain",
            "preset_im_finished": "I am finished",
            "preset_want_lie_down": "I want to lie down",
            "preset_want_sit_up": "I want to sit up",
            // Personal Care
            "preset_need_medication": "I need my medication",
            "preset_need_bath": "I need a bath",
            "preset_need_shower": "I need a shower",
            "preset_need_wash_face": "I need to wash my face",
            "preset_want_brush_hair": "I need to brush my hair",
            "preset_fix_pillow": "Please fix my pillow",
            "preset_need_spit": "I need to spit",
            "preset_trouble_breathing": "I am having trouble breathing",
            "preset_need_jacket": "I need a jacket",
            // Conversation
            "preset_hello": "Hello",
            "preset_good_morning": "Good morning",
            "preset_good_evening": "Good evening",
            "preset_pleased_to_meet_you": "Pleased to meet you",
            "preset_how_is_day": "How is your day?",
            "preset_how_are_you": "How are you?",
            "preset_how_is_it_going": "How's it going?",
            "preset_how_was_your_weekend": "How was your weekend?",
            "preset_goodbye": "Goodbye",
            "preset_okay": "Okay",
            "preset_bad": "Bad",
            "preset_good": "Good",
            "preset_that_makes_sense": "That makes sense",
            "preset_i_like_it": "I like it",
            "preset_please_stop": "Please stop",
            "preset_i_do_not_agree": "I do not agree",
            "preset_please_repeat": "Please repeat what you said",
            // Environment
            "preset_turn_on_lights": "Please turn the lights on",
            "preset_turn_off_lights": "Please turn the lights off",
            "preset_no_visitors": "No visitors please",
            "preset_like_visitors": "I would like visitors",
            "preset_be_quiet": "Please be quiet",
            "preset_like_to_talk": "I would like to talk",
            "preset_tv_on": "Please turn the TV on",
            "preset_tv_off": "Please turn the TV off",
            "preset_volume_up": "Please turn the volume up",
            "preset_volume_down": "Please turn the volume down",
            "preset_open_blinds": "Please open the blinds",
            "preset_close_blinds": "Please close the blinds",
            "preset_open_window": "Please open the window",
            "preset_close_window": "Please close the window",
            // User Keypad
            "category_123_0": "0",
            "category_123_1": "1",
            "category_123_2": "2",
            "category_123_3": "3",
            "category_123_4": "4",
            "category_123_5": "5",
            "category_123_6": "6",
            "category_123_7": "7",
            "category_123_8": "8",
            "category_123_9": "9",
            "category_123_yes": "Yes",
            "category_123_no": "No"
        ]
        
        return phraseTexts[phraseId] ?? phraseId
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
