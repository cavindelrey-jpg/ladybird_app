import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Upload-key signing for Google Play. If android/key.properties + the
// keystore are present (committed for the CI release build), release
// artifacts are signed with the upload key; otherwise they fall back to
// the debug key (local dev).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.academia_app"
    // Pinned explicitly rather than left on flutter.compileSdkVersion --
    // that tracks whatever this Flutter version's bundled template
    // defaults to, which lags behind Play Store's actual requirement.
    // Google Play requires API 35+ for new apps/updates as of 2025, and
    // is expected to raise that to API 36 around 2026-08-31 -- targeting
    // 36 now means this doesn't need revisiting again this year.
    compileSdk = 36

    // Change this line from: ndkVersion = flutter.ndkVersion
    // Bumped 27 -> 28.2.13676358: the `jni` plugin (a transitive Flutter
    // plugin dependency) requires that version specifically; NDK is
    // backward-compatible so building everything against the higher
    // version is Flutter's own recommended fix rather than pinning per
    // plugin.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ladybird.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // No manual ndk.abiFilters here -- Flutter's own --split-per-abi
        // flag injects its own `splits { abi { ... } }` block, and Gradle
        // refuses to have both set at once ("Conflicting configuration").
        // Restrict architectures via `flutter build ... --target-platform
        // android-arm64` at build time instead (see build.gradle.kts'
        // flavor comment below for the full command).
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // Was unset -- release builds were shipping completely
            // unshrunk (no R8, no unused-resource removal), which is
            // most of why app-*-release.apk was ~80MB.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Same codebase, multiple distinct products (see lib/config/branding.dart
    // for the Dart-side half of this split -- BRAND_ID picks the
    // name/colors/logo). Build with e.g.:
    //   flutter build apk --flavor academia --dart-define=BRAND_ID=academia
    //   flutter build apk --flavor greenhill --dart-define=BRAND_ID=green_hill
    //   flutter build apk --flavor cfpmi --dart-define=BRAND_ID=cfpmi
    // --flavor and --dart-define are independent flags and must both be
    // passed together to get a consistent build -- the flavor picks the
    // Android applicationId/launcher label, the dart-define picks the
    // in-app branding. Mismatching them (e.g. --flavor greenhill with
    // BRAND_ID=academia) produces a build that looks like one product
    // and installs as the other's package -- always pass both.
    //
    // This repo is the CFPMI fork (see docs/AUTOPILOT_LOG.md) -- its
    // primary flavor is cfpmi. Build with:
    //   flutter build apk --flavor cfpmi --dart-define=BRAND_ID=cfpmi
    flavorDimensions += "brand"
    productFlavors {
        create("ladybird") {
            dimension = "brand"
            applicationId = "com.ladybird.app"
            resValue("string", "app_name", "Ladybird")
        }
        create("greenhill") {
            dimension = "brand"
            applicationId = "com.example.academia_app.greenhill"
            resValue("string", "app_name", "Green Hills")
        }
        create("cfpmi") {
            dimension = "brand"
            applicationId = "com.cfpmi.app"
            resValue("string", "app_name", "CFPMI")
        }
        create("academia") {
            dimension = "brand"
            applicationId = "com.example.academia_app"
            resValue("string", "app_name", "Academia")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
