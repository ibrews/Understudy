plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "agilelens.understudy"
    compileSdk = 36

    defaultConfig {
        applicationId = "agilelens.understudy"
        minSdk = 26
        targetSdk = 36
        versionCode = 29
        versionName = "0.26"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }

        buildConfigField("String", "APP_VERSION", "\"0.26\"")
        buildConfigField("int", "APP_BUILD", "29")
    }

    // Release signing — read keystore path + passwords from env so secrets
    // never land in git. The values are sourced from
    // ~/.private_keys/understudy-release.jks and the matching password file
    // on the fleet machine; see HANDOFF_GOOGLE_PLAY.md. Fleet convention:
    //   UNDERSTUDY_KEYSTORE_PATH     absolute path to .jks
    //   UNDERSTUDY_KEYSTORE_PASSWORD store + key password (single value; we
    //                                use the same for both to simplify
    //                                scripts/ship-playstore.sh)
    //   UNDERSTUDY_KEY_ALIAS         defaults to "understudy"
    // If any env var is missing, releaseSigning is null and :app:bundleRelease
    // falls back to the debug keystore (fine for local validation, NOT for
    // Play Console upload).
    signingConfigs {
        val keystorePath = System.getenv("UNDERSTUDY_KEYSTORE_PATH")
        val keystorePwd = System.getenv("UNDERSTUDY_KEYSTORE_PASSWORD")
        val keyAlias = System.getenv("UNDERSTUDY_KEY_ALIAS") ?: "understudy"
        if (!keystorePath.isNullOrBlank() && !keystorePwd.isNullOrBlank()) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = keystorePwd
                this.keyAlias = keyAlias
                keyPassword = keystorePwd
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Only wire the release signingConfig if env vars set it up.
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    // composeOptions.kotlinCompilerExtensionVersion removed — replaced by
    // the org.jetbrains.kotlin.plugin.compose Gradle plugin (Kotlin 2.0+).
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Core + lifecycle
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.3")
    implementation("androidx.activity:activity-compose:1.9.1")

    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Networking
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // ARCore
    implementation("com.google.ar:core:1.44.0")

    // DataStore (for preferences)
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Android XR — projected display for AI Glasses companion
    implementation("androidx.xr.projected:projected:1.0.0-alpha03")

    // Unit tests — round-trip the Swift-generated /test-fixtures/*.json
    // through the Kotlin decoder so cross-platform drift fails CI.
    testImplementation("junit:junit:4.13.2")
}
