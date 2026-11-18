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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && installApk(path))
                    }

                    "openInstallSettings" -> result.success(openInstallSettings())

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Abre el instalador del sistema para el APK descargado por la app.
     * Devuelve false cuando falta el permiso de instalación; en ese caso la
     * app abre los ajustes y el usuario puede reintentar.
     */
    private fun installApk(path: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            // La app abre los ajustes del sistema al recibir `false`.
            return false
        }

        return try {
            val dir = File(cacheDir, "updates").apply { mkdirs() }
            val target = File(dir, "polaris-update.apk")
            File(path).copyTo(target, overwrite = true)

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
            true
        } catch (e: Exception) {
            android.util.Log.e("PolarisUpdater", "No se pudo abrir el APK", e)
            false
        }
    }

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
            android.util.Log.e("PolarisUpdater", "No se pudieron abrir los ajustes", e)
            false
        }
    }
}
