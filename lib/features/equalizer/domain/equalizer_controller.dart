import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/models/equalizer_preset.dart';
import '../../../core/services/audio_device_profile_service.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/system_audio_service.dart';
import '../../../core/utils/equalizer_dsp.dart';

/// Estado del ecualizador: configuración DSP + perfiles guardados.
@immutable
class EqualizerState {
  const EqualizerState({
    this.enabled = false,
    this.config = const EqualizerConfig(),
    this.presets = const <EqualizerPreset>[],
    this.selectedPreset = 'Flat',
    this.loaded = false,
    this.activeDeviceName,
    this.usingDeviceProfile = false,
    this.pure = false,
    this.perDeviceProfiles = false,
    this.dspDegraded = false,
  });

  final bool enabled;

  /// Bypass temporal de todo el DSP; la [config] no se toca.
  final bool pure;
  final EqualizerConfig config;
  final List<EqualizerPreset> presets;
  final String selectedPreset;
  final bool loaded;

  /// Nombre de la salida activa cuando hay perfiles por dispositivo activos.
  final String? activeDeviceName;

  /// `true` cuando la configuración visible pertenece al perfil del dispositivo
  /// (en vez del perfil global). Determina dónde se persisten los cambios.
  final bool usingDeviceProfile;

  /// Aplicación automática de perfiles por salida. Vive en el estado (no solo
  /// en el servicio) para que el interruptor responda aunque no haya salida
  /// detectada y por tanto no llegue ningún evento del servicio.
  final bool perDeviceProfiles;

  /// `true` cuando libmpv degradó la cadena pedida a un fallback. La UI debe
  /// decirlo en vez de anunciar un DSP activo que no está sonando.
  final bool dspDegraded;

  List<double> get bands => config.bands;
  double get preampDb => config.preampDb;
  EqMode get mode => config.mode;
  List<double> get frequencies => config.frequencies;
  List<ParametricFilter> get filters => config.filters;
  SubHarmonicSettings get sub => config.sub;

  EqualizerState copyWith({
    bool? enabled,
    EqualizerConfig? config,
    List<EqualizerPreset>? presets,
    String? selectedPreset,
    bool? loaded,
    Object? activeDeviceName = _unset,
    bool? usingDeviceProfile,
    bool? pure,
    bool? perDeviceProfiles,
    bool? dspDegraded,
  }) => EqualizerState(
    enabled: enabled ?? this.enabled,
    pure: pure ?? this.pure,
    config: config ?? this.config,
    presets: presets ?? this.presets,
    selectedPreset: selectedPreset ?? this.selectedPreset,
    loaded: loaded ?? this.loaded,
    activeDeviceName: identical(activeDeviceName, _unset)
        ? this.activeDeviceName
        : activeDeviceName as String?,
    usingDeviceProfile: usingDeviceProfile ?? this.usingDeviceProfile,
    perDeviceProfiles: perDeviceProfiles ?? this.perDeviceProfiles,
    dspDegraded: dspDegraded ?? this.dspDegraded,
  );

  static const Object _unset = Object();
}

/// Controlador del ecualizador.
///
/// Los ajustes se persisten en Drift y se envían a libmpv como una cadena
/// `lavfi` (preamp + bandas o filtros paramétricos + sub-armónico + anti-clip).
/// [EqualizerState.pure] bypassa esa cadena sin borrar la curva. En plataformas
/// sin libmpv nativo el DSP se omite y la UI lo indica.
class EqualizerController extends StateNotifier<EqualizerState> {
  EqualizerController(this._dao, this._settings, this._engine, [this._profiles])
    : super(const EqualizerState()) {
    _dspDegradedListener = () {
      if (!_controllerDisposed) {
        state = state.copyWith(dspDegraded: _engine.audioFilterDegraded.value);
      }
    };
    _engine.audioFilterDegraded.addListener(_dspDegradedListener);
  }

  final EqDao _dao;
  final SettingsService _settings;
  final AudioEngineService _engine;
  final AudioDeviceProfileService? _profiles;

  /// Los deslizadores envían muchos eventos por segundo. Solo la última
  /// configuración llega a libmpv: así el grafo de audio se reconstruye una vez
  /// por arrastre y no se percibe ningún corte mientras el dedo se mueve.
  static const Duration _liveDspWindow = Duration(milliseconds: 180);

  Timer? _dspDebounce;
  StreamSubscription<EqualizerConfig?>? _profileSub;
  late final VoidCallback _dspDegradedListener;
  bool _controllerDisposed = false;

  /// Perfil global (fuente de verdad cuando no hay perfil de dispositivo).
  EqualizerConfig _globalConfig = const EqualizerConfig();

  bool get backendAvailable => _engine.dspAvailable;

  bool get perDeviceProfilesEnabled => _profiles?.enabled ?? false;
  AudioOutputDevice? get currentDevice => _profiles?.currentDevice;

  Future<void> load() async {
    final List<EqPresetRow> rows = await _dao.getAll();
    final List<EqualizerPreset> presets = rows
        .map(EqualizerPreset.fromRow)
        .toList(growable: false);
    final String presetName = _settings.stringOr(
      AppConstants.keyEqPreset,
      'Flat',
    );
    final String rawConfig = _settings.stringOr(AppConstants.keyEqConfig, '');

    EqualizerConfig config;
    if (rawConfig.isNotEmpty) {
      config = EqualizerConfig.deserialize(rawConfig);
    } else if (presetName == 'Personalizado') {
      config = EqualizerConfig.fromLegacy(
        gains: _parseBands(
          _settings.stringOr(AppConstants.keyEqCustomBands, ''),
        ),
        preampDb: _settings.doubleOr(AppConstants.keyEqCustomPreamp),
      );
    } else {
      final EqualizerPreset selected = presets.firstWhere(
        (EqualizerPreset p) => p.name == presetName,
        orElse: () => presets.isEmpty ? EqualizerPreset.flat() : presets.first,
      );
      config = selected.config;
    }

    _globalConfig = config;
    state = state.copyWith(
      enabled: _settings.boolOr(AppConstants.keyEqEnabled, fallback: false),
      pure: _settings.pureAudio,
      config: config,
      presets: presets,
      selectedPreset: presetName,
      loaded: true,
      perDeviceProfiles: _profiles?.enabled ?? false,
      dspDegraded: _engine.audioFilterDegraded.value,
    );

    if (_profiles != null) {
      _profileSub ??= _profiles.activeProfileChanged.listen(_onActiveProfile);
      // El servicio se crea antes que este controlador: puede haber emitido un
      // perfil antes de que existiéramos. Se recupera el último valor.
      await _onActiveProfile(_profiles.activeConfig);
    } else {
      await _applyDsp();
    }
  }

  /// Reacciona al cambio de salida: muestra y aplica el perfil correspondiente
  /// (o vuelve al global). Nunca escribe `af` directamente; [_applyDsp] sigue
  /// siendo el único productor de la cadena de filtros.
  Future<void> _onActiveProfile(EqualizerConfig? profile) async {
    // El usuario puede cambiar de salida justo al soltar un deslizador: sin
    // este flush el perfil anterior perdería el último valor.
    await _flushPendingDsp();
    if (profile != null && _profiles != null) {
      state = state.copyWith(
        config: profile,
        activeDeviceName: _profiles.currentDevice?.name,
        usingDeviceProfile: true,
        selectedPreset: 'Personalizado',
      );
    } else {
      state = state.copyWith(
        config: _globalConfig,
        selectedPreset: _settings.stringOr(AppConstants.keyEqPreset, 'Flat'),
        activeDeviceName: null,
        usingDeviceProfile: false,
      );
    }
    await _applyDsp();
  }

  // ---------------------------------------------------------------------------
  // Perfiles por dispositivo de salida
  // ---------------------------------------------------------------------------

  /// Activa/desactiva la aplicación automática de perfiles por salida.
  Future<void> setPerDeviceProfiles(bool value) async {
    // Actualizamos la UI antes de tocar la base de datos: sin salida detectada
    // el servicio no emite nada y el interruptor antes se quedaba quieto.
    state = state.copyWith(perDeviceProfiles: value);
    await _profiles?.setEnabled(value);
    if (currentDevice == null) {
      await _onActiveProfile(null);
    }
  }

