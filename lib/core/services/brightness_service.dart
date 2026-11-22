import 'dart:io';

import 'package:flutter/services.dart';

/// Brillo de pantalla mientras se está en el reproductor (solo Android).
///
/// El valor se mantiene en memoria para que arrastrar el borde de la carátula
/// sea incremental; el canal nativo devuelve el brillo real la primera vez.
/// En otras plataformas los métodos son silenciosos y no lanzan errores.
class BrightnessService {
  static const MethodChannel _channel = MethodChannel(
    'com.polaris.polaris_music/brightness',
  );

  double? _level;

  bool get isAvailable => Platform.isAndroid;

  Future<double> get level async {
    final double? cached = _level;
    if (cached != null) return cached;
    if (!isAvailable) return 0.5;
    try {
      final Object? value = await _channel.invokeMethod<Object?>(
        'getBrightness',
      );
      if (value is num) {
        final double clamped = value.toDouble().clamp(0.05, 1.0).toDouble();
        _level = clamped;
        return clamped;
      }
    } on MissingPluginException {
      // Canal no registrado: se mantiene el valor neutro.
    } on PlatformException {
      // El sistema puede denegar la lectura en algunos dispositivos.
    }
    return 0.5;
  }

  /// [delta] positivo sube el brillo; se expresa como fracción de pantalla.
  Future<void> adjust(double delta) async {
    if (!isAvailable || delta == 0) return;
    final double current = await level;
    final double next = (current + delta).clamp(0.05, 1.0).toDouble();
    if ((next - current).abs() < 0.005) return;
    _level = next;
    try {
      await _channel.invokeMethod<void>('setBrightness', <String, Object>{
        'value': next,
      });
    } on MissingPluginException {
      // Plataforma sin soporte: se conserva el valor en memoria.
    } on PlatformException {
      // No se interrumpe la reproducción por un fallo de brillo.
    }
  }
}
