plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.here.heresdkunitskotlin"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.here.heresdkunitskotlin"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    implementation(fileTree(mapOf(
        "dir" to "libs",
        "include" to listOf("*.aar", "*.jar"),
        "exclude" to listOf("*mock*.jar")
    )))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    // Add available HERE SDK Units for use in this host project for easy development of units. Note that when integrating compiled units as AAR into your own apps, this is not needed.
    implementation(project(path = ":here-sdk-units-core"))
    implementation(project(path = ":here-sdk-units-mapswitcher"))
    implementation(project(path = ":here-sdk-units-compass"))
    implementation(project(path = ":here-sdk-units-mapruler"))
    implementation(project(path = ":here-sdk-units-speedlimit"))
    implementation(project(path = ":here-sdk-units-popupmenu"))
}
