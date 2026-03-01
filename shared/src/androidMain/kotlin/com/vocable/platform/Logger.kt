package com.vocable.platform

import timber.log.Timber

/**
 * Android actual implementation for Logger using Timber.
 */
actual fun createLogger(tag: String): Logger = TimberLogger(tag)

/**
 * Timber-based logger implementation for Android.
 */
class TimberLogger(private val tag: String) : Logger {
    override fun debug(message: String) {
        Timber.tag(tag).d(message)
    }

    override fun info(message: String) {
        Timber.tag(tag).i(message)
    }

    override fun warn(message: String) {
        Timber.tag(tag).w(message)
    }

    override fun error(message: String, throwable: Throwable?) {
        if (throwable != null) {
            Timber.tag(tag).e(throwable, message)
        } else {
            Timber.tag(tag).e(message)
        }
    }
}
