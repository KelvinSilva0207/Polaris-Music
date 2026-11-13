import 'package:drift/drift.dart';

/// Canciones indexadas en la biblioteca local.
///
/// La ruta es única: es la clave natural para no duplicar una pista al
/// reescanear una carpeta. Las estadísticas (playCount, isFavorite...) se
/// preservan en los rescaneos porque el upsert actualiza solo los metadatos.
@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get path => text().unique()();

  TextColumn get title => text()();
  TextColumn get artist => text().withDefault(const Constant('Desconocido'))();
  TextColumn get album => text().withDefault(const Constant('Desconocido'))();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get genre => text().nullable()();

  IntColumn get year => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();

  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();

  TextColumn get artworkPath => text().nullable()();

  /// Ganancia ReplayGain en dB (etiqueta REPLAYGAIN_TRACK_GAIN / APE).
  RealColumn get replayGainTrackDb => real().nullable()();
  RealColumn get replayGainAlbumDb => real().nullable()();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get skipCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Carpetas elegidas por el usuario para indexar.
@DataClassName('ScanFolderRow')
class ScanFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  BoolColumn get recursive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastScanAt => dateTime().nullable()();
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PlaylistEntryRow')
class PlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// Historial crudo de reproducciones: base para estadísticas y "Wrapped".
@DataClassName('PlayHistoryRow')
class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get msPlayed => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// Presets de ecualización (10 bandas + preamp), persistidos como JSON.
@DataClassName('EqPresetRow')
class EqPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  TextColumn get bandsJson => text()();
  RealColumn get preampDb => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Preferencias clave/valor, aisladas por perfil (`global` si no aplica).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get scope => text().withDefault(const Constant('global'))();
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {scope, key};
}

@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Letras cacheadas (locales `.lrc` o descargadas).
@DataClassName('LyricRow')
class Lyrics extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().withDefault(const Constant('local'))();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {trackId};
}

/// Plugins instalados (arquitectura preparada; ejecución en fase posterior).
@DataClassName('PluginRow')
class Plugins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get version => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  TextColumn get configJson => text().nullable()();
  DateTimeColumn get installedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
