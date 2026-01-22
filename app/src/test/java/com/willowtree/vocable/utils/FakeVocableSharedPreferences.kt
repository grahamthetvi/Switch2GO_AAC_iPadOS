package com.willowtree.vocable.utils

import android.content.SharedPreferences


class FakeVocableSharedPreferences(
    private var mySayings: List<String> = listOf(),
    private var dwellTime: Long = 0,
    private var sensitivity: Float = 0f,
    private var headTrackingEnabled: Boolean = false,
    private var firstTime: Boolean = false,
    private var selectionMode: SelectionMode = SelectionMode.HEAD_TRACKING,
    private var eyeGazeEnabled: Boolean = false,
    private var gpuRenderingEnabled: Boolean = false,
    private var eyeTrackingMode: String = "2D",
    private var eyeSelection: String = "BOTH_EYES",
    private var gazeAmplification: Float = 1.0f
) : IVocableSharedPreferences {

    override fun registerOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener) {
        // no-op currently
    }

    override fun unregisterOnSharedPreferenceChangeListener(vararg listeners: SharedPreferences.OnSharedPreferenceChangeListener) {
        // no-op currently
    }

    override fun getMySayings(): List<String> {
        return mySayings
    }

    override fun setMySayings(mySayings: Set<String>) {
        this.mySayings = mySayings.toList()
    }

    override fun getDwellTime(): Long {
        return dwellTime
    }

    override fun setDwellTime(time: Long) {
        dwellTime = time
    }

    override fun getSensitivity(): Float {
        return sensitivity
    }

    override fun setSensitivity(sensitivity: Float) {
        this.sensitivity = sensitivity
    }

    override fun setHeadTrackingEnabled(enabled: Boolean) {
        headTrackingEnabled = enabled
    }

    override fun getHeadTrackingEnabled(): Boolean {
        return headTrackingEnabled
    }

    override fun setFirstTime() {
        firstTime = true
    }

    override fun getFirstTime(): Boolean {
        return firstTime
    }

    override fun getSelectionMode(): SelectionMode {
        return selectionMode
    }

    override fun setSelectionMode(mode: SelectionMode) {
        selectionMode = mode
    }

    override fun getEyeGazeEnabled(): Boolean {
        return eyeGazeEnabled
    }

    override fun setEyeGazeEnabled(enabled: Boolean) {
        eyeGazeEnabled = enabled
    }

    override fun getGpuRenderingEnabled(): Boolean {
        return gpuRenderingEnabled
    }

    override fun setGpuRenderingEnabled(enabled: Boolean) {
        gpuRenderingEnabled = enabled
    }

    override fun getEyeTrackingMode(): String {
        return eyeTrackingMode
    }

    override fun setEyeTrackingMode(mode: String) {
        eyeTrackingMode = mode
    }

    override fun getEyeSelection(): String {
        return eyeSelection
    }

    override fun setEyeSelection(selection: String) {
        eyeSelection = selection
    }

    override fun getGazeAmplification(): Float {
        return gazeAmplification
    }

    override fun setGazeAmplification(amplification: Float) {
        gazeAmplification = amplification
    }
}