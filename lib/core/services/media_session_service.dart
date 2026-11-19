import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart' as smtc;

import '../constants/app_constants.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import '../utils/logger.dart';
import 'audio_engine_service.dart';

/// Integración con los controles nativos de cada plataforma.
///
/// - Android: `audio_service` → notificación, pantalla de bloqueo y botones
///   de auriculares. `audio_service` **no soporta Windows** (su plugin solo
///   registra Android/iOS/macOS/web), por eso no se inicializa allí.
/// - Windows: `smtc_windows` → System Media Transport Controls (teclas
///   multimedia y panel de medios del sistema).
class MediaSessionService {
  MediaSessionService(this._engine);

  static const String _tag = 'MediaSession';

  final AudioEngineService _engine;

  AudioHandler? _androidHandler;
  smtc.SMTCWindows? _smtc;
  StreamSubscription<PlaybackSnapshot>? _stateSub;
  StreamSubscription<smtc.PressedButton>? _buttonSub;
  StreamSubscription<smtc.RepeatMode>? _repeatSub;
  StreamSubscription<bool>? _shuffleSub;

  Track? _smtcTrack;
  bool _smtcPlaying = false;
  DateTime _lastSmtcUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isAndroidSessionActive => _androidHandler != null;
  bool get isWindowsSessionActive => _smtc != null;

  /// Detiene la reproducción y el servicio en primer plano de Android.
  ///
  /// `AudioHandler.stop()` deja el estado en `idle`, que es lo que oculta la
  /// notificación persistente; además se pide al plataforma que detenga el
  /// `AudioService` para que no quede proceso en segundo plano.
  Future<void> shutdown() async {
    final AudioHandler? handler = _androidHandler;
    if (handler != null) {
      try {
        await handler.stop();
        // ignore: deprecated_member_use
        await AudioService.stop();
      } catch (error, stack) {
        AppLog.w(_tag, 'No se pudo detener el servicio de audio', error, stack);
      }
      _androidHandler = null;
    }
    await dispose();
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      _androidHandler = await AudioService.init(
        builder: () => PolarisAudioHandler(_engine),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.polaris.polaris_music.playback',
          androidNotificationChannelName: 'Polaris Music',
          androidNotificationChannelDescription: 'Controles de reproducción',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      AppLog.i(_tag, 'audio_service inicializado (Android)');
      return;
    }

    if (Platform.isWindows) {
      await _initWindows();
    }
  }

  Future<void> _initWindows() async {
    try {
      await smtc.SMTCWindows.initialize();
      _smtc = smtc.SMTCWindows(
        status: smtc.PlaybackStatus.stopped,
        config: const smtc.SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: false,
          fastForwardEnabled: true,
          rewindEnabled: true,
        ),
      );

      _buttonSub = _smtc!.buttonPressStream.listen(_onButton);
      _repeatSub = _smtc!.repeatModeChangeStream.listen((smtc.RepeatMode mode) {
        _engine.setRepeat(switch (mode) {
          smtc.RepeatMode.none => RepeatMode.off,
          smtc.RepeatMode.track => RepeatMode.one,
          smtc.RepeatMode.list => RepeatMode.all,
        });
      });
      _shuffleSub = _smtc!.shuffleChangeStream.listen(_engine.setShuffle);

      _stateSub = _engine.states.listen(_updateSmtc);
      AppLog.i(_tag, 'SMTC inicializado (Windows)');
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'SMTC no disponible; se continúa sin controles de sistema',
        error,
        stack,
      );
    }
  }

  void _onButton(smtc.PressedButton button) {
    switch (button) {
      case smtc.PressedButton.play:
        unawaited(_engine.play());
      case smtc.PressedButton.pause:
        unawaited(_engine.pause());
      case smtc.PressedButton.next:
        unawaited(_engine.next());
      case smtc.PressedButton.previous:
        unawaited(_engine.previous());
      case smtc.PressedButton.stop:
        unawaited(_engine.stop());
      case smtc.PressedButton.fastForward:
        unawaited(
          _engine.seek(_engine.state.position + const Duration(seconds: 10)),
        );
      case smtc.PressedButton.rewind:
        final Duration target =
            _engine.state.position - const Duration(seconds: 10);
        unawaited(
          _engine.seek(target < Duration.zero ? Duration.zero : target),
        );
      case smtc.PressedButton.record:
      case smtc.PressedButton.channelUp:
      case smtc.PressedButton.channelDown:
        break;
    }
  }

  void _updateSmtc(PlaybackSnapshot snapshot) {
    final smtc.SMTCWindows? smtcInstance = _smtc;
    if (smtcInstance == null) return;

    final Track? track = snapshot.currentTrack;
    // La identidad cambia también al editar etiquetas con el mismo id, de modo
    // que el panel de medios refleja la edición sin esperar un cambio de pista.
    final bool trackChanged = !identical(track, _smtcTrack);

    if (trackChanged) {
      _smtcTrack = track;
      unawaited(
        smtcInstance.updateMetadata(
          smtc.MusicMetadata(
            title: track?.title ?? AppConstants.appName,
            artist: track?.artist,
            album: track?.album,
            albumArtist: track?.albumArtist,
            thumbnail: track?.artworkPath,
          ),
        ),
      );
    }

    final DateTime now = DateTime.now();
    final bool timeToRefresh =
        now.difference(_lastSmtcUpdate) > const Duration(milliseconds: 900);

    if (trackChanged || timeToRefresh || snapshot.playing != _smtcPlaying) {
      _lastSmtcUpdate = now;
      _smtcPlaying = snapshot.playing;

      unawaited(
        smtcInstance.updateTimeline(
          smtc.PlaybackTimeline(
            positionMs: snapshot.position.inMilliseconds,
            startTimeMs: 0,
            endTimeMs: snapshot.duration.inMilliseconds,
            minSeekTimeMs: 0,
            maxSeekTimeMs: snapshot.duration.inMilliseconds,
          ),
        ),
      );
      unawaited(
        smtcInstance.setPlaybackStatus(
          snapshot.playing
              ? smtc.PlaybackStatus.playing
              : (snapshot.hasTrack
                    ? smtc.PlaybackStatus.paused
                    : smtc.PlaybackStatus.stopped),
        ),
      );
    }
  }

  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _buttonSub?.cancel();
    await _repeatSub?.cancel();
    await _shuffleSub?.cancel();
    await _smtc?.dispose();
    await _androidHandler?.stop();
  }
}

