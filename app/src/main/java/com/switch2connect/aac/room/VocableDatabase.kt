package com.switch2connect.aac.room

import android.content.Context
import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.switch2connect.aac.utils.IVocableSharedPreferences

/**
 * Canonical persistence for the Android app. The SQLDelight schema in the KMP
 * `shared` module (commonMain `sqldelight/com/vocable/database/`) is used by the iOS
 * app and is intentionally separate from this Room database today — see
 * [com.vocable.data.createDatabase] for the iOS-side counterpart.
 *
 * Schema changes here should keep entity names and column shapes broadly consistent
 * with the SQLDelight tree so future unification remains low-risk.
 */
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

        fun createVocableDatabase(
            context: Context,
            prefs: IVocableSharedPreferences
        ): VocableDatabase =
            Room.databaseBuilder(context, VocableDatabase::class.java, DATABASE_NAME)
                .addVocableMigrations(prefs)
                .build()
    }

    abstract fun categoryDao(): CategoryDao

    abstract fun phraseDao(): PhraseDao

    abstract fun presetPhrasesDao(): PresetPhrasesDao

    abstract fun presetCategoryDao(): PresetCategoryDao
}

// Note: this database holds irreplaceable user content (custom phrases and categories).
// We intentionally do NOT enable a blanket fallbackToDestructiveMigration() — any unhandled
// upgrade should crash loudly so we can ship a real migration, rather than silently wipe data.
// Downgrades (e.g. a user installing an older build) are unrecoverable and may reset state.
fun RoomDatabase.Builder<VocableDatabase>.addVocableMigrations(
    prefs: IVocableSharedPreferences
) = fallbackToDestructiveMigrationOnDowngrade()
    .addMigrations(*VocableDatabaseMigrations.all(prefs))
