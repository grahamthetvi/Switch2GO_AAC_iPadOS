package com.vocable.data

import com.vocable.data.models.PresetCategories
import com.vocable.data.models.PhraseModel

/**
 * Preset categories and phrases data
 * Populated from Android app resources
 */
object PresetData {
    
    /**
     * All preset categories in order
     */
    val categories = listOf(
        PresetCategories.GENERAL,
        PresetCategories.BASIC_NEEDS,
        PresetCategories.PERSONAL_CARE,
        PresetCategories.CONVERSATION,
        PresetCategories.ENVIRONMENT,
        PresetCategories.USER_KEYPAD,
        PresetCategories.RECENTS
    )
    
    /**
     * Get all preset phrases for a category
     */
    fun getPhrasesForCategory(category: PresetCategories): List<PhraseModel> {
        return when (category) {
            PresetCategories.GENERAL -> generalPhrases
            PresetCategories.BASIC_NEEDS -> basicNeedsPhrases
            PresetCategories.PERSONAL_CARE -> personalCarePhrases
            PresetCategories.CONVERSATION -> conversationPhrases
            PresetCategories.ENVIRONMENT -> environmentPhrases
            PresetCategories.USER_KEYPAD -> userKeypadPhrases
            PresetCategories.RECENTS -> emptyList() // Dynamic - no preset phrases
            PresetCategories.MY_SAYINGS -> emptyList() // Deprecated
        }
    }
    
    /**
     * Get all preset phrases across all categories
     */
    fun getAllPresetPhrases(): List<PhraseModel> {
        return generalPhrases + 
               basicNeedsPhrases + 
               personalCarePhrases + 
               conversationPhrases + 
               environmentPhrases + 
               userKeypadPhrases
    }
    
    // GENERAL CATEGORY
    private val generalPhrases = listOf(
        PhraseModel(
            phraseId = "preset_please",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Please",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_thank_you",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Thank you",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_yes",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Yes",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_no",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "No",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_maybe",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Maybe",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_please_wait",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Please wait",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_dont_know",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "I don't know",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_didnt_mean_say_that",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "I didn't mean to say that",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_be_patient",
            parentCategoryId = PresetCategories.GENERAL.id,
            localizedUtterance = "Please be patient",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // BASIC NEEDS CATEGORY
    private val basicNeedsPhrases = listOf(
        PhraseModel(
            phraseId = "preset_need_restroom",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I need to go to the restroom",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_thirsty",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am thirsty",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_hungry",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am hungry",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_cold",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am cold",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_hot",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am hot",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_tired",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am tired",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_fine",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am fine",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_good",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am good",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_uncomfortable",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am uncomfortable",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_in_pain",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am in pain",
            sortOrder = 9,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_im_finished",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I am finished",
            sortOrder = 10,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_want_lie_down",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I want to lie down",
            sortOrder = 11,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_want_sit_up",
            parentCategoryId = PresetCategories.BASIC_NEEDS.id,
            localizedUtterance = "I want to sit up",
            sortOrder = 12,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // PERSONAL CARE CATEGORY
    private val personalCarePhrases = listOf(
        PhraseModel(
            phraseId = "preset_need_medication",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need my medication",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_need_bath",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need a bath",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_need_shower",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need a shower",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_need_wash_face",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need to wash my face",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_want_brush_hair",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need to brush my hair",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_fix_pillow",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "Please fix my pillow",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_need_spit",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need to spit",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_trouble_breathing",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I am having trouble breathing",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_need_jacket",
            parentCategoryId = PresetCategories.PERSONAL_CARE.id,
            localizedUtterance = "I need a jacket",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // CONVERSATION CATEGORY
    private val conversationPhrases = listOf(
        PhraseModel(
            phraseId = "preset_hello",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Hello",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_good_morning",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Good morning",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_good_evening",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Good evening",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_pleased_to_meet_you",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Pleased to meet you",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_how_is_day",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "How is your day?",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_how_are_you",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "How are you?",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_how_is_it_going",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "How's it going?",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_how_was_your_weekend",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "How was your weekend?",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_goodbye",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Goodbye",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_okay",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Okay",
            sortOrder = 9,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_bad",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Bad",
            sortOrder = 10,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_good",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Good",
            sortOrder = 11,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_that_makes_sense",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "That makes sense",
            sortOrder = 12,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_like_it",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "I like it",
            sortOrder = 13,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_please_stop",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Please stop",
            sortOrder = 14,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_do_not_agree",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "I do not agree",
            sortOrder = 15,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_please_repeat",
            parentCategoryId = PresetCategories.CONVERSATION.id,
            localizedUtterance = "Please repeat what you said",
            sortOrder = 16,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // ENVIRONMENT CATEGORY
    private val environmentPhrases = listOf(
        PhraseModel(
            phraseId = "preset_turn_on_lights",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the lights on",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_turn_off_lights",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the lights off",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_no_visitors",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "No visitors please",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_like_visitors",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "I would like visitors",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_be_quiet",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please be quiet",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_like_to_talk",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "I would like to talk",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_tv_on",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the TV on",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_tv_off",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the TV off",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_volume_up",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the volume up",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_volume_down",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please turn the volume down",
            sortOrder = 9,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_open_blinds",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please open the blinds",
            sortOrder = 10,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_close_blinds",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please close the blinds",
            sortOrder = 11,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_open_window",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please open the window",
            sortOrder = 12,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_close_window",
            parentCategoryId = PresetCategories.ENVIRONMENT.id,
            localizedUtterance = "Please close the window",
            sortOrder = 13,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // USER KEYPAD CATEGORY (123)
    private val userKeypadPhrases = listOf(
        PhraseModel(
            phraseId = "category_123_0",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "0",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_1",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "1",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_2",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "2",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_3",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "3",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_4",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "4",
            sortOrder = 4,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_5",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "5",
            sortOrder = 5,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_6",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "6",
            sortOrder = 6,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_7",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "7",
            sortOrder = 7,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_8",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "8",
            sortOrder = 8,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_9",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "9",
            sortOrder = 9,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_yes",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "Yes",
            sortOrder = 10,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "category_123_no",
            parentCategoryId = PresetCategories.USER_KEYPAD.id,
            localizedUtterance = "No",
            sortOrder = 11,
            creationDate = 0L,
            isPreset = true
        )
    )
}
