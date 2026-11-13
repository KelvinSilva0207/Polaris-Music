import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/settings_service.dart';

/// Contenido de la "isla dinámica" flotante.
enum IslandMode { hidden, compact, expanded }

@immutable
class DynamicIslandState {
  const DynamicIslandState({
    this.enabled = true,
    this.mode = IslandMode.compact,
    this.message,
    this.track,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final bool enabled;
  final IslandMode mode;
  final String? message;
  final Track? track;
  final bool playing;
  final Duration position;
  final Duration duration;

  bool get visible =>
      enabled &&
      mode != IslandMode.hidden &&
      (track != null || message != null);
  bool get expanded => mode == IslandMode.expanded;
  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  DynamicIslandState copyWith({
    bool? enabled,
    IslandMode? mode,
    Object? message = _unset,
    Object? track = _unset,
    bool? playing,
    Duration? position,
    Duration? duration,
  }) => DynamicIslandState(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    message: identical(message, _unset) ? this.message : message as String?,
    track: identical(track, _unset) ? this.track : track as Track?,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

const Object _unset = Object();

/// Controla el globo flotante que muestra la pista actual y acciones rápidas.
///
/// En Fase 1 es un overlay dentro de la ventana (Windows/Android). En fases
/// posteriores puede convertirse en una ventana independiente o en una
/// notificación flotante nativa sin cambiar este estado.
class DynamicIslandController extends StateNotifier<DynamicIslandState> {
  DynamicIslandController({
    required SettingsService settings,
    required AudioEngineService engine,
  }) : _settings = settings,
       _engine = engine,
       super(
         DynamicIslandState(
           enabled: settings.boolOr(
             AppConstants.keyIslandEnabled,
             fallback: true,
           ),
           track: engine.state.currentTrack,
           playing: engine.state.playing,
         ),
       ) {
    _subscription = _engine.states.listen(onPlayback);
  }

  final SettingsService _settings;
  final AudioEngineService _engine;
  StreamSubscription<PlaybackSnapshot>? _subscription;
  Timer? _collapseTimer;
  Timer? _messageTimer;
  int? _lastTrackId;

  void onPlayback(PlaybackSnapshot snapshot) {
    final Track? track = snapshot.currentTrack;
    final bool changed = track != null && track.id != _lastTrackId;
    if (changed) {
      _lastTrackId = track.id;
      state = state.copyWith(
        track: track,
        mode: IslandMode.expanded,
        message: null,
      );
      _scheduleCollapse();
    }

    state = state.copyWith(
      track: track,
      playing: snapshot.playing,
      position: snapshot.position,
      duration: snapshot.duration,
      mode: changed ? IslandMode.expanded : state.mode,
    );
  }

  Future<void> setEnabled(bool value) async {
    await _settings.setBool(AppConstants.keyIslandEnabled, value);
    state = state.copyWith(
      enabled: value,
      mode: value ? IslandMode.compact : IslandMode.hidden,
    );
    if (value) _scheduleCollapse();
  }

  void toggleExpanded() {
    if (state.mode == IslandMode.expanded) {
      state = state.copyWith(mode: IslandMode.compact);
      _collapseTimer?.cancel();
    } else {
      state = state.copyWith(mode: IslandMode.expanded);
      _scheduleCollapse();
    }
  }

  /// Muestra un mensaje breve (volumen, cambio de modo, etc.).
  void flash(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!state.enabled) return;
    _messageTimer?.cancel();
    state = state.copyWith(message: message, mode: IslandMode.expanded);
    _messageTimer = Timer(duration, () {
      if (!mounted) return;
      state = state.copyWith(message: null, mode: IslandMode.compact);
    });
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (state.message == null) {
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
