plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlinSerialization)
    alias(libs.plugins.sqldelight)
}

kotlin {
    androidTarget {
        compilations.all {
            compileTaskProvider.configure {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }

    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach {
        it.binaries.framework {
            baseName = "VocableShared"
            isStatic = true

            // Allow suspend calls from MediaPipe's non-main detection queue.
            // Also set in gradle.properties; redundant binaryOption keeps the
            // framework build self-describing if properties are overridden.
            binaryOption("objcExportSuspendFunctionLaunchThreadRestriction", "none")

            // Generate dSYM for crash reporting
            freeCompilerArgs += listOf("-Xadd-light-debug=enable")
        }
    }

    sourceSets {
        // Common source set - shared code
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.koin.core)
            implementation(libs.sqldelight.coroutines.extensions)
        }

        commonTest.dependencies {
            implementation(libs.junit)
            implementation(libs.kotlinx.coroutines.test)
        }

        // Android source set
        androidMain.dependencies {
            implementation(libs.androidx.camera.core)
            implementation(libs.androidx.camera.camera2)
            implementation(libs.androidx.camera.lifecycle)
            implementation(libs.mediapipe.tasks.vision)
            implementation(libs.kotlinx.coroutines.android)
            implementation(libs.koin.android)
            implementation(libs.timber)
            implementation(libs.sqldelight.android.driver)
        }

        // iOS source set
        iosMain.dependencies {
            // iOS-specific dependencies will be added here
            // MediaPipe iOS bindings will be configured via CocoaPods
            implementation(libs.sqldelight.native.driver)
        }
    }
}

sqldelight {
    databases {
        create("VocableDatabase") {
            packageName.set("com.vocable.database")
            srcDirs.setFrom("src/commonMain/sqldelight")
        }
    }
}

android {
    namespace = "com.vocable.shared"
    compileSdk = 35

    defaultConfig {
        // Keep aligned with the app's minSdk in build-logic/src/main/java/android.kt
        // so :app and :shared have the same minimum API surface.
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

/**
 * Regenerates web/src/data/presets.json from PresetData.kt (and Category.kt ids).
 * Run: ./gradlew :shared:exportWebPresets
 */
tasks.register<Exec>("exportWebPresets") {
    group = "build"
    description = "Export PresetData.kt into web/src/data/presets.json"
    workingDir = rootProject.projectDir
    commandLine("node", "scripts/export-presets.mjs")
}
