package com.switch2go.aac.utils.permissions

interface PermissionsChecker {
    fun hasPermissions(permission: String): Boolean
    fun shouldShowRequestPermissionRationale(permission: String): Boolean
}
