package com.vocable.data

import app.cash.sqldelight.db.SqlDriver
import com.vocable.database.VocableDatabase

/**
 * Cross-platform SQLDelight database wiring.
 *
 * Platform persistence ownership:
 *  - iOS  : THIS SQLDelight database is the canonical store (see DatabaseManager.swift).
 *  - Android : The Room database in `com.switch2connect.aac.room.VocableDatabase` is
 *              canonical. This SQLDelight tree is NOT used at runtime on Android today.
 *
 * If you change the schema here, the Android Room schema in `app/src/main/.../room/`
 * is the source of truth for user-content semantics — keep entity names and columns
 * consistent so future unification stays cheap.
 */
expect class DatabaseDriverFactory {
    fun createDriver(): SqlDriver
}

/**
 * Creates and initializes the Vocable database.
 * Note: Boolean columns are stored as INTEGER (0/1) in SQLite.
 */
fun createDatabase(driverFactory: DatabaseDriverFactory): VocableDatabase {
    val driver = driverFactory.createDriver()
    return VocableDatabase(driver)
}
