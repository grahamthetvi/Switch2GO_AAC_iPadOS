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
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
