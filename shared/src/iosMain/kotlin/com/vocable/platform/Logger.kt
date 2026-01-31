package com.vocable.platform

import platform.Foundation.NSLog

/**
 * iOS actual implementation for Logger using NSLog.
 */
actual fun createLogger(tag: String): Logger = OSLogger(tag)

class OSLogger(private val tag: String) : Logger {
    override fun debug(message: String) {
        NSLog("[DEBUG] [%s] %s", tag, message)
    }

    override fun info(message: String) {
        NSLog("[INFO] [%s] %s", tag, message)
    }

    override fun warn(message: String) {
        NSLog("[WARN] [%s] %s", tag, message)
    }

    override fun error(message: String, throwable: Throwable?) {
        if (throwable != null) {
            NSLog("[ERROR] [%s] %s - %s", tag, message, throwable.toString())
        } else {
            NSLog("[ERROR] [%s] %s", tag, message)
        }
    }
}
