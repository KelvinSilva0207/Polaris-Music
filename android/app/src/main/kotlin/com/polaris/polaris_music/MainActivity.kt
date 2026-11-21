package com.polaris.polaris_music

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val UPDATER_CHANNEL = "com.polaris.polaris_music/updater"
        private const val LOG_TAG = "PolarisUpdater"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canRequestInstall())

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
    }

    /** Android O+ exige el permiso de "instalar aplicaciones desconocidas". */
    private fun canRequestInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /**
     * Copia el APK descargado a `cacheDir/updates` y lo comparte mediante
     * FileProvider con el instalador del sistema. El authority usa el
     * `applicationId`, idéntico al `namespace` y al manifesto.
     */
    private fun installApk(path: String): Boolean {
        val source = File(path)
        if (!source.exists() || source.length() <= 0L) {
            error("El APK descargado no existe o está vacío")
        }

        val dir = File(cacheDir, "updates").apply { mkdirs() }
        val target = File(dir, "polaris-update.apk")
        source.copyTo(target, overwrite = true)

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            target,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
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
