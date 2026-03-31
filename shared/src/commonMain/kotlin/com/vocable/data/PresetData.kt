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
        PresetCategories.ROUTINE_ACTIVITY,
        PresetCategories.FOOD_DRINK,
        PresetCategories.COMFORT_STATE,
        PresetCategories.PLAY_LEISURE,
        PresetCategories.POSITIONING,
        PresetCategories.RECENTS
    )
    
    /**
     * Get all preset phrases for a category
     */
    fun getPhrasesForCategory(category: PresetCategories): List<PhraseModel> {
        return when (category) {
            PresetCategories.ROUTINE_ACTIVITY -> routineActivityPhrases
            PresetCategories.FOOD_DRINK -> foodDrinkPhrases
            PresetCategories.COMFORT_STATE -> comfortStatePhrases
            PresetCategories.PLAY_LEISURE -> playLeisurePhrases
            PresetCategories.POSITIONING -> positioningPhrases
            PresetCategories.RECENTS -> emptyList() // Dynamic - no preset phrases
        }
    }
    
    /**
     * Get all preset phrases across all categories
     */
    fun getAllPresetPhrases(): List<PhraseModel> {
        return routineActivityPhrases + 
               foodDrinkPhrases + 
               comfortStatePhrases + 
               playLeisurePhrases + 
               positioningPhrases
    }
    
    // DAILY ACTIVITIES
    private val routineActivityPhrases = listOf(
        PhraseModel(
            phraseId = "preset_need_help",
            parentCategoryId = PresetCategories.ROUTINE_ACTIVITY.id,
            localizedUtterance = "I need help",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_all_done",
            parentCategoryId = PresetCategories.ROUTINE_ACTIVITY.id,
            localizedUtterance = "I'm all done",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_want_more",
            parentCategoryId = PresetCategories.ROUTINE_ACTIVITY.id,
            localizedUtterance = "I want more",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_take_break",
            parentCategoryId = PresetCategories.ROUTINE_ACTIVITY.id,
            localizedUtterance = "I need a break",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // FOOD & DRINKS
    private val foodDrinkPhrases = listOf(
        PhraseModel(
            phraseId = "preset_eat_food",
            parentCategoryId = PresetCategories.FOOD_DRINK.id,
            localizedUtterance = "I want to eat",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_drink_water",
            parentCategoryId = PresetCategories.FOOD_DRINK.id,
            localizedUtterance = "I want a drink",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_more_please",
            parentCategoryId = PresetCategories.FOOD_DRINK.id,
            localizedUtterance = "More please",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_no_more",
            parentCategoryId = PresetCategories.FOOD_DRINK.id,
            localizedUtterance = "No more",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // HOW I FEEL
    private val comfortStatePhrases = listOf(
        PhraseModel(
            phraseId = "preset_it_hurts",
            parentCategoryId = PresetCategories.COMFORT_STATE.id,
            localizedUtterance = "It hurts",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_feel_good",
            parentCategoryId = PresetCategories.COMFORT_STATE.id,
            localizedUtterance = "I feel good",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_am_hot",
            parentCategoryId = PresetCategories.COMFORT_STATE.id,
            localizedUtterance = "I'm hot",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_i_am_cold",
            parentCategoryId = PresetCategories.COMFORT_STATE.id,
            localizedUtterance = "I'm cold",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // FUN & GAMES
    private val playLeisurePhrases = listOf(
        PhraseModel(
            phraseId = "preset_go_now",
            parentCategoryId = PresetCategories.PLAY_LEISURE.id,
            localizedUtterance = "Let's go",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_stop_now",
            parentCategoryId = PresetCategories.PLAY_LEISURE.id,
            localizedUtterance = "Stop",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_my_turn",
            parentCategoryId = PresetCategories.PLAY_LEISURE.id,
            localizedUtterance = "My turn",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_your_turn",
            parentCategoryId = PresetCategories.PLAY_LEISURE.id,
            localizedUtterance = "Your turn",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        )
    )
    
    // MOVE ME
    private val positioningPhrases = listOf(
        PhraseModel(
            phraseId = "preset_move_me",
            parentCategoryId = PresetCategories.POSITIONING.id,
            localizedUtterance = "Move me",
            sortOrder = 0,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_stay_here",
            parentCategoryId = PresetCategories.POSITIONING.id,
            localizedUtterance = "Stay here",
            sortOrder = 1,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_sit_up",
            parentCategoryId = PresetCategories.POSITIONING.id,
            localizedUtterance = "Sit me up",
            sortOrder = 2,
            creationDate = 0L,
            isPreset = true
        ),
        PhraseModel(
            phraseId = "preset_lay_back",
            parentCategoryId = PresetCategories.POSITIONING.id,
            localizedUtterance = "Lay me back",
            sortOrder = 3,
            creationDate = 0L,
            isPreset = true
        )
    )
}
