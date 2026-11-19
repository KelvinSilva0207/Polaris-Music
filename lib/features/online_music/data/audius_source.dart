import '../domain/music_source.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Adaptador del catálogo abierto de Audius al contrato de proveedores.
///
/// Audius no requiere credenciales y entrega audio reproducible, por lo que es
/// la fuente por defecto de la aplicación.
class AudiusSource implements MusicSourceProvider {
  AudiusSource(this._repository);

  final OnlineMusicRepository _repository;

  MusicSourceStatus _status = const MusicSourceStatus();

  @override
  MusicSourceId get id => MusicSourceId.audius;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  @override
  bool get canStream => true;

  @override
  bool get canDownload => true;

  @override
  MusicSourceStatus get status => _status;

  @override
  Future<MusicSourceStatus> checkAvailability() async {
    try {
      await _repository.trending(limit: 1);
      _status = const MusicSourceStatus(
        available: true,
        checkedAt: null,
      ).copyWith(checkedAt: DateTime.now());
    } catch (error) {
      _status = MusicSourceErrorMapper.map(error, id);
    }
    return _status;
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) async {
    try {
      return SourceResult(
        source: id,
        items: await _repository.search(query, limit: limit),
      );
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) async {
    try {
      return SourceResult(
        source: id,
        items: await _repository.trending(limit: limit),
      );
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) =>
      _repository.resolveStream(track);

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _repository.cacheArtwork(artworkUrl);
}
