import 'package:flutter/foundation.dart';

/// Datos técnicos leídos del contenedor o del stream en reproducción.
///
/// Se rellena con propiedades de libmpv en el momento de abrir el inspector.
/// Todos los campos son opcionales: un stream puede no informar de bitrate o
/// tamaño, y la interfaz cae entonces a los metadatos indexados.
@immutable
class TrackTechnicalInfo {
  const TrackTechnicalInfo({
    this.codec,
    this.container,
    this.bitrateBps,
    this.sampleRateHz,
    this.channels,
    this.duration,
    this.sizeBytes,
  });

  final String? codec;
  final String? container;
  final int? bitrateBps;
  final int? sampleRateHz;
  final int? channels;
  final Duration? duration;
  final int? sizeBytes;

  bool get isEmpty =>
      codec == null &&
      container == null &&
      bitrateBps == null &&
      sampleRateHz == null &&
      channels == null &&
      duration == null &&
      sizeBytes == null;

  /// Completa los huecos con otra fuente (metadatos del archivo o de Drift).
  TrackTechnicalInfo orElse(TrackTechnicalInfo fallback) => TrackTechnicalInfo(
    codec: codec ?? fallback.codec,
    container: container ?? fallback.container,
    bitrateBps: bitrateBps ?? fallback.bitrateBps,
    sampleRateHz: sampleRateHz ?? fallback.sampleRateHz,
    channels: channels ?? fallback.channels,
    duration: duration ?? fallback.duration,
    sizeBytes: sizeBytes ?? fallback.sizeBytes,
  );

  /// Convierte las cadenas devueltas por mpv sin depender de Flutter ni FFI.
  factory TrackTechnicalInfo.fromMpv(Map<String, String?> values) {
    String? clean(String key) {
      final String? raw = values[key]?.trim();
      if (raw == null || raw.isEmpty || raw == 'null') return null;
      return raw;
    }

    int? integer(String key) => int.tryParse(clean(key) ?? '');
    int? positive(String key) {
      final int? value = integer(key);
      return value != null && value > 0 ? value : null;
    }

    final double? seconds = double.tryParse(clean('duration') ?? '');

    return TrackTechnicalInfo(
      codec: clean('codec'),
      container: clean('container'),
      bitrateBps: positive('bitrate'),
      sampleRateHz: positive('samplerate'),
      channels: positive('channels'),
      duration: seconds != null && seconds.isFinite && seconds > 0
          ? Duration(milliseconds: (seconds * 1000).round())
          : null,
      sizeBytes: positive('file-size'),
    );
  }
}
