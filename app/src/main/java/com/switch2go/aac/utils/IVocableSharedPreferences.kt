package com.switch2go.aac.utils

import android.content.SharedPreferences


interface ISwitch2GOSharedPreferences {

    fun registerOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener)

    fun unregisterOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener)

    fun getMySayings(): List<String>

    fun setMySayings(mySayings: Set<String>)

    fun getDwellTime(): Long

    fun setDwellTime(time: Long)

    fun getSensitivity(): Float

    fun setSensitivity(sensitivity: Float)

    fun setHeadTrackingEnabled(enabled: Boolean)

    fun getHeadTrackingEnabled(): Boolean

    fun setFirstTime()

    fun getFirstTime(): Boolean

    fun getSelectionMode(): SelectionMode

    fun setSelectionMode(mode: SelectionMode)

    fun getEyeGazeEnabled(): Boolean

    fun setEyeGazeEnabled(enabled: Boolean)

    fun getGpuRenderingEnabled(): Boolean

    fun setGpuRenderingEnabled(enabled: Boolean)

    fun getEyeTrackingMode(): String

    fun setEyeTrackingMode(mode: String)

    fun getEyeSelection(): String

    fun setEyeSelection(selection: String)

    fun getGazeAmplification(): Float

    fun setGazeAmplification(amplification: Float)
}