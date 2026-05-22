import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyPropsFile.inputStream().use { keyProps.load(it) }
}

android {
    namespace = "id.go.bps.pinrangkab.fasih_converter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProps.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS") ?: ""
            keyPassword = keyProps.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD") ?: ""
            storeFile = file(keyProps.getProperty("storeFile") ?: "release.jks")
            storePassword = keyProps.getProperty("storePassword") ?: System.getenv("STORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        applicationId = "id.go.bps.pinrangkab.fasih_converter"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            if (variant.buildType.name == "release") {
                output.outputFileName = "FasihConverter-v${variant.versionName}-release.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}
