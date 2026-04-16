// Top-level build file.
plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.21" apply false
    // Kotlin 2.0+ requires the Compose compiler plugin to be applied separately
    // (replacing composeOptions.kotlinCompilerExtensionVersion in app/build.gradle.kts).
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
