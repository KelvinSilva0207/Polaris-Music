import '../domain/music_source.dart';
import '../domain/music_source_catalog.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import 'metadata_audio_bridge.dart';
import 'source_helpers.dart';

/// Fachada que mantiene el contrato histórico del módulo online.
///
/// El reproductor y el gestor de descargas siguen hablando con un único
/// `OnlineMusicRepository`, pero las consultas se reparten entre proveedores y
/// el enrutado de streams/descargas se hace por el prefijo de `externalId`.
/// Las fuentes que solo entregan metadatos se resuelven mediante
/// [MetadataAudioBridge], que etiqueta el audio con su origen real.
class OnlineCatalogRepository implements OnlineMusicRepository {
  OnlineCatalogRepository({
    required this.catalog,
    required this.artworkCache,
    MetadataAudioBridge? bridge,
  }) : bridge = bridge ?? MetadataAudioBridge(catalog);

  final MusicSourceCatalog catalog;
  final ArtworkCache artworkCache;
  final MetadataAudioBridge bridge;

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
  Future<List<OnlineTrack>> searchCancellable(
    String query, {
    int limit = 25,
    required OnlineRequestToken token,
  }) async {
    final CatalogResult result = await catalog.search(
      query,
      limit: limit,
      token: token,
    );
    return result.tracks;
  }

  @override
  Future<List<OnlineTrack>> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) async {
    final CatalogResult result = await catalog.trending(
      limit: limit,
      token: token,
    );
    return result.tracks;
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) {
    final MusicSourceId source =
        MusicSourceIdX.fromExternalId(track.externalId) ?? MusicSourceId.audius;

    // Estas fuentes no entregan audio abierto: se usa el puente y se devuelve
    // una etiqueta del tipo "Spotify → YouTube Music".
    if (source == MusicSourceId.spotify || source == MusicSourceId.tidal) {
      return bridge.resolve(track);
    }

    final MusicSourceProvider? provider = catalog.providerFor(source);
    if (provider == null || !provider.canStream) {
      return bridge.resolve(track);
    }
    return provider.resolveStream(track);
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      artworkCache.cache(artworkUrl, MusicSourceId.audius);

  @override
  Future<String?> cacheArtworkFor(OnlineTrack track) {
    final MusicSourceId source =
        MusicSourceIdX.fromExternalId(track.externalId) ?? MusicSourceId.audius;
    return artworkCache.cache(track.artworkUrl, source);
  }

  @override
  bool canStreamTrack(OnlineTrack track) {
    final MusicSourceId source =
        MusicSourceIdX.fromExternalId(track.externalId) ?? MusicSourceId.audius;
    if (source == MusicSourceId.spotify || source == MusicSourceId.tidal) {
      return true;
    }
    return catalog.providerFor(source)?.canStream ?? false;
  }

  @override
  bool canDownloadTrack(OnlineTrack track) {
    final MusicSourceId source =
        MusicSourceIdX.fromExternalId(track.externalId) ?? MusicSourceId.audius;
    if (source == MusicSourceId.spotify || source == MusicSourceId.tidal) {
      return true;
    }
    return catalog.providerFor(source)?.canDownload ?? false;
  }

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) => catalog.collectionTracks(collection, limit: limit);

  @override
  Future<CollectionPage> collectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    required OnlineRequestToken token,
  }) => catalog.loadCollectionPage(
    collection,
    continuation: continuation,
    limit: limit,
    token: token,
  );
}
