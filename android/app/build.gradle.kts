plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pol_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.pol_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
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

// Debug builds talk to the backend at 127.0.0.1:8000; tunnel that port from the phone to this PC.
// The mapping is lost whenever the phone reconnects, so re-create it on every debug build.
val adbReverse by tasks.registering {
    val adb = android.sdkDirectory.resolve("platform-tools/adb").absolutePath
    doLast {
        try {
            val process = ProcessBuilder(adb, "reverse", "tcp:8000", "tcp:8000").redirectErrorStream(true).start()
            val output = process.inputStream.bufferedReader().readText().trim()
            if (process.waitFor() != 0) logger.warn("adb reverse failed: $output")
        } catch (e: Exception) {
            logger.warn("adb reverse failed: ${e.message}")
        }
    }
}
tasks.matching { it.name == "assembleDebug" }.configureEach { finalizedBy(adbReverse) }
