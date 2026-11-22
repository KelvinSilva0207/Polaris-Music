package com.polaris.polaris_music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews

/** Widget mínimo de "suena ahora": carátula, título y transporte esencial. */
class PolarisWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PLAY -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            ACTION_NEXT -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREVIOUS -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        const val ACTION_PLAY = "com.polaris.polaris_music.widget.PLAY"
        const val ACTION_NEXT = "com.polaris.polaris_music.widget.NEXT"
        const val ACTION_PREVIOUS = "com.polaris.polaris_music.widget.PREVIOUS"

        private const val PREFS = "polaris_widget_state"

        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing)

            views.setTextViewText(
                R.id.widget_title,
                prefs.getString("title", "Polaris Music"),
            )
            views.setTextViewText(
                R.id.widget_artist,
                prefs.getString("artist", "Toca para abrir"),
            )

            val artPath = prefs.getString("artwork", null)
            if (!artPath.isNullOrBlank()) {
                BitmapFactory.decodeFile(artPath)?.let { bitmap ->
                    views.setImageViewBitmap(R.id.widget_art, bitmap)
                }
            }

            val playing = prefs.getBoolean("playing", false)
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

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, PolarisWidgetProvider::class.java),
            )
            for (id in ids) updateWidget(context, manager, id)
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

        /** Reenvía la tecla multimedia al receptor de audio_service. */
        private fun sendMediaKey(context: Context, keyCode: Int) {
            val intent = Intent(
                context,
                com.ryanheise.audioservice.MediaButtonReceiver::class.java,
            )
            intent.putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, keyCode),
            )
            context.sendBroadcast(intent)
        }
    }
}
