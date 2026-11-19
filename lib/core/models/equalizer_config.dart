import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Tipo de ecualizador activo.
enum EqMode { graphic, parametric }

EqMode eqModeFromCode(int code) =>
    code == 1 ? EqMode.parametric : EqMode.graphic;

extension EqModeX on EqMode {
  int get code => this == EqMode.parametric ? 1 : 0;
  String get label => this == EqMode.parametric ? 'Paramétrico' : 'Gráfico';
}

/// Tipo de filtro biquadrático del ecualizador paramétrico.
enum ParametricFilterType { peaking, lowShelf, highShelf, lowpass, highpass }

extension ParametricFilterTypeX on ParametricFilterType {
  String get id => switch (this) {
    ParametricFilterType.peaking => 'peaking',
    ParametricFilterType.lowShelf => 'lowShelf',
    ParametricFilterType.highShelf => 'highShelf',
    ParametricFilterType.lowpass => 'lowpass',
    ParametricFilterType.highpass => 'highpass',
  };

  String get label => switch (this) {
    ParametricFilterType.peaking => 'Campana',
    ParametricFilterType.lowShelf => 'Estante grave',
    ParametricFilterType.highShelf => 'Estante agudo',
    ParametricFilterType.lowpass => 'Pasa-bajos',
    ParametricFilterType.highpass => 'Pasa-altos',
  };
}

ParametricFilterType parametricFilterTypeFromId(String id) {
  for (final ParametricFilterType type in ParametricFilterType.values) {
    if (type.id == id) return type;
  }
  return ParametricFilterType.peaking;
}

/// Un filtro paramétrico: frecuencia central, ganancia y ancho de banda (Q).
@immutable
class ParametricFilter {
  const ParametricFilter({
    this.enabled = true,
    this.type = ParametricFilterType.peaking,
    this.frequencyHz = 1000,
    this.gainDb = 0,
    this.q = 1,
  });

  final bool enabled;
  final ParametricFilterType type;
  final double frequencyHz;
  final double gainDb;
  final double q;

  /// Filtros iniciales: cuatro campanas planas repartidas por el espectro.
  static const List<ParametricFilter> defaults = <ParametricFilter>[
    ParametricFilter(frequencyHz: 80),
    ParametricFilter(frequencyHz: 350),
    ParametricFilter(frequencyHz: 2200),
    ParametricFilter(frequencyHz: 8000),
  ];

  ParametricFilter copyWith({
    bool? enabled,
    ParametricFilterType? type,
    double? frequencyHz,
    double? gainDb,
    double? q,
  }) => ParametricFilter(
    enabled: enabled ?? this.enabled,
    type: type ?? this.type,
    frequencyHz: frequencyHz ?? this.frequencyHz,
    gainDb: gainDb ?? this.gainDb,
    q: q ?? this.q,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'type': type.id,
    'frequencyHz': frequencyHz,
    'gainDb': gainDb,
    'q': q,
  };

  factory ParametricFilter.fromJson(Map<String, dynamic> json) {
    return ParametricFilter(
      enabled: json['enabled'] as bool? ?? true,
      type: parametricFilterTypeFromId('${json['type'] ?? ''}'),
      frequencyHz: _finite(
        json['frequencyHz'],
        fallback: 1000,
      ).clamp(AppConstants.eqMinFrequency, AppConstants.eqMaxFrequency),
      gainDb: _finite(json['gainDb'])
          .clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain),
      q: _finite(
        json['q'],
        fallback: 1,
      ).clamp(AppConstants.eqMinQ, AppConstants.eqMaxQ),
    );
  }

  static double _finite(Object? value, {double fallback = 0}) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? fallback;
    return parsed.isFinite ? parsed : fallback;
  }
}

/// Sintetizador sub-armónico: mezcla de una copia desplazada una octava hacia
/// abajo de las frecuencias inferiores al corte indicado.
@immutable
class SubHarmonicSettings {
  const SubHarmonicSettings({
    this.enabled = false,
    this.mix = 0.18,
    this.crossoverHz = 90,
  });

  final bool enabled;
  final double mix;
  final double crossoverHz;

  SubHarmonicSettings copyWith({
    bool? enabled,
    double? mix,
    double? crossoverHz,
  }) => SubHarmonicSettings(
    enabled: enabled ?? this.enabled,
    mix: mix ?? this.mix,
    crossoverHz: crossoverHz ?? this.crossoverHz,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'mix': mix,
    'crossoverHz': crossoverHz,
  };

  factory SubHarmonicSettings.fromJson(Map<String, dynamic> json) {
    final double mix = ParametricFilter._finite(
      json['mix'],
      fallback: 0.18,
    ).clamp(AppConstants.subMinMix, AppConstants.subMaxMix);
    final double crossover = ParametricFilter._finite(
      json['crossoverHz'],
      fallback: 90,
    ).clamp(AppConstants.subMinCrossover, AppConstants.subMaxCrossover);
    return SubHarmonicSettings(
      enabled: json['enabled'] as bool? ?? false,
      mix: mix,
      crossoverHz: crossover,
    );
  }
}

/// Configuración completa del DSP: modo, curva, filtros y sub-armónico.
///
/// Se serializa en un único campo de la base de datos para que un preset
/// restaure exactamente la cadena de filtros que el usuario guardó.
@immutable
class EqualizerConfig {
  const EqualizerConfig({
    this.mode = EqMode.graphic,
    this.frequencies = AppConstants.eqBands,
    this.bands = const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.filters = ParametricFilter.defaults,
    this.preampDb = 0,
    this.sub = const SubHarmonicSettings(),
  });

  final EqMode mode;
  final List<double> frequencies;
  final List<double> bands;
  final List<ParametricFilter> filters;
  final double preampDb;
  final SubHarmonicSettings sub;

  static const EqualizerConfig flat = EqualizerConfig();

  /// Identificador del diseño gráfico activo, o `custom` si se ha editado.
  String get layoutId {
    for (final MapEntry<String, List<double>> entry
        in AppConstants.eqBandLayouts.entries) {
      if (_sameFrequencies(entry.value, frequencies)) return entry.key;
    }
    return AppConstants.eqCustomLayout;
  }

  bool get isFlat =>
      preampDb.abs() < 0.01 &&
      bands.every((double gain) => gain.abs() < 0.01) &&
      filters.every(
        (ParametricFilter filter) =>
            !filter.enabled || filter.gainDb.abs() < 0.01,
      ) &&
      !sub.enabled;

  EqualizerConfig copyWith({
    EqMode? mode,
    List<double>? frequencies,
    List<double>? bands,
    List<ParametricFilter>? filters,
    double? preampDb,
    SubHarmonicSettings? sub,
  }) => EqualizerConfig(
    mode: mode ?? this.mode,
    frequencies: frequencies ?? this.frequencies,
    bands: bands ?? this.bands,
    filters: filters ?? this.filters,
    preampDb: preampDb ?? this.preampDb,
    sub: sub ?? this.sub,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'mode': mode.code,
    'frequencies': frequencies,
    'bands': bands,
    'filters': filters
        .map((ParametricFilter filter) => filter.toJson())
        .toList(growable: false),
    'preampDb': preampDb,
    'sub': sub.toJson(),
  };

  String serialize() => jsonEncode(toJson());

  factory EqualizerConfig.deserialize(String raw) {
    if (raw.trim().isEmpty) return const EqualizerConfig();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const EqualizerConfig();
      return EqualizerConfig.fromJson(decoded);
    } catch (_) {
      return const EqualizerConfig();
    }
  }

  factory EqualizerConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawFrequencies = json['frequencies'] is List
        ? json['frequencies'] as List
        : const [];
    final List<dynamic> rawBands = json['bands'] is List
        ? json['bands'] as List
        : const [];
    final int length = rawFrequencies.length > rawBands.length
        ? rawFrequencies.length
        : rawBands.length;
    final int safeLength = length == 0 ? AppConstants.eqBands.length : length;

    final List<double> frequencies = List<double>.generate(safeLength, (int i) {
      final double fallback = i < AppConstants.eqBands.length
          ? AppConstants.eqBands[i]
          : 20000;
      final double value = i < rawFrequencies.length
          ? ParametricFilter._finite(rawFrequencies[i], fallback: fallback)
          : fallback;
      return value.clamp(
        AppConstants.eqMinFrequency,
        AppConstants.eqMaxFrequency,
      );
    })..sort();

    final List<double> bands = List<double>.generate(safeLength, (int i) {
      final double value = i < rawBands.length
          ? ParametricFilter._finite(rawBands[i])
          : 0;
      return value.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);
    });

    final List<ParametricFilter> filters = json['filters'] is List
        ? (json['filters'] as List)
              .whereType<Map>()
              .map(
                (Map entry) =>
                    ParametricFilter.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList(growable: false)
        : List<ParametricFilter>.of(ParametricFilter.defaults);

    final Object? rawSub = json['sub'];
    final SubHarmonicSettings sub = rawSub is Map<String, dynamic>
        ? SubHarmonicSettings.fromJson(rawSub)
        : rawSub is Map
        ? SubHarmonicSettings.fromJson(Map<String, dynamic>.from(rawSub))
        : const SubHarmonicSettings();

    return EqualizerConfig(
      mode: eqModeFromCode(ParametricFilter._finite(json['mode']).toInt()),
      frequencies: frequencies,
      bands: bands,
      filters: filters.isEmpty
          ? List<ParametricFilter>.of(ParametricFilter.defaults)
          : filters,
      preampDb: ParametricFilter._finite(json['preampDb'])
          .clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain),
      sub: sub,
    );
  }

  /// Presets creados antes de los modos gráfico/paramétrico.
  factory EqualizerConfig.fromLegacy({
    required List<double> gains,
    double preampDb = 0,
  }) {
    // Los presets históricos tenían exactamente 10 bandas; si llega una lista
    // más corta se rellena con ceros para no perder el diseño original.
    final int length = gains.length > AppConstants.eqBands.length
        ? gains.length
        : AppConstants.eqBands.length;
    final List<double> bands = List<double>.generate(
      length,
      (int i) => i < gains.length
          ? gains[i].clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain)
          : 0,
    );
    final List<double> frequencies = List<double>.generate(
      bands.length,
      (int i) =>
          i < AppConstants.eqBands.length ? AppConstants.eqBands[i] : 20000,
    );
    return EqualizerConfig(
      frequencies: frequencies,
      bands: bands,
      preampDb: preampDb,
    );
  }

  static bool _sameFrequencies(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.051) return false;
    }
    return true;
  }
}
