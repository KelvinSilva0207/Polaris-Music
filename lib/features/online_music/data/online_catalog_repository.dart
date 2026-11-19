import '../domain/music_source.dart';
import '../domain/music_source_catalog.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Fachada que mantiene el contrato histórico del módulo online.
///
/// El reproductor y el gestor de descargas siguen hablando con un único
/// `OnlineMusicRepository`, pero las consultas se reparten entre proveedores y
/// el enrutado de streams/descargas se hace por el prefijo de `externalId`.
class OnlineCatalogRepository implements OnlineMusicRepository {
  const OnlineCatalogRepository({
    required this.catalog,
    required this.artworkCache,
  });

  final MusicSourceCatalog catalog;
  final ArtworkCache artworkCache;

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async {
    final CatalogResult result = await catalog.search(query, limit: limit);
    return result.tracks;
  }

  @override
  Future<List<OnlineTrack>> trending({int limit = 25}) async {
    final CatalogResult result = await catalog.trending(limit: limit);
    return result.tracks;
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) {
    final MusicSourceId source =
        MusicSourceIdX.fromExternalId(track.externalId) ?? MusicSourceId.audius;
    final MusicSourceProvider? provider = catalog.providerFor(source);
    if (provider == null || !provider.canStream) {
      return Future<ResolvedStream>.error(
        MusicSourceException(
          '${source.label} no permite reproducir audio en Polaris Music.',
          source: source,
          issue: MusicSourceIssue.unsupported,
        ),
      );
    }
    return provider.resolveStream(track);
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      artworkCache.cache(artworkUrl, MusicSourceId.audius);
}
