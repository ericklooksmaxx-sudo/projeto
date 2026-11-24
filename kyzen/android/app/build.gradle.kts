@file:Suppress("UnstableApiUsage")
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()

if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "xyz.kyzendlc.app"
    compileSdk = 37 //permission_handler requires 37
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
    // https://github.com/flutter/flutter/issues/173898
    // can be removed but u will get double the apk size.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    defaultConfig {
        applicationId = "xyz.kyzendlc.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
        }

        externalNativeBuild {
            cmake {
                arguments("-DANDROID_STL=none")
                targets("decrypt_lib")
            }
        }
    }

        signingConfigs {
            if (hasKeystore) {
                create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file("${keystoreProperties["storeFile"]}")
                    storePassword = keystoreProperties["storePassword"] as String

                    enableV2Signing = true
                    enableV3Signing = true
                }
                getByName("debug") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file("${keystoreProperties["storeFile"]}")
                    storePassword = keystoreProperties["storePassword"] as String

                    enableV2Signing = true
                    enableV3Signing = true
                }
            }
            if (!hasKeystore) {
                val yellow = "\u001B[33;1m"  // yellow
                val reset  = "\u001B[0m"
                println(
                    "\n${yellow}WARNING: key.properties not found, release builds will be signed with the debug keystore.\n" +
                    "Create key.properties at the project root to configure a release signing key.${reset}\n"
                )
            }
        }


        buildTypes {
            getByName("release") {
                signingConfig = if (hasKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            }
            getByName("debug") {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
}

    flutter {
        source = "../.."
    }

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
        implementation("com.squareup.okhttp3:okhttp:5.5.0")
    }

    dependencies {
        implementation("androidx.documentfile:documentfile:1.1.0")
    }
