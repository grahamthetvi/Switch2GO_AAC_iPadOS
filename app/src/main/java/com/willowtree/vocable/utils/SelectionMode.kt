package com.willowtree.vocable.utils

/**
 * Enum representing the different selection modes for cursor control.
 */
enum class SelectionMode {
    /**
     * Head tracking mode using ARCore to track the user's nose tip direction.
     * This is the traditional selection method that moves the cursor based on head position.
     */
    HEAD_TRACKING,

    /**
     * Eye gaze tracking mode using MediaPipe FaceMesh to track where the user is looking.
     * This mode tracks the iris position to determine gaze direction.
     */
    EYE_GAZE;

    companion object {
        /**
         * Returns the default selection mode.
         */
        fun default(): SelectionMode = HEAD_TRACKING

        /**
         * Safely converts a string to SelectionMode, returning the default if not found.
         */
        fun fromString(value: String?): SelectionMode {
            return try {
                value?.let { valueOf(it) } ?: default()
            } catch (e: IllegalArgumentException) {
                default()
            }
        }
    }
}

