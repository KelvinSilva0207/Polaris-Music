import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Rutas estándar de Polaris Music en Windows y Android.
///
/// Hay dos grupos claramente separados:
///
/// * **Datos internos** ([root], [artwork], [backups], [fonts], [cache]): en
///   Windows viven bajo `%LOCALAPPDATA%\Polaris Music` y en Android bajo el
///   directorio privado de la app. Nunca se comparten con otras apps.
/// * **Archivos visibles** ([documents], [music], [downloads], [updates]): en
///   Windows usan las carpetas conocidas Documentos/Música/Descargas; en
///   Android usan los directorios externos propios de la app
///   (`Android/data/<paquete>/files/...`), que no requieren permisos extra y
///   pueden compartirse con el instalador mediante `FileProvider`.
class AppPaths {
  AppPaths._();

  static const String folderName = 'Polaris Music';

  static Directory? _root;

  /// Raíz de datos internos (base de datos, carátulas, ajustes y caché).
  static Future<Directory> root() async {
    final Directory? cached = _root;
    if (cached != null) return cached;

    final Directory dir = await _create(await _computeRoot());
    if (Platform.isWindows) {
      await _migrateLegacySupport(dir);
    }
    _root = dir;
    return dir;
  }

  static Future<Directory> _computeRoot() async {
    if (Platform.isWindows) {
      final String? localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory(p.join(localAppData, folderName));
      }
    }
    final Directory? support = await _try(getApplicationSupportDirectory);
    if (support != null) {
      return Directory(
        p.join(support.path, Platform.isAndroid ? 'polaris_music' : folderName),
      );
    }
    return Directory(p.join(Directory.systemTemp.path, 'polaris', folderName));
  }

  /// Copia una vez la antigua raíz de carátulas/fuentes a la nueva ubicación.
  ///
  /// Las versiones previas usaban `getApplicationSupportDirectory()` (Roaming
  /// en Windows). La base de datos se migra por separado en `DatabaseGuard`.
  static Future<void> _migrateLegacySupport(Directory target) async {
    try {
      final Directory? legacyBase = await _try(getApplicationSupportDirectory);
      if (legacyBase == null) return;
      final Directory legacy = Directory(
        p.join(legacyBase.path, 'polaris_music'),
      );
      if (p.normalize(legacy.path) == p.normalize(target.path)) return;
      if (!legacy.existsSync()) return;
      await _copyDirectory(legacy, target);
    } catch (_) {
      // Una migración de caché fallida no debe impedir el arranque: el escáner
      // regenera carátulas y el usuario puede volver a importar fuentes.
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final FileSystemEntity entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final String relative = p.relative(entity.path, from: source.path);
      final String destination = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        final File file = File(destination);
        if (await file.exists()) continue;
        await file.parent.create(recursive: true);
        await entity.copy(file.path);
      }
    }
  }

  /// Archivo SQLite usado por Drift (en la raíz interna).
  static Future<File> databaseFile() async {
    return File(p.join((await root()).path, 'polaris_music.sqlite'));
  }

  /// Ubicación anterior de la base de datos en Windows (Documentos).
  ///
  /// Se usa solo para migrar instalaciones de versiones anteriores.
  static Future<File?> legacyDatabaseFile() async {
    if (!Platform.isWindows) return null;
    final Directory? documents = await _try(getApplicationDocumentsDirectory);
    if (documents == null) return null;
    return File(p.join(documents.path, 'polaris_music.sqlite'));
  }

  static Directory? _artworkDir;

  static Future<Directory> artwork() async {
    final Directory dir = await _sub('artwork');
    _artworkDir = dir;
    return dir;
  }

  /// Ruta del caché ya resuelta tras el bootstrap; permite recuperar carátulas
  /// sin volver a pedir `path_provider` desde el modelo de pista.
  static String? get artworkPathSync => _artworkDir?.path;

  static Future<Directory> backups() => _sub('backups');

  static Future<Directory> lyrics() => _sub('lyrics');

  static Future<Directory> fonts() => _sub('fonts');

  /// Caché temporal de la app (scripts del updater, archivos intermedios).
  static Future<Directory> cache() async {
    if (Platform.isWindows) {
      final String? localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return _create(Directory(p.join(localAppData, folderName, 'cache')));
      }
    }
    final Directory? cacheDir = await _try(getApplicationCacheDirectory);
    if (cacheDir != null) {
      return _create(Directory(p.join(cacheDir.path, folderName)));
    }
    return _sub('cache');
  }

  /// Documentos visibles: exportaciones M3U, respaldos, letras exportadas.
  static Future<Directory> documents() async {
    Directory base;
    if (Platform.isWindows) {
      base = await _windowsKnownFolder(
        'Documents',
        getApplicationDocumentsDirectory,
      );
    } else if (Platform.isAndroid) {
      base =
          await _androidExternal(StorageDirectory.documents) ??
          await _requireDocuments();
    } else {
      base = await _requireDocuments();
    }
    return _create(Directory(p.join(base.path, folderName)));
  }

  /// Música descargada visible para el usuario.
  static Future<Directory> music() async {
    Directory base;
    if (Platform.isWindows) {
      base = await _windowsKnownFolder(
        'Music',
        getApplicationDocumentsDirectory,
      );
    } else if (Platform.isAndroid) {
      final Directory? external = await _androidExternal(
        StorageDirectory.music,
      );
      if (external != null) {
        return _create(Directory(p.join(external.path, folderName)));
      }
      base = await downloads();
      return _create(Directory(p.join(base.path, 'Music')));
    } else {
      base = await downloads();
      return _create(Directory(p.join(base.path, 'Music')));
    }
    return _create(Directory(p.join(base.path, folderName)));
  }

  /// Raíz de descargas visibles de Polaris Music.
  static Future<Directory> downloads() async {
    Directory base;
    if (Platform.isWindows) {
      base = await _windowsKnownFolder('Downloads', _downloadsOrTemp);
    } else {
      base = await _downloadsOrTemp();
    }
    return _create(Directory(p.join(base.path, folderName)));
  }

  /// Instaladores/APK de actualizaciones: `Descargas/Polaris Music/Updates`.
  static Future<Directory> updates() async {
    return _create(Directory(p.join((await downloads()).path, 'Updates')));
  }

  /// Resuelve una carpeta elegida por el usuario, con fallback seguro.
  ///
  /// Si la preferencia no existe, está vacía o ya no es utilizable, se crea la
  /// carpeta estándar correspondiente y se sigue con esa.
  static Future<Directory> resolveOverride(
    String? value,
    Future<Directory> Function() fallback,
  ) async {
    final String? raw = value?.trim();
    if (raw == null || raw.isEmpty) return fallback();
    try {
      final Directory dir = Directory(raw);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return fallback();
    }
  }

  static Future<Directory> _downloadsOrTemp() async {
    final Directory? downloads = await _try(getDownloadsDirectory);
    if (downloads != null) return downloads;
    if (Platform.isWindows) {
      final String? home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        return _create(Directory(p.join(home, 'Downloads')));
      }
    }
    return Directory.systemTemp;
  }

  static Future<Directory> _requireDocuments() async {
    final Directory? documents = await _try(getApplicationDocumentsDirectory);
    return documents ?? Directory.systemTemp;
  }

  static Future<Directory> _windowsKnownFolder(
    String name,
    Future<Directory> Function() fallback,
  ) async {
    final String? home = Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return _create(Directory(p.join(home, name)));
    }
    return _create(await fallback());
  }

  static Future<Directory?> _androidExternal(StorageDirectory type) async {
    if (!Platform.isAndroid) return null;
    try {
      final List<Directory>? dirs = await getExternalStorageDirectories(
        type: type,
      );
      if (dirs == null || dirs.isEmpty) return null;
      return dirs.first;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _sub(String name) async {
    final Directory base = await root();
    return _create(Directory(p.join(base.path, name)));
  }

  static Future<Directory> _create(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<T?> _try<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }
}
