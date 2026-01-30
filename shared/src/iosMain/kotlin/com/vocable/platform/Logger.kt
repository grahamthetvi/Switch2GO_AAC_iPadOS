package com.vocable.platform

import platform.Foundation.NSLog

/**
 * iOS implementation of Logger using NSLog.
 * In production, consider using os_log for better performance and privacy.
 */
class IOSLogger(private val tag: String) : Logger {
    override fun debug(message: String) {
        NSLog("[$tag] DEBUG: $message")
    }

    override fun info(message: String) {
        NSLog("[$tag] INFO: $message")
    }

    override fun warn(message: String) {
        NSLog("[$tag] WARN: $message")
    }

    override fun error(message: String, throwable: Throwable?) {
        val errorMessage = if (throwable != null) {
            "$message - ${throwable.message}"
        } else {
            message
        }
        NSLog("[$tag] ERROR: $errorMessage")
    }
}

/**
 * Actual implementation for iOS platform logger.
 */
actual fun createLogger(tag: String): Logger = IOSLogger(tag)
