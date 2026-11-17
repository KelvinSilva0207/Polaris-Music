import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';
part 'daos/eq_dao.dart';
part 'daos/folder_dao.dart';
part 'daos/history_dao.dart';
part 'daos/lyrics_dao.dart';
part 'daos/playlist_dao.dart';
part 'daos/profile_dao.dart';
part 'daos/settings_dao.dart';
part 'daos/track_dao.dart';

/// Base de datos local de Polaris Music.
///
/// Se abre en un isolate de fondo con `drift_flutter` (a través de los hooks de
/// `sqlite3` 3.x, que empaqueta SQLite sin scripts nativos por plataforma).
@DriftDatabase(
  tables: [
    Tracks,
    ScanFolders,
    Playlists,
    PlaylistEntries,
    PlayHistory,
    EqPresets,
    Settings,
    Profiles,
    Lyrics,
    Plugins,
  ],
  daos: [
    TrackDao,
    FolderDao,
    PlaylistDao,
    HistoryDao,
    EqDao,
    SettingsDao,
    ProfileDao,
    LyricsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'polaris_music'));

  /// Constructor para tests (en memoria).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: origen de la pista y vínculo con la fuente online.
        await m.addColumn(tracks, tracks.source);
        await m.addColumn(tracks, tracks.externalId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) {
        await _seedDefaults();
      }
    },
  );

  /// Datos iniciales: perfil por defecto y presets de ecualización de estudio.
  Future<void> _seedDefaults() async {
    await into(profiles).insert(
      ProfilesCompanion.insert(name: 'Principal', isActive: const Value(true)),
      mode: InsertMode.insertOrIgnore,
    );

    const presets = <String, List<double>>{
      'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      'Rock': [5, 3, 1, -1, -2, -1, 2, 3, 4, 4],
      'Pop': [-1, 0, 2, 4, 4, 2, 0, -1, -1, 0],
      'Jazz': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
      'Clásica': [4, 3, 2, 1, 0, 0, -1, -2, -2, -2],
      'Vocal': [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
      'Bass Boost': [7, 6, 5, 3, 1, 0, 0, 0, 0, 0],
      'Electronic': [5, 4, 2, 0, -2, 1, 2, 3, 5, 5],
    };

    for (final entry in presets.entries) {
      await into(eqPresets).insert(
        EqPresetsCompanion.insert(
          name: entry.key,
          isBuiltIn: const Value(true),
          bandsJson: entry.value.join(','),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  /// Ruta de la carpeta de datos de la app (carátulas, backups, letras).
  static Future<Directory> appDataDirectory() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'polaris_music'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
