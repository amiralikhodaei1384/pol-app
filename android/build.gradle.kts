allprojects {
    repositories {
        // Mirror first: dl.google.com returns 404 from this network.
        maven("https://maven.aliyun.com/repository/google")
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Some plugins (e.g. file_picker) pin an old AGP in their own buildscript; reuse the project's AGP instead.
subprojects {
    buildscript.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                useVersion("8.11.1")
            }
        }
    }
}

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
