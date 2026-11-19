import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import 'equalizer_config.dart';

/// Preset del ecualizador: nombre + configuración completa del DSP.
@immutable
class EqualizerPreset {
  const EqualizerPreset({
    this.id,
    required this.name,
    required this.config,
    this.isBuiltIn = false,
  });

  final int? id;
  final String name;
  final EqualizerConfig config;
  final bool isBuiltIn;

  /// Compatibilidad con callers que consumían la lista de ganancias.
  List<double> get gains => config.bands;
  double get preampDb => config.preampDb;

  bool get isFlat => config.isFlat;

  factory EqualizerPreset.flat() =>
      const EqualizerPreset(name: 'Flat', config: EqualizerConfig.flat);

  factory EqualizerPreset.fromRow(EqPresetRow row) {
    final EqualizerConfig config = row.configJson == null
        ? EqualizerConfig.fromLegacy(
            gains: _parseLegacy(row.bandsJson),
            preampDb: row.preampDb,
          )
        : EqualizerConfig.deserialize(row.configJson!);
    return EqualizerPreset(
      id: row.id,
      name: row.name,
      config: config,
      isBuiltIn: row.isBuiltIn,
    );
  }

  EqualizerPreset copyWith({String? name, EqualizerConfig? config}) =>
      EqualizerPreset(
        id: id,
        name: name ?? this.name,
        config: config ?? this.config,
        isBuiltIn: isBuiltIn,
      );

  /// Valor de ganancia normalizado (-1..1) para dibujar la curva.
  List<double> get normalizedGains => config.bands
      .map((double g) => (g / AppConstants.eqMaxGain).clamp(-1.0, 1.0))
      .toList(growable: false);

  static List<double> _parseLegacy(String raw) => raw
      .split(',')
      .map((String s) => double.tryParse(s.trim()) ?? 0)
      .toList(growable: false);
}
