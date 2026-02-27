// YEH LINE ADD KAREN (top mein ya buildscript ke andar):
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // YEH LINE ADD KAREN:
        classpath("com.google.gms:google-services:4.4.0")
    }
}

// Baaki aapka existing code:
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}