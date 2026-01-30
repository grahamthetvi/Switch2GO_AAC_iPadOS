package com.switch2go.aac.utils

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts
import com.switch2go.aac.utils.IEyeGazePermissions.PermissionState.Disabled
import com.switch2go.aac.utils.IEyeGazePermissions.PermissionState.Enabled
import com.switch2go.aac.utils.permissions.PermissionRequestLauncher
import com.switch2go.aac.utils.permissions.PermissionRequester
import com.switch2go.aac.utils.permissions.PermissionsChecker
import com.switch2go.aac.utils.permissions.PermissionsRationaleDialogShower
import kotlinx.coroutines.flow.MutableStateFlow

class EyeGazePermissions(
    private val sharedPreferences: ISwitch2GOSharedPreferences,
    private val packageName: String,
    private val hasPermissionsChecker: PermissionsChecker,
    private val permissionsRationaleDialogShower: PermissionsRationaleDialogShower,
    permissionRequester: PermissionRequester,
) : IEyeGazePermissions {

    override val permissionState: MutableStateFlow<IEyeGazePermissions.PermissionState> =
        MutableStateFlow(if (sharedPreferences.getEyeGazeEnabled()) Enabled else Disabled)

    private val permissionLauncher: PermissionRequestLauncher =
        permissionRequester.registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
            if (isGranted) {
                enableEyeGaze()
            } else {
                disableEyeGaze()
                showSettingsPermissionRationaleDialog()
            }
        }

    private val permissionRequestViaSettingsLauncher: PermissionRequestLauncher =
        permissionRequester.registerForActivityResult(object : ActivityResultContract<String, Boolean>() {
            override fun createIntent(context: Context, input: String): Intent {
                return Intent().apply {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.fromParts("package", packageName, null)
                }
            }

            override fun parseResult(resultCode: Int, intent: Intent?): Boolean {
                return when (resultCode) {
                    Activity.RESULT_OK, Activity.RESULT_CANCELED -> true
                    else -> false
                }
            }
        }) { isGranted ->
            if (isGranted) {
                permissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }

    init {
        // Check for permissions on startup
        if (sharedPreferences.getEyeGazeEnabled()) {
            requestEyeGaze()
        }
    }

    private fun enableEyeGaze() {
        sharedPreferences.setEyeGazeEnabled(true)
        sharedPreferences.setSelectionMode(SelectionMode.EYE_GAZE)
        permissionState.tryEmit(Enabled)
    }

    override fun disableEyeGaze() {
        sharedPreferences.setEyeGazeEnabled(false)
        permissionState.tryEmit(Disabled)
    }

    override fun requestEyeGaze() {
        // Bypass check if we already have permission
        if (hasPermissionsChecker.hasPermissions(Manifest.permission.CAMERA)) {
            enableEyeGaze()
            return
        }

        // Permission has been denied before, show rationale
        if (hasPermissionsChecker.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)) {
            showPermissionsRationaleDialog()
            return
        }

        // Ask for permissions
        permissionLauncher.launch(Manifest.permission.CAMERA)
    }

    private fun showPermissionsRationaleDialog() {
        permissionsRationaleDialogShower.showPermissionRationaleDialog(
            onPositiveClick = { permissionLauncher.launch(Manifest.permission.CAMERA) },
            onNegativeClick = ::disableEyeGaze,
            onDismiss = ::disableEyeGaze,
        )
    }

    private fun showSettingsPermissionRationaleDialog() {
        permissionsRationaleDialogShower.showSettingsPermissionRationaleDialog(
            onPositiveClick = {
                permissionRequestViaSettingsLauncher.launch(Manifest.permission.CAMERA)
            },
            onNegativeClick = ::disableEyeGaze,
        )
    }
}

