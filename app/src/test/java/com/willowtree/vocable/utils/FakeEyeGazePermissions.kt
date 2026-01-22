package com.willowtree.vocable.utils

import kotlinx.coroutines.flow.MutableStateFlow


class FakeEyeGazePermissions(enabled: Boolean) : IEyeGazePermissions {

    override val permissionState: MutableStateFlow<IEyeGazePermissions.PermissionState> =
        MutableStateFlow(if (enabled) IEyeGazePermissions.PermissionState.Enabled else IEyeGazePermissions.PermissionState.Disabled)

    override fun requestEyeGaze() {}

    override fun disableEyeGaze() {
        permissionState.tryEmit(IEyeGazePermissions.PermissionState.Disabled)
    }
}

