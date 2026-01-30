package com.vocable.platform

import com.vocable.eyetracking.calibration.CalibrationMode
import com.vocable.eyetracking.models.CalibrationData
import platform.Foundation.NSUserDefaults

/**
 * iOS actual implementation for Storage using NSUserDefaults.
 */
actual fun createStorage(): Storage = UserDefaultsStorage()

/**
 * NSUserDefaults-based storage implementation for iOS.
 */
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

    private val logger = createLogger("UserDefaultsStorage")

    override fun saveCalibrationData(data: CalibrationData, mode: String): Boolean {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode

            // Save transform X coefficients as comma-separated string
            defaults.setObject(data.transformX.joinToString(","), prefix + KEY_TRANSFORM_X)

            // Save transform Y coefficients as comma-separated string
            defaults.setObject(data.transformY.joinToString(","), prefix + KEY_TRANSFORM_Y)

            defaults.setInteger(data.screenWidth.toLong(), prefix + KEY_SCREEN_WIDTH)
            defaults.setInteger(data.screenHeight.toLong(), prefix + KEY_SCREEN_HEIGHT)
            defaults.setFloat(data.calibrationError, prefix + KEY_ERROR)
            defaults.setObject(data.mode.name, prefix + KEY_MODE)

            defaults.synchronize()

            logger.debug("Saved calibration data for mode: $mode")
            true
        } catch (e: Exception) {
            logger.error("Failed to save calibration data", e)
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
            val calibrationMode = try {
                CalibrationMode.valueOf(modeStr)
            } catch (e: Exception) {
                CalibrationMode.AFFINE
            }

            if (screenWidth == 0 || screenHeight == 0) {
                return null
            }

            logger.debug("Loaded calibration data for mode: $mode")
            CalibrationData(
                transformX = transformX,
                transformY = transformY,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                calibrationError = error,
                mode = calibrationMode
            )
        } catch (e: Exception) {
            logger.error("Failed to load calibration data", e)
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

            defaults.synchronize()

            logger.debug("Deleted calibration data for mode: $mode")
            true
        } catch (e: Exception) {
            logger.error("Failed to delete calibration data", e)
            false
        }
    }

    override fun saveString(key: String, value: String) {
        defaults.setObject(value, key)
        defaults.synchronize()
    }

    override fun loadString(key: String, defaultValue: String): String {
        return defaults.stringForKey(key) ?: defaultValue
    }

    override fun saveFloat(key: String, value: Float) {
        defaults.setFloat(value, key)
        defaults.synchronize()
    }

    override fun loadFloat(key: String, defaultValue: Float): Float {
        val hasKey = defaults.objectForKey(key) != null
        return if (hasKey) defaults.floatForKey(key) else defaultValue
    }

    override fun saveBoolean(key: String, value: Boolean) {
        defaults.setBool(value, key)
        defaults.synchronize()
    }

    override fun loadBoolean(key: String, defaultValue: Boolean): Boolean {
        val hasKey = defaults.objectForKey(key) != null
        return if (hasKey) defaults.boolForKey(key) else defaultValue
    }

    override fun saveInt(key: String, value: Int) {
        defaults.setInteger(value.toLong(), key)
        defaults.synchronize()
    }

    override fun loadInt(key: String, defaultValue: Int): Int {
        val hasKey = defaults.objectForKey(key) != null
        return if (hasKey) defaults.integerForKey(key).toInt() else defaultValue
    }
}
