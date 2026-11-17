import 'online_music_repository.dart';
import 'online_track.dart';

/// Búsqueda de pistas online y listado de tendencias.
class SearchOnlineTracksUseCase {
  const SearchOnlineTracksUseCase(this._repository);

  final OnlineMusicRepository _repository;

  Future<List<OnlineTrack>> search(String query, {int limit = 25}) {
    final String term = query.trim();
    if (term.isEmpty) return Future<List<OnlineTrack>>.value(const []);
    return _repository.search(term, limit: limit);
  }

  Future<List<OnlineTrack>> trending({int limit = 25}) =>
      _repository.trending(limit: limit);
}
