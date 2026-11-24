import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../constants/app_paths.dart';
import '../utils/logger.dart';
import 'database_guard.dart';
import 'tables.dart';

part 'app_database.g.dart';
part 'daos/eq_dao.dart';
part 'daos/folder_dao.dart';
part 'daos/history_dao.dart';
part 'daos/lyrics_dao.dart';
part 'daos/online_sync_dao.dart';
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
    OnlineReferences,
    OnlineReferenceTracks,
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
    OnlineSyncDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : _manageBackups = true,
      super(
        executor ??
            driftDatabase(
              name: DatabaseGuard.databaseName,
              native: DriftNativeOptions(
                databasePath: () async =>
                    (await DatabaseGuard.databaseFile()).path,
              ),
            ),
      );

  /// Constructor para tests (en memoria): no toca copias de seguridad.
  AppDatabase.forTesting(super.executor) : _manageBackups = false;

  final bool _manageBackups;

  /// v5 añade tablas propias para referencias online (sin filas falsas en
  /// `Tracks`). La migración es aditiva y no toca biblioteca ni historial.
  @override
  int get schemaVersion => 5;

  static final List<Index> _libraryIndexes = <Index>[
    Index(
      'idx_tracks_genre',
      'CREATE INDEX IF NOT EXISTS idx_tracks_genre ON tracks (genre)',
    ),
    Index(
      'idx_tracks_year',
      'CREATE INDEX IF NOT EXISTS idx_tracks_year ON tracks (year)',
    ),
    Index(
      'idx_tracks_play_count',
      'CREATE INDEX IF NOT EXISTS idx_tracks_play_count ON tracks (play_count)',
    ),
    Index(
      'idx_tracks_added_at',
      'CREATE INDEX IF NOT EXISTS idx_tracks_added_at ON tracks (added_at)',
    ),
    Index(
      'idx_tracks_external_id',
      'CREATE INDEX IF NOT EXISTS idx_tracks_external_id ON tracks (external_id)',
    ),
    Index(
      'idx_playlist_entries_position',
      'CREATE INDEX IF NOT EXISTS idx_playlist_entries_position '
          'ON playlist_entries (playlist_id, position)',
    ),
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes(m);
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      // La copia va ANTES de cualquier ALTER TABLE: es el punto en el que un
      // fallo de migración todavía puede recuperarse con el archivo original.
      if (_manageBackups) {
        try {
          await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (error, stack) {
          AppLog.w(
            'Database',
            'No se pudo hacer checkpoint antes de la copia de migración',
            error,
            stack,
          );
        }
        await DatabaseGuard.backupBeforeMigration();
      }

      if (from < 2) {
        // v2: origen de la pista y vínculo con la fuente online.
        await m.addColumn(tracks, tracks.source);
        await m.addColumn(tracks, tracks.externalId);
      }
      if (from < 3) {
        // v3: índices de biblioteca (CREATE INDEX IF NOT EXISTS, no destructivo).
        await _createIndexes(m);
      }
      if (from < 4) {
        // v4: preset de ecualizador con modo, bandas y filtros paramétricos.
        // Los presets antiguos siguen leyéndose desde bandsJson/preampDb.
        await m.addColumn(eqPresets, eqPresets.configJson);
      }
      if (from < 5) {
        // v5: tablas de referencias online. `m.create` usa CREATE TABLE IF NOT
        // EXISTS: no se borra ni se reescribe Tracks, PlaylistEntries ni
        // PlayHistory. Los favoritos/contadores locales nunca se tocan.
        await m.create(onlineReferences);
        await m.create(onlineReferenceTracks);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _assertHealthy();
      if (details.wasCreated) {
        await _seedDefaults();
      }
    },
  );

  /// Drift ejecuta `beforeOpen` después de las migraciones, así que aquí solo
  /// podemos detectar daños residuales; el bootstrap ya hizo un `quick_check`
  /// antes de abrir (ver [DatabaseGuard.prepare]).
  Future<void> _assertHealthy() async {
    try {
      final List<QueryRow> rows = await customSelect('PRAGMA quick_check(1)')
          .get();
      final Object? status = rows.isEmpty ? null : rows.first.data.values.first;
      if (status == null || '$status' != 'ok') {
        throw DatabaseCorruptionException('$status');
      }
    } on DatabaseCorruptionException {
      rethrow;
    } catch (error, stack) {
      AppLog.w(
        'Database',
        'No se pudo verificar la integridad; se continúa con cautela',
        error,
        stack,
      );
    }
  }

  Future<void> _createIndexes(Migrator m) async {
    for (final Index index in _libraryIndexes) {
      await m.create(index);
    }
  }

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
  static Future<Directory> appDataDirectory() => AppPaths.root();
}
