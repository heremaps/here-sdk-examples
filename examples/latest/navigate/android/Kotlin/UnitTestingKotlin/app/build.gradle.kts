plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

repositories {
    google()
    mavenCentral()

    flatDir {
        dirs("libs")
    }
}

// Find the real HERE SDK AARs.
// We need their names because the AARs must be added as named dependencies.
// Adding them through fileTree() would make it impossible to exclude them
// from the unit test configuration later.
val hereSdkArtifactNames = fileTree("libs") {
    include("heresdk-*.aar")
}.files.map { file ->
    file.nameWithoutExtension
}

// Unit tests must not use the real HERE SDK AAR.
// Instead, they use the HERE SDK mock JAR added further below.
configurations.named("testImplementation") {
    hereSdkArtifactNames.forEach { artifactName ->
        exclude(module = artifactName)
    }
}

android {
    namespace = "com.here.unittesting"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.here.unittesting"
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

    // -------------------------------------------------------------------------
    // HERE SDK
    // -------------------------------------------------------------------------

    // Use the real HERE SDK AAR when building/running the application.
    //
    // Important:
    // Do not add the HERE SDK using:
    //
    // implementation(fileTree(...))
    //
    // because file dependencies cannot be excluded from the unit test
    // dependency configuration.
    hereSdkArtifactNames.forEach { artifactName ->
        implementation(
            mapOf(
                "name" to artifactName,
                "ext" to "aar"
            )
        )
    }

    // Use the HERE SDK mock library for local JVM unit tests.
    testImplementation(
        fileTree("libs") {
            include("heresdk-*-mock-*.jar")
        }
    )

    // -------------------------------------------------------------------------
    // Android
    // -------------------------------------------------------------------------

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    // -------------------------------------------------------------------------
    // Compose
    // -------------------------------------------------------------------------

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)

    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    // -------------------------------------------------------------------------
    // Unit testing
    // -------------------------------------------------------------------------

    testImplementation(kotlin("test"))
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.23.0")
}