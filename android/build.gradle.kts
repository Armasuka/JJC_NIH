buildscript {
  extra["compileSdkVersion"] = 36
  extra["targetSdkVersion"] = 36
  extra["minSdkVersion"] = 21
  
  repositories {
    google()
    mavenCentral()
  }
  
  dependencies {
    classpath("com.android.tools.build:gradle:8.7.3")
    classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
  }
}

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
