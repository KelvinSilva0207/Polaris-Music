import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/audio_device_profile_service.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/audio_output_selection_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/system_audio_service.dart';

/// Selector de salida perezoso: se crea la primera vez que se abre el
/// reproductor, sin tocar el bootstrap compartido con otras áreas.
final ChangeNotifierProvider<AudioOutputSelectionService>
audioOutputSelectionProvider =
    ChangeNotifierProvider<AudioOutputSelectionService>((Ref ref) {
      final SystemAudioService systemAudio = sl<SystemAudioService>();
      final AudioOutputSelectionService service = AudioOutputSelectionService(
        engine: sl<AudioEngineService>(),
        settings: sl<SettingsService>(),
        systemAudio: systemAudio,
        resolveSystemDevice: (device) => systemAudio.resolveMediaKitDevice(
          name: device.name,
          description: device.description,
        ),
      );

      if (sl.isRegistered<AudioDeviceProfileService>()) {
        sl<AudioDeviceProfileService>().attachSelection(service);
      }
      unawaited(service.initialize());
      ref.onDispose(service.dispose);
      return service;
    });
