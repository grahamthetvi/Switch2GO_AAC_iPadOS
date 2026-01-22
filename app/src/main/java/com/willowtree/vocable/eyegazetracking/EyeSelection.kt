package com.willowtree.vocable.eyegazetracking

/**
 * Enum representing which eye(s) to use for gaze tracking.
 *
 * Some users may have better tracking results using only one eye due to:
 * - Vision impairment in one eye
 * - Strabismus (crossed or wandering eye)
 * - Ptosis (drooping eyelid)
 * - Better calibration accuracy with a dominant eye
 * - Medical conditions affecting one eye
 */
enum class EyeSelection {
    /**
     * Use both eyes for gaze tracking (default).
     * Gaze is calculated as the average of both eyes for better accuracy.
     */
    BOTH_EYES,

    /**
     * Use only the left eye for gaze tracking.
     * Useful when the right eye has issues or the left eye is dominant.
     */
    LEFT_EYE_ONLY,

    /**
     * Use only the right eye for gaze tracking.
     * Useful when the left eye has issues or the right eye is dominant.
     */
    RIGHT_EYE_ONLY;

    companion object {
        /**
         * Convert a string value to EyeSelection enum.
         * Returns BOTH_EYES if the value is null or unrecognized.
         */
        fun fromString(value: String?): EyeSelection {
            return when (value) {
                "LEFT_EYE_ONLY" -> LEFT_EYE_ONLY
                "RIGHT_EYE_ONLY" -> RIGHT_EYE_ONLY
                "BOTH_EYES" -> BOTH_EYES
                else -> BOTH_EYES
            }
        }
    }
}
