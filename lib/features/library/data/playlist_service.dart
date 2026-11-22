import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../../../core/utils/m3u_parser.dart';
import '../domain/smart_playlist.dart';
import 'library_repository.dart';

/// Listas locales, listas inteligentes e intercambio M3U.
///
/// La UI solo ve [Track] y [PlaylistRow]; Drift queda confinado aquí.
class PlaylistService {
  PlaylistService(this._db, this._repository);

  final AppDatabase _db;
  final LibraryRepository _repository;

  PlaylistDao get _dao => _db.playlistDao;

  Stream<List<PlaylistRow>> watchAll() => _dao.watchAll();

  Future<int> create(String name) => _dao.create(name.trim());

  Future<int> createSmart(String name, SmartPlaylistRule rule) =>
      _dao.createSmart(name.trim(), rule.name);

  Future<void> rename(int id, String name) => _dao.rename(id, name.trim());

  Future<void> delete(int id) => _dao.deletePlaylist(id);

  Future<void> addTrack(int playlistId, int trackId) =>
      _dao.addTrack(playlistId, trackId);

  /// Pistas de una lista. En las inteligentes se evalúa la regla contra la
  /// biblioteca actual para que reflejen cambios sin reescribir entradas.
  Future<List<Track>> tracksOf(PlaylistRow playlist) async {
    if (playlist.isSmart) {
      final SmartPlaylistRule? rule = SmartPlaylistRule.fromName(
        playlist.description ?? '',
      );
      if (rule == null) return const <Track>[];
      return rule.apply(await _repository.all());
    }
    final List<TrackRow> rows = await _dao.tracksOf(playlist.id);
    return rows.map(Track.fromRow).toList(growable: false);
  }

  /// Importa un M3U creando una lista con las pistas que ya estén indexadas.
  /// Devuelve cuántas se encontraron (0 si ninguna ruta coincide).
  Future<int> importM3u(String filePath) async {
    final M3uDocument document = await M3uDocument.read(filePath);
    if (document.entries.isEmpty) return 0;
    final Map<String, Track> byPath = <String, Track>{
      for (final Track track in await _repository.all())
        p.normalize(track.path): track,
    };
    final List<int> found = <int>[];
    final Set<int> seen = <int>{};
    for (final M3uEntry entry in document.entries) {
      final Track? track = byPath[p.normalize(entry.location)];
      if (track != null && seen.add(track.id)) found.add(track.id);
    }
    if (found.isEmpty) return 0;
    final String name = p.basenameWithoutExtension(filePath);
    final int playlistId = await create(name);
    for (final int trackId in found) {
      await _dao.addTrack(playlistId, trackId);
    }
    return found.length;
  }

  /// Exporta pistas a un M3U8 con rutas absolutas y títulos conocidos.
  Future<void> exportM3u(String filePath, List<Track> tracks) async {
    final List<M3uEntry> entries = <M3uEntry>[];
    for (final Track track in tracks) {
      if (track.path.isEmpty) continue;
      entries.add(
        M3uEntry(
          location: track.path,
          title: '${track.artist} - ${track.title}',
          durationSeconds: track.duration.inSeconds,
        ),
      );
    }
    await M3uDocument(entries).write(filePath);
  }
}
