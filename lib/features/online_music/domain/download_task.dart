import 'package:flutter/foundation.dart';

import 'online_track.dart';

/// Estado de una descarga dentro de la cola.
enum DownloadStatus { queued, downloading, completed, failed, canceled }

/// Foto inmutable de una descarga para la UI.
@immutable
class DownloadTask {
  const DownloadTask({
    required this.track,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.error,
    this.filePath,
  });

  final OnlineTrack track;
  final DownloadStatus status;

  /// Avance entre 0 y 1 (0 cuando el servidor no informa el tamaño).
  final double progress;
  final String? error;
  final String? filePath;

  String get externalId => track.externalId;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  bool get isCompleted => status == DownloadStatus.completed;

  bool get isFailed => status == DownloadStatus.failed;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
    String? filePath,
  }) => DownloadTask(
    track: track,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error ?? this.error,
    filePath: filePath ?? this.filePath,
  );

  @override
  String toString() => 'DownloadTask($externalId, ${status.name})';
}

/// Cola de descargas expuesta al dominio.
abstract interface class DownloadQueue {
  /// Encola una pista. Si ya está activa no se duplica.
  void enqueue(OnlineTrack track);

  /// Cancela una descarga activa o quita una pendiente.
  void cancel(String externalId);

  /// Reintenta una descarga fallida o cancelada.
  void retry(OnlineTrack track);

  /// Elimina de la lista las tareas ya finalizadas.
  void clearFinished();
}
