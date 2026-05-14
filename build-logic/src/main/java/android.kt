import com.android.build.api.dsl.CommonExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

fun Project.commonAndroid(extension: CommonExtension<*, *, *, *, *, *>) {
    pluginManager.apply("org.jetbrains.kotlin.android")

    extension.apply {
        compileSdk = 35
        defaultConfig.minSdk = 24
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        // Wire Android Lint into CI. The first CI run will auto-generate
        // lint-baseline.xml; commit that file to make new lint regressions fail the
        // build. Until the baseline is committed, abortOnError stays false so lint is
        // an informational signal rather than a blocker.
        lint {
            warningsAsErrors = false
            abortOnError = false
            checkReleaseBuilds = false
            baseline = file("lint-baseline.xml")
        }
    }

    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
            freeCompilerArgs.addAll(
                "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi"
            )
        }
    }
}