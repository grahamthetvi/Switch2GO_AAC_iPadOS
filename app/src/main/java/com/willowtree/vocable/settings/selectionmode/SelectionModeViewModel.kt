package com.willowtree.vocable.settings.selectionmode

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.asLiveData
import androidx.lifecycle.map
import com.willowtree.vocable.utils.IEyeGazePermissions
import com.willowtree.vocable.utils.IFaceTrackingPermissions
import com.willowtree.vocable.utils.IVocableSharedPreferences
import com.willowtree.vocable.utils.SelectionMode
import com.willowtree.vocable.utils.isEnabled
import com.willowtree.vocable.utils.isEyeGazeEnabled

class SelectionModeViewModel(
    private val faceTrackingPermissions: IFaceTrackingPermissions,
    private val eyeGazePermissions: IEyeGazePermissions,
    private val sharedPrefs: IVocableSharedPreferences,
) : ViewModel() {

    val headTrackingEnabled = faceTrackingPermissions.permissionState.asLiveData().map { it.isEnabled() }
    val eyeGazeEnabled = eyeGazePermissions.permissionState.asLiveData().map { it.isEyeGazeEnabled() }

    private val _currentSelectionMode = MutableLiveData<SelectionMode>()
    val currentSelectionMode: LiveData<SelectionMode> = _currentSelectionMode

    init {
        _currentSelectionMode.value = sharedPrefs.getSelectionMode()
    }

    fun requestHeadTracking() {
        // Disable eye gaze when enabling head tracking
        eyeGazePermissions.disableEyeGaze()
        sharedPrefs.setSelectionMode(SelectionMode.HEAD_TRACKING)
        _currentSelectionMode.value = SelectionMode.HEAD_TRACKING
        faceTrackingPermissions.requestFaceTracking()
    }

    fun disableHeadTracking() {
        faceTrackingPermissions.disableFaceTracking()
        if (sharedPrefs.getSelectionMode() == SelectionMode.HEAD_TRACKING) {
            // Only clear selection mode if head tracking was the active mode
            _currentSelectionMode.value = SelectionMode.HEAD_TRACKING
        }
    }

    fun requestEyeGaze() {
        // Disable head tracking when enabling eye gaze
        faceTrackingPermissions.disableFaceTracking()
        sharedPrefs.setSelectionMode(SelectionMode.EYE_GAZE)
        _currentSelectionMode.value = SelectionMode.EYE_GAZE
        eyeGazePermissions.requestEyeGaze()
    }

    fun disableEyeGaze() {
        eyeGazePermissions.disableEyeGaze()
        if (sharedPrefs.getSelectionMode() == SelectionMode.EYE_GAZE) {
            _currentSelectionMode.value = SelectionMode.EYE_GAZE
        }
    }
}



