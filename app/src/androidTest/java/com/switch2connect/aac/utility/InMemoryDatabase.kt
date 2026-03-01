package com.switch2connect.aac.utility

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.switch2connect.aac.room.VocableDatabase
import com.switch2connect.aac.room.addVocableMigrations

fun getInMemoryVocableDatabase() = Room
    .inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(),
        VocableDatabase::class.java
    )
    .addVocableMigrations()
    .build()
