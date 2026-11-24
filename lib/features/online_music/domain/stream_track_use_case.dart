import '../../../core/models/track.dart';
import 'online_music_repository.dart';
import 'online_track.dart';
import 'stream_retry.dart';

/// Convierte una pista de catálogo en una pista reproducible.
///
/// Resuelve la URL directa de audio con reintento ante `403`/caducidad y cachea
/// la carátula sin que un fallo de imagen impida sonar. El reproductor (volumen,
/// progreso, letras y ecualizador) funciona igual que con un archivo local.
class StreamTrackUseCase {
  StreamTrackUseCase(
    OnlineMusicRepository repository, {
    ResilientStreamResolver? resolver,
  }) : _resolver = resolver ?? ResilientStreamResolver(repository);

  final ResilientStreamResolver _resolver;

  Future<Track> call(OnlineTrack track) async {
    final ResolvedAudio resolved = await _resolver.resolve(track);
    final ResolvedStream stream = resolved.stream;
    return track.toTrack(
      streamUrl: stream.url,
      artworkPath: resolved.artworkPath,
      httpHeaders: stream.httpHeaders,
      // Si el audio viene de un puente, el reproductor debe mostrar el origen
      // real (p. ej. "Spotify → YouTube Music"), no solo el catálogo consultado.
      sourceLabel: stream.resolvedVia,
      streamAlternatives: stream.alternatives,
    );
  }

  /// Vuelve a resolver una pista que ya estaba en la cola y cuyos enlaces
  /// (incluidas las alternativas) han caducado.
  Future<Track?> refresh(Track playable) =>
      call(OnlineTrack.fromPlayable(playable));
}
