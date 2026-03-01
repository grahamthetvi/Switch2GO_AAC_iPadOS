package com.vocable.data

import app.cash.sqldelight.db.SqlDriver
import com.vocable.database.VocableDatabase

/**
 * Expect/actual pattern for creating the database driver
 */
expect class DatabaseDriverFactory {
    fun createDriver(): SqlDriver
}

/**
 * Creates and initializes the Vocable database
 * Note: Boolean columns are stored as INTEGER (0/1) in SQLite
 */
fun createDatabase(driverFactory: DatabaseDriverFactory): VocableDatabase {
    val driver = driverFactory.createDriver()
    val database = VocableDatabase(driver)
    
    return database
}