  /// Guarda la configuración actual como perfil de la salida activa.
  Future<void> saveProfileForCurrentDevice() async {
    await _profiles?.saveCurrent(state.config);
  }

  /// Borra el perfil de la salida activa y vuelve al global.
  Future<void> deleteProfileForCurrentDevice() async {
    final AudioOutputDevice? device = currentDevice;
    if (device == null) return;
    await _profiles!.deleteFor(device);
  }

  /// ¿Existe un perfil guardado para la salida activa?
  Future<bool> hasProfileForCurrentDevice() async {
    final AudioOutputDevice? device = currentDevice;
    if (device == null || _profiles == null) return false;
    return await _profiles.loadFor(device) != null;
  }

  Future<void> setEnabled(bool value) async {
    await _flushPendingDsp();
    state = state.copyWith(enabled: value);
    await _settings.setBool(AppConstants.keyEqEnabled, value);
    await _applyDsp();
  }

  Future<void> toggleEnabled() => setEnabled(!state.enabled);

  /// Activa/desactiva el bypass sin alterar la curva ni el sub-armónico.
  ///
  /// Es la única fuente de verdad del modo puro: persistimos la preferencia y
  /// recalculamos `af` para que el silencio de filtros sea inmediato.
  Future<void> setPure(bool value) async {
    await _flushPendingDsp();
    if (state.pure == value) return;
    state = state.copyWith(pure: value);
    await _settings.setPureAudio(value);
    await _applyDsp();
  }

  Future<void> togglePure() => setPure(!state.pure);

  Future<void> setMode(EqMode mode) async {
    await _update(state.config.copyWith(mode: mode));
  }

  /// Cambia el número de bandas del ecualizador gráfico conservando la curva.
  Future<void> setBandLayout(String layoutId) async {
    final List<double>? frequencies = AppConstants.eqBandLayouts[layoutId];
    if (frequencies == null) return;
    await _update(
      state.config.copyWith(
        frequencies: frequencies,
        bands: _remapBands(
          state.config.bands,
          state.config.frequencies,
          frequencies,
        ),
      ),
    );
  }

  /// Añade una banda personalizada en un hueco libre del espectro.
  Future<void> addBand() async {
    if (state.config.frequencies.length >= 31) return;
    final List<double> frequencies = List<double>.of(state.config.frequencies);
    final List<double> bands = List<double>.of(state.config.bands);
    final double last = frequencies.last;
    double next = math.min(AppConstants.eqMaxFrequency, last * 1.25);
    if (next <= last + 1) {
      next = math.max(AppConstants.eqMinFrequency, last / 1.1);
    }
    int insertAt = frequencies.indexWhere((double hz) => hz > next);
    if (insertAt < 0) insertAt = frequencies.length;
    frequencies.insert(insertAt, next);
    bands.insert(insertAt, 0);
    await _update(
      state.config.copyWith(frequencies: frequencies, bands: bands),
    );
  }

  /// Quita una banda del diseño personalizado (nunca deja menos de dos).
  Future<void> removeBand(int index) async {
    if (index < 0 ||
        index >= state.config.frequencies.length ||
        state.config.frequencies.length <= 2) {
      return;
    }
    final List<double> frequencies = List<double>.of(state.config.frequencies)
      ..removeAt(index);
    final List<double> bands = List<double>.of(state.config.bands)
      ..removeAt(index);
    await _update(
      state.config.copyWith(frequencies: frequencies, bands: bands),
    );
  }

