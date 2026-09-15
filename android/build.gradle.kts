buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ... yang sudah ada (mungkin classpath untuk Gradle, Kotlin, dll)
        classpath("com.google.gms:google-services:4.4.0")   // <-- tambahkan ini
    }
}

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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
