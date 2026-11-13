import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/settings_service.dart';
import '../domain/equalizer_controller.dart';

final StateNotifierProvider<EqualizerController, EqualizerState>
equalizerControllerProvider =
    StateNotifierProvider<EqualizerController, EqualizerState>((Ref ref) {
      final AppDatabase db = sl<AppDatabase>();
      final SettingsService settings = sl<SettingsService>();
      final EqualizerController controller = EqualizerController(
        db.eqDao,
        settings,
        sl<AudioEngineService>(),
      );
      unawaited(controller.load());
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Atajo para saber si el DSP real está conectado (libmpv disponible).
final Provider<bool> equalizerBackendAvailableProvider = Provider<bool>(
  (Ref ref) => sl<AudioEngineService>().dspAvailable,
);
