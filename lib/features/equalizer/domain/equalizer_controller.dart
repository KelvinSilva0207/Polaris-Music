import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/equalizer_preset.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/equalizer_dsp.dart';

/// Estado del ecualizador de 10 bandas.
@immutable
class EqualizerState {
  const EqualizerState({
    this.enabled = false,
    this.bands = const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.preampDb = 0,
    this.presets = const <EqualizerPreset>[],
    this.selectedPreset = 'Flat',
    this.loaded = false,
  });

  final bool enabled;
  final List<double> bands;
  final double preampDb;
  final List<EqualizerPreset> presets;
  final String selectedPreset;
  final bool loaded;

  EqualizerState copyWith({
    bool? enabled,
    List<double>? bands,
    double? preampDb,
    List<EqualizerPreset>? presets,
    String? selectedPreset,
    bool? loaded,
  }) => EqualizerState(
    enabled: enabled ?? this.enabled,
    bands: bands ?? this.bands,
    preampDb: preampDb ?? this.preampDb,
    presets: presets ?? this.presets,
    selectedPreset: selectedPreset ?? this.selectedPreset,
    loaded: loaded ?? this.loaded,
  );
}

/// Controlador del ecualizador.
///
/// Los ajustes se persisten en Drift y, además, se envían a libmpv como una
/// cadena de filtros `lavfi` (preamp + 10 bandas). En plataformas sin libmpv
/// nativo el DSP se omite y la UI lo indica.
class EqualizerController extends StateNotifier<EqualizerState> {
  EqualizerController(this._dao, this._settings, this._engine)
    : super(const EqualizerState());

  final EqDao _dao;
  final SettingsService _settings;
  final AudioEngineService _engine;

  Timer? _dspDebounce;

  bool get backendAvailable => _engine.dspAvailable;

  Future<void> load() async {
    final List<EqPresetRow> rows = await _dao.getAll();
    final List<EqualizerPreset> presets = rows
        .map(EqualizerPreset.fromRow)
        .toList(growable: false);
    final String presetName = _settings.stringOr(
      AppConstants.keyEqPreset,
      'Flat',
    );
    final bool custom = presetName == 'Personalizado';
    final EqualizerPreset selected = custom
        ? EqualizerPreset(
            name: 'Personalizado',
            gains: _parseBands(
              _settings.stringOr(AppConstants.keyEqCustomBands, ''),
            ),
            preampDb: _settings.doubleOr(AppConstants.keyEqCustomPreamp),
          )
        : presets.firstWhere(
            (EqualizerPreset p) => p.name == presetName,
            orElse: () =>
                presets.isEmpty ? EqualizerPreset.flat() : presets.first,
          );

    state = state.copyWith(
      enabled: _settings.boolOr(AppConstants.keyEqEnabled, fallback: false),
      bands: List<double>.of(selected.gains),
      preampDb: selected.preampDb,
      presets: presets,
      selectedPreset: selected.name,
      loaded: true,
    );
    await _applyDsp();
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _settings.setBool(AppConstants.keyEqEnabled, value);
    await _applyDsp();
  }

  Future<void> toggleEnabled() => setEnabled(!state.enabled);

  Future<void> setBand(int index, double gainDb) async {
    if (index < 0 || index >= state.bands.length) return;
    final List<double> bands = List<double>.of(state.bands);
    bands[index] = gainDb.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);
    state = state.copyWith(bands: bands, selectedPreset: 'Personalizado');
    _scheduleDsp();
  }

  Future<void> setPreamp(double db) async {
    state = state.copyWith(
      preampDb: db.clamp(-12.0, 12.0),
      selectedPreset: 'Personalizado',
    );
    _scheduleDsp();
  }

  Future<void> applyPreset(String name) async {
    EqualizerPreset? preset;
    for (final EqualizerPreset candidate in state.presets) {
      if (candidate.name == name) {
        preset = candidate;
        break;
      }
    }
    if (preset == null) return;
    state = state.copyWith(
      bands: List<double>.of(preset.gains),
      preampDb: preset.preampDb,
      selectedPreset: preset.name,
    );
    await _settings.setString(AppConstants.keyEqPreset, preset.name);
    await _applyDsp();
  }

  Future<void> saveAs(String name) async {
    final String cleaned = name.trim();
    if (cleaned.isEmpty) return;
    await _dao.save(
      name: cleaned,
      bands: state.bands,
      preampDb: state.preampDb,
    );
    await _refreshPresets(selected: cleaned);
  }

  Future<void> deletePreset(EqualizerPreset preset) async {
    final int? id = preset.id;
    if (id == null || preset.isBuiltIn) return;
    await _dao.deletePreset(id);
    await _refreshPresets(
      selected: state.selectedPreset == preset.name
          ? 'Flat'
          : state.selectedPreset,
    );
  }

  Future<void> reset() async {
    state = state.copyWith(
      bands: List<double>.filled(AppConstants.eqBands.length, 0),
      preampDb: 0,
      selectedPreset: 'Flat',
    );
    await _settings.setString(AppConstants.keyEqPreset, 'Flat');
    await _applyDsp();
  }

  Future<void> _applyDsp() async {
    _dspDebounce?.cancel();
    await _engine.setAudioFilter(
      EqualizerDsp.buildFilter(
        enabled: state.enabled,
        gains: state.bands,
        preampDb: state.preampDb,
      ),
    );
  }

  /// Evita inundar libmpv mientras se arrastra un deslizador.
  void _scheduleDsp() {
    _dspDebounce?.cancel();
    _dspDebounce = Timer(const Duration(milliseconds: 60), () {
      unawaited(_persistCustom());
      unawaited(_applyDsp());
    });
  }

  /// Recuerda la curva manual para que sobreviva al reinicio.
  Future<void> _persistCustom() async {
    if (state.selectedPreset != 'Personalizado') return;
    await _settings.setString(AppConstants.keyEqPreset, 'Personalizado');
    await _settings.setString(
      AppConstants.keyEqCustomBands,
      state.bands.map((double gain) => gain.toStringAsFixed(2)).join(','),
    );
    await _settings.setDouble(AppConstants.keyEqCustomPreamp, state.preampDb);
  }

  static List<double> _parseBands(String raw) {
    final int length = AppConstants.eqBands.length;
    if (raw.isEmpty) return List<double>.filled(length, 0);
    final List<double> parsed = raw
        .split(',')
        .map((String value) => double.tryParse(value.trim()) ?? 0)
        .toList(growable: false);
    return List<double>.generate(
      length,
      (int index) => index < parsed.length
          ? parsed[index].clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain)
          : 0,
    );
  }

  @override
  void dispose() {
    _dspDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshPresets({required String selected}) async {
    final List<EqPresetRow> rows = await _dao.getAll();
    state = state.copyWith(
      presets: rows.map(EqualizerPreset.fromRow).toList(growable: false),
      selectedPreset: selected,
    );
  }
}
