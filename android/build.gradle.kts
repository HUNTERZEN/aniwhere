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

subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (_: Exception) {
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(android, 36)
                } catch (_: Exception) {}
            }
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    val pkg = "dev.isar.${project.name.replace('-', '_')}"
                    setNamespace.invoke(android, pkg)
                }
            } catch (_: Exception) {}
        }
    }

    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (_: Exception) {
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(android, 36)
                } catch (_: Exception) {}
            }
        }
        // Disable verifyReleaseResources on library plugins that have no resources or older AAPT
        tasks.matching { it.name.startsWith("verify") && it.name.endsWith("Resources") }.configureEach {
            enabled = false
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
