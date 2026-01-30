package com.switch2go.aac.platform

import android.content.Context
import android.content.SharedPreferences
import com.switch2go.aac.eyetracking.calibration.CalibrationMode
import com.switch2go.aac.eyetracking.models.CalibrationData
import timber.log.Timber

/**
 * Android actual implementation for Storage using SharedPreferences.
 */
actual fun createStorage(): Storage {
    throw IllegalStateException(
        "createStorage() requires a Context. Use createStorage(context) instead."
    )
}

/**
 * Create storage with Android Context.
 */
fun createStorage(context: Context): Storage = SharedPreferencesStorage(context)

/**
 * SharedPreferences-based storage implementation for Android.
 */
class SharedPreferencesStorage(context: Context) : Storage {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "vocable_shared_prefs",
        Context.MODE_PRIVATE
    )

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

            prefs.edit().apply {
                // Save transform X coefficients as comma-separated string
                putString(prefix + KEY_TRANSFORM_X, data.transformX.joinToString(","))

                // Save transform Y coefficients as comma-separated string
                putString(prefix + KEY_TRANSFORM_Y, data.transformY.joinToString(","))

                putInt(prefix + KEY_SCREEN_WIDTH, data.screenWidth)
                putInt(prefix + KEY_SCREEN_HEIGHT, data.screenHeight)
                putFloat(prefix + KEY_ERROR, data.calibrationError)
                putString(prefix + KEY_MODE, data.mode.name)

                apply()
            }

            Timber.d("Saved calibration data for mode: $mode")
            true
        } catch (e: Exception) {
            Timber.e(e, "Failed to save calibration data")
            false
        }
    }

    override fun loadCalibrationData(mode: String): CalibrationData? {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode

            val transformXStr = prefs.getString(prefix + KEY_TRANSFORM_X, null) ?: return null
            val transformYStr = prefs.getString(prefix + KEY_TRANSFORM_Y, null) ?: return null

            val transformX = transformXStr.split(",").map { it.toFloat() }.toFloatArray()
            val transformY = transformYStr.split(",").map { it.toFloat() }.toFloatArray()

            val screenWidth = prefs.getInt(prefix + KEY_SCREEN_WIDTH, 0)
            val screenHeight = prefs.getInt(prefix + KEY_SCREEN_HEIGHT, 0)
            val error = prefs.getFloat(prefix + KEY_ERROR, 0f)
            val modeStr = prefs.getString(prefix + KEY_MODE, CalibrationMode.AFFINE.name)
            val calibrationMode = CalibrationMode.valueOf(modeStr ?: CalibrationMode.AFFINE.name)

            if (screenWidth == 0 || screenHeight == 0) {
                return null
            }

            Timber.d("Loaded calibration data for mode: $mode")
            CalibrationData(
                transformX = transformX,
                transformY = transformY,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                calibrationError = error,
                mode = calibrationMode
            )
        } catch (e: Exception) {
            Timber.e(e, "Failed to load calibration data")
            null
        }
    }

    override fun deleteCalibrationData(mode: String): Boolean {
        return try {
            val prefix = KEY_CALIBRATION_PREFIX + mode

            prefs.edit().apply {
                remove(prefix + KEY_TRANSFORM_X)
                remove(prefix + KEY_TRANSFORM_Y)
                remove(prefix + KEY_SCREEN_WIDTH)
                remove(prefix + KEY_SCREEN_HEIGHT)
                remove(prefix + KEY_ERROR)
                remove(prefix + KEY_MODE)
                apply()
            }

            Timber.d("Deleted calibration data for mode: $mode")
            true
        } catch (e: Exception) {
            Timber.e(e, "Failed to delete calibration data")
            false
        }
    }

    override fun saveString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    override fun loadString(key: String, defaultValue: String): String {
        return prefs.getString(key, defaultValue) ?: defaultValue
    }

    override fun saveFloat(key: String, value: Float) {
        prefs.edit().putFloat(key, value).apply()
    }

    override fun loadFloat(key: String, defaultValue: Float): Float {
        return prefs.getFloat(key, defaultValue)
    }

    override fun saveBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun loadBoolean(key: String, defaultValue: Boolean): Boolean {
        return prefs.getBoolean(key, defaultValue)
    }

    override fun saveInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    override fun loadInt(key: String, defaultValue: Int): Int {
        return prefs.getInt(key, defaultValue)
    }
}
