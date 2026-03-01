package com.switch2connect.aac.splash

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.switch2connect.aac.room.RoomPresetPhrasesRepository
import com.switch2connect.aac.utils.IdlingResourceContainer
import com.switch2connect.aac.utils.VocableSharedPreferences
import kotlinx.coroutines.launch

class SplashViewModel(
    private val newPresetsRepository: RoomPresetPhrasesRepository,
    private val sharedPrefs: VocableSharedPreferences,
    private val idlingResourceContainer: IdlingResourceContainer
) : ViewModel() {

    private val liveExitSplash = MutableLiveData(false)
    val exitSplash: LiveData<Boolean> = liveExitSplash

    init {
        populateDatabase()
    }

    private fun populateDatabase() {
        viewModelScope.launch {
            idlingResourceContainer.run {
                if (sharedPrefs.getFirstTime()) {
                    newPresetsRepository.populateDatabase()
                    sharedPrefs.setFirstTime()
                }

                liveExitSplash.postValue(true)
            }
        }
    }
}
