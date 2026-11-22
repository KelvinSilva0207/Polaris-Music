import 'dart:async';
import 'dart:convert';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../models/scrobble_config.dart';

/// Acceso tipado a las preferencias persistidas en la tabla `settings`.
///
/// Mantiene una caché en memoria para que la UI pueda leer valores de forma
/// síncrona (por ejemplo en `build`) y notifica cambios por [changes] para que
/// Riverpod reconstruya solo lo necesario.
class SettingsService {
  SettingsService(this._dao);

  final SettingsDao _dao;
  final StreamController<Map<String, String>> _changes =
      StreamController<Map<String, String>>.broadcast();

  Map<String, String> _values = const <String, String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Copia inmutable de las preferencias actuales.
  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  Stream<Map<String, String>> get changes => _changes.stream;

  Future<void> load() async {
    _values = await _dao.all();
    _loaded = true;
    _notify();
  }

  String? getString(String key) => _values[key];

  String stringOr(String key, String fallback) => getString(key) ?? fallback;

  bool boolOr(String key, {bool fallback = false}) {
    final String? raw = getString(key);
    if (raw == null) return fallback;
    return raw == 'true' || raw == '1';
  }

  int intOr(String key, {int fallback = 0}) =>
      int.tryParse(getString(key) ?? '') ?? fallback;

  double doubleOr(String key, {double fallback = 0}) =>
      double.tryParse(getString(key) ?? '') ?? fallback;

  Future<void> setString(String key, String value) async {
    await _dao.setValue(key, value);
    _values = <String, String>{..._values, key: value};
    _notify();
  }

  /// Lectura en un scope arbitrario (perfiles de usuario, salidas de audio).
  Future<String?> getScoped(String scope, String key) =>
      _dao.getValue(key, scope: scope);

  /// Escritura en un scope arbitrario sin tocar la caché global.
  Future<void> setScoped(String scope, String key, String value) =>
      _dao.setValue(key, value, scope: scope);

  Future<void> removeScoped(String scope, String key) =>
      _dao.remove(key, scope: scope);

  Future<void> setBool(String key, bool value) =>
      setString(key, value ? 'true' : 'false');

  Future<void> setInt(String key, int value) => setString(key, '$value');

  Future<void> setDouble(String key, double value) =>
      setString(key, value.toStringAsFixed(4));

  Future<void> remove(String key) async {
    await _dao.remove(key);
    final Map<String, String> next = <String, String>{..._values}..remove(key);
    _values = next;
    _notify();
  }

  /// Restaura las preferencias globales de configuración a su valor inicial.
  ///
  /// Usa [remove] para mantener la caché y el stream sincronizados. Nunca
  /// llama a `SettingsDao.clear()` sin scope: eso borraría credenciales,
  /// introducción y sesión de reproducción.
  Future<void> resetPreferences() async {
    for (final String key in AppConstants.resettablePreferenceKeys) {
      if (getString(key) != null) await remove(key);
    }
  }

  /// Borra solo los perfiles EQ por salida de audio (scopes `device:`).
  ///
  /// Se separa de [resetPreferences] para que la limpieza global funcione con
  /// servicios de pruebas sin base de datos real.
  Future<void> resetDeviceScopes() async {
    final Map<String, Map<String, String>> scoped = await _dao.allScoped();
    for (final String scope in scoped.keys) {
      if (scope.startsWith(AppConstants.resettableScopePrefix)) {
        await _dao.clear(scope: scope);
      }
    }
  }

  /// Atajos para las preferencias usadas por la app.
  bool get replayGainEnabled =>
      boolOr(AppConstants.keyReplayGain, fallback: true);

  /// Modo puro: bypass de la cadena de filtros sin borrar la curva guardada.
  bool get pureAudio => boolOr(AppConstants.keyPureAudio, fallback: false);

  Future<void> setPureAudio(bool value) =>
      setBool(AppConstants.keyPureAudio, value);

