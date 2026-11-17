import '../../../core/models/track.dart';
import 'online_music_repository.dart';
import 'online_track.dart';

/// Convierte una pista de catálogo en una pista reproducible.
///
/// Resuelve la URL directa de audio y cachea la carátula para que el
/// reproductor (volumen, progreso, letras y ecualizador) funcione igual que con
/// un archivo local.
class StreamTrackUseCase {
  const StreamTrackUseCase(this._repository);

  final OnlineMusicRepository _repository;

  Future<Track> call(OnlineTrack track) async {
    final String? artworkPath = await _repository.cacheArtwork(
      track.artworkUrl,
    );
    final ResolvedStream stream = await _repository.resolveStream(track);
    return track.toTrack(streamUrl: stream.url, artworkPath: artworkPath);
  }
}
