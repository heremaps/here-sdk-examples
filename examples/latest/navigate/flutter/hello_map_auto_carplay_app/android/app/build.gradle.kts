plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.here.sdk.examples.hello_map_auto_carplay_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.here.sdk.examples.hello_map_auto_carplay_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    repositories {
        flatDir {
            dirs("libs", "../../plugins/here_sdk/android/libs")
        }
    }
}

dependencies {
    // HERE SDK AAR from the Flutter plugin (auto-picks current navigate AAR version).
    compileOnly(
        fileTree("../../plugins/here_sdk/android/libs") {
            include("heresdk-navigate-*.aar")
        }
    )

    // Android Auto / Car App Library.
    // 1.2.0-rc01+ is required for SurfaceCallback gesture support (car API 2).
    implementation("androidx.car.app:app:1.4.0")
}

flutter {
    source = "../.."
}