  Future<void> setBand(int index, double gainDb) async {
    if (index < 0 || index >= state.config.bands.length) return;
    final List<double> bands = List<double>.of(state.config.bands);
    bands[index] = gainDb.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);
    await _update(state.config.copyWith(bands: bands), immediate: false);
  }

  Future<void> setPreamp(double db) async {
    await _update(
      state.config.copyWith(
        preampDb: db.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain),
      ),
      immediate: false,
    );
  }

  Future<void> setParametricFilter(int index, ParametricFilter filter) async {
    if (index < 0 || index >= state.config.filters.length) return;
    final List<ParametricFilter> filters = List<ParametricFilter>.of(
      state.config.filters,
    );
    filters[index] = filter;
    await _update(state.config.copyWith(filters: filters), immediate: false);
  }

  Future<void> addParametricFilter() async {
    if (state.config.filters.length >= AppConstants.eqMaxParametricFilters) {
      return;
    }
    final List<ParametricFilter> filters = List<ParametricFilter>.of(
      state.config.filters,
    );
    final double hz = math.min(
      AppConstants.eqMaxFrequency,
      (200 * math.pow(2, filters.length)).toDouble(),
    );
    filters.add(ParametricFilter(frequencyHz: hz));
    await _update(state.config.copyWith(filters: filters));
  }

  Future<void> removeParametricFilter(int index) async {
    if (index < 0 || index >= state.config.filters.length) return;
    final List<ParametricFilter> filters = List<ParametricFilter>.of(
      state.config.filters,
    )..removeAt(index);
    await _update(state.config.copyWith(filters: filters));
  }

  Future<void> setSub({bool? enabled, double? mix, double? crossoverHz}) async {
    await _update(
      state.config.copyWith(
        sub: state.config.sub.copyWith(
          enabled: enabled,
          mix: mix,
          crossoverHz: crossoverHz,
        ),
      ),
      immediate: mix == null && crossoverHz == null,
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
    state = state.copyWith(config: preset.config, selectedPreset: preset.name);
    await _persistConfig();
    await _applyDsp();
  }

  Future<void> saveAs(String name) async {
    final String cleaned = name.trim();
    if (cleaned.isEmpty) return;
    await _dao.save(
      name: cleaned,
      bands: state.config.bands,
      preampDb: state.config.preampDb,
      configJson: state.config.serialize(),
    );
    await _refreshPresets(selected: cleaned);
  }

  Future<void> deletePreset(EqualizerPreset preset) async {
    final int? id = preset.id;
    if (id == null || preset.isBuiltIn) return;
    await _dao.deletePreset(id);
    final bool wasSelected = state.selectedPreset == preset.name;
    if (wasSelected) {
      state = state.copyWith(
        config: const EqualizerConfig(),
        selectedPreset: 'Flat',
      );
      await _persistConfig();
      await _applyDsp();
    }
    await _refreshPresets(
      selected: wasSelected ? 'Flat' : state.selectedPreset,
    );
  }

  Future<void> reset() async {
    state = state.copyWith(
      config: const EqualizerConfig(),
      selectedPreset: 'Flat',
    );
    await _persistConfig();
    await _applyDsp();
  }

  /// Actualiza la configuración y decide si se aplica ya o con debounce.
  Future<void> _update(EqualizerConfig config, {bool immediate = true}) async {
    state = state.copyWith(config: config, selectedPreset: 'Personalizado');
    if (immediate) {
      await _applyDsp();
      await _persistConfig();
    } else {
      _scheduleDsp();
    }
  }

  Future<void> _applyDsp() async {
    _dspDebounce?.cancel();
    final List<String> candidates = EqualizerDsp.buildFilterCandidates(
      enabled: state.enabled,
      gains: state.config.bands,
      frequencies: state.config.frequencies,
      preampDb: state.config.preampDb,
      mode: state.config.mode,
      filters: state.config.filters,
      sub: state.config.sub,
      pure: state.pure,
    );
    await _engine.setAudioFilter(
      candidates.first,
      fallbacks: candidates.skip(1).toList(growable: false),
    );
  }

  /// Evita inundar libmpv mientras se arrastra un deslizador. La ventana se
  /// reinicia en cada evento, así que solo se aplica el valor final; la curva
  /// de la UI mientras tanto se actualiza de inmediato desde [state].
  void _scheduleDsp() {
    _dspDebounce?.cancel();
    _dspDebounce = Timer(_liveDspWindow, () {
      unawaited(_flushPendingDsp().then((_) => _applyDsp()));
    });
  }

  /// Cancela la ventana de arrastre y guarda el valor final antes de que otra
  /// acción cambie el alcance de la configuración (salida, pure, enabled).
  ///
  /// No vuelve a aplicar el DSP aquí: quien llama ya va a hacerlo con el estado
  /// final, y duplicarlo reconstruiría el grafo dos veces.
  Future<void> _flushPendingDsp() async {
    final Timer? timer = _dspDebounce;
    if (timer == null) return;
    _dspDebounce = null;
    if (timer.isActive) timer.cancel();
    await _persistConfig();
  }

  /// Guarda la configuración completa y mantiene las claves históricas.
  ///
  /// Con un perfil de dispositivo activo se escribe en ese scope (no se pisa el
  /// perfil global), de modo que cada salida recuerde su propio EQ/sub-graves.
  Future<void> _setIfChanged(String key, String value) async {
    if (_settings.getString(key) == value) return;
    await _settings.setString(key, value);
  }

  Future<void> _persistConfig({
    EqualizerConfig? config,
    String? preset,
    bool? usingDeviceProfile,
  }) async {
    final EqualizerConfig target = config ?? state.config;
    final String targetPreset = preset ?? state.selectedPreset;
    final bool targetUsingDevice =
        usingDeviceProfile ?? state.usingDeviceProfile;
    if (targetUsingDevice && _profiles != null) {
      await _profiles.saveCurrent(target);
      return;
    }
    _globalConfig = target;
    final String bands = target.bands
        .map((double gain) => gain.toStringAsFixed(2))
        .join(',');
    // Cada escritura notifica a todos los widgets que observan `settings`.
    // Omitir valores idénticos evita reconstrucciones innecesarias al arrastrar.
    await _setIfChanged(AppConstants.keyEqConfig, target.serialize());
    await _setIfChanged(AppConstants.keyEqPreset, targetPreset);
    await _setIfChanged(AppConstants.keyEqCustomBands, bands);
    final String preamp = target.preampDb.toStringAsFixed(4);
    if (_settings.stringOr(AppConstants.keyEqCustomPreamp, '') != preamp) {
      await _settings.setDouble(
        AppConstants.keyEqCustomPreamp,
        target.preampDb,
      );
    }
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

  /// Traslada las ganancias al nuevo conjunto de frecuencias por proximidad.
  static List<double> _remapBands(
    List<double> oldBands,
    List<double> oldFrequencies,
    List<double> newFrequencies,
  ) {
    return List<double>.generate(newFrequencies.length, (int i) {
      if (i < oldBands.length &&
          i < oldFrequencies.length &&
          (oldFrequencies[i] - newFrequencies[i]).abs() < 0.05) {
        return oldBands[i];
      }
      int best = -1;
      double distance = double.infinity;
      for (int j = 0; j < oldFrequencies.length && j < oldBands.length; j++) {
        final double d = (oldFrequencies[j] - newFrequencies[i]).abs();
        if (d < distance) {
          distance = d;
          best = j;
        }
      }
      return best >= 0 ? oldBands[best] : 0;
    });
  }

  @override
  void dispose() {
    _controllerDisposed = true;
    _engine.audioFilterDegraded.removeListener(_dspDegradedListener);
    // Si el usuario cierra la pantalla justo después de soltar un deslizador,
    // el temporizador aún no ha guardado el último valor: lo persistimos ahora.
    // No reaplicamos el DSP aquí: una invalidación del provider creará otro
    // controlador que aplicará su propia configuración al cargar.
    final Timer? timer = _dspDebounce;
    if (timer != null) {
      _dspDebounce = null;
      if (timer.isActive) timer.cancel();
      // Capturamos el estado antes de llamar a `super.dispose()`: el notifier
      // ya no debe leerse después de liberarse.
      final EqualizerConfig config = state.config;
      final String preset = state.selectedPreset;
      final bool usingDeviceProfile = state.usingDeviceProfile;
      unawaited(
        _persistConfig(
          config: config,
          preset: preset,
          usingDeviceProfile: usingDeviceProfile,
        ),
      );
    }
    unawaited(_profileSub?.cancel());
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
