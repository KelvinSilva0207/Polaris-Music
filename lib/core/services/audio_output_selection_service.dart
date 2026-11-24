import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' show AudioDevice;

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'audio_output_engine.dart';
import 'settings_service.dart';
import 'system_audio_service.dart';

/// Traduce un `AudioDevice` de media_kit a la identidad estable que ya usan los
/// perfiles de ecualizador. Puede inyectarse en pruebas.
typedef AudioOutputSystemResolver = AudioOutputDevice? Function(
  AudioDevice device,
);

/// Una opción shown en el selector.
///
/// [name] es el identificador que mpv espera en `audio-device`; [label] es el
/// texto legible que viene en `description`. No guardamos el `description` como
/// clave porque puede cambiar si el usuario renombra el dispositivo.
@immutable
class AudioOutputChoice {
  const AudioOutputChoice._({
    required this.name,
    required this.label,
    required this.systemKey,
  });

  static const AudioOutputChoice automatic = AudioOutputChoice._(
    name: 'auto',
    label: 'Automática (sistema)',
    systemKey: null,
  );

  factory AudioOutputChoice.auto() => automatic;

  factory AudioOutputChoice.device(AudioDevice device, {String? systemKey}) {
    final String label = device.description.trim().isEmpty
        ? device.name
        : device.description.trim();
    return AudioOutputChoice._(
      name: device.name,
      label: label,
      systemKey: systemKey,
    );
  }

  final String name;
  final String label;
  final String? systemKey;

  bool get isAuto => name == 'auto' || name.isEmpty;

  AudioDevice get mediaKitDevice =>
      isAuto ? AudioDevice.auto() : AudioDevice(name, label);

  @override
  bool operator ==(Object other) =>
      other is AudioOutputChoice &&
      other.name == name &&
      other.systemKey == systemKey;

  @override
  int get hashCode => Object.hash(name, systemKey);

  @override
  String toString() => 'AudioOutputChoice($label, $name)';
}

/// Estado inmutable que consume la hoja de salida de audio.
@immutable
class AudioOutputSelectionState {
  const AudioOutputSelectionState({
    this.choices = const <AudioOutputChoice>[],
    this.selected = AudioOutputChoice.automatic,
    this.message,
    this.platformSupportsSelection = true,
    this.multiOutputSupported = false,
    this.multiOutputMessage =
        AudioOutputSelectionService.multiOutputExplanation,
  });

  final List<AudioOutputChoice> choices;
  final AudioOutputChoice selected;
  final String? message;
  final bool platformSupportsSelection;
  final bool multiOutputSupported;
  final String multiOutputMessage;

  @override
  bool operator ==(Object other) =>
      other is AudioOutputSelectionState &&
      other.selected == selected &&
      other.message == message &&
      other.platformSupportsSelection == platformSupportsSelection &&
      other.multiOutputSupported == multiOutputSupported &&
      _sameChoices(other.choices, choices);

  @override
  int get hashCode => Object.hash(
    selected,
    message,
    platformSupportsSelection,
    multiOutputSupported,
    Object.hashAll(choices),
  );

  static bool _sameChoices(
    List<AudioOutputChoice> a,
    List<AudioOutputChoice> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Selección de salida basada en la API real de media_kit.
///
/// `Player.setAudioDevice` cambia la propiedad `audio-device` de mpv: no vuelve
/// a abrir la playlist, así que la cola y la posición siguen donde estaban. El
/// nombre elegido se persiste en `settings` y se restaura al arrancar. Cuando
/// la plataforma no soporta la API (web) o mpv rechaza el dispositivo, el
/// servicio vuelve a `AudioDevice.auto()` y expone un mensaje claro.
class AudioOutputSelectionService extends ChangeNotifier {
  AudioOutputSelectionService({
    required this._engine,
    required this._settings,
    this._resolveSystemDevice,
    this._systemAudio,
  }) {
    _choices = <AudioOutputChoice>[AudioOutputChoice.auto()];
    _platformSupportsSelection = _engine.audioOutputSelectionAvailable;
  }

  static const String _tag = 'AudioOutput';

  /// Explicación mostrada cuando el usuario pregunta por dos salidas a la vez.
  static const String multiOutputExplanation =
      'La salida dual/múltiple está desactivada: media_kit 1.2.6 enruta cada '
      'reproductor a un solo audio-device. Para enviar el mismo sonido a dos '
      'altavoces, crea un dispositivo virtual en el sistema operativo.';

  static const String unsupportedPlatformExplanation =
      'La selección de salida no está disponible en esta plataforma. Se usa '
      'la salida automática del sistema.';

  final AudioOutputEngine _engine;
  final SettingsService _settings;
  final AudioOutputSystemResolver? _resolveSystemDevice;
  final SystemAudioService? _systemAudio;

  StreamSubscription<List<AudioDevice>>? _devicesSub;
  StreamSubscription<AudioDevice>? _selectedSub;
  StreamSubscription<Map<String, String>>? _settingsSub;

  List<AudioOutputChoice> _choices = <AudioOutputChoice>[];
  AudioOutputChoice _selected = AudioOutputChoice.auto();
  String? _message;
  bool _platformSupportsSelection = true;
  bool _initialized = false;
  bool _disposed = false;
  bool _suppressSettingsReaction = false;
  bool _applying = false;
  bool _handlingMissing = false;

  AudioOutputSelectionState get state => AudioOutputSelectionState(
    choices: List<AudioOutputChoice>.unmodifiable(_choices),
    selected: _selected,
    message: _message,
    platformSupportsSelection: _platformSupportsSelection,
    multiOutputSupported: false,
    multiOutputMessage: multiOutputExplanation,
  );

  /// `true` cuando el usuario ha fijado una salida distinta de la automática.
  bool get hasExplicitSelection => !_selected.isAuto;

  /// Salida en el formato que ya consumen los perfiles del ecualizador.
  AudioOutputDevice? get currentSystemDevice {
    if (_selected.isAuto) return null;
    final AudioOutputSystemResolver? resolver = _resolveSystemDevice;
    if (resolver == null) return null;
    try {
      return resolver(_selected.mediaKitDevice);
    } catch (_) {
      return null;
    }
  }

  /// Inicializa streams, restaura la preferencia y avisa a los servicios que
  /// necesitan saber si hay una salida fijada por el usuario.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    _platformSupportsSelection = _engine.audioOutputSelectionAvailable;
    _systemAudio?.hasExplicitAudioOutputSelection = () => hasExplicitSelection;

    _devicesSub = _engine.availableAudioDevicesChanged.listen((_) {
      _refreshChoices();
    });
    _selectedSub = _engine.currentAudioDeviceChanged.listen((_) {
      _refreshChoices();
    });
    _settingsSub = _settings.changes.listen((_) {
      if (!_suppressSettingsReaction) unawaited(reload());
    });

    _refreshChoices();
    await reload();
  }

  /// Vuelve a leer la preferencia persistida y la aplica al motor.
  Future<void> reload() async {
    if (_disposed) return;
    _platformSupportsSelection = _engine.audioOutputSelectionAvailable;
    if (!_platformSupportsSelection) {
      _selected = AudioOutputChoice.auto();
      _message = unsupportedPlatformExplanation;
      _notify();
      return;
    }

    final String? saved = _settings.getString(
      AppConstants.keyAudioOutputDevice,
    );
    final AudioDevice target = (saved == null || saved.trim().isEmpty)
        ? AudioDevice.auto()
        : AudioDevice(saved, _descriptionFor(saved) ?? saved);

    if (target.name == 'auto' &&
        _engine.currentAudioDevice.name == 'auto' &&
        !hasExplicitSelection) {
      _selected = AudioOutputChoice.auto();
      _message = null;
      _notify();
      return;
    }
    await _apply(target, persist: false);
  }

  /// Fija una salida concreta. No toca la playlist ni la posición.
  Future<void> select(AudioOutputChoice choice) async {
    if (_disposed) return;
    if (!_platformSupportsSelection) {
      _message = unsupportedPlatformExplanation;
      _notify();
      return;
    }
    await _apply(choice.mediaKitDevice, persist: true);
  }

  /// Vuelve a la selección automática del sistema.
  Future<void> selectAuto() => select(AudioOutputChoice.auto());

  /// Recarga la lista que expone media_kit (útil tras conectar un dispositivo).
  Future<void> refresh() async {
    if (_disposed) return;
    _refreshChoices();
  }

  Future<void> _apply(AudioDevice device, {required bool persist}) async {
    final bool isAuto = device.name == 'auto' || device.name.isEmpty;
    _applying = true;
    try {
      await _engine.setAudioDevice(device);
      if (persist) await _persist(device);
      _selected = _choiceFor(device);
      _message = null;
      _refreshChoices();
      AppLog.i(
        _tag,
        isAuto
            ? 'Salida automática activada'
            : 'Salida activa: ${_selected.label}',
      );
      _notify();
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo seleccionar la salida de audio', error, stack);
      if (!isAuto) {
        await _clearPreference();
        try {
          await _engine.setAudioDevice(AudioDevice.auto());
        } catch (_) {
          // Si incluso la salida automática falla, el mensaje lo indica.
        }
      }
      _selected = AudioOutputChoice.auto();
      _message = isAuto
          ? 'No se pudo volver a la salida automática. Inténtalo de nuevo.'
          : 'No se pudo usar “${device.description.isEmpty ? device.name : device.description}”. Se mantiene la salida automática.';
      _refreshChoices();
      _notify();
    } finally {
      _applying = false;
    }
  }

  Future<void> _persist(AudioDevice device) async {
    _suppressSettingsReaction = true;
    try {
      final bool isAuto = device.name == 'auto' || device.name.isEmpty;
      if (isAuto) {
        await _settings.remove(AppConstants.keyAudioOutputDevice);
      } else {
        await _settings.setString(
          AppConstants.keyAudioOutputDevice,
          device.name,
        );
      }
    } finally {
      _suppressSettingsReaction = false;
    }
  }

  Future<void> _clearPreference() async {
    _suppressSettingsReaction = true;
    try {
      await _settings.remove(AppConstants.keyAudioOutputDevice);
    } finally {
      _suppressSettingsReaction = false;
    }
  }

  void _refreshChoices() {
    if (_disposed) return;
    final List<AudioDevice> devices = _engine.availableAudioDevices;
    final List<AudioOutputChoice> next = <AudioOutputChoice>[
      AudioOutputChoice.auto(),
      for (final AudioDevice device in devices)
        if (device.name != 'auto' && device.name.isNotEmpty) _choiceFor(device),
    ];

    final String? saved = _settings.getString(
      AppConstants.keyAudioOutputDevice,
    );
    final String activeName = saved != null && saved.isNotEmpty
        ? saved
        : _engine.currentAudioDevice.name;
    AudioOutputChoice active = next.firstWhere(
      (AudioOutputChoice choice) => choice.name == activeName,
      orElse: () => _choiceFor(
        AudioDevice(activeName, _descriptionFor(activeName) ?? activeName),
      ),
    );
    if (!next.any((AudioOutputChoice choice) => choice.name == active.name)) {
      next.add(active);
    }

    bool changed = next.length != _choices.length;
    if (!changed) {
      for (int i = 0; i < next.length; i++) {
        if (next[i] != _choices[i]) {
          changed = true;
          break;
        }
      }
    }
    if (changed) _choices = List<AudioOutputChoice>.unmodifiable(next);

    if (!_applying && active != _selected) {
      _selected = active;
      changed = true;
    }

    if (saved != null &&
        saved.isNotEmpty &&
        devices.isNotEmpty &&
        !devices.any((AudioDevice device) => device.name == saved) &&
        !_applying &&
        !_handlingMissing) {
      unawaited(_handleMissingDevice(saved));
    }

    if (changed) _notify();
  }

  Future<void> _handleMissingDevice(String name) async {
    _handlingMissing = true;
    try {
      await _clearPreference();
      try {
        await _engine.setAudioDevice(AudioDevice.auto());
      } catch (_) {}
      _selected = AudioOutputChoice.auto();
      _message =
          'La salida “$name” ya no está disponible. Se volvió a la salida automática.';
      _notify();
    } finally {
      _handlingMissing = false;
    }
  }

  AudioOutputChoice _choiceFor(AudioDevice device) {
    String? systemKey;
    final AudioOutputSystemResolver? resolver = _resolveSystemDevice;
    if (resolver != null && device.name != 'auto' && device.name.isNotEmpty) {
      try {
        systemKey = resolver(device)?.key;
      } catch (_) {}
    }
    return AudioOutputChoice.device(device, systemKey: systemKey);
  }

  String? _descriptionFor(String name) {
    for (final AudioDevice device in _engine.availableAudioDevices) {
      if (device.name == name) {
        return device.description.trim().isEmpty
            ? null
            : device.description.trim();
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _devicesSub?.cancel();
    _selectedSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }
}
