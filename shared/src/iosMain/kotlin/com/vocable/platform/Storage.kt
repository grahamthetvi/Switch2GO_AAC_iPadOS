package com.vocable.platform

import com.vocable.eyetracking.calibration.CalibrationMode
import com.vocable.eyetracking.models.CalibrationData
import platform.Foundation.NSUserDefaults

/**
 * iOS actual implementation for Storage using NSUserDefaults.
 */
actual fun createStorage(): Storage = UserDefaultsStorage()

class UserDefaultsStorage : Storage {
    private val defaults = NSUserDefaults.standardUserDefaults

    companion object {
        private const val KEY_CALIBRATION_PREFIX = "calibration_data_"
        private const val KEY_TRANSFORM_X = "_transform_x"
        private const val KEY_TRANSFORM_Y = "_transform_y"
        private const val KEY_SCREEN_WIDTH = "_screen_width"
        private const val KEY_SCREEN_HEIGHT = "_screen_height"
        private const val KEY_ERROR = "_error"
        private const val KEY_MODE = "_mode"
    }

    override fun saveCalibrationData(data: CalibrationData, mode: String): Boolean {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode

            defaults.setObject(data.transformX.joinToString(","), prefix + KEY_TRANSFORM_X)
            defaults.setObject(data.transformY.joinToString(","), prefix + KEY_TRANSFORM_Y)
            defaults.setInteger(data.screenWidth.toLong(), prefix + KEY_SCREEN_WIDTH)
            defaults.setInteger(data.screenHeight.toLong(), prefix + KEY_SCREEN_HEIGHT)
            defaults.setFloat(data.calibrationError, prefix + KEY_ERROR)
            defaults.setObject(data.mode.name, prefix + KEY_MODE)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun loadCalibrationData(mode: String): CalibrationData? {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode

            val transformXStr = defaults.stringForKey(prefix + KEY_TRANSFORM_X) ?: return null
            val transformYStr = defaults.stringForKey(prefix + KEY_TRANSFORM_Y) ?: return null

            val transformX = transformXStr.split(",").map { it.toFloat() }.toFloatArray()
            val transformY = transformYStr.split(",").map { it.toFloat() }.toFloatArray()

            val screenWidth = defaults.integerForKey(prefix + KEY_SCREEN_WIDTH).toInt()
            val screenHeight = defaults.integerForKey(prefix + KEY_SCREEN_HEIGHT).toInt()
            val error = defaults.floatForKey(prefix + KEY_ERROR)
            val modeStr = defaults.stringForKey(prefix + KEY_MODE) ?: CalibrationMode.AFFINE.name
            val calibrationMode = CalibrationMode.valueOf(modeStr)

            if (screenWidth == 0 || screenHeight == 0) {
                return null
            }

            CalibrationData(
                transformX = transformX,
                transformY = transformY,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                calibrationError = error,
                mode = calibrationMode
            )
        } catch (_: Exception) {
            null
        }
    }

    override fun deleteCalibrationData(mode: String): Boolean {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode
            defaults.removeObjectForKey(prefix + KEY_TRANSFORM_X)
            defaults.removeObjectForKey(prefix + KEY_TRANSFORM_Y)
            defaults.removeObjectForKey(prefix + KEY_SCREEN_WIDTH)
            defaults.removeObjectForKey(prefix + KEY_SCREEN_HEIGHT)
            defaults.removeObjectForKey(prefix + KEY_ERROR)
            defaults.removeObjectForKey(prefix + KEY_MODE)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun saveString(key: String, value: String) {
        defaults.setObject(value, key)
    }

    override fun loadString(key: String, defaultValue: String): String {
        return defaults.stringForKey(key) ?: defaultValue
    }

    override fun saveFloat(key: String, value: Float) {
        defaults.setFloat(value, key)
    }

    override fun loadFloat(key: String, defaultValue: Float): Float {
        val value = defaults.floatForKey(key)
        return if (value == 0f) defaultValue else value
    }

    override fun saveBoolean(key: String, value: Boolean) {
        defaults.setBool(value, key)
    }

    override fun loadBoolean(key: String, defaultValue: Boolean): Boolean {
        return defaults.boolForKey(key)
    }

    override fun saveInt(key: String, value: Int) {
        defaults.setInteger(value.toLong(), key)
    }

    override fun loadInt(key: String, defaultValue: Int): Int {
        val value = defaults.integerForKey(key).toInt()
        return if (value == 0) defaultValue else value
    }
}