/// Handler de `audio_service` para Android.
class PolarisAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  PolarisAudioHandler(this._engine) {
    _subscription = _engine.states.listen(_onState);
  }

  final AudioEngineService _engine;
  StreamSubscription<PlaybackSnapshot>? _subscription;

  Track? _lastTrack;
  List<Track>? _lastQueue;
  bool _lastPlaying = false;
  Duration _lastPosition = Duration.zero;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  void _onState(PlaybackSnapshot snapshot) {
    final Track? track = snapshot.currentTrack;
    final bool trackChanged = !identical(track, _lastTrack);
    final bool queueChanged = !identical(snapshot.queue, _lastQueue);

    if (trackChanged) {
      _lastTrack = track;
      if (track != null) mediaItem.add(_toMediaItem(track));
    }
    if (queueChanged) {
      _lastQueue = snapshot.queue;
      queue.add(snapshot.queue.map(_toMediaItem).toList(growable: false));
    }

    final DateTime now = DateTime.now();
    final bool shouldEmit =
        trackChanged ||
        queueChanged ||
        snapshot.playing != _lastPlaying ||
        snapshot.completed ||
        (snapshot.position - _lastPosition).abs() >
            const Duration(milliseconds: 900) ||
        now.difference(_lastEmit) > const Duration(seconds: 2);

    if (!shouldEmit) return;

    _lastPlaying = snapshot.playing;
    _lastPosition = snapshot.position;
    _lastEmit = now;

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (snapshot.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const <int>[0, 1, 2],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: snapshot.buffering
            ? AudioProcessingState.buffering
            : (snapshot.hasTrack
                  ? AudioProcessingState.ready
                  : AudioProcessingState.idle),
        playing: snapshot.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.position,
        speed: snapshot.speed,
        repeatMode: switch (snapshot.repeat) {
          RepeatMode.off => AudioServiceRepeatMode.none,
          RepeatMode.one => AudioServiceRepeatMode.one,
          RepeatMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: snapshot.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        queueIndex: snapshot.index >= 0 ? snapshot.index : null,
      ),
    );
  }

  MediaItem _toMediaItem(Track track) => MediaItem(
    id: '${track.id}',
    title: track.title,
    album: track.album,
    artist: track.artist,
    duration: track.duration,
    artUri: track.artworkPath == null ? null : Uri.file(track.artworkPath!),
    playable: true,
  );

  @override
  Future<void> play() => _engine.play();

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> stop() async {
    await _engine.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _engine.seek(position);

  @override
  Future<void> skipToNext() => _engine.next();

  @override
  Future<void> skipToPrevious() => _engine.previous();

  /// Botón multimedia de los auriculares (`media` = play/pause).
  @override
  Future<void> click([MediaButton button = MediaButton.media]) =>
      switch (button) {
        MediaButton.media => _engine.playOrPause(),
        MediaButton.next => _engine.next(),
        MediaButton.previous => _engine.previous(),
      };

  @override
  Future<void> fastForward() =>
      _engine.seek(_engine.state.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() async {
    final Duration target =
        _engine.state.position - const Duration(seconds: 10);
    await _engine.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> prepare() => Future<void>.value();

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) =>
      Future<void>.value();

  @override
  Future<void> skipToQueueItem(int index) => _engine.playIndex(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    _engine.setRepeat(switch (repeatMode) {
      AudioServiceRepeatMode.none => RepeatMode.off,
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all => RepeatMode.all,
      AudioServiceRepeatMode.group => RepeatMode.off,
    });
    return Future<void>.value();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    _engine.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
    return Future<void>.value();
  }

  @override
  Future<void> onTaskRemoved() => _engine.pause();

  Future<void> disposeHandler() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
