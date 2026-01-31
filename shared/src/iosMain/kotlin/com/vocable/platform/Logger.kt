package com.vocable.platform

import platform.Foundation.NSLog

/**
 * iOS implementation of Logger using NSLog.
 * NSLog outputs to both console and system log.
 */
actual fun createLogger(tag: String): Logger = OSLogger(tag)

class OSLogger(private val tag: String) : Logger {
    override fun debug(message: String) {
        NSLog("[$tag] DEBUG: %@", message)
    }

    override fun info(message: String) {
        NSLog("[$tag] INFO: %@", message)
    }

    override fun warn(message: String) {
        NSLog("[$tag] WARN: %@", message)
    }

    override fun error(message: String, throwable: Throwable?) {
        if (throwable != null) {
            NSLog("[$tag] ERROR: %@ - %@", message, throwable.message ?: "Unknown error")
        } else {
            NSLog("[$tag] ERROR: %@", message)
        }
    }
}
