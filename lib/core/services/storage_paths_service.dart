import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../constants/app_paths.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

/// Carpetas que el usuario puede inspeccionar desde Ajustes.
enum StorageFolderKind { data, documents, music, downloads }

/// Una fila de la sección «Carpetas» de Ajustes.
class StoragePathInfo {
  const StoragePathInfo({
    required this.kind,
    required this.title,
    required this.description,
    required this.path,
  });

  final StorageFolderKind kind;
  final String title;
  final String description;
  final String path;

  bool get canChange => kind != StorageFolderKind.data;
}

/// Resuelve las rutas activas y aplica las carpetas elegidas por el usuario.
///
/// La ruta interna nunca se puede cambiar: es la que usa Drift para la base de
/// datos, los ajustes y la caché. El resto tiene un valor estándar por
/// plataforma y una preferencia opcional que lo sustituye.
class StoragePathsService {
  StoragePathsService(this._settings);

  static const String _tag = 'StoragePaths';

  final SettingsService _settings;

  Future<Directory> data() => AppPaths.root();

  Future<Directory> documents() => AppPaths.resolveOverride(
    _settings.getString(AppConstants.keyDocumentsFolder),
    AppPaths.documents,
  );

  Future<Directory> music() => AppPaths.resolveOverride(
    _settings.getString(AppConstants.keyMusicFolder),
    AppPaths.music,
  );

  /// Carpeta donde se guardan los instaladores/APK de actualizaciones.
  Future<Directory> updates() => AppPaths.resolveOverride(
    _settings.getString(AppConstants.keyDownloadsFolder),
    AppPaths.updates,
  );

  Future<Directory> resolve(StorageFolderKind kind) {
    switch (kind) {
      case StorageFolderKind.data:
        return data();
      case StorageFolderKind.documents:
        return documents();
      case StorageFolderKind.music:
        return music();
      case StorageFolderKind.downloads:
        return updates();
    }
  }

  Future<List<StoragePathInfo>> describe() async {
    final Directory dataDir = await data();
    final Directory documentsDir = await documents();
    final Directory musicDir = await music();
    final Directory updatesDir = await updates();

    return <StoragePathInfo>[
      StoragePathInfo(
        kind: StorageFolderKind.data,
        title: 'Datos internos',
        description: Platform.isWindows
            ? 'Base de datos, ajustes y caché (%LOCALAPPDATA%)'
            : 'Base de datos, ajustes y caché (almacenamiento privado)',
        path: dataDir.path,
      ),
      StoragePathInfo(
        kind: StorageFolderKind.documents,
        title: 'Documentos y exportaciones',
        description: 'Respaldos, listas M3U y letras exportadas',
        path: documentsDir.path,
      ),
      StoragePathInfo(
        kind: StorageFolderKind.music,
        title: 'Música descargada',
        description: 'Canciones descargadas desde fuentes online',
        path: musicDir.path,
      ),
      StoragePathInfo(
        kind: StorageFolderKind.downloads,
        title: 'Actualizaciones',
        description: 'Instaladores y APK descargados',
        path: updatesDir.path,
      ),
    ];
  }

  /// Cambia la carpeta elegida. Devuelve `false` si el usuario cancela.
  Future<bool> change(StorageFolderKind kind) async {
    if (kind == StorageFolderKind.data) {
      throw ArgumentError.value(
        kind,
        'kind',
        'La carpeta interna no se cambia',
      );
    }
    final Directory current = await resolve(kind);
    final String? picked = await FilePicker.getDirectoryPath(
      dialogTitle: switch (kind) {
        StorageFolderKind.documents =>
          'Carpeta para documentos y exportaciones',
        StorageFolderKind.music => 'Carpeta para música descargada',
        StorageFolderKind.downloads => 'Carpeta para actualizaciones',
        StorageFolderKind.data => 'Datos internos',
      },
      initialDirectory: current.path,
    );
    if (picked == null || picked.trim().isEmpty) return false;

    final Directory chosen = Directory(picked.trim());
    if (!await chosen.exists()) {
      await chosen.create(recursive: true);
    }

    final String key = switch (kind) {
      StorageFolderKind.documents => AppConstants.keyDocumentsFolder,
      StorageFolderKind.music => AppConstants.keyMusicFolder,
      StorageFolderKind.downloads => AppConstants.keyDownloadsFolder,
      StorageFolderKind.data => '',
    };
    await _settings.setString(key, chosen.path);
    return true;
  }

  /// Vuelve a la carpeta estándar de la plataforma.
  Future<void> reset(StorageFolderKind kind) async {
    if (kind == StorageFolderKind.data) return;
    final String key = switch (kind) {
      StorageFolderKind.documents => AppConstants.keyDocumentsFolder,
      StorageFolderKind.music => AppConstants.keyMusicFolder,
      StorageFolderKind.downloads => AppConstants.keyDownloadsFolder,
      StorageFolderKind.data => '',
    };
    await _settings.remove(key);
  }

  /// Abre la carpeta en el explorador de archivos del sistema.
  Future<bool> open(StorageFolderKind kind) async {
    final Directory dir = await resolve(kind);
    try {
      if (!kIsWeb && Platform.isWindows) {
        final ProcessResult result = await Process.run('explorer.exe', <String>[
          dir.path,
        ]);
        return result.exitCode == 0;
      }
      final Uri uri = Uri.file(dir.path);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir ${dir.path}', error, stack);
      return false;
    }
  }
}
