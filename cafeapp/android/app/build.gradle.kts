plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        minSdk = flutter.minSdkVersion
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}