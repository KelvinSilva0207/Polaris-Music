import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../domain/player_controller.dart';

/// Estado del reproductor (transporte, cola, temporizador de sueño).
final StateNotifierProvider<PlayerController, PlayerUiState>
playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerUiState>((Ref ref) {
      final PlayerController controller = PlayerController(
        engine: sl(),
        settings: sl(),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Pista actual, para widgets que no necesitan toda la cola.
final Provider<Track?> currentTrackProvider = Provider<Track?>(
  (Ref ref) => ref.watch(playerControllerProvider).track,
);
