plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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
        // Ladybird fork of the Green Hills app -- defaults to the ladybird
        // package so a flavor-less `flutter run`/`flutter build` (no
        // --flavor flag) matches this repo's primary identity, same
        // reasoning as BRAND_ID's default in lib/config/branding.dart.
        applicationId = "com.example.academia_app.ladybird"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // No manual ndk.abiFilters here -- Flutter's own --split-per-abi
        // flag injects its own `splits { abi { ... } }` block, and Gradle
        // refuses to have both set at once ("Conflicting configuration").
        // Restrict architectures via `flutter build ... --target-platform
        // android-arm64` at build time instead (see build.gradle.kts'
        // flavor comment below for the full command).
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
    //   flutter build apk --flavor ladybird --dart-define=BRAND_ID=ladybird
    // --flavor and --dart-define are independent flags and must both be
    // passed together to get a consistent build -- the flavor picks the
    // Android applicationId/launcher label, the dart-define picks the
    // in-app branding. Mismatching them (e.g. --flavor greenhill with
    // BRAND_ID=academia) produces a build that looks like one product
    // and installs as the other's package -- always pass both.
    //
    // The academia/greenhill flavors are carried over unmodified from the
    // Green Hills app this was forked from (see docs/AUTOPILOT_LOG.md) --
    // left in place rather than stripped so this stays an accurate copy;
    // delete them once it's clear this repo will only ever ship Ladybird.
    flavorDimensions += "brand"
    productFlavors {
        create("academia") {
            dimension = "brand"
            applicationId = "com.example.academia_app"
            resValue("string", "app_name", "Academia")
        }
        create("greenhill") {
            dimension = "brand"
            applicationId = "com.example.academia_app.greenhill"
            resValue("string", "app_name", "Green Hill Academy")
        }
        create("ladybird") {
            dimension = "brand"
            // Distinct package -- installs side-by-side with the other
            // flavors rather than overwriting them, so multiple brands can
            // be demoed on the same device at once.
            applicationId = "com.example.academia_app.ladybird"
            resValue("string", "app_name", "Ladybird Schools")
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
