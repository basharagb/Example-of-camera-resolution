allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// agora_rtc_engine 6.5 still declares compileSdk 31, but the
// androidx.window.extensions it pulls in require callers to compile against 33
// or later, so the build fails on a dependency the plugin itself introduced.
// Raising any plugin module below this floor keeps the whole build on one SDK
// level. Compilation only: minSdk and targetSdk are untouched, so the range of
// devices the app runs on is unchanged.
//
// This has to be registered before the `evaluationDependsOn` block below,
// because that one forces plugin projects to evaluate and afterEvaluate cannot
// be attached to an already evaluated project.
subprojects {
    afterEvaluate {
        extensions
            .findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.let { android ->
                val declared = android.compileSdk
                if (declared == null || declared < 35) {
                    android.compileSdk = 35
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// CameraX 1.6.1 marks concurrent-futures as runtime-only even though its
// public annotated API references CallbackToFutureAdapter during javac. Make
// that class visible to the camera plugin compiler until the upstream POM is
// corrected.
subprojects {
    if (name == "camera_android_camerax") {
        plugins.withId("com.android.library") {
            dependencies.add("compileOnly", "androidx.concurrent:concurrent-futures:1.1.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
