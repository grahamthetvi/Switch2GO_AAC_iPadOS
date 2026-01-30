package com.switch2go.aac.tests

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.switch2go.aac.screens.MainScreen
import com.switch2go.aac.utility.assertTextMatches
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainScreenTest : BaseTest() {

    private val mainScreen = MainScreen()

    @Test
    fun verifyDefaultTextAppears() {
        mainScreen.apply {
            val defaultText = "Select something below to speak."
            currentText.assertTextMatches(defaultText)
        }
    }

    @Test
    fun verifyClickingPhraseUpdatesCurrentText() {
        mainScreen.apply {
            tapPhrase(defaultPhraseGeneral[0])
            currentText.assertTextMatches(defaultPhraseGeneral[0])
        }
    }

    @Test
    fun verifyDefaultCategoriesExist() {
        mainScreen.apply {
            verifyDefaultCategoriesExist()
        }
    }

    @Test
    fun verifyDefaultSayingsInCategoriesExist() {
        mainScreen.apply {
            scrollRightAndTapCurrentCategory(0)
            verifyGivenPhrasesDisplay(defaultPhraseGeneral)
        }
    }

    @Test
    fun verifySelectingCategoryChangesPhrases() {
        mainScreen.apply {
            scrollRightAndTapCurrentCategory(1)
            verifyGivenPhrasesDisplay(defaultPhraseBasicNeeds)
        }
    }
}