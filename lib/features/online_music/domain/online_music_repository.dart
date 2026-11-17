import 'online_track.dart';

/// Contrato del catálogo online.
///
/// La capa de dominio no conoce HTTP: solo pide búsquedas, tendencias, URLs de
/// streaming y carátulas cacheadas. La implementación vive en `data/`.
abstract interface class OnlineMusicRepository {
  /// Busca por título, artista o álbum.
  Future<List<OnlineTrack>> search(String query, {int limit = 25});

  /// Pistas populares del catálogo, para la pantalla sin búsqueda.
  Future<List<OnlineTrack>> trending({int limit = 25});

  /// Resuelve la URL directa de audio (siguiendo redirecciones).
  Future<ResolvedStream> resolveStream(OnlineTrack track);

  /// Descarga la carátula a la caché local y devuelve su ruta.
  Future<String?> cacheArtwork(String? artworkUrl);
}
