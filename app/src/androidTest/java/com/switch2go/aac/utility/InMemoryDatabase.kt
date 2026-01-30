package com.switch2go.aac.utility

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.switch2go.aac.room.VocableDatabase
import com.switch2go.aac.room.addVocableMigrations

fun getInMemoryVocableDatabase() = Room
    .inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(),
        VocableDatabase::class.java
    )
    .addVocableMigrations()
    .build()
