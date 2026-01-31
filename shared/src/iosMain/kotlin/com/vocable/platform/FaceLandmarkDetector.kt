package com.vocable.platform

/**
 * iOS actual implementation for FaceLandmarkDetector.
 *
 * This is a lightweight placeholder until MediaPipe iOS bindings are wired in.
 */
actual class PlatformFaceLandmarkDetector : FaceLandmarkDetector {
    private var isInitialized = false
    private var isUsingGpu = false

    override fun initialize(useGpu: Boolean): Boolean {
        isUsingGpu = useGpu
        isInitialized = true
        return true
    }

    override suspend fun detectLandmarks(): FaceLandmarkResult? {
        return null
    }

    override fun isReady(): Boolean = isInitialized

    override fun isUsingGpu(): Boolean = isUsingGpu

    override fun close() {
        isInitialized = false
    }
}
