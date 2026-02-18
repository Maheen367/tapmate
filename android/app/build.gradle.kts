plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.tapmatefyp"
    compileSdk = 36  // 👈 SPECIFIC VERSION DALO (34 is stable)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.tapmatefyp"
        // 👇 IMPORTANT: minSdk = 23 hona chahiye
        minSdk = flutter.minSdkVersion  // flutter.minSdkVersion ki jagah 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.facebook.android:facebook-login:16.0.1")
    implementation("com.facebook.android:facebook-core:16.0.1") // 👈 ADD THIS
}
