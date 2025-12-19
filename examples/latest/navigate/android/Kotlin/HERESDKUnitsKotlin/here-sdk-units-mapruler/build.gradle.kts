plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

version = 1.0

android {
    namespace = "com.here.sdk.units.mapruler"
    compileSdk {
        version = release(35)
    }

    defaultConfig {
        minSdk = 24

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
    }
}

val hereSdkLibsDir = project(":app").projectDir.resolve("libs")

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)

    // Compose dependencies.
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material:material-icons-extended")

    // Add dependency to the here-sdk-units-core module which is required by all units.
    api(project(":here-sdk-units-core"))

    // Pick the HERE SDK AAR matching the pattern found in HERESDKUnits/app/libs/.
    // Note: compileOnly ensures that the AAR is not exported together with the resulting unit AAR.
    compileOnly(
        fileTree(hereSdkLibsDir) {
            include("heresdk-navigate-*.aar")
        }
    )
}