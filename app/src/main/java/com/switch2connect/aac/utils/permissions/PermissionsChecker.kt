package com.switch2connect.aac.utils.permissions

interface PermissionsChecker {
    fun hasPermissions(permission: String): Boolean
    fun shouldShowRequestPermissionRationale(permission: String): Boolean
}
