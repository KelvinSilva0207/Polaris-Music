import 'dart:io';

import 'package:flutter/services.dart';

import '../models/track.dart';

/// Publica la pista actual en el widget de Android.
///
/// El canal nativo guarda un pequeño estado en SharedPreferences y repinta el
/// widget; en otras plataformas el servicio no hace nada.
class WidgetBridgeService {
  static const MethodChannel _channel = MethodChannel(
    'com.polaris.polaris_music/widget',
  );

  bool get isAvailable => Platform.isAndroid;

  Future<void> update(Track track, {required bool playing}) async {
    if (!isAvailable) return;
    Uint8List? artwork;
    final String? path = track.artworkPath;
    if (path != null && path.isNotEmpty) {
      try {
        artwork = await File(path).readAsBytes();
      } catch (_) {
        // Una carátula cacheada desaparecida no impide actualizar el texto.
      }
    }
    try {
      await _channel.invokeMethod<void>('update', <String, Object>{
        'title': track.title,
        'artist': track.artist,
        'playing': playing,
        if (artwork != null && artwork.isNotEmpty) 'artwork': artwork,
      });
    } on MissingPluginException {
      // Widget no disponible en esta build.
    } on PlatformException {
      // Un fallo del widget nunca afecta a la reproducción.
    }
  }
}
