pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Held at 8.x deliberately. AGP 9 turned "two libraries declare the same
    // namespace" from a warning into a hard error, and the Agora 6.5.4 native
    // SDK ships iris-rtc and agora-special-full both declaring io.agora.rtc.
    //
    // Moving to Agora 6.6.x is not an option either: it pins ffi ^1.1.2, which
    // cannot resolve alongside device_info_plus (ffi ^2.x) used by the camera
    // feature. Revisit once Agora publishes a build with distinct namespaces
    // and an ffi 2.x constraint.
    id("com.android.application") version "8.12.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
