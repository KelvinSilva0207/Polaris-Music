import java.util.Properties
import java.util.Locale

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Identificador único de Polaris Music.
 *
 * Debe coincidir con el `authority` del FileProvider del manifesto. Se define
 * una sola vez para que `applicationId`, `namespace` y la firma no puedan
 * diverger entre builds y provocar "conflicto de paquete" al actualizar.
 */
val polarisApplicationId = "com.polaris.polaris_music"

/** Preferencias de firma leídas desde android/key.properties (no versionado). */
val signingProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(property: String, env: String): String? =
    signingProperties.getProperty(property)?.trim()?.takeIf { it.isNotEmpty() }
        ?: project.providers.environmentVariable(env).orNull
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

val releaseStorePath = signingValue("storeFile", "POLARIS_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "POLARIS_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "POLARIS_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "POLARIS_KEY_PASSWORD")

val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

val requireReleaseSigning =
    project.providers.environmentVariable("POLARIS_REQUIRE_RELEASE_SIGNING").orNull == "true"

if (requireReleaseSigning && !hasReleaseSigning) {
    error(
        "La build de release de Polaris Music necesita un keystore persistente. " +
            "Configura POLARIS_KEYSTORE_PATH, POLARIS_KEYSTORE_PASSWORD, " +
            "POLARIS_KEY_ALIAS y POLARIS_KEY_PASSWORD (o android/key.properties). " +
            "Consulta android/RELEASE_SIGNING.md.",
    )
}

/**
 * VersionCode determinista: mayor que cualquier build anterior basado en el
 * número de compilación de pubspec (7) y estrictamente creciente al subir
 * versión. `major.minor.patch+build` -> major*10.000.000 + minor*100.000 +
 * patch*1.000 + build. Admite hasta 999 builds por versión.
 */
fun computeVersionCode(versionName: String, buildNumber: Int): Int {
    val clean = versionName.trim().lowercase(Locale.ROOT).substringBefore("+")
    val parts = clean.split(".").map { it.toIntOrNull() ?: 0 }
    val major = parts.getOrNull(0) ?: 0
    val minor = parts.getOrNull(1) ?: 0
    val patch = parts.getOrNull(2) ?: 0
    check(buildNumber in 0..999) {
        "El número de build ($buildNumber) debe estar entre 0 y 999 para mantener versionCode incremental."
    }
    return major * 10_000_000 + minor * 100_000 + patch * 1_000 + buildNumber
}

val polarisVersionCode = computeVersionCode(flutter.versionName, flutter.versionCode)

if (!hasReleaseSigning) {
    project.logger.lifecycle(
        "Polaris Music: no hay firma de release configurada; " +
            "la build usará la clave debug SOLO para desarrollo. " +
            "Consulta android/RELEASE_SIGNING.md antes de publicar.",
    )
}

android {
    namespace = polarisApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = rootProject.file(releaseStorePath!!)
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
                // Firma completa para Android 4.1+, APK v2 y v3.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = polarisApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = polarisVersionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // FileProvider e Intent compatibles usados por el instalador del updater.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
