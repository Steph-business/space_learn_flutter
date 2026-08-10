allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Workaround for older plugins (e.g. flutter_native_splash 2.2.16) that don't
    // declare a namespace, which AGP 8+ requires. Must be registered before
    // evaluationDependsOn forces early evaluation below. See
    // https://d.android.com/r/tools/upgrade-assistant/set-namespace
    afterEvaluate {
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExt != null && androidExt.namespace == null) {
            val manifestFile = androidExt.sourceSets.getByName("main").manifest.srcFile
            val packageName = if (manifestFile.exists()) {
                Regex("""package\s*=\s*"([^"]+)"""").find(manifestFile.readText())?.groupValues?.get(1)
            } else null
            androidExt.namespace = packageName ?: "com.example.${project.name.replace('-', '_')}"
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
