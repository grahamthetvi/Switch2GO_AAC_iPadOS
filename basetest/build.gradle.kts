plugins {
    id("vocable.library")
}

android {
    namespace = "com.switch2connect.aac.basetest"
}

dependencies {
    implementation(project(":app"))
}