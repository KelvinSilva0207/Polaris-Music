import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../constants/app_paths.dart';
import '../database/app_database.dart';
import '../services/settings_service.dart';
import '../theme/app_theme_config.dart';
import '../theme/compact_style_config.dart';
import '../theme/typography_config.dart';
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
    this.themes = 0,
    this.warnings = const <String>[],
    this.path,
  });

  final int settings;
  final int eqPresets;
  final int playlists;
  final int favorites;
  final int lyrics;
  final int plugins;
  final int profiles;
  final int themes;
  final List<String> warnings;
  final String? path;

  int get total =>
      settings +
      eqPresets +
      playlists +
      favorites +
      lyrics +
      plugins +
      profiles +
      themes;
}

/// Exportación e importación de perfiles, preferencias y colecciones.
///
/// Formato JSON versionado (también se puede envolver en un ZIP). Las pistas se
/// referencian por **ruta absoluta** porque los ids cambian entre instalaciones;
/// al importar se resuelven contra la biblioteca actual y lo que no exista se
/// omite sin abortar el resto del respaldo.
///
/// v2 añade la sección `themes` (tema RGB/ARGB, perfiles de tema, tipografía y
/// estilos compactos), conserva el `configJson` completo de cada preset de EQ
/// (paramétrico + sub-armónico) y respeta el perfil activo. Los respaldos v1 se
/// siguen importando: si falta `themes` se leen las claves legacy de `settings`.
class BackupService {
  BackupService(this._db, {this._settingsService})
    : _settings = _db.settingsDao,
      _eq = _db.eqDao,
      _playlists = _db.playlistDao,
      _profiles = _db.profileDao,
      _tracks = _db.trackDao,
      _lyrics = _db.lyricsDao;

  static const String _tag = 'Backup';
  static const int _formatVersion = 2;

  /// Preferencias que contienen credenciales y no deben viajar en un backup.
  static const String _credentialPrefix = 'online.';

  /// Claves de temas que se importan validadas desde la sección `themes`.
  static const Set<String> _themeKeys = <String>{
    AppConstants.keyThemeConfig,
    AppConstants.keyThemeProfiles,
    AppConstants.keyTypography,
    AppConstants.keyCompactIslandStyle,
    AppConstants.keyCompactMiniStyle,
    AppConstants.keyCompactPhoneStyle,
    AppConstants.keyCompactPlayerStyle,
  };

  static const Map<String, String> _compactKeys = <String, String>{
    'island': AppConstants.keyCompactIslandStyle,
    'mini': AppConstants.keyCompactMiniStyle,
    'phone': AppConstants.keyCompactPhoneStyle,
    'player': AppConstants.keyCompactPlayerStyle,
  };

  static CompactSurface _compactSurface(String name) =>
      CompactSurface.values.firstWhere(
        (CompactSurface surface) => surface.name == name,
        orElse: () => CompactSurface.player,
      );

  final AppDatabase _db;
  final SettingsDao _settings;
  final EqDao _eq;
  final PlaylistDao _playlists;
  final ProfileDao _profiles;
  final TrackDao _tracks;
  final LyricsDao _lyrics;
  final SettingsService? _settingsService;

