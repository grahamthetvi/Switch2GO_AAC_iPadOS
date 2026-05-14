package com.switch2connect.aac.utility

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.switch2connect.aac.room.VocableDatabase
import com.switch2connect.aac.room.addVocableMigrations
import com.switch2connect.aac.utils.IVocableSharedPreferences
import com.switch2connect.aac.utils.VocableSharedPreferences

fun getInMemoryVocableDatabase(
    prefs: IVocableSharedPreferences = VocableSharedPreferences()
) = Room
    .inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(),
        VocableDatabase::class.java
    )
    .addVocableMigrations(prefs)
    .build()
