import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/settings_service.dart';

/// Contenido de la "isla dinámica" flotante.
enum IslandMode { hidden, compact, expanded }

/// Estado de UI de la isla.
///
/// Deliberadamente NO guarda pista, carátula, progreso ni reproducción: esos
/// datos los lee la vista directamente de `playerControllerProvider`, que es la
/// única fuente de verdad. Aquí solo vive el modo (compacto/expandido), el
/// mensaje temporal y la preferencia de activación.
@immutable
class DynamicIslandState {
  const DynamicIslandState({
    this.enabled = true,
    this.mode = IslandMode.compact,
    this.message,
  });

  final bool enabled;
  final IslandMode mode;
  final String? message;

  bool get visible => enabled && mode != IslandMode.hidden;
  bool get expanded => mode == IslandMode.expanded;

  DynamicIslandState copyWith({
    bool? enabled,
    IslandMode? mode,
    Object? message = _unset,
  }) => DynamicIslandState(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    message: identical(message, _unset) ? this.message : message as String?,
  );
}

const Object _unset = Object();

/// Controla el globo flotante que muestra la pista actual y acciones rápidas.
///
/// Se suscribe al motor solo para detectar un cambio de pista y expandirse una
/// vez; el contenido visible siempre viene del controlador del reproductor.
class DynamicIslandController extends StateNotifier<DynamicIslandState> {
  DynamicIslandController({
    required SettingsService settings,
    required AudioEngineService engine,
  }) : _settings = settings,
       super(
         DynamicIslandState(
           enabled: settings.boolOr(
             AppConstants.keyIslandEnabled,
             fallback: true,
           ),
         ),
       ) {
    _subscription = engine.states.listen(onPlayback);
  }

  final SettingsService _settings;
  StreamSubscription<PlaybackSnapshot>? _subscription;
  Timer? _collapseTimer;
  Timer? _messageTimer;
  int? _lastTrackId;

  /// Expansión fijada por el usuario: ni un aviso ni el temporizador automático
  /// deben compactarla.
  bool _userExpanded = false;

  void onPlayback(PlaybackSnapshot snapshot) {
    final int? trackId = snapshot.currentTrack?.id;
    if (trackId != null && trackId != _lastTrackId) {
      _lastTrackId = trackId;
      _userExpanded = false;
      state = state.copyWith(mode: IslandMode.expanded, message: null);
      _scheduleCollapse();
    }
  }

  Future<void> setEnabled(bool value) async {
    await _settings.setBool(AppConstants.keyIslandEnabled, value);
    _collapseTimer?.cancel();
    _messageTimer?.cancel();
    _userExpanded = false;
    state = state.copyWith(
      enabled: value,
      message: null,
      mode: value ? IslandMode.compact : IslandMode.hidden,
    );
    if (value) _scheduleCollapse();
  }

  void toggleExpanded() {
    // La interacción del usuario tiene prioridad sobre avisos y auto-ocultado.
    _collapseTimer?.cancel();
    _messageTimer?.cancel();
    _userExpanded = state.mode != IslandMode.expanded;
    state = state.copyWith(
      message: null,
      mode: _userExpanded ? IslandMode.expanded : IslandMode.compact,
    );
  }

  /// Muestra un mensaje breve (volumen, cambio de modo, etc.).
  void flash(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!state.enabled) return;
    _messageTimer?.cancel();
    _collapseTimer?.cancel();
    state = state.copyWith(message: message, mode: IslandMode.expanded);
    _messageTimer = Timer(duration, () {
      if (!mounted) return;
      state = state.copyWith(message: null);
      if (!_userExpanded) _scheduleCollapse();
    });
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (state.message == null && !_userExpanded) {
        state = state.copyWith(mode: IslandMode.compact);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _collapseTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }
}
