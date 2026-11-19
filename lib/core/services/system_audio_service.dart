import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:ffi/ffi.dart' show calloc;
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import '../models/playback_state.dart';
import '../utils/logger.dart';
import 'audio_engine_service.dart';
import 'settings_service.dart';

/// Salida de audio activa detectada por el sistema.
///
/// La [key] es estable entre reinicios (endpoint de WASAPI en Windows, tipo +
/// nombre del dispositivo en Android) y sirve para guardar perfiles de EQ por
/// salida sin depender de ids volátiles.
@immutable
class AudioOutputDevice {
  const AudioOutputDevice({
    required this.key,
    required this.name,
    required this.platform,
  });

  final String key;
  final String name;
  final String platform;

  static const AudioOutputDevice unknown = AudioOutputDevice(
    key: 'unknown',
    name: 'Salida predeterminada',
    platform: 'unknown',
  );

  @override
  bool operator ==(Object other) =>
      other is AudioOutputDevice && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'AudioOutputDevice($name, $key)';
}

/// Detecta eventos del sistema relacionados con la salida de audio.
///
/// - Android: usa `audio_session` para «becoming noisy» (desconectar
///   auriculares) y para cambios de dispositivos, además de consultar el
///   volumen de la corriente multimedia.
/// - Windows: consulta periódicamente el endpoint de reproducción por defecto
///   y su volumen maestro mediante WASAPI/COM.
/// - Todas las plataformas: reacciona al volumen efectivo del motor, de modo
///   que bajar el deslizador de la app a cero también puede pausar.
class SystemAudioService {
  SystemAudioService({required this.engine, required this.settings});

  static const String _tag = 'SystemAudio';

  final AudioEngineService engine;
  final SettingsService settings;

  StreamSubscription<PlaybackSnapshot>? _engineSub;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesSub;
  Timer? _pollTimer;

  IMMDeviceEnumerator? _enumerator;
  bool _comInitialized = false;
  bool _wasSystemVolumeZero = false;
  String? _lastEndpointId;

  final StreamController<AudioOutputDevice> _outputController =
      StreamController<AudioOutputDevice>.broadcast();
  AudioOutputDevice? _currentOutput;

  /// Salida activa actual (o `null` hasta la primera detección).
  AudioOutputDevice? get currentOutput => _currentOutput;

  /// Cambios de salida. Lo consume el perfil de audio por dispositivo.
  Stream<AudioOutputDevice> get outputChanged => _outputController.stream;

  void _setOutput(AudioOutputDevice device) {
    if (_currentOutput == device) return;
    _currentOutput = device;
    if (!_outputController.isClosed) _outputController.add(device);
    AppLog.i(_tag, 'Salida de audio: ${device.name} (${device.key})');
  }

  /// Registra la interfaz COM que no viene generada en `package:win32`.
  /// Se ejecuta una sola vez por proceso.
  static final bool _endpointVolumeRegistered = () {
    ComInterface.register<IAudioEndpointVolume>(
      const IAudioEndpointVolumeCompanion(),
    );
    return true;
  }();

