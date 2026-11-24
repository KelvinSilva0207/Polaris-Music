import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' show AudioDevice;
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/audio_output_engine.dart';
import 'package:polaris_music/core/services/audio_output_selection_service.dart';
import 'package:polaris_music/core/services/system_audio_service.dart';

import 'support/fake_settings_service.dart';

class FakeAudioOutputEngine implements AudioOutputEngine {
  FakeAudioOutputEngine([List<AudioDevice>? devices]) {
    if (devices != null) _devices.addAll(devices);
  }

  final List<AudioDevice> _devices = <AudioDevice>[];
  final StreamController<List<AudioDevice>> _devicesController =
      StreamController<List<AudioDevice>>.broadcast();
  final StreamController<AudioDevice> _selectedController =
      StreamController<AudioDevice>.broadcast();

  AudioDevice _current = AudioDevice.auto();
  bool selectionAvailable = true;
  bool failSelection = false;

  int setAudioDeviceCalls = 0;
  int openCalls = 0;
  int seekCalls = 0;

  /// Snapshots que el cambio de salida NO debe tocar.
  List<Track> queue = const <Track>[];
  int queueIndex = 0;
  Duration position = const Duration(seconds: 42);

  @override
  List<AudioDevice> get availableAudioDevices =>
      List<AudioDevice>.unmodifiable(_devices);

  @override
  Stream<List<AudioDevice>> get availableAudioDevicesChanged =>
      _devicesController.stream;

  @override
  AudioDevice get currentAudioDevice => _current;

  @override
  Stream<AudioDevice> get currentAudioDeviceChanged =>
      _selectedController.stream;

  @override
  bool get audioOutputSelectionAvailable => selectionAvailable;

  @override
  Future<void> setAudioDevice(AudioDevice device) async {
    setAudioDeviceCalls++;
    if (failSelection) throw StateError('mpv rechazó el dispositivo');
    _current = device;
    _selectedController.add(device);
  }

  void emitDevices(List<AudioDevice> devices) {
    _devices
      ..clear()
      ..addAll(devices);
    _devicesController.add(List<AudioDevice>.unmodifiable(_devices));
  }

  Future<void> dispose() async {
    await _devicesController.close();
    await _selectedController.close();
  }
}

void main() {
  const AudioDevice speakers = AudioDevice('wasapi\\speakers', 'Altavoces USB');
  const AudioDevice headphones = AudioDevice(
    'wasapi\\headphones',
    'Auriculares',
  );

  group('Selector de salida de audio', () {
    test('restaura la salida persistida y resuelve su etiqueta', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final FakeAudioOutputEngine engine = FakeAudioOutputEngine(<AudioDevice>[
        speakers,
        headphones,
      ]);
      await settings.setString(
        AppConstants.keyAudioOutputDevice,
        speakers.name,
      );
      final AudioOutputSelectionService service = AudioOutputSelectionService(
        engine: engine,
        settings: settings,
      );

      await service.initialize();

      expect(service.state.selected.name, speakers.name);
      expect(service.state.selected.label, 'Altavoces USB');
      expect(engine.setAudioDeviceCalls, 1);
      expect(service.hasExplicitSelection, isTrue);
      service.dispose();
      await engine.dispose();
    });

    test('cambiar de salida no reabre la cola ni mueve la posición', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final FakeAudioOutputEngine engine = FakeAudioOutputEngine(<AudioDevice>[
        speakers,
        headphones,
      ]);
      final AudioOutputSelectionService service = AudioOutputSelectionService(
        engine: engine,
        settings: settings,
      );
      await service.initialize();
      final int callsBefore = engine.setAudioDeviceCalls;

      final AudioOutputChoice choice = service.state.choices.firstWhere(
        (AudioOutputChoice item) => item.name == headphones.name,
      );
      await service.select(choice);

      expect(engine.setAudioDeviceCalls, callsBefore + 1);
      expect(engine.openCalls, 0);
      expect(engine.seekCalls, 0);
      expect(engine.queue, isEmpty);
      expect(engine.queueIndex, 0);
      expect(engine.position, const Duration(seconds: 42));
      expect(
        settings.getString(AppConstants.keyAudioOutputDevice),
        headphones.name,
      );
      service.dispose();
      await engine.dispose();
    });

    test(
      'la salida elegida se resuelve a la clave de perfiles del EQ',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        final FakeAudioOutputEngine engine = FakeAudioOutputEngine(
          <AudioDevice>[speakers],
        );
        const AudioOutputDevice mapped = AudioOutputDevice(
          key: 'windows:endpoint-1',
          name: 'Altavoces USB',
          platform: 'windows',
        );
        final AudioOutputSelectionService service = AudioOutputSelectionService(
          engine: engine,
          settings: settings,
          resolveSystemDevice: (AudioDevice device) => mapped,
        );
        await service.initialize();
        await service.select(service.state.choices.last);

        expect(service.currentSystemDevice, mapped);
        expect(service.currentSystemDevice?.key, 'windows:endpoint-1');
        service.dispose();
        await engine.dispose();
      },
    );

    test('sin API real avisa y deja la salida automática', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final FakeAudioOutputEngine engine = FakeAudioOutputEngine(<AudioDevice>[
        speakers,
      ]);
      engine.selectionAvailable = false;
      final AudioOutputSelectionService service = AudioOutputSelectionService(
        engine: engine,
        settings: settings,
      );

      await service.initialize();
      await service.select(service.state.choices.last);

      expect(service.state.message, contains('no está disponible'));
      expect(service.state.platformSupportsSelection, isFalse);
      expect(service.state.selected.isAuto, isTrue);
      expect(engine.setAudioDeviceCalls, 0);
      expect(settings.getString(AppConstants.keyAudioOutputDevice), isNull);
      service.dispose();
      await engine.dispose();
    });

    test(
      'un dispositivo rechazado vuelve al automático y limpia la clave',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        final FakeAudioOutputEngine engine = FakeAudioOutputEngine(
          <AudioDevice>[speakers],
        );
        engine.failSelection = true;
        final AudioOutputSelectionService service = AudioOutputSelectionService(
          engine: engine,
          settings: settings,
        );
        await service.initialize();

        await service.select(service.state.choices.last);

        expect(service.state.selected.isAuto, isTrue);
        expect(service.state.message, contains('No se pudo usar'));
        expect(settings.getString(AppConstants.keyAudioOutputDevice), isNull);
        expect(engine.setAudioDeviceCalls, 2);
        service.dispose();
        await engine.dispose();
      },
    );

    test('si desaparece la salida elegida se vuelve al automático', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final FakeAudioOutputEngine engine = FakeAudioOutputEngine(<AudioDevice>[
        speakers,
        headphones,
      ]);
      final AudioOutputSelectionService service = AudioOutputSelectionService(
        engine: engine,
        settings: settings,
      );
      await service.initialize();
      await service.select(service.state.choices.last);

      engine.emitDevices(<AudioDevice>[speakers]);
      await Future<void>.delayed(Duration.zero);

      expect(service.state.selected.isAuto, isTrue);
      expect(service.state.message, contains('ya no está disponible'));
      expect(settings.getString(AppConstants.keyAudioOutputDevice), isNull);
      service.dispose();
      await engine.dispose();
    });
  });
}
