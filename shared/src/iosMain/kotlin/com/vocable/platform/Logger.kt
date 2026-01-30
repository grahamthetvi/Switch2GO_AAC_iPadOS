package com.vocable.platform

import platform.Foundation.NSLog

/**
 * iOS actual implementation for Logger using NSLog.
 * For more advanced logging, consider using os_log via Kotlin/Native interop.
 */
actual fun createLogger(tag: String): Logger = IOSLogger(tag)

/**
 * NSLog-based logger implementation for iOS.
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
        if (throwable != null) {
            NSLog("[$tag] ERROR: $message - ${throwable.message}")
            throwable.printStackTrace()
        } else {
            NSLog("[$tag] ERROR: $message")
        }
    }
}
