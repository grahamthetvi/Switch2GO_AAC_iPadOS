package com.switch2go.aac.utils

import androidx.lifecycle.MutableLiveData

/**
 * A LiveData object that represents the text that was most recently spoken aloud by TTS
 */
object SpokenText : MutableLiveData<String>()