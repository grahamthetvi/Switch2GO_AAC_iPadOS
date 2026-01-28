package com.willowtree.vocable.utils

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.willowtree.vocable.settings.SensitivityFragment
import org.koin.core.component.KoinComponent
import org.koin.core.component.get

class VocableSharedPreferences :
    IVocableSharedPreferences,
    KoinComponent {

    companion object {
        private const val PREFERENCES_NAME =
            "com.willowtree.vocable.utils.vocable-encrypted-preferences"
        private const val KEY_MY_SAYINGS = "KEY_MY_SAYINGS"
        private const val KEY_MY_LOCALIZED_SAYINGS = "KEY_MY_LOCALIZED_SAYINGS"
        const val KEY_HEAD_TRACKING_ENABLED = "KEY_HEAD_TRACKING_ENABLED"
        const val KEY_SENSITIVITY = "KEY_SENSITIVITY"
        const val DEFAULT_SENSITIVITY = SensitivityFragment.MEDIUM_SENSITIVITY
        const val KEY_DWELL_TIME = "KEY_DWELL_TIME"
        const val DEFAULT_DWELL_TIME = SensitivityFragment.DWELL_TIME_ONE_SECOND
        const val KEY_FIRST_TIME = "KEY_FIRST_TIME_OPENING"
        const val KEY_SELECTION_MODE = "KEY_SELECTION_MODE"
        const val KEY_EYE_GAZE_ENABLED = "KEY_EYE_GAZE_ENABLED"
        const val KEY_GPU_RENDERING_ENABLED = "KEY_GPU_RENDERING_ENABLED"
        const val KEY_EYE_TRACKING_MODE = "KEY_EYE_TRACKING_MODE"
        const val EYE_TRACKING_MODE_2D = "2D"
        const val EYE_TRACKING_MODE_3D = "3D"
        const val KEY_EYE_SELECTION = "KEY_EYE_SELECTION"
        const val EYE_SELECTION_BOTH = "BOTH_EYES"
        const val EYE_SELECTION_LEFT = "LEFT_EYE_ONLY"
        const val EYE_SELECTION_RIGHT = "RIGHT_EYE_ONLY"

        // CVI Display settings
        const val KEY_SYMBOL_COUNT = "KEY_SYMBOL_COUNT"
        const val DEFAULT_SYMBOL_COUNT = 2
        const val MIN_SYMBOL_COUNT = 2
        const val MAX_SYMBOL_COUNT = 9

        // Symbol colors - stored as hex color integers
        const val KEY_SYMBOL_COLOR_PREFIX = "KEY_SYMBOL_COLOR_"

        // Gaze amplification
        const val KEY_GAZE_AMPLIFICATION = "KEY_GAZE_AMPLIFICATION"
        const val DEFAULT_GAZE_AMPLIFICATION = 1.0f

    }

    private val encryptedPrefs: SharedPreferences by lazy {
        val context = get<Context>()
        EncryptedSharedPreferences.create(
            PREFERENCES_NAME,
            MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override fun registerOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener) {
        listeners.forEach {
            encryptedPrefs.registerOnSharedPreferenceChangeListener(it)
        }
    }

    override fun unregisterOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener) {
        listeners.forEach {
            encryptedPrefs.unregisterOnSharedPreferenceChangeListener(it)
        }
    }

    override fun getMySayings(): List<String> {
        encryptedPrefs.getStringSet(KEY_MY_SAYINGS, setOf())?.let {
            return it.toList()
        }
        return listOf()
    }

    override fun setMySayings(mySayings: Set<String>) {
        encryptedPrefs.edit().putStringSet(KEY_MY_SAYINGS, mySayings).apply()
    }

    override fun getDwellTime(): Long = encryptedPrefs.getLong(KEY_DWELL_TIME, DEFAULT_DWELL_TIME)

    override fun setDwellTime(time: Long) {
        encryptedPrefs.edit().putLong(KEY_DWELL_TIME, time).apply()
    }

    override fun getSensitivity(): Float = encryptedPrefs.getFloat(KEY_SENSITIVITY, DEFAULT_SENSITIVITY)

    override fun setSensitivity(sensitivity: Float) {
        encryptedPrefs.edit().putFloat(KEY_SENSITIVITY, sensitivity).apply()
    }

    override fun setHeadTrackingEnabled(enabled: Boolean) {
        encryptedPrefs.edit().putBoolean(KEY_HEAD_TRACKING_ENABLED, enabled).apply()
    }

    override fun getHeadTrackingEnabled(): Boolean =
        encryptedPrefs.getBoolean(KEY_HEAD_TRACKING_ENABLED, true)

    override fun setFirstTime() {
        encryptedPrefs.edit().putBoolean(KEY_FIRST_TIME, false).apply()
    }

    override fun getFirstTime(): Boolean =
        encryptedPrefs.getBoolean(KEY_FIRST_TIME, true)

    override fun getSelectionMode(): SelectionMode =
        SelectionMode.fromString(encryptedPrefs.getString(KEY_SELECTION_MODE, null))

    override fun setSelectionMode(mode: SelectionMode) {
        encryptedPrefs.edit().putString(KEY_SELECTION_MODE, mode.name).apply()
    }

    override fun getEyeGazeEnabled(): Boolean =
        encryptedPrefs.getBoolean(KEY_EYE_GAZE_ENABLED, false)

    override fun setEyeGazeEnabled(enabled: Boolean) {
        encryptedPrefs.edit().putBoolean(KEY_EYE_GAZE_ENABLED, enabled).apply()
    }

    override fun getGpuRenderingEnabled(): Boolean =
        encryptedPrefs.getBoolean(KEY_GPU_RENDERING_ENABLED, false)

    override fun setGpuRenderingEnabled(enabled: Boolean) {
        encryptedPrefs.edit().putBoolean(KEY_GPU_RENDERING_ENABLED, enabled).apply()
    }

    override fun getEyeTrackingMode(): String =
        encryptedPrefs.getString(KEY_EYE_TRACKING_MODE, EYE_TRACKING_MODE_2D) ?: EYE_TRACKING_MODE_2D

    override fun setEyeTrackingMode(mode: String) {
        encryptedPrefs.edit().putString(KEY_EYE_TRACKING_MODE, mode).apply()
    }

    override fun getEyeSelection(): String =
        encryptedPrefs.getString(KEY_EYE_SELECTION, EYE_SELECTION_BOTH) ?: EYE_SELECTION_BOTH

    override fun setEyeSelection(selection: String) {
        encryptedPrefs.edit().putString(KEY_EYE_SELECTION, selection).apply()
    }

    override fun getGazeAmplification(): Float =
        encryptedPrefs.getFloat(KEY_GAZE_AMPLIFICATION, DEFAULT_GAZE_AMPLIFICATION)

    override fun setGazeAmplification(amplification: Float) {
        encryptedPrefs.edit().putFloat(KEY_GAZE_AMPLIFICATION, amplification).apply()
    }

    fun getSymbolCount(): Int =
        encryptedPrefs.getInt(KEY_SYMBOL_COUNT, DEFAULT_SYMBOL_COUNT).coerceIn(MIN_SYMBOL_COUNT, MAX_SYMBOL_COUNT)

    fun setSymbolCount(count: Int) {
        encryptedPrefs.edit().putInt(KEY_SYMBOL_COUNT, count.coerceIn(MIN_SYMBOL_COUNT, MAX_SYMBOL_COUNT)).apply()
    }

    /**
     * Gets the color for a specific symbol position (1-9).
     * Returns null if no custom color is set (use default).
     */
    fun getSymbolColor(position: Int): Int? {
        val key = KEY_SYMBOL_COLOR_PREFIX + position
        return if (encryptedPrefs.contains(key)) {
            encryptedPrefs.getInt(key, 0)
        } else {
            null
        }
    }

    /**
     * Sets the color for a specific symbol position (1-9).
     * Pass null to reset to default color.
     */
    fun setSymbolColor(position: Int, color: Int?) {
        val key = KEY_SYMBOL_COLOR_PREFIX + position
        if (color != null) {
            encryptedPrefs.edit().putInt(key, color).apply()
        } else {
            encryptedPrefs.edit().remove(key).apply()
        }
    }

    /**
     * Gets all symbol colors as a map of position to color.
     * Only includes positions with custom colors set.
     */
    fun getAllSymbolColors(): Map<Int, Int> {
        val colors = mutableMapOf<Int, Int>()
        for (i in 1..MAX_SYMBOL_COUNT) {
            getSymbolColor(i)?.let { colors[i] = it }
        }
        return colors
    }


    @SuppressLint("ApplySharedPref")
    fun clearAll() {
        encryptedPrefs.edit().clear().commit()
    }
}
