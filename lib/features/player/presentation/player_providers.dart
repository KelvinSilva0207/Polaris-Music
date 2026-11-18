import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../../../core/services/playback_session_service.dart';
import '../../../core/services/window_service.dart';
import '../../library/data/library_repository.dart';
import '../domain/player_controller.dart';

/// Estado del reproductor (transporte, cola, temporizador de sueño).
final StateNotifierProvider<PlayerController, PlayerUiState>
playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerUiState>((Ref ref) {
      final PlayerController controller = PlayerController(
        engine: sl(),
        settings: sl(),
        session: sl<PlaybackSessionService>(),
        // El dominio solo recibe rutas; la infraestructura las resuelve a
        // pistas reales de la biblioteca sin exponer Drift a la UI.
        resolveTracks: (List<String> paths) async {
          final Map<String, Track> byPath = <String, Track>{
            for (final Track track in await sl<LibraryRepository>().all())
              if (track.path.isNotEmpty) track.path: track,
          };
          return paths
              .map((String path) => byPath[path])
              .whereType<Track>()
              .toList(growable: false);
        },
        persistFavorite: sl<LibraryRepository>().setFavorite,
        isBackgrounded: () =>
            sl.isRegistered<WindowService>() &&
            sl<WindowService>().backgrounded,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Pista actual, para widgets que no necesitan toda la cola.
final Provider<Track?> currentTrackProvider = Provider<Track?>(
  (Ref ref) => ref.watch(playerControllerProvider).track,
);
