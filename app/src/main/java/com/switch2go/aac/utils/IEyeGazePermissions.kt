package com.switch2go.aac.utils

import kotlinx.coroutines.flow.MutableStateFlow


interface IEyeGazePermissions {

    sealed interface PermissionState {
        object Enabled : PermissionState
        object Disabled : PermissionState
    }

    val permissionState: MutableStateFlow<PermissionState>

    fun requestEyeGaze()

    fun disableEyeGaze()
}

fun IEyeGazePermissions.PermissionState.isEyeGazeEnabled() = this == IEyeGazePermissions.PermissionState.Enabled

