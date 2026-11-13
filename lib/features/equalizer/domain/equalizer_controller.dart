import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/equalizer_preset.dart';
import '../../../core/services/settings_service.dart';

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
/// **Limitación conocida de Fase 1:** `media_kit` no expone filtros de audio
/// (solo volumen, velocidad y tono), así que los ajustes se guardan y se
/// dibujan, pero el DSP real todavía no se aplica. No se simula: la UI muestra
/// un aviso claro y el README documenta la brecha. El backend (mpv
/// `af=equalizer` o un procesador nativo) se conectará en Fase 2 sin cambiar
/// este controlador.
class EqualizerController extends StateNotifier<EqualizerState> {
  EqualizerController(this._dao, this._settings)
    : super(const EqualizerState());

  final EqDao _dao;
  final SettingsService _settings;

  static const bool backendAvailable = false;

  Future<void> load() async {
    final List<EqPresetRow> rows = await _dao.getAll();
    final List<EqualizerPreset> presets = rows
        .map(EqualizerPreset.fromRow)
        .toList(growable: false);
    final String presetName = _settings.stringOr(
      AppConstants.keyEqPreset,
      'Flat',
    );
    final EqualizerPreset selected = presets.firstWhere(
      (EqualizerPreset p) => p.name == presetName,
      orElse: () => presets.isEmpty ? EqualizerPreset.flat() : presets.first,
    );

    state = state.copyWith(
      enabled: _settings.boolOr(AppConstants.keyEqEnabled, fallback: false),
      bands: List<double>.of(selected.gains),
      preampDb: selected.preampDb,
      presets: presets,
      selectedPreset: selected.name,
      loaded: true,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _settings.setBool(AppConstants.keyEqEnabled, value);
  }

  Future<void> toggleEnabled() => setEnabled(!state.enabled);

  Future<void> setBand(int index, double gainDb) async {
    if (index < 0 || index >= state.bands.length) return;
    final List<double> bands = List<double>.of(state.bands);
    bands[index] = gainDb.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);
    state = state.copyWith(bands: bands, selectedPreset: 'Personalizado');
  }

  Future<void> setPreamp(double db) async {
    state = state.copyWith(
      preampDb: db.clamp(-12.0, 12.0),
      selectedPreset: 'Personalizado',
    );
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
  }

  Future<void> _refreshPresets({required String selected}) async {
    final List<EqPresetRow> rows = await _dao.getAll();
    state = state.copyWith(
      presets: rows.map(EqualizerPreset.fromRow).toList(growable: false),
      selectedPreset: selected,
    );
  }
}
