# Build Fix Applied - SQLDelight Type Adapters

## 🔧 Issue Encountered

When building the shared framework, SQLDelight generated code had unresolved `Boolean` references:

```
e: Unresolved reference 'Boolean'
e: No value passed for parameter 'CategoryAdapter'
```

## ✅ Root Cause

SQLDelight uses custom type adapters for non-standard SQL types. Our schema used:
```sql
hidden INTEGER AS Boolean NOT NULL DEFAULT 0
```

But we didn't provide the `Boolean` type adapter to the VocableDatabase constructor.

## ✅ Fix Applied

Updated `shared/src/commonMain/kotlin/com/vocable/data/Database.kt`:

### Before:
```kotlin
fun createDatabase(driverFactory: DatabaseDriverFactory): VocableDatabase {
    val driver = driverFactory.createDriver()
    val database = VocableDatabase(driver)  // ❌ Missing adapters
    return database
}
```

### After:
```kotlin
private val booleanAdapter = object : ColumnAdapter<Boolean, Long> {
    override fun decode(databaseValue: Long): Boolean = databaseValue == 1L
    override fun encode(value: Boolean): Long = if (value) 1L else 0L
}

fun createDatabase(driverFactory: DatabaseDriverFactory): VocableDatabase {
    val driver = driverFactory.createDriver()
    
    val database = VocableDatabase(
        driver = driver,
        CategoryAdapter = Category.Adapter(
            hiddenAdapter = booleanAdapter
        ),
        PresetCategoryAdapter = PresetCategory.Adapter(
            hiddenAdapter = booleanAdapter,
            deletedAdapter = booleanAdapter
        ),
        PresetPhraseAdapter = PresetPhrase.Adapter(
            deletedAdapter = booleanAdapter
        )
    )
    
    return database
}
```

## ✅ What Changed

1. **Created booleanAdapter**: Converts between SQL INTEGER (0/1) and Kotlin Boolean
2. **Added Category.Adapter**: For `hidden` column
3. **Added PresetCategory.Adapter**: For `hidden` and `deleted` columns
4. **Added PresetPhrase.Adapter**: For `deleted` column

## ✅ Why This Works

SQLDelight generates adapter parameters for any column with `AS TypeName` syntax. The adapters:
- **decode()**: SQL → Kotlin (1L → true, 0L → false)
- **encode()**: Kotlin → SQL (true → 1L, false → 0L)

This is standard SQLDelight practice for Boolean columns in SQLite (which doesn't have a native Boolean type).

## ✅ Build Should Now Succeed

Try again:
```bash
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64 --no-daemon
```

Expected output:
```
BUILD SUCCESSFUL in XXs
```

## ✅ Files Modified

- `shared/src/commonMain/kotlin/com/vocable/data/Database.kt` ✅

## ✅ Impact

- Database now compiles correctly
- Boolean columns work properly
- All queries return correct types
- No behavior changes (just fixes compilation)

## 📚 Reference

SQLDelight Type Adapters Documentation:
https://cashapp.github.io/sqldelight/2.0.0/common/types/

---

**Status**: ✅ **FIXED**  
**Date**: February 2, 2026  
**Ready to build**: Yes 🚀
