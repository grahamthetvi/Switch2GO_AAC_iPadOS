plugins {
    `kotlin-dsl`
}

group = "com.switch2connect.aac.buildlogic"

dependencies {
    implementation(libs.android.gradlePlugin)
    implementation(libs.kotlin.gradlePlugin)
}

// iCloud Desktop / macOS File Provider can create duplicate accessor metadata
// files named "HASH 2". Gradle uses those filenames as
// -Xscript-resolver-environment keys, which the Kotlin compiler rejects:
//   Unable to parse script-resolver-environment argument HASH 2="..."
tasks.matching { it.name == "compileKotlin" }.configureEach {
    doFirst {
        val metadata = file("build/kotlin-dsl/precompiled-script-plugins-metadata")
        if (metadata.isDirectory) {
            metadata.walkTopDown()
                .filter { it.isFile && it.name.contains(' ') }
                .forEach { it.delete() }
        }
    }
}