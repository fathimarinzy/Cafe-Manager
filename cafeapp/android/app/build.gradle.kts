import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing key properties
val keystorePropertiesFile = rootProject.file("android/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.cafeapp"
    compileSdk = flutter.compileSdkVersion
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.cafeapp"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Debug: Print what properties are available
        println("Available properties:")
        project.properties.forEach { key, value ->
            if (key.contains("GOOGLE") || key.contains("CLIENT")) {
                println("  $key = $value")
            }
        }
        
        // Debug: Check environment variables
        val envClientId = System.getenv("GOOGLE_CLIENT_ID")
        println("Environment GOOGLE_CLIENT_ID: $envClientId")
        
        // Debug: Check project properties
        val propClientId = project.findProperty("GOOGLE_CLIENT_ID") as String?
        println("Project property GOOGLE_CLIENT_ID: $propClientId")
        
        // Get Google Client ID from environment variables or gradle properties
        val googleClientId = propClientId ?: envClientId ?: ""
        
        // Validate that the client ID is provided
        if (googleClientId.isEmpty()) {
            throw GradleException(
                "GOOGLE_CLIENT_ID not found. Please add it to:\n" +
                "1. gradle.properties file in project root: GOOGLE_CLIENT_ID=your_client_id\n" +
                "2. Environment variables\n" +
                "3. Or run with: flutter build apk --release --dart-define=GOOGLE_CLIENT_ID=your_client_id\n" +
                "Current working directory: ${project.rootDir}"
            )
        }

        // Generate string resources dynamically
        resValue("string", "server_client_id", googleClientId)
        resValue("string", "app_name", "SIMS CAFE")
        
        println("Using Google Client ID: ${googleClientId.take(20)}...")
    }

    // Release signing configuration
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release signing key if available, otherwise fall back to debug
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}