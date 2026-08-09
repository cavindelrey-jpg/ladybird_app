plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.academia_app"
    compileSdk = flutter.compileSdkVersion

    // Change this line from: ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.academia_app"
        minSdk = flutter.minSdkVersion
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
        }
    }

    // Same codebase, two distinct products (see lib/config/app_config.dart
    // and lib/config/branding.dart for the Dart-side half of this split).
    // Build with e.g.:
    //   flutter build apk --flavor academia --dart-define=BRAND_ID=academia --dart-define=APP_MODE=platform
    //   flutter build apk --flavor greenhill --dart-define=BRAND_ID=green_hill --dart-define=APP_MODE=school
    // --flavor and --dart-define are independent flags and must both be
    // passed together to get a consistent build -- the flavor picks the
    // Android applicationId/launcher label, the dart-defines pick the
    // in-app branding/nav gating. Mismatching them (e.g. --flavor
    // greenhill with BRAND_ID=academia) produces a build that looks like
    // one product and installs as the other's package -- always pass both.
    flavorDimensions += "brand"
    productFlavors {
        create("academia") {
            dimension = "brand"
            applicationId = "com.example.academia_app"
            resValue("string", "app_name", "Academia")
        }
        create("greenhill") {
            dimension = "brand"
            // Distinct package -- installs side-by-side with the academia
            // flavor rather than overwriting it, so both can be demoed on
            // the same device at once.
            applicationId = "com.example.academia_app.greenhill"
            resValue("string", "app_name", "Green Hill Academy")
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
