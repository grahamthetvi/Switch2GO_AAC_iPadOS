plugins {
    id("vocable.library")
}

android {
    namespace = "com.switch2go.aac.basetest"
}

dependencies {
    implementation(project(":app"))
}