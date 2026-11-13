import 'dart:io';

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';
import 'library_scanner.dart';

/// Punto único de acceso a la biblioteca para la capa de presentación.
///
/// Traduce filas de Drift a [Track] y aplica orden/filtros en memoria. La UI
/// nunca importa `drift` ni conoce `TrackRow`.
class LibraryRepository {
  LibraryRepository(AppDatabase db)
    : _tracks = db.trackDao,
      _folders = db.folderDao,
      scanner = LibraryScanner(db);

  final TrackDao _tracks;
  final FolderDao _folders;

  final LibraryScanner scanner;

  Stream<List<Track>> watch({
    String query = '',
    LibrarySort sort = LibrarySort.artist,
    bool ascending = true,
  }) => _tracks
      .watchAll(query: query)
      .map(
        (List<TrackRow> rows) => sortTracks(
          rows.map(Track.fromRow).toList(growable: false),
          sort: sort,
          ascending: ascending,
        ),
      );

  Stream<List<Track>> watchFavorites({
    LibrarySort sort = LibrarySort.title,
    bool ascending = true,
  }) => _tracks.watchFavorites().map(
    (List<TrackRow> rows) => sortTracks(
      rows.map(Track.fromRow).toList(growable: false),
      sort: sort,
      ascending: ascending,
    ),
  );

  Future<List<Track>> all() async {
    final List<TrackRow> rows = await _tracks.getAll();
    return rows.map(Track.fromRow).toList(growable: false);
  }

  Future<Track?> byId(int id) async {
    final TrackRow? row = await _tracks.byId(id);
    return row == null ? null : Track.fromRow(row);
  }

  Future<List<DuplicateGroup>> duplicates() => _tracks.findDuplicates();

  Future<void> setFavorite(int id, bool value) =>
      _tracks.setFavorite(id, value);

  Future<void> deleteTracks(List<int> ids) => _tracks.deleteByIds(ids);

  Future<void> updateMetadata(
    Track track, {
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
  }) => _tracks.updateMetadata(
    track.id,
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    genre: genre,
    year: year,
    trackNumber: trackNumber,
    discNumber: discNumber,
  );

  Stream<List<LibraryFolder>> watchFolders() => _folders.watchAll().map(
    (List<ScanFolderRow> rows) => rows
        .map(
          (ScanFolderRow row) => LibraryFolder(
            id: row.id,
            path: row.path,
            recursive: row.recursive,
            lastScanAt: row.lastScanAt,
          ),
        )
        .toList(growable: false),
  );

  Future<int> addFolder(String path, {bool recursive = true}) =>
      _folders.add(path, recursive: recursive);

  Future<void> removeFolder(int id) => _folders.remove(id);

  /// Añade una carpeta validando que exista en disco.
  Future<int> addFolderFromPicker(String path, {bool recursive = true}) async {
    if (!await Directory(path).exists()) {
      throw FileSystemException('La carpeta no existe', path);
    }
    return addFolder(path, recursive: recursive);
  }

  Stream<ScanProgress> get scanProgress => scanner.progress;

  Future<ScanSummary> scan() => scanner.scanAll();

  Future<void> dispose() => scanner.dispose();
}
