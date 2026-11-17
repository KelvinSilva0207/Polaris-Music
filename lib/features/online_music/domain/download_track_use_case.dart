import 'download_task.dart';
import 'online_track.dart';

/// Encola la descarga de una pista del catálogo online.
///
/// La cola concreta (`DownloadManager`) resuelve la URL, descarga con `dio` y
/// registra el resultado en la biblioteca local.
class DownloadTrackUseCase {
  const DownloadTrackUseCase(this._queue);

  final DownloadQueue _queue;

  void call(OnlineTrack track) => _queue.enqueue(track);
}
