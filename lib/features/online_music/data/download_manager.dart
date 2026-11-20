// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/models/downloaded_track.dart';
import '../../../core/models/track.dart' show StreamAlternative;
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../domain/download_task.dart';
import '../domain/music_source.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

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
    Future<Directory> Function()? musicDirectory,
    this.maxConcurrent = 2,
  }) : _repository = repository,
       _registerDownloaded = registerDownloaded,
       _hasDownloaded = hasDownloaded,
       _musicDirectory = musicDirectory ?? AppPaths.music,
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
  final Future<Directory> Function() _musicDirectory;
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
    File? partial;

    try {
      if (await _hasDownloaded(track.externalId)) {
        _update(initial, status: DownloadStatus.completed, progress: 1);
        return;
      }

      _update(initial, status: DownloadStatus.downloading);

      final ResolvedStream stream = await _repository.resolveStream(track);
      final String? artworkPath = await _repository.cacheArtworkFor(track);

      final Directory dir = await _musicDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String extension = stream.extension.isEmpty
          ? 'mp3'
          : stream.extension;
      final String baseName = FileUtils.sanitizeFileName(
        '${track.artist} - ${track.title}',
      );
      // El hash evita colisiones entre pistas con el mismo título en fuentes
      // distintas (la columna `path` de la biblioteca es única).
      final String safeName =
          '${baseName.isEmpty ? 'pista' : baseName}_'
          '${FileUtils.fnv1a(track.externalId)}';
      target = File(p.join(dir.path, '$safeName.$extension'));
      partial = File('${target.path}.part');
      if (await partial.exists()) await partial.delete();

      final CancelToken token = CancelToken();
      _tokens[track.externalId] = token;

      // Cada URL de InnerTube lleva las cabeceras de SU cliente. La principal
      // y las alternativas se prueban en orden: si el primero responde 403 por
      // expiración/-cliente, el siguiente suele funcionar sin pedir la pista
      // otra vez.
      final List<StreamAlternative> candidates = <StreamAlternative>[
        StreamAlternative(
          url: stream.url,
          httpHeaders: stream.httpHeaders,
          label: stream.clientLabel,
        ),
        ...stream.alternatives,
      ];
      for (int i = 0; i < candidates.length; i++) {
        final StreamAlternative candidate = candidates[i];
        try {
          await _dio.download(
            candidate.url,
            partial.path,
            cancelToken: token,
            onReceiveProgress: (int received, int total) {
              if (total <= 0) {
                _update(
                  initial,
                  status: DownloadStatus.downloading,
                  indeterminate: true,
                );
                return;
              }
              final double progress = (received / total).clamp(0.0, 1.0);
              _update(
                initial,
                status: DownloadStatus.downloading,
                progress: progress,
                indeterminate: false,
              );
            },
            options: Options(
              followRedirects: true,
              headers: <String, String>{
                'Accept': 'audio/*,*/*;q=0.8',
                ...candidate.httpHeaders,
              },
            ),
          );
          break;
        } on DioException catch (error) {
          final int? status = error.response?.statusCode;
          final bool retryable =
              i < candidates.length - 1 &&
              !CancelToken.isCancel(error) &&
              (status == 401 ||
                  status == 403 ||
                  status == 404 ||
                  status == 410);
          if (!retryable) rethrow;
          AppLog.w(
            _tag,
            'Fallo al descargar con ${candidate.label.isEmpty ? 'la fuente principal' : candidate.label} '
            '($status); probando alternativa ${i + 2}/${candidates.length}',
            error,
          );
          await _deletePartial(partial);
        }
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);

      final int size = await target.length();
      final String originLabel = stream.resolvedVia ?? track.sourceLabel;
      final String album = stream.resolvedVia == null
          ? (track.album.isEmpty ? track.sourceLabel : track.album)
          : (track.album.isEmpty
                ? originLabel
                : '$originLabel · ${track.album}');
      final DownloadedTrack downloaded = DownloadedTrack(
        externalId: track.externalId,
        path: target.path,
        title: track.title,
        artist: track.artist,
        album: album,
        durationMs: track.durationMs,
        artworkPath: artworkPath,
        format: extension.toUpperCase(),
        fileSize: size,
        sourceLabel: originLabel,
      );

      await _registerDownloaded(downloaded);
      _update(
        initial,
        status: DownloadStatus.completed,
        progress: 1,
        indeterminate: false,
        filePath: target.path,
      );
      AppLog.i(_tag, 'Descarga completada: ${target.path}');
    } on DioException catch (error, stack) {
      if (CancelToken.isCancel(error)) {
        _update(initial, status: DownloadStatus.canceled);
      } else {
        final MusicSourceId source =
            MusicSourceIdX.fromExternalId(track.externalId) ??
            MusicSourceId.audius;
        final String detail = MusicSourceErrorMapper.map(error, source).detail;
        _update(
          initial,
          status: DownloadStatus.failed,
          error: detail.isEmpty ? 'No se pudo descargar la pista.' : detail,
        );
        AppLog.w(_tag, 'Fallo al descargar ${track.externalId}', error, stack);
      }
      await _deletePartial(partial);
    } catch (error, stack) {
      final String detail = error is MusicSourceException
          ? error.message
          : MusicSourceErrorMapper.map(
              error,
              MusicSourceIdX.fromExternalId(track.externalId) ??
                  MusicSourceId.audius,
            ).detail;
      _update(
        initial,
        status: DownloadStatus.failed,
        error: detail.isEmpty ? 'No se pudo descargar la pista.' : detail,
      );
      AppLog.w(_tag, 'Fallo al descargar ${track.externalId}', error, stack);
      await _deletePartial(partial);
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
    bool? indeterminate,
    String? error,
    String? filePath,
  }) {
    final DownloadTask? current = _tasks[base.externalId];
    if (current == null) return;
    _tasks[base.externalId] = current.copyWith(
      status: status,
      progress: progress,
      indeterminate: indeterminate,
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
