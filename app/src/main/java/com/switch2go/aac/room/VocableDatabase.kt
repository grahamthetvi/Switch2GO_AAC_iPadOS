package com.switch2go.aac.room

import android.content.Context
import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [
        CategoryDto::class,
        PhraseDto::class,
        PresetCategoryDto::class,
        PresetPhraseDto::class
    ],
    version = 8,
    autoMigrations = [
        AutoMigration(from = 6, to = 7, spec = Version7Migration::class),
        AutoMigration(from = 7, to = 8)
    ]
)
@TypeConverters(Converters::class)
abstract class VocableDatabase : RoomDatabase() {

    companion object {
        private const val DATABASE_NAME = "VocableDatabase"

        fun createVocableDatabase(context: Context): VocableDatabase =
            Room.databaseBuilder(context, VocableDatabase::class.java, DATABASE_NAME)
                .addVocableMigrations()
                .build()
    }

    abstract fun categoryDao(): CategoryDao

    abstract fun phraseDao(): PhraseDao

    abstract fun presetPhrasesDao(): PresetPhrasesDao

    abstract fun presetCategoryDao(): PresetCategoryDao
}

fun RoomDatabase.Builder<VocableDatabase>.addVocableMigrations() =
    fallbackToDestructiveMigration()
        .addMigrations(
            VocableDatabaseMigrations.MIGRATION_1_2,
            VocableDatabaseMigrations.MIGRATION_2_3,
            VocableDatabaseMigrations.MIGRATION_3_4,
            VocableDatabaseMigrations.MIGRATION_4_5,
            VocableDatabaseMigrations.MIGRATION_5_6
        )
