import java.io.FileInputStream // Import FileInputStream for reading properties
import java.util.Properties // Import Properties for loading from local.properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("local.properties") // Path to local.properties
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.engineeryourconvenience.chess_freak"
    compileSdk = flutter.compileSdkVersion // This should typically be 35 based on current requirements
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.engineeryourconvenience.chess_freak" // Consider changing this for a real app, it has "example" in it
        minSdkVersion(flutter.minSdkVersion)
        targetSdk = 35 
        versionCode = 1
        versionName = "1.0.0"
    }

    // 2. Define signing configurations
    signingConfigs {
        create("release") { // Define a signing config named "release"
            // Use 'file()' for storeFile as it expects a File object
            storeFile = file(keystoreProperties.getProperty("storeFile") ?: "")
            storePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("STORE_PASSWORD")
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS")
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // ... (existing release block)
            // 3. Apply the custom release signing config
            signingConfig = signingConfigs.getByName("release") // Apply your new "release" signing config here

            // If you want to enable ProGuard/R8 for more aggressive minification (optional, Flutter does some by default)
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
