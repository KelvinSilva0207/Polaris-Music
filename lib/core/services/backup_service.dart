import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../constants/app_paths.dart';
import '../database/app_database.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

/// Resumen de un respaldo exportado o importado.
class BackupSummary {
  const BackupSummary({
    this.settings = 0,
    this.eqPresets = 0,
    this.playlists = 0,
    this.favorites = 0,
    this.lyrics = 0,
    this.plugins = 0,
    this.profiles = 0,
    this.path,
  });

  final int settings;
  final int eqPresets;
  final int playlists;
  final int favorites;
  final int lyrics;
  final int plugins;
  final int profiles;
  final String? path;

  int get total =>
      settings +
      eqPresets +
      playlists +
      favorites +
      lyrics +
      plugins +
      profiles;
}

/// Exportación e importación de perfiles, preferencias y colecciones.
///
/// Formato JSON versionado (también se puede envolver en un ZIP). Las pistas se
/// referencian por **ruta absoluta** porque los ids cambian entre instalaciones;
/// al importar se resuelven contra la biblioteca actual y lo que no exista se
/// omite sin abortar el resto del respaldo.
class BackupService {
  BackupService(this._db)
    : _settings = _db.settingsDao,
      _eq = _db.eqDao,
      _playlists = _db.playlistDao,
      _profiles = _db.profileDao,
      _tracks = _db.trackDao,
      _lyrics = _db.lyricsDao;

  static const String _tag = 'Backup';
  static const int _formatVersion = 1;

  /// Preferencias que contienen credenciales y no deben viajar en un backup.
  static const String _credentialPrefix = 'online.';

  final AppDatabase _db;
  final SettingsDao _settings;
  final EqDao _eq;
  final PlaylistDao _playlists;
  final ProfileDao _profiles;
  final TrackDao _tracks;
  final LyricsDao _lyrics;

  /// Serializa el estado actual a un mapa listo para `jsonEncode`.
  Future<Map<String, dynamic>> buildBackup() async {
    final Map<String, String> settings = Map<String, String>.from(
      await _settings.all(),
    )..removeWhere((String key, _) => key.startsWith(_credentialPrefix));
    final List<EqPresetRow> presets = await _eq.getAll();
    final List<ProfileRow> profiles = await _profiles.getAll();
    final List<PlaylistRow> playlistRows = await _playlists.getAll();
    final List<String> favorites = await _tracks.favoritePaths();
    final List<LyricBackupEntry> lyrics = await _lyrics.allWithPaths();
    final List<PluginRow> plugins = await _db.select(_db.plugins).get();

    final List<Map<String, dynamic>> playlistJson = <Map<String, dynamic>>[];
    for (final PlaylistRow playlist in playlistRows) {
      playlistJson.add(<String, dynamic>{
        'name': playlist.name,
        'description': playlist.description,
        'tracks': await _playlists.trackPaths(playlist.id),
      });
    }

    return <String, dynamic>{
      'app': AppConstants.appName,
      'formatVersion': _formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'profiles': profiles
          .map(
            (ProfileRow p) => <String, dynamic>{
              'name': p.name,
              'isActive': p.isActive,
            },
          )
          .toList(growable: false),
      'eqPresets': presets
          .map(
            (EqPresetRow p) => <String, dynamic>{
              'name': p.name,
              'bands': p.bandsJson
                  .split(',')
                  .map((String s) => double.tryParse(s.trim()) ?? 0)
                  .toList(growable: false),
              'preampDb': p.preampDb,
            },
          )
          .toList(growable: false),
      'playlists': playlistJson,
      'favorites': favorites,
      'lyrics': lyrics
          .map(
            (LyricBackupEntry l) => <String, dynamic>{
              'path': l.path,
              'content': l.content,
              'synced': l.synced,
              'source': l.source,
            },
          )
          .toList(growable: false),
      'plugins': plugins
          .map(
            (PluginRow p) => <String, dynamic>{
              'name': p.name,
              'version': p.version,
              'enabled': p.enabled,
              'configJson': p.configJson,
            },
          )
          .toList(growable: false),
    };
  }

  /// Exporta a un archivo dentro de `AppPaths.backups()`.
  ///
  /// Si [compress] es `true` genera un ZIP con el JSON dentro; si no, un `.json`
  /// legible. Devuelve la ruta creada.
  Future<String> exportToFile({bool compress = true}) async {
    final Map<String, dynamic> data = await buildBackup();
    final Directory dir = await AppPaths.backups();
    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final String baseName = 'polaris_backup_$stamp';

    if (!compress) {
      final File file = File(p.join(dir.path, '$baseName.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      AppLog.i(_tag, 'Respaldo JSON: ${file.path}');
      return file.path;
    }

    final Uint8List jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(data)),
    );
    final Archive archive = Archive()
      ..addFile(ArchiveFile.bytes('polaris_backup.json', jsonBytes));
    final List<int> zipBytes = ZipEncoder().encode(archive);
    final File file = File(p.join(dir.path, '$baseName.zip'));
    await file.writeAsBytes(zipBytes, flush: true);
    AppLog.i(_tag, 'Respaldo ZIP: ${file.path}');
    return file.path;
  }

