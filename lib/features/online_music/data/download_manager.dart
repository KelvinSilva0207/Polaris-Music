// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/models/downloaded_track.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../domain/download_task.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';

/// Persiste una descarga en la biblioteca local. Devuelve el id de la fila.
typedef RegisterDownloadedCallback = Future<int> Function(
  DownloadedTrack track,
);

/// Comprueba si el `externalId` ya está en la biblioteca.
typedef HasDownloadedCallback = Future<bool> Function(String externalId);

/// Cola de descargas con `dio`.
///
/// - Máximo [maxConcurrent] descargas simultáneas, el resto espera.
/// - Progreso por pista y cancelación con `CancelToken`.
/// - Deduplicación por `externalId` antes de descargar.
/// - Al terminar registra la pista en Drift (vía callback) para que la
///   biblioteca la muestre al instante con la etiqueta de nube.
class DownloadManager implements DownloadQueue {
  DownloadManager({
    required OnlineMusicRepository repository,
    required RegisterDownloadedCallback registerDownloaded,
    required HasDownloadedCallback hasDownloaded,
    Dio? dio,
    this.maxConcurrent = 2,
  }) : _repository = repository,
       _registerDownloaded = registerDownloaded,
       _hasDownloaded = hasDownloaded,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(minutes: 10),
               headers: <String, String>{
                 'User-Agent': 'PolarisMusic/1.0 (Flutter)',
               },
             ),
           );

  static const String _tag = 'Downloads';

  final OnlineMusicRepository _repository;
  final RegisterDownloadedCallback _registerDownloaded;
  final HasDownloadedCallback _hasDownloaded;
  final Dio _dio;
  final int maxConcurrent;

  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};
  final List<String> _pending = <String>[];
  final StreamController<List<DownloadTask>> _changes =
      StreamController<List<DownloadTask>>.broadcast();

  int _active = 0;

  /// Emite la lista completa cada vez que cambia un estado.
  ///
  /// Al suscribirse entrega primero una foto del estado actual para que la UI
  /// que se abre tarde no pierda descargas ya iniciadas.
  Stream<List<DownloadTask>> get changes async* {
    yield tasks;
    yield* _changes.stream;
  }

  List<DownloadTask> get tasks =>
      List<DownloadTask>.unmodifiable(_tasks.values.toList(growable: false));

  bool get hasActive => _tasks.values.any((DownloadTask t) => t.isActive);

  @override
  void enqueue(OnlineTrack track) {
    final DownloadTask? current = _tasks[track.externalId];
    if (current != null && current.isActive) return;
    if (current != null && current.isCompleted) return;

    _tasks[track.externalId] = DownloadTask(track: track);
    _pending.add(track.externalId);
    _emit();
    _pump();
  }

  @override
  void cancel(String externalId) {
    _pending.remove(externalId);
    _tokens.remove(externalId)?.cancel();
    final DownloadTask? current = _tasks[externalId];
    if (current != null && current.isActive) {
      _tasks[externalId] = current.copyWith(status: DownloadStatus.canceled);
      _emit();
    }
  }

  @override
  void retry(OnlineTrack track) {
    final DownloadTask? current = _tasks[track.externalId];
    if (current != null && current.isActive) return;
    _tasks[track.externalId] = DownloadTask(track: track);
    _pending.add(track.externalId);
    _emit();
    _pump();
  }

  @override
  void clearFinished() {
    _tasks.removeWhere((String _, DownloadTask task) => !task.isActive);
    _emit();
  }

  void _pump() {
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final String externalId = _pending.removeAt(0);
      final DownloadTask? task = _tasks[externalId];
      if (task == null || !task.isActive) continue;
      _active++;
      unawaited(
        _run(task).whenComplete(() {
          _active--;
          _pump();
        }),
      );
    }
  }

  Future<void> _run(DownloadTask initial) async {
    final OnlineTrack track = initial.track;
    File? target;

    try {
      if (await _hasDownloaded(track.externalId)) {
        _update(initial, status: DownloadStatus.completed, progress: 1);
        return;
      }

      _update(initial, status: DownloadStatus.downloading);

      final ResolvedStream stream = await _repository.resolveStream(track);
      final String? artworkPath = await _repository.cacheArtwork(
        track.artworkUrl,
      );

      final Directory dir = await AppPaths.music();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String extension = stream.extension.isEmpty
          ? 'mp3'
          : stream.extension;
      final String baseName = FileUtils.sanitizeFileName(
        '${track.artist} - ${track.title}',
      );
      final String safeName = baseName.isEmpty
          ? FileUtils.fnv1a(track.externalId)
          : baseName;
      target = File(p.join(dir.path, '$safeName.$extension'));

      final CancelToken token = CancelToken();
      _tokens[track.externalId] = token;

      await _dio.download(
        stream.url,
        target.path,
        cancelToken: token,
        onReceiveProgress: (int received, int total) {
          if (total <= 0) return;
          final double progress = (received / total).clamp(0.0, 1.0);
          _update(
            initial,
            status: DownloadStatus.downloading,
            progress: progress,
          );
        },
        options: Options(
          followRedirects: true,
          headers: <String, String>{'Accept': 'audio/*,*/*;q=0.8'},
        ),
      );

      final int size = await target.length();
      final DownloadedTrack downloaded = DownloadedTrack(
        externalId: track.externalId,
        path: target.path,
        title: track.title,
        artist: track.artist,
        album: track.album.isEmpty ? track.sourceLabel : track.album,
        durationMs: track.durationMs,
        artworkPath: artworkPath,
        format: extension.toUpperCase(),
        fileSize: size,
        sourceLabel: track.sourceLabel,
      );

      await _registerDownloaded(downloaded);
      _update(
        initial,
        status: DownloadStatus.completed,
        progress: 1,
        filePath: target.path,
      );
      AppLog.i(_tag, 'Descarga completada: ${target.path}');
    } on DioException catch (error, stack) {
      if (CancelToken.isCancel(error)) {
        _update(initial, status: DownloadStatus.canceled);
      } else {
        _update(
          initial,
          status: DownloadStatus.failed,
          error: 'No se pudo descargar la pista. Inténtalo de nuevo.',
        );
        AppLog.w(_tag, 'Fallo al descargar ${track.externalId}', error, stack);
      }
      await _deletePartial(target);
    } catch (error, stack) {
      _update(
        initial,
        status: DownloadStatus.failed,
        error: 'No se pudo descargar la pista. Inténtalo de nuevo.',
      );
      AppLog.w(_tag, 'Fallo al descargar ${track.externalId}', error, stack);
      await _deletePartial(target);
    } finally {
      _tokens.remove(track.externalId);
    }
  }

  Future<void> _deletePartial(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un archivo bloqueado se limpiará en el siguiente intento.
    }
  }

  void _update(
    DownloadTask base, {
    DownloadStatus? status,
    double? progress,
    String? error,
    String? filePath,
  }) {
    final DownloadTask? current = _tasks[base.externalId];
    if (current == null) return;
    _tasks[base.externalId] = current.copyWith(
      status: status,
      progress: progress,
      error: error,
      filePath: filePath,
    );
    _emit();
  }

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(tasks);
  }

  Future<void> dispose() async {
    for (final CancelToken token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _pending.clear();
    await _changes.close();
    _dio.close(force: true);
  }
}
