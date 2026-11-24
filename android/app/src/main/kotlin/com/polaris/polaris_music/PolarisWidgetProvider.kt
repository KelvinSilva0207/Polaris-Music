package com.polaris.polaris_music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File

/** Widget mínimo de "suena ahora": carátula, título y transporte esencial. */
class PolarisWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        if (appWidgetIds.isEmpty()) return
        // Varios widgets comparten la misma carátula: se decodifica una sola vez.
        // No se recicla: RemoteViews conserva la referencia hasta aplicarla.
        val artwork = loadArtwork(context)
        for (id in appWidgetIds) paintWidget(context, appWidgetManager, id, artwork)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PLAY -> {
                // Respuesta inmediata; el snapshot de Dart vuelve a fijarlo.
                toggleCachedPlaying(context)
                sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
            ACTION_NEXT -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREVIOUS -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        const val ACTION_PLAY = "com.polaris.polaris_music.widget.PLAY"
        const val ACTION_NEXT = "com.polaris.polaris_music.widget.NEXT"
        const val ACTION_PREVIOUS = "com.polaris.polaris_music.widget.PREVIOUS"

        /**
         * Estado del widget. Un único nombre y un único conjunto de claves para
         * que MainActivity y el provider no puedan divergir.
         */
        private const val PREFS = "polaris_widget_state"
        const val KEY_TITLE = "title"
        const val KEY_ARTIST = "artist"
        const val KEY_PLAYING = "playing"
        const val KEY_ARTWORK = "artwork"

        const val DEFAULT_TITLE = "Polaris Music"
        const val DEFAULT_ARTIST = "Toca para abrir"

        private const val ARTWORK_FILE = "polaris_widget_art.jpg"

        /** El ImageView del layout mide 44dp; 160px cubre hasta xxxhdpi. */
        private const val ARTWORK_MAX_PX = 160

        /**
         * Único escritor del estado: guarda los cuatro campos del snapshot y
         * repinta todos los widgets. `putString(key, null)` elimina la clave,
         * así que una pista sin carátula no arrastra la anterior.
         */
        fun publishState(
            context: Context,
            title: String,
            artist: String,
            playing: Boolean,
            artwork: ByteArray?,
        ) {
            val artPath = saveArtwork(context, artwork)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_ARTIST, artist)
                .putBoolean(KEY_PLAYING, playing)
                .putString(KEY_ARTWORK, artPath)
                .apply()
            refreshAll(context)
        }

        /** Vuelve al estado de espera cuando no hay pista activa. */
        fun clearState(context: Context) =
            publishState(context, DEFAULT_TITLE, DEFAULT_ARTIST, false, null)

        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            paintWidget(context, manager, id, loadArtwork(context))
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, PolarisWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val artwork = loadArtwork(context)
            for (id in ids) paintWidget(context, manager, id, artwork)
        }

        private fun paintWidget(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            artwork: Bitmap?,
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing)

            views.setTextViewText(
                R.id.widget_title,
                prefs.getString(KEY_TITLE, DEFAULT_TITLE),
            )
            views.setTextViewText(
                R.id.widget_artist,
                prefs.getString(KEY_ARTIST, DEFAULT_ARTIST),
            )

            if (artwork != null) {
                views.setImageViewBitmap(R.id.widget_art, artwork)
            } else {
                // Sin carátula se restaura el icono: RemoteViews no conserva
                // el `src` del layout entre actualizaciones.
                views.setImageViewResource(R.id.widget_art, R.mipmap.ic_launcher)
            }

            val playing = prefs.getBoolean(KEY_PLAYING, false)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
            )

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                flags,
            )
            views.setOnClickPendingIntent(R.id.widget_art, openApp)
            views.setOnClickPendingIntent(R.id.widget_title, openApp)
            views.setOnClickPendingIntent(R.id.widget_artist, openApp)

            views.setOnClickPendingIntent(
                R.id.widget_play,
                broadcast(context, ACTION_PLAY, 1, flags),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                broadcast(context, ACTION_NEXT, 2, flags),
            )
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                broadcast(context, ACTION_PREVIOUS, 3, flags),
            )

            manager.updateAppWidget(id, views)
        }

        /** Alterna el icono guardado para que el toque se vea sin esperar a Dart. */
        private fun toggleCachedPlaying(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_PLAYING, !prefs.getBoolean(KEY_PLAYING, false))
                .apply()
            refreshAll(context)
        }

        private fun broadcast(
            context: Context,
            action: String,
            requestCode: Int,
            flags: Int,
        ): PendingIntent {
            val intent = Intent(context, PolarisWidgetProvider::class.java)
            intent.action = action
            return PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }

        /**
         * Reenvía la tecla multimedia al receptor de audio_service.
         *
         * `androidx.media.session.MediaButtonReceiver` descarta cualquier
         * intent cuyo action no sea `ACTION_MEDIA_BUTTON`; audio_service
         * construye sus propios PendingIntents con ese action y un KeyEvent
         * `ACTION_DOWN`. Sin él, los tres botones del widget no hacen nada.
         */
        private fun sendMediaKey(context: Context, keyCode: Int) {
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setClass(context, com.ryanheise.audioservice.MediaButtonReceiver::class.java)
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            context.sendBroadcast(intent)
        }

        /** Guarda la carátula en un único archivo temporal: el del widget. */
        private fun saveArtwork(context: Context, artwork: ByteArray?): String? {
            val file = File(context.cacheDir, ARTWORK_FILE)
            if (artwork == null || artwork.isEmpty()) {
                if (file.exists()) file.delete()
                return null
            }
            return try {
                file.writeBytes(artwork)
                file.absolutePath
            } catch (error: Exception) {
                android.util.Log.w("PolarisWidget", "No se pudo guardar la carátula", error)
                null
            }
        }

        /** Decodifica la carátula con muestreo y escalado hasta 160px. */
        private fun loadArtwork(context: Context): Bitmap? {
            val path = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ARTWORK, null)
            if (path.isNullOrBlank()) return null

            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

            val sample = maxOf(
                1,
                minOf(bounds.outWidth / ARTWORK_MAX_PX, bounds.outHeight / ARTWORK_MAX_PX),
            )
            val decoded = BitmapFactory.decodeFile(
                path,
                BitmapFactory.Options().apply { inSampleSize = sample },
            ) ?: return null

            val longest = maxOf(decoded.width, decoded.height)
            if (longest <= ARTWORK_MAX_PX) return decoded

            val scale = ARTWORK_MAX_PX.toFloat() / longest
            val scaled = Bitmap.createScaledBitmap(
                decoded,
                maxOf(1, (decoded.width * scale).toInt()),
                maxOf(1, (decoded.height * scale).toInt()),
                true,
            )
            decoded.recycle()
            return scaled
        }
    }
}
