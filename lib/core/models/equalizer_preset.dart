import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';

/// Preset de ecualización de 10 bandas + preamplificador.
@immutable
class EqualizerPreset {
  const EqualizerPreset({
    this.id,
    required this.name,
    required this.gains,
    this.preampDb = 0,
    this.isBuiltIn = false,
  });

  final int? id;
  final String name;
  final List<double> gains;
  final double preampDb;
  final bool isBuiltIn;

  bool get isFlat => gains.every((double g) => g.abs() < 0.01) && preampDb == 0;

  factory EqualizerPreset.flat() => const EqualizerPreset(
    name: 'Flat',
    gains: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  factory EqualizerPreset.fromRow(EqPresetRow row) {
    final List<double> parsed = row.bandsJson
        .split(',')
        .map((String s) => double.tryParse(s.trim()) ?? 0)
        .toList(growable: false);
    return EqualizerPreset(
      id: row.id,
      name: row.name,
      gains: List<double>.generate(
        AppConstants.eqBands.length,
        (int i) => i < parsed.length ? parsed[i] : 0,
      ),
      preampDb: row.preampDb,
      isBuiltIn: row.isBuiltIn,
    );
  }

  EqualizerPreset copyWith({
    String? name,
    List<double>? gains,
    double? preampDb,
  }) => EqualizerPreset(
    id: id,
    name: name ?? this.name,
    gains: gains ?? this.gains,
    preampDb: preampDb ?? this.preampDb,
    isBuiltIn: isBuiltIn,
  );

  /// Valor de ganancia normalizado (-1..1) para dibujar la curva.
  List<double> get normalizedGains => gains
      .map((double g) => (g / AppConstants.eqMaxGain).clamp(-1.0, 1.0))
      .toList(growable: false);
}
