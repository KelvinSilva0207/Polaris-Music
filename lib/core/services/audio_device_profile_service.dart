import 'dart:async';

import '../constants/app_constants.dart';
import '../models/equalizer_config.dart';
import '../utils/logger.dart';
import 'settings_service.dart';
import 'system_audio_service.dart';

/// Perfiles de audio (ecualizador + sub-armónico) por dispositivo de salida.
///
/// Cada salida tiene su propio `scope` en la tabla `settings`, con la misma
/// clave `eq.config` que el perfil global. Así no hace falta una tabla nueva ni
/// una migración de esquema, y los perfiles viajan en el respaldo JSON v2.
///
/// El servicio solo decide **qué configuración toca**; la cadena `af` la sigue
/// construyendo `EqualizerDsp` y la aplica `EqualizerController`.
class AudioDeviceProfileService {
  AudioDeviceProfileService({
    required this._settings,
    required this._systemAudio,
  }) {
    _outputSub = _systemAudio.outputChanged.listen(_onOutputChanged);
    final AudioOutputDevice? initial = _systemAudio.currentOutput;
    if (initial != null) _onOutputChanged(initial);
  }

  static const String _tag = 'AudioProfiles';
  static const String _scopePrefix = 'device:';

  final SettingsService _settings;
  final SystemAudioService _systemAudio;
  StreamSubscription<AudioOutputDevice>? _outputSub;

  final StreamController<EqualizerConfig?> _activeController =
      StreamController<EqualizerConfig?>.broadcast();

  /// Configuración que debe aplicarse a la salida activa (`null` = usar global).
  Stream<EqualizerConfig?> get activeProfileChanged => _activeController.stream;

  EqualizerConfig? _activeConfig;
  EqualizerConfig? get activeConfig => _activeConfig;

  AudioOutputDevice? get currentDevice => _systemAudio.currentOutput;

  bool get enabled => _settings.perDeviceProfilesEnabled;

  String scopeFor(AudioOutputDevice device) => '$_scopePrefix${device.key}';

  /// Devuelve el perfil guardado para una salida, o `null` si no existe.
  Future<EqualizerConfig?> loadFor(AudioOutputDevice device) async {
    final String? raw = await _settings.getScoped(
      scopeFor(device),
      AppConstants.keyEqConfig,
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      return EqualizerConfig.deserialize(raw);
    } catch (error, stack) {
      AppLog.w(_tag, 'Perfil corrupto para ${device.name}', error, stack);
      return null;
    }
  }

  /// Guarda (o actualiza) el perfil de la salida indicada.
  Future<void> saveFor(AudioOutputDevice device, EqualizerConfig config) async {
    await _settings.setScoped(
      scopeFor(device),
      AppConstants.keyEqConfig,
      config.serialize(),
    );
    if (currentDevice == device && enabled) {
      _activeConfig = config;
      if (!_activeController.isClosed) _activeController.add(config);
    }
    AppLog.i(_tag, 'Perfil guardado para ${device.name}');
  }

  /// Guarda la configuración actual para la salida activa.
  Future<void> saveCurrent(EqualizerConfig config) async {
    final AudioOutputDevice? device = currentDevice;
    if (device != null) await saveFor(device, config);
  }

  /// Borra el perfil de una salida (no altera el perfil global).
  Future<void> deleteFor(AudioOutputDevice device) async {
    await _settings.removeScoped(scopeFor(device), AppConstants.keyEqConfig);
    if (currentDevice == device) {
      _activeConfig = null;
      if (!_activeController.isClosed) _activeController.add(null);
    }
  }

  /// Activa o desactiva la aplicación automática por salida.
  Future<void> setEnabled(bool value) async {
    await _settings.setBool(AppConstants.keyPerDeviceProfiles, value);
    final AudioOutputDevice? device = currentDevice;
    if (device != null) {
      _activeConfig = value ? await loadFor(device) : null;
      if (!_activeController.isClosed) _activeController.add(_activeConfig);
    }
  }

  void _onOutputChanged(AudioOutputDevice device) async {
    if (!enabled) {
      _activeConfig = null;
      if (!_activeController.isClosed) _activeController.add(null);
      return;
    }
    _activeConfig = await loadFor(device);
    if (!_activeController.isClosed) _activeController.add(_activeConfig);
    AppLog.i(
      _tag,
      _activeConfig == null
          ? 'Sin perfil para ${device.name}; se usa el global'
          : 'Perfil aplicado para ${device.name}',
    );
  }

  Future<void> dispose() async {
    await _outputSub?.cancel();
    await _activeController.close();
  }
}