  /// Serializa el estado actual a un mapa listo para `jsonEncode`.
  Future<Map<String, dynamic>> buildBackup() async {
    final Map<String, String> settings = Map<String, String>.from(
      await _settings.all(),
    )..removeWhere((String key, _) => key.startsWith(_credentialPrefix));
    final Map<String, Map<String, String>> allSettings = await _settings
        .allScoped();
    for (final Map<String, String> scoped in allSettings.values) {
      scoped.removeWhere((String key, _) => key.startsWith(_credentialPrefix));
    }
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
      'allSettings': allSettings,
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
              'configJson': p.configJson,
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
      'themes': _buildThemes(settings),
    };
  }

  /// Valida y normaliza los JSON de tema guardados en `settings`.
  ///
  /// Los colores se guardan como ARGB de 32 bits (`toARGB32`), que es lo que
  /// usan los modelos; el editor RGB/HSV/HEX solo mantiene HSV en memoria.
  Map<String, dynamic> _buildThemes(Map<String, String> settings) {
    final Map<String, dynamic> themes = <String, dynamic>{};

    final String? configRaw = settings[AppConstants.keyThemeConfig];
    if (configRaw != null) {
      try {
        themes['config'] = AppThemeConfig.fromJson(
          jsonDecode(configRaw) as Map<String, dynamic>,
        ).toJson();
      } catch (error, stack) {
        AppLog.w(_tag, 'Tema corrupto; se omite del respaldo', error, stack);
      }
    }

    final String? profilesRaw = settings[AppConstants.keyThemeProfiles];
    if (profilesRaw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(profilesRaw) as List<dynamic>;
        themes['profiles'] = decoded
            .whereType<Map<String, dynamic>>()
            .map(
              (Map<String, dynamic> raw) =>
                  CustomThemeProfile.fromJson(raw).toJson(),
            )
            .toList(growable: false);
      } catch (error, stack) {
        AppLog.w(
          _tag,
          'Perfiles de tema corruptos; se omiten del respaldo',
          error,
          stack,
        );
      }
    }

    final String? typographyRaw = settings[AppConstants.keyTypography];
    if (typographyRaw != null) {
      try {
        themes['typography'] = TypographyConfig.fromJson(
          jsonDecode(typographyRaw) as Map<String, dynamic>,
        ).toJson();
      } catch (error, stack) {
        AppLog.w(
          _tag,
          'Tipografía corrupta; se omite del respaldo',
          error,
          stack,
        );
      }
    }

    final Map<String, dynamic> compact = <String, dynamic>{};
    for (final MapEntry<String, String> entry in _compactKeys.entries) {
      final String? raw = settings[entry.value];
      if (raw == null) continue;
      try {
        compact[entry.key] = CompactStyleConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
          surface: _compactSurface(entry.key),
        ).toJson();
      } catch (error, stack) {
        AppLog.w(
          _tag,
          'Estilo compacto ${entry.key} corrupto; se omite',
          error,
          stack,
        );
      }
    }
    if (compact.isNotEmpty) themes['compact'] = compact;

    return themes;
  }

  /// Genera los bytes del respaldo sin escribir a disco.
  ///
  /// Útil para guardar en la ubicación elegida con `FilePicker.saveFile`.
  Future<Uint8List> buildBytes({bool compress = true}) async {
    final Map<String, dynamic> data = await buildBackup();
    final Uint8List jsonBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (!compress) return jsonBytes;
    final Archive archive = Archive()
      ..addFile(ArchiveFile.bytes('polaris_backup.json', jsonBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Exporta a un archivo en [directory] o, por defecto, en `AppPaths.backups()`.
  ///
  /// Si [compress] es `true` genera un ZIP con el JSON dentro; si no, un `.json`
  /// legible. Devuelve la ruta creada.
  Future<String> exportToFile({
    bool compress = true,
    Directory? directory,
  }) async {
    final Map<String, dynamic> data = await buildBackup();
    final Directory dir = directory ?? await AppPaths.backups();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
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
  /// `merge == false` las preferencias globales se reemplazan, pero nunca se
  /// eliminan pistas de la biblioteca. La importación es transaccional: un
  /// fallo inesperado no deja la base a medias. Los bloques opcionales (temas)
  /// registran avisos en lugar de abortar.
  Future<BackupSummary> importFromFile(File file, {bool merge = true}) async {
    final Map<String, dynamic> json = await _read(file);
    final int version = (json['formatVersion'] as num?)?.toInt() ?? 0;
    if (version > _formatVersion) {
      throw FormatException(
        'El respaldo fue creado por una versión más nueva de Polaris Music.',
      );
    }

    final List<String> warnings = <String>[];
    int settingsCount = 0;
    int profileCount = 0;
    int eqCount = 0;
    int playlistCount = 0;
    int favoriteCount = 0;
    int lyricsCount = 0;
    int pluginCount = 0;
    int themeCount = 0;

    await _db.transaction(() async {
      // Resolver rutas → ids una sola vez.
      final List<TrackRow> allTracks = await _tracks.getAll();
      final Map<String, int> idByPath = <String, int>{
        for (final TrackRow row in allTracks) row.path: row.id,
      };

      final Map<String, dynamic> settings =
          (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (!merge) {
        // Solo el scope global: borrar todo destruiría perfiles con scope propio.
        await _settings.clear(scope: 'global');
      }
      for (final MapEntry<String, dynamic> entry in settings.entries) {
        if (entry.key.startsWith(_credentialPrefix)) continue;
        if (_themeKeys.contains(entry.key)) continue;
        await _settings.setValue(entry.key, '${entry.value}');
        settingsCount++;
      }

      // Scopes adicionales: perfiles de usuario y perfiles por dispositivo.
      final Map<String, dynamic> allSettings =
          (json['allSettings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      for (final MapEntry<String, dynamic> scopeEntry in allSettings.entries) {
        if (scopeEntry.key == 'global') continue;
        if (scopeEntry.value is! Map<String, dynamic>) continue;
        final Map<String, dynamic> scopeValues =
            scopeEntry.value as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> entry in scopeValues.entries) {
          if (entry.key.startsWith(_credentialPrefix)) continue;
          await _settings.setValue(
            entry.key,
            '${entry.value}',
            scope: scopeEntry.key,
          );
          settingsCount++;
        }
      }

      // Perfiles: se conserva cuál estaba activo.
      final List<dynamic> profiles =
          (json['profiles'] as List<dynamic>?) ?? const <dynamic>[];
      int? activeProfileId;
      for (final dynamic raw in profiles.whereType<Map<String, dynamic>>()) {
        final String name = (raw['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final int id = await _profiles.create(name);
        if (raw['isActive'] == true) activeProfileId = id;
        profileCount++;
      }
      if (activeProfileId != null) {
        await _profiles.activate(activeProfileId);
      }

      // Presets de EQ: se conserva el DSP completo (paramétrico + sub-armónico).
      final List<dynamic> presets =
          (json['eqPresets'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic raw in presets.whereType<Map<String, dynamic>>()) {
        final String name = (raw['name'] as String? ?? '').trim();
        final List<double> bands =
            ((raw['bands'] as List<dynamic>?) ?? const <dynamic>[])
                .map((dynamic v) => (v as num).toDouble())
                .toList(growable: false);
        if (name.isEmpty || bands.length != AppConstants.eqBands.length) {
          continue;
        }
        await _eq.save(
          name: name,
          bands: bands,
          preampDb: (raw['preampDb'] as num?)?.toDouble() ?? 0,
          configJson: raw['configJson'] as String?,
        );
        eqCount++;
      }

      // Playlists.
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

      // Favoritos.
      final List<dynamic> favorites =
          (json['favorites'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic path in favorites.whereType<String>()) {
        if (idByPath.containsKey(path)) {
          await _tracks.setFavoriteByPath(path, true);
          favoriteCount++;
        }
      }

      // Letras.
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

      // Plugins.
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

      // Temas (v2) con fallback a las claves legacy de v1.
      themeCount = await _importThemes(json, settings, warnings);
    });

    // La caché de SettingsService debe verse actualizada sin reiniciar.
    await _settingsService?.load();

    final BackupSummary summary = BackupSummary(
      settings: settingsCount,
      eqPresets: eqCount,
      playlists: playlistCount,
      favorites: favoriteCount,
      lyrics: lyricsCount,
      plugins: pluginCount,
      profiles: profileCount,
      themes: themeCount,
      warnings: List<String>.unmodifiable(warnings),
      path: file.path,
    );
    AppLog.i(_tag, 'Respaldo importado: ${summary.total} elementos');
    return summary;
  }

  /// Importa temas validando cada JSON. Los modelos ya hacen clamp/fallback,
  /// de modo que un valor corrupto se normaliza en lugar de romper la app.
  Future<int> _importThemes(
    Map<String, dynamic> json,
    Map<String, dynamic> settings,
    List<String> warnings,
  ) async {
    final Map<String, dynamic> themes =
        (json['themes'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> compact =
        (themes['compact'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    int count = 0;

    Future<void> apply(
      String key,
      dynamic raw,
      Future<String> Function(dynamic raw) build,
    ) async {
      // Un respaldo v1 puede no tener nada de temas: eso no es un error.
      if (raw == null) return;
      try {
        final String value = await build(raw);
        await _settings.setValue(key, value);
        count++;
      } catch (error, stack) {
        warnings.add('No se pudo restaurar $key');
        AppLog.w(_tag, 'No se pudo restaurar $key', error, stack);
      }
    }

    Map<String, dynamic> objectOf(dynamic raw) => raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : raw as Map<String, dynamic>;

    List<dynamic> listOf(dynamic raw) =>
        raw is String ? jsonDecode(raw) as List<dynamic> : raw as List<dynamic>;

    await apply(
      AppConstants.keyThemeConfig,
      themes['config'] ?? settings[AppConstants.keyThemeConfig],
      (dynamic raw) async =>
          jsonEncode(AppThemeConfig.fromJson(objectOf(raw)).toJson()),
    );

    await apply(
      AppConstants.keyThemeProfiles,
      themes['profiles'] ?? settings[AppConstants.keyThemeProfiles],
      (dynamic raw) async {
        final List<Map<String, dynamic>> restored = listOf(raw)
            .whereType<Map<String, dynamic>>()
            .map(
              (Map<String, dynamic> item) =>
                  CustomThemeProfile.fromJson(item).toJson(),
            )
            .toList(growable: false);
        return jsonEncode(restored);
      },
    );

    await apply(
      AppConstants.keyTypography,
      themes['typography'] ?? settings[AppConstants.keyTypography],
      (dynamic raw) async =>
          jsonEncode(TypographyConfig.fromJson(objectOf(raw)).toJson()),
    );

    for (final MapEntry<String, String> entry in _compactKeys.entries) {
      await apply(
        entry.value,
        compact[entry.key] ?? settings[entry.value],
        (dynamic raw) async => jsonEncode(
          CompactStyleConfig.fromJson(
            objectOf(raw),
            surface: _compactSurface(entry.key),
          ).toJson(),
        ),
      );
    }

    return count;
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