  bool get gaplessEnabled => boolOr(AppConstants.keyGapless, fallback: true);

  bool get crossfadeEnabled =>
      boolOr(AppConstants.keyCrossfade, fallback: false);

  /// Pausa al desconectar auriculares o cambiar de salida de audio.
  bool get pauseOnHeadphonesDisconnect =>
      boolOr(AppConstants.keyPauseOnHeadphonesDisconnect, fallback: false);

  /// Pausa cuando el volumen (de la app o del sistema en Android) llega a cero.
  bool get pauseOnVolumeZero =>
      boolOr(AppConstants.keyPauseOnVolumeZero, fallback: false);

  int get crossfadeMs => intOr(AppConstants.keyCrossfadeMs, fallback: 3000);

  /// Últimos términos buscados en la biblioteca, más reciente primero.
  List<String> get recentSearches {
    final String raw = stringOr(AppConstants.keyRecentSearches, '[]');
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .whereType<String>()
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// Guarda un término evitando duplicados y recortando la lista a 8 entradas.
  Future<void> rememberSearch(String term) async {
    final String clean = term.trim();
    if (clean.isEmpty) return;
    final List<String> next = <String>[
      clean,
      ...recentSearches.where(
        (String value) => value.toLowerCase() != clean.toLowerCase(),
      ),
    ];
    if (next.length > 8) next.length = 8;
    await setString(AppConstants.keyRecentSearches, jsonEncode(next));
  }

  Future<void> clearRecentSearches() => remove(AppConstants.keyRecentSearches);

  bool get karaokeEnabled =>
      boolOr(AppConstants.keyKaraokeEnabled, fallback: false);

  Future<void> setKaraokeEnabled(bool value) =>
      setBool(AppConstants.keyKaraokeEnabled, value);

  /// Configuración de scrobbling (claves de la API y sesión de Last.fm).
  ScrobbleConfig get scrobbleConfig {
    final String raw = stringOr(AppConstants.keyScrobbleConfig, '{}');
    try {
      return ScrobbleConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return ScrobbleConfig.empty;
    }
  }

  Future<void> setScrobbleConfig(ScrobbleConfig config) =>
      setString(AppConstants.keyScrobbleConfig, jsonEncode(config.toJson()));

  /// Minutos recordados del último temporizador personalizado.
  int get sleepTimerDefaultMinutes =>
      intOr(AppConstants.keySleepTimerDefault, fallback: 30).clamp(1, 480);

  /// Segundos de fundido al detenerse el temporizador de sueño.
  int get sleepFadeSeconds =>
      intOr(AppConstants.keySleepFadeSeconds, fallback: 5).clamp(1, 30);

  /// Recorte de silencios al inicio/final de las pistas.
  bool get silenceTrimEnabled =>
      boolOr(AppConstants.keySilenceTrim, fallback: false);

  int get silenceTrimStartMs =>
      intOr(AppConstants.keySilenceTrimStartMs, fallback: 0);

  int get silenceTrimEndMs =>
      intOr(AppConstants.keySilenceTrimEndMs, fallback: 0);

  /// Aplica automáticamente el EQ guardado para la salida activa.
  bool get perDeviceProfilesEnabled =>
      boolOr(AppConstants.keyPerDeviceProfiles, fallback: false);

  double get volume => doubleOr(
    AppConstants.keyVolume,
    fallback: 0.5,
  ).clamp(0.0, 1.0).toDouble();

  bool get onboardingDone =>
      boolOr(AppConstants.keyOnboardingDone, fallback: false);

  bool get scanOnStartup =>
      boolOr(AppConstants.keyScanOnStartup, fallback: true);

  Future<void> markOnboardingDone() =>
      setBool(AppConstants.keyOnboardingDone, true);

  Future<void> saveVolume(double value) =>
      setDouble(AppConstants.keyVolume, value.clamp(0.0, 1.0));

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(values);
    }
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
