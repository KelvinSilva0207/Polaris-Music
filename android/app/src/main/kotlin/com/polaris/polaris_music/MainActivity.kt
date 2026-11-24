package com.polaris.polaris_music

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val UPDATER_CHANNEL = "com.polaris.polaris_music/updater"
        private const val UPDATER_EVENTS_CHANNEL =
            "com.polaris.polaris_music/updater_events"
        private const val WIDGET_CHANNEL = "com.polaris.polaris_music/widget"
        private const val LOG_TAG = "PolarisUpdater"
        private const val REQUEST_INSTALL_APK = 4242
    }

    /** Canal usado para avisar a Dart cuando el instalador termina. */
    private var updaterEvents: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updaterEvents = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATER_EVENTS_CHANNEL,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canRequestInstall())

                    "installedSignatureFingerprint" ->
                        result.success(installedSignatureFingerprint())

                    "inspectApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Ruta de APK vacía", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(inspectApk(path))
                        } catch (e: Exception) {
                            android.util.Log.e(LOG_TAG, "No se pudo inspeccionar el APK", e)
                            result.error("INSPECT_FAILED", e.message, null)
                        }
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Ruta de APK vacía", null)
                            return@setMethodCallHandler
                        }
                        if (!canRequestInstall()) {
                            result.error(
                                "PERMISSION_REQUIRED",
                                "Falta REQUEST_INSTALL_PACKAGES",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(installApk(path))
                        } catch (e: Exception) {
                            android.util.Log.e(LOG_TAG, "No se pudo abrir el APK", e)
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }

                    "openInstallSettings" -> result.success(openInstallSettings())

                    else -> result.notImplemented()
                }
            }

        // El widget de inicio se actualiza desde el hilo de Flutter al cambiar
        // de pista o de estado de reproducción. PREFS y el repintado viven solo
        // en PolarisWidgetProvider: aquí no se duplica ninguna clave.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val title = call.argument<String>("title")
                            ?: PolarisWidgetProvider.DEFAULT_TITLE
                        val artist = call.argument<String>("artist")
                            ?: PolarisWidgetProvider.DEFAULT_ARTIST
                        val playing = call.argument<Boolean>("playing") == true
                        PolarisWidgetProvider.publishState(
                            this,
                            title,
                            artist,
                            playing,
                            call.argument<ByteArray>("artwork"),
                        )
                        result.success(null)
                    }

                    "clear" -> {
                        PolarisWidgetProvider.clearState(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** Android O+ exige el permiso de "instalar aplicaciones desconocidas". */
    private fun canRequestInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /**
     * Flags necesarios para leer los certificados de firma. En Android 9+ se
     * usa `GET_SIGNING_CERTIFICATES`; en versiones anteriores, `GET_SIGNATURES`.
     */
    private fun signatureFlags(): Int =
        PackageManager.GET_META_DATA or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                @Suppress("DEPRECATION")
                PackageManager.GET_SIGNATURES
            }

    private fun ByteArray.hex(): String =
        joinToString("") { String.format(Locale.ROOT, "%02x", it.toInt() and 0xff) }

    private fun certificates(info: PackageInfo): Set<String> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return info.signingInfo?.apkContentsSigners
                ?.map { it.toByteArray().hex() }
                ?.toSet()
                ?: emptySet()
        }
        @Suppress("DEPRECATION")
        return info.signatures
            ?.map { it.toByteArray().hex() }
            ?.toSet()
            ?: emptySet()
    }

    /**
     * Huella SHA256 del certificado con el que está firmada la app instalada.
     * Es el mismo valor que muestra `keytool -list -v` y permite diagnosticar
     * conflictos de instalación sin leer archivos del usuario.
     */
    private fun installedSignatureFingerprint(): String? {
        val info = try {
            packageManager.getPackageInfo(packageName, signatureFlags())
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val certificate = certificates(info).firstOrNull() ?: return null
        val bytes = ByteArray(certificate.length / 2) { index ->
            certificate.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString(":") { byte ->
            String.format(Locale.ROOT, "%02X", byte.toInt() and 0xff)
        }
    }

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }

    /**
     * Compara el APK descargado con la app instalada SIN instalarlo. Así el
     * updater puede explicar un "conflicto para instalar este paquete" antes de
     * abrir el instalador del sistema: paquete distinto, firma distinta o
     * versión más antigua.
     */
    private fun inspectApk(path: String): Map<String, Any?> {
        val flags = signatureFlags()
        val candidate = packageManager.getPackageArchiveInfo(path, flags)
            ?: error("No se pudo leer el APK")
        candidate.applicationInfo?.let {
            it.sourceDir = path
            it.publicSourceDir = path
        }
        val installed = try {
            packageManager.getPackageInfo(packageName, flags)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }

        val candidateCerts = certificates(candidate)
        val installedCerts = installed?.let(::certificates) ?: emptySet()
        return mapOf(
            "samePackage" to (candidate.packageName == packageName),
            "signatureMatches" to (
                candidateCerts.isNotEmpty() && candidateCerts == installedCerts
                ),
            "versionCode" to versionCode(candidate),
            "installedVersionCode" to (installed?.let(::versionCode) ?: 0L),
        )
    }

    /**
     * Comparte el APK mediante FileProvider con el instalador del sistema.
     *
     * Si el archivo ya está en las descargas propias de la app se usa directo;
     * si el usuario eligió otra carpeta, se copia a `cacheDir/updates`, que es
     * la ruta cubierta por `file_paths.xml`. El authority usa el
     * `applicationId`, idéntico al `namespace` y al manifesto.
     */
    private fun installApk(path: String): Boolean {
        val source = File(path)
        if (!source.exists() || source.length() <= 0L) {
            error("El APK descargado no existe o está vacío")
        }

        val filesRoot = filesDir.canonicalPath
        val sourcePath = source.canonicalPath
        val target = if (sourcePath.startsWith(filesRoot + File.separator)) {
            source
        } else {
            val dir = File(cacheDir, "updates").apply { mkdirs() }
            File(dir, "polaris-update.apk").also {
                source.copyTo(it, overwrite = true)
            }
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            target,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_INSTALL_APK)
        return true
    }

    /**
     * El instalador del sistema es una actividad externa: el usuario puede
     * cancelarla o esta puede rechazar el APK. Reenviamos el desenlace a Dart
     * para que la interfaz pueda mostrar un mensaje claro en lugar de dejar la
     * actualización “en curso” para siempre.
     */
    @Deprecated("API de actividad antigua, necesaria para el resultado del instalador")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_INSTALL_APK) return

        val status = when (resultCode) {
            Activity.RESULT_OK -> "installed"
            Activity.RESULT_CANCELED -> "cancelled"
            else -> "failed"
        }
        updaterEvents?.invokeMethod(
            "installOutcome",
            mapOf("status" to status),
        )
    }

    /** Abre los ajustes específicos de "instalar aplicaciones desconocidas". */
    private fun openInstallSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
            true
        } catch (e: Exception) {
            android.util.Log.e(LOG_TAG, "No se pudieron abrir los ajustes", e)
            false
        }
    }
}