  Future<void> initialize() async {
    if (kIsWeb) return;

    _engineSub = engine.states.listen(_onEngineState);

    if (Platform.isAndroid) {
      final AudioSession session = await AudioSession.instance;
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        if (settings.pauseOnHeadphonesDisconnect) {
          unawaited(_pause('auriculares desconectados'));
        }
      });
      _devicesSub = session.devicesChangedEventStream.listen(_onDevicesChanged);
      unawaited(_refreshAndroidOutput());
      _pollTimer = Timer.periodic(
        const Duration(seconds: 1),
        (Timer _) => unawaited(_pollAndroidVolume()),
      );
      AppLog.i(_tag, 'Eventos de audio de Android suscritos');
      return;
    }

    if (Platform.isWindows) {
      await _initWindows();
    }
  }

  void _onEngineState(PlaybackSnapshot snapshot) {
    if (!settings.pauseOnVolumeZero) return;
    if (snapshot.playing && snapshot.volume <= 0.5) {
      unawaited(_pause('volumen de la app al 0 %'));
    }
  }

  void _onDevicesChanged(AudioDevicesChangedEvent event) {
    // Cualquier cambio de salida (incluida una conexión nueva) debe notificarse
    // al perfil de audio por dispositivo.
    if (event.devicesAdded.any((AudioDevice d) => d.isOutput) ||
        event.devicesRemoved.any((AudioDevice d) => d.isOutput)) {
      unawaited(_refreshAndroidOutput());
    }
    if (!settings.pauseOnHeadphonesDisconnect) return;
    if (event.devicesRemoved.any((AudioDevice device) => device.isOutput)) {
      unawaited(_pause('salida de audio desconectada'));
    }
  }

  /// Consulta los dispositivos disponibles y publica la salida preferida.
  ///
  /// `audio_session` no expone la ruta activa en Android, así que se prioriza
  /// cualquier salida que no sea el altavoz/auricular integrado (BT, USB, cable).
  Future<void> _refreshAndroidOutput() async {
    try {
      final AudioSession session = await AudioSession.instance;
      final Set<AudioDevice> devices = await session.getDevices(
        includeInputs: false,
        includeOutputs: true,
      );
      final List<AudioDevice> outputs = devices
          .where((AudioDevice d) => d.isOutput)
          .toList(growable: false);
      if (outputs.isEmpty) return;
      // Se compara por nombre para no depender de los valores del enum
      // experimental `AudioDeviceType` (cambian entre versiones del plugin).
      const Set<String> builtIn = <String>{'builtInSpeaker', 'builtInEarpiece'};
      final AudioDevice chosen = outputs.firstWhere(
        (AudioDevice d) => !builtIn.contains(d.type.name),
        orElse: () => outputs.first,
      );
      _setOutput(
        AudioOutputDevice(
          key: 'android:${chosen.type.name}:${chosen.name}:${chosen.id}',
          name: chosen.name.isEmpty ? chosen.type.name : chosen.name,
          platform: 'android',
        ),
      );
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo consultar la salida de Android', error, stack);
    }
  }

  Future<void> _pollAndroidVolume() async {
    if (!settings.pauseOnVolumeZero) {
      _wasSystemVolumeZero = false;
      return;
    }
    try {
      final int level = await AndroidAudioManager().getStreamVolume(
        AndroidStreamType.music,
      );
      final bool isZero = level == 0;
      if (isZero && !_wasSystemVolumeZero) {
        await _pause('volumen del sistema al 0 %');
      }
      _wasSystemVolumeZero = isZero;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo leer el volumen de Android', error, stack);
    }
  }

  Future<void> _initWindows() async {
    if (!_endpointVolumeRegistered) return;
    try {
      HRESULT result = CoInitializeEx(COINIT_APARTMENTTHREADED);
      if (result.isError) result = CoInitializeEx(COINIT_MULTITHREADED);
      if (result.isError) throw WindowsException(result);
      _comInitialized = true;

      _enumerator = createInstance<IMMDeviceEnumerator>(MMDeviceEnumerator);
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (Timer _) => unawaited(_pollWindows()),
      );
      await _pollWindows();
      AppLog.i(_tag, 'Seguimiento de endpoint y volumen de Windows activo');
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo iniciar la monitorización de audio de Windows',
        error,
        stack,
      );
    }
  }

  /// Lee el dispositivo de reproducción por defecto y su volumen maestro.
  ///
  /// El identificador del endpoint cambia al conectar o desconectar auriculares
  /// Bluetooth/USB, así que sirve como señal de desconexión sin procesar
  /// notificaciones COM en el hilo de UI.
  Future<void> _pollWindows() async {
    final IMMDeviceEnumerator? enumerator = _enumerator;
    if (enumerator == null) return;

    IMMDevice? device;
    IAudioEndpointVolume? endpointVolume;
    try {
      device = enumerator.getDefaultAudioEndpoint(eRender, eMultimedia);
      if (device == null) return;

      final PWSTR idPointer = device.getId();
      final String endpointId = idPointer.toDartString();
      CoTaskMemFree(idPointer);

      _setOutput(
        AudioOutputDevice(
          key: 'windows:$endpointId',
          name: _friendlyName(device, endpointId),
          platform: 'windows',
        ),
      );

      endpointVolume = device.queryInterface<IAudioEndpointVolume>();
      final double level = endpointVolume.getMasterVolumeLevelScalar();

      final String? previous = _lastEndpointId;
      _lastEndpointId = endpointId;
      if (previous != null &&
          previous != endpointId &&
          settings.pauseOnHeadphonesDisconnect) {
        await _pause('salida de audio cambiada');
      }

      final bool isZero = level <= 0.001;
      if (isZero && !_wasSystemVolumeZero && settings.pauseOnVolumeZero) {
        await _pause('volumen del sistema al 0 %');
      }
      _wasSystemVolumeZero = isZero;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo consultar el audio de Windows', error, stack);
    } finally {
      endpointVolume?.release();
      device?.release();
    }
  }

  /// Nombre amigable del endpoint (p. ej. «Altavoces (Realtek)»).
  ///
  /// Si la propiedad no está disponible se usa el id de WASAPI como fallback.
  String _friendlyName(IMMDevice device, String fallback) {
    IPropertyStore? store;
    Pointer<PROPVARIANT>? variant;
    final Pointer<PROPERTYKEY> key = PKEY_Device_FriendlyName.toNative(
      allocator: calloc,
    );
    try {
      store = device.openPropertyStore(STGM_READ);
      if (store == null) return fallback;
      variant = store.getValue(key);
      final PCWSTR text = PropVariantToStringWithDefault(variant, null);
      if (text.address == 0) return fallback;
      final String name = text.toDartString().trim();
      return name.isEmpty ? fallback : name;
    } catch (_) {
      return fallback;
    } finally {
      if (variant != null) PropVariantClear(variant);
      calloc.free(key);
      store?.release();
    }
  }

  Future<void> _pause(String reason) async {
    if (!engine.state.playing) return;
    await engine.pause();
    AppLog.i(_tag, 'Pausa automática: $reason');
  }

  Future<void> dispose() async {
    await _engineSub?.cancel();
    await _noisySub?.cancel();
    await _devicesSub?.cancel();
    _pollTimer?.cancel();
    await _outputController.close();

    final IMMDeviceEnumerator? enumerator = _enumerator;
    _enumerator = null;
    enumerator?.release();
    if (_comInitialized) {
      CoUninitialize();
      _comInitialized = false;
    }
  }
}

