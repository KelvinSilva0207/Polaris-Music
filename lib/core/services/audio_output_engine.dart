import 'package:media_kit/media_kit.dart' show AudioDevice;

/// Contrato mínimo que necesita el selector de salida.
///
/// `AudioEngineService` lo implementa sin exponer media_kit a la UI. Las pruebas
/// pueden sustituirlo por un motor falso sin inicializar libmpv.
abstract class AudioOutputEngine {
  /// Dispositivos que media_kit/mpv ha descubierto.
  List<AudioDevice> get availableAudioDevices;

  /// Cambios en la lista de dispositivos disponibles.
  Stream<List<AudioDevice>> get availableAudioDevicesChanged;

  /// Dispositivo que mpv tiene seleccionado ahora mismo.
  AudioDevice get currentAudioDevice;

  /// Cambios en el dispositivo seleccionado.
  Stream<AudioDevice> get currentAudioDeviceChanged;

  /// `false` en plataformas donde `Player.setAudioDevice` no existe (web).
  bool get audioOutputSelectionAvailable;

  /// Cambia la salida sin reabrir la playlist ni mover la posición.
  Future<void> setAudioDevice(AudioDevice device);
}