  /// Importa un respaldo `.json` o `.zip`.
  ///
  /// [merge] conserva lo existente (inserta/actualiza sin borrar). Con
  /// `merge == false` las preferencias se reemplazan, pero nunca se eliminan
  /// pistas de la biblioteca.
  Future<BackupSummary> importFromFile(File file, {bool merge = true}) async {
    final Map<String, dynamic> json = await _read(file);
    final int version = (json['formatVersion'] as num?)?.toInt() ?? 0;
    if (version > _formatVersion) {
      throw FormatException(
        'El respaldo fue creado por una versión más nueva de Polaris Music.',
      );
    }

    // Resolver rutas → ids una sola vez.
    final List<TrackRow> allTracks = await _tracks.getAll();
    final Map<String, int> idByPath = <String, int>{
      for (final TrackRow row in allTracks) row.path: row.id,
    };

    int settingsCount = 0;
    final Map<String, dynamic> settings =
        (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (!merge) {
      await _settings.clear();
    }
    for (final MapEntry<String, dynamic> entry in settings.entries) {
      if (entry.key.startsWith(_credentialPrefix)) continue;
      await _settings.setValue(entry.key, '${entry.value}');
      settingsCount++;
    }

    int profileCount = 0;
    final List<dynamic> profiles =
        (json['profiles'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic raw in profiles.whereType<Map<String, dynamic>>()) {
      final String name = (raw['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      await _profiles.create(name);
      profileCount++;
    }

    int eqCount = 0;
    final List<dynamic> presets =
        (json['eqPresets'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic raw in presets.whereType<Map<String, dynamic>>()) {
      final String name = (raw['name'] as String? ?? '').trim();
      final List<double> bands =
          ((raw['bands'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic v) => (v as num).toDouble())
              .toList(growable: false);
      if (name.isEmpty || bands.length != AppConstants.eqBands.length) continue;
      await _eq.save(
        name: name,
        bands: bands,
        preampDb: (raw['preampDb'] as num?)?.toDouble() ?? 0,
      );
      eqCount++;
    }

    int playlistCount = 0;
    final List<dynamic> playlists =
        (json['playlists'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic raw in playlists.whereType<Map<String, dynamic>>()) {
      final String name = (raw['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final int id = await _playlists.create(
        name,
        description: raw['description'] as String?,
      );
      final List<dynamic> paths =
          (raw['tracks'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic path in paths.whereType<String>()) {
        final int? trackId = idByPath[path];
        if (trackId != null) {
          await _playlists.addTrack(id, trackId);
        }
      }
      playlistCount++;
    }

    int favoriteCount = 0;
    final List<dynamic> favorites =
        (json['favorites'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic path in favorites.whereType<String>()) {
      if (idByPath.containsKey(path)) {
        await _tracks.setFavoriteByPath(path, true);
        favoriteCount++;
      }
    }

    int lyricsCount = 0;
    final List<dynamic> lyrics =
        (json['lyrics'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic raw in lyrics.whereType<Map<String, dynamic>>()) {
      final String path = raw['path'] as String? ?? '';
      final int? trackId = idByPath[path];
      if (trackId == null) continue;
      await _lyrics.save(
        trackId,
        raw['content'] as String? ?? '',
        synced: raw['synced'] as bool? ?? false,
        source: raw['source'] as String? ?? 'backup',
      );
      lyricsCount++;
    }

    int pluginCount = 0;
    final List<dynamic> plugins =
        (json['plugins'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic raw in plugins.whereType<Map<String, dynamic>>()) {
      final String name = (raw['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      await _db
          .into(_db.plugins)
          .insert(
            PluginsCompanion.insert(
              name: name,
              version: raw['version'] as String? ?? '0.0.0',
              enabled: Value(raw['enabled'] as bool? ?? false),
              configJson: Value(raw['configJson'] as String?),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      pluginCount++;
    }

    final BackupSummary summary = BackupSummary(
      settings: settingsCount,
      eqPresets: eqCount,
      playlists: playlistCount,
      favorites: favoriteCount,
      lyrics: lyricsCount,
      plugins: pluginCount,
      profiles: profileCount,
      path: file.path,
    );
    AppLog.i(_tag, 'Respaldo importado: ${summary.total} elementos');
    return summary;
  }

  Future<Map<String, dynamic>> _read(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final bool isZip =
        p.extension(file.path).toLowerCase() == '.zip' ||
        (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B);

    if (!isZip) {
      final dynamic decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El archivo no es un respaldo válido.');
      }
      return decoded;
    }

    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final ArchiveFile? entry = archive.files.cast<ArchiveFile?>().firstWhere(
      (ArchiveFile? f) => f?.name == 'polaris_backup.json',
      orElse: () => null,
    );
    if (entry == null) {
      throw const FormatException('El ZIP no contiene polaris_backup.json.');
    }
    final Uint8List? content = entry.readBytes();
    if (content == null) {
      throw const FormatException('No se pudo leer el respaldo del ZIP.');
    }
    final dynamic decoded = jsonDecode(utf8.decode(content));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El respaldo del ZIP no es válido.');
    }
    return decoded;
  }

  /// Nombre sugerido para el diálogo de guardado.
  static String suggestedFileName({bool zip = true}) =>
      'polaris_backup_${FileUtils.fnv1a(DateTime.now().toIso8601String())}'
      '${zip ? '.zip' : '.json'}';
}