/// Interfaz COM `IAudioEndpointVolume` de WASAPI.
///
/// `package:win32` no la genera, pero el vtable es estable: los tres primeros
/// punteros son `IUnknown` y declaramos los métodos intermedios para llegar a
/// `GetMasterVolumeLevelScalar`, que es el único que se invoca. El resto del
/// vtable no se toca.
class IAudioEndpointVolume extends IUnknown implements ComInterface {
  IAudioEndpointVolume(super.ptr)
    : _vtable = ptr.value.cast<IAudioEndpointVolumeVtbl>().ref;

  factory IAudioEndpointVolume.from(IUnknown interface) =>
      interface.queryInterface();

  final IAudioEndpointVolumeVtbl _vtable;

  late final int Function(VTablePointer, Pointer<Float>)
  _getMasterVolumeLevelScalarFn = _vtable.getMasterVolumeLevelScalar
      .asFunction<int Function(VTablePointer, Pointer<Float>)>();

  /// Volumen maestro del endpoint en el rango 0.0..1.0.
  double getMasterVolumeLevelScalar() {
    final Pointer<Float> level = calloc<Float>();
    try {
      final HRESULT result = HRESULT(_getMasterVolumeLevelScalarFn(ptr, level));
      if (result.isError) throw WindowsException(result);
      return level.value;
    } finally {
      calloc.free(level);
    }
  }
}

base class IAudioEndpointVolumeVtbl extends Struct {
  external IUnknownVtbl base$;

  external Pointer<NativeFunction<Int32 Function(VTablePointer, VTablePointer)>>
  registerControlChangeNotify;

  external Pointer<NativeFunction<Int32 Function(VTablePointer, VTablePointer)>>
  unregisterControlChangeNotify;

  external Pointer<
    NativeFunction<Int32 Function(VTablePointer, Pointer<Uint32>)>
  >
  getChannelCount;

  external Pointer<
    NativeFunction<Int32 Function(VTablePointer, Float, Pointer<GUID>)>
  >
  setMasterVolumeLevel;

  external Pointer<
    NativeFunction<Int32 Function(VTablePointer, Float, Pointer<GUID>)>
  >
  setMasterVolumeLevelScalar;

  external Pointer<
    NativeFunction<Int32 Function(VTablePointer, Pointer<Float>)>
  >
  getMasterVolumeLevel;

  external Pointer<
    NativeFunction<Int32 Function(VTablePointer, Pointer<Float>)>
  >
  getMasterVolumeLevelScalar;
}

final class IAudioEndpointVolumeCompanion
    extends ComCompanion<IAudioEndpointVolume> {
  const IAudioEndpointVolumeCompanion();

  @override
  IAudioEndpointVolume Function(VTablePointer ptr) get fromPointer =>
      IAudioEndpointVolume.new;

  @override
  GUID get iid => iidIAudioEndpointVolume;
}

/// `{5CDF2C82-841E-4546-9722-0CF74078229A}`.
final GUID iidIAudioEndpointVolume = GUID.fromComponents(
  0x5cdf2c82,
  0x841e,
  0x4546,
  .fromList(const <int>[0x97, 0x22, 0x0c, 0xf7, 0x40, 0x78, 0x22, 0x9a]),
);
