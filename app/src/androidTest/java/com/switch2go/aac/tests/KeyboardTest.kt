package com.switch2go.aac.tests

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.switch2go.aac.screens.KeyboardScreen
import com.switch2go.aac.screens.MainScreen
import com.switch2go.aac.utility.assertElementExists
import com.switch2go.aac.utility.assertTextMatches
import com.switch2go.aac.utility.tap
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class KeyboardScreenTest : BaseTest() {

    private val keyboardScreen = KeyboardScreen()
    private val mainScreen = MainScreen()

     @Test
    fun verifyKeyboardButtonBringsUpKeyboard() {
        navigateToKeyboard()

        keyboardScreen.apply {
            keyboardCont.assertElementExists()
            keyboardInputText.assertTextMatches("Start typing…")
        }
    }

    @Test
    fun verifyPhraseAppearsWhenTyped() {
        navigateToKeyboard()

        keyboardScreen.apply {
            tapSeveralLetters("CAT! cat cat")
            keyboardInputText.assertTextMatches("Cat cat cat")
        }
    }

    @Test
    fun verifyBackspaceRemovesLetters() {
        navigateToKeyboard()

        keyboardScreen.apply {
            tapSeveralLetters("Cats")
            keyboardBackspaceButton.tap()
            keyboardInputText.assertTextMatches("Cat")
        }
    }

    @Test
    fun verifyClearResetsInput() {
        navigateToKeyboard()

        keyboardScreen.apply {
            tapSeveralLetters("Cats")
            keyboardClearButton.tap()
            keyboardInputText.assertTextMatches("Start typing…")
        }
    }

    @Test
    fun verifyPresetsButtonReturnsToHome() {
        navigateToKeyboard()

        keyboardScreen.apply {
            keyboardPresetsButton.tap()
        }

        mainScreen.apply {
            currentText.assertElementExists()
        }

    }

    private fun navigateToKeyboard() {
        mainScreen.apply {
            keyboardNavitgationButton.tap()
        }

    }
}