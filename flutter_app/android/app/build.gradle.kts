plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vibevoice.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.vibevoice.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 只编译 arm64-v8a 大幅加速构建
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    // 只构建 arm64-v8a ABI
    splits {
        abi {
            isEnable = false
        }
    }
}

flutter {
    source = "../.."
}
