package com.vocable.platform

import com.vocable.eyetracking.calibration.CalibrationMode
import com.vocable.eyetracking.models.CalibrationData
import platform.Foundation.NSUserDefaults

/**
 * iOS implementation of Storage using NSUserDefaults.
 */
actual fun createStorage(): Storage = UserDefaultsStorage()

class UserDefaultsStorage : Storage {
    private val defaults = NSUserDefaults.standardUserDefaults

    override fun saveCalibrationData(data: CalibrationData, mode: String): Boolean {
        return try {
            val prefix = "calibration_${mode}_"

            // Save transform X coefficients as comma-separated string
            val transformXStr = data.transformX.joinToString(",") { it.toString() }
            defaults.setObject(transformXStr, "${prefix}transformX")

            // Save transform Y coefficients as comma-separated string
            val transformYStr = data.transformY.joinToString(",") { it.toString() }
            defaults.setObject(transformYStr, "${prefix}transformY")

            // Save metadata
            defaults.setInteger(data.screenWidth.toLong(), "${prefix}screenWidth")
            defaults.setInteger(data.screenHeight.toLong(), "${prefix}screenHeight")
            defaults.setFloat(data.calibrationError, "${prefix}error")
            defaults.setObject(data.mode.name, "${prefix}mode")

            defaults.synchronize()
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun loadCalibrationData(mode: String): CalibrationData? {
        return try {
            val prefix = "calibration_${mode}_"

            val transformXStr = defaults.stringForKey("${prefix}transformX") ?: return null
            val transformYStr = defaults.stringForKey("${prefix}transformY") ?: return null

            val transformX = transformXStr.split(",").map { it.toFloat() }.toFloatArray()
            val transformY = transformYStr.split(",").map { it.toFloat() }.toFloatArray()

            val modeStr = defaults.stringForKey("${prefix}mode") ?: CalibrationMode.AFFINE.name
            val calibrationMode = try {
                CalibrationMode.valueOf(modeStr)
            } catch (e: Exception) {
                CalibrationMode.AFFINE
            }

            CalibrationData(
                transformX = transformX,
                transformY = transformY,
                screenWidth = defaults.integerForKey("${prefix}screenWidth").toInt(),
                screenHeight = defaults.integerForKey("${prefix}screenHeight").toInt(),
                calibrationError = defaults.floatForKey("${prefix}error"),
                mode = calibrationMode
            )
        } catch (e: Exception) {
            null
        }
    }

    override fun deleteCalibrationData(mode: String): Boolean {
        return try {
            val prefix = "calibration_${mode}_"
            listOf("transformX", "transformY", "screenWidth", "screenHeight", "error", "mode").forEach {
                defaults.removeObjectForKey("$prefix$it")
            }
            defaults.synchronize()
            true
        } catch (e: Exception) {
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
        return if (defaults.objectForKey(key) != null) {
            defaults.floatForKey(key)
        } else {
            defaultValue
        }
    }

    override fun saveBoolean(key: String, value: Boolean) {
        defaults.setBool(value, key)
        defaults.synchronize()
    }

    override fun loadBoolean(key: String, defaultValue: Boolean): Boolean {
        return if (defaults.objectForKey(key) != null) {
            defaults.boolForKey(key)
        } else {
            defaultValue
        }
    }

    override fun saveInt(key: String, value: Int) {
        defaults.setInteger(value.toLong(), key)
        defaults.synchronize()
    }

    override fun loadInt(key: String, defaultValue: Int): Int {
        return if (defaults.objectForKey(key) != null) {
            defaults.integerForKey(key).toInt()
        } else {
            defaultValue
        }
    }
}
