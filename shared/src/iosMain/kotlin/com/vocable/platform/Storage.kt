package com.vocable.platform

import com.vocable.eyetracking.models.CalibrationData
import com.vocable.eyetracking.calibration.CalibrationMode
import platform.Foundation.NSUserDefaults
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import kotlinx.serialization.Serializable

/**
 * iOS implementation of Storage using NSUserDefaults.
 */
class UserDefaultsStorage : Storage {
    private val defaults = NSUserDefaults.standardUserDefaults
    private val json = Json { ignoreUnknownKeys = true }

    override fun saveCalibrationData(data: CalibrationData, mode: String): Boolean {
        return try {
            val serializable = SerializableCalibrationData(
                transformX = data.transformX.toList(),
                transformY = data.transformY.toList(),
                screenWidth = data.screenWidth,
                screenHeight = data.screenHeight,
                calibrationError = data.calibrationError,
                mode = data.mode.name
            )
            val jsonString = json.encodeToString(serializable)
            defaults.setObject(jsonString, forKey = "calibration_$mode")
            defaults.synchronize()
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun loadCalibrationData(mode: String): CalibrationData? {
        return try {
            val jsonString = defaults.stringForKey("calibration_$mode") ?: return null
            val serializable = json.decodeFromString<SerializableCalibrationData>(jsonString)
            CalibrationData(
                transformX = serializable.transformX.toFloatArray(),
                transformY = serializable.transformY.toFloatArray(),
                screenWidth = serializable.screenWidth,
                screenHeight = serializable.screenHeight,
                calibrationError = serializable.calibrationError,
                mode = CalibrationMode.valueOf(serializable.mode)
            )
        } catch (e: Exception) {
            null
        }
    }

    override fun deleteCalibrationData(mode: String): Boolean {
        defaults.removeObjectForKey("calibration_$mode")
        return defaults.synchronize()
    }

    override fun saveString(key: String, value: String) {
        defaults.setObject(value, forKey = key)
        defaults.synchronize()
    }

    override fun loadString(key: String, defaultValue: String): String {
        return defaults.stringForKey(key) ?: defaultValue
    }

    override fun saveFloat(key: String, value: Float) {
        defaults.setFloat(value, forKey = key)
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
        defaults.setBool(value, forKey = key)
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
        defaults.setInteger(value.toLong(), forKey = key)
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

/**
 * Serializable version of CalibrationData for JSON persistence.
 */
@Serializable
private data class SerializableCalibrationData(
    val transformX: List<Float>,
    val transformY: List<Float>,
    val screenWidth: Int,
    val screenHeight: Int,
    val calibrationError: Float,
    val mode: String
)

/**
 * Actual implementation for iOS platform storage.
 */
actual fun createStorage(): Storage = UserDefaultsStorage()
