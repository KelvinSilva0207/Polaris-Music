import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';

/// Utilidades de archivo sin dependencias de Flutter.
class FileUtils {
  FileUtils._();

  static String extensionOf(String path) {
    final String ext = p.extension(path);
    return ext.isEmpty ? '' : ext.substring(1).toLowerCase();
  }

  static bool isAudioFile(String path) =>
      AppConstants.audioExtensions.contains(extensionOf(path));

  static bool isLrcFile(String path) => extensionOf(path) == 'lrc';

  /// Hash FNV-1a de 32 bits en hexadecimal, estable entre ejecuciones.
  ///
  /// Se usa para nombrar carátulas cacheadas a partir de la ruta o metadatos.
  static String fnv1a(String input) {
    int hash = 0x811c9dc5;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String sanitizeFileName(String input) {
    final String cleaned = input.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    return cleaned.trim().isEmpty ? 'sin_nombre' : cleaned.trim();
  }

  static Future<Directory> ensureDirectory(String path) async {
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Recorre una carpeta devolviendo solo archivos de audio.
  ///
  /// Tolera carpetas sin permisos: un error en una subcarpeta no aborta todo
  /// el escaneo (importante en Android).
  static Future<List<String>> listAudioFiles(
    String root, {
    bool recursive = true,
  }) async {
    final List<String> found = <String>[];
    final Directory dir = Directory(root);
    if (!await dir.exists()) return found;

    try {
      await for (final FileSystemEntity entity in dir.list(
        recursive: recursive,
        followLinks: false,
      )) {
        if (entity is File && isAudioFile(entity.path)) {
          found.add(entity.path);
        }
      }
    } on FileSystemException {
      // Permiso denegado en una rama: seguimos con lo que ya se encontró.
    }
    return found;
  }

  static Future<int> fileSize(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  /// Busca un `.lrc` junto al archivo de audio (`cancion.mp3` → `cancion.lrc`).
  static Future<File?> siblingLyrics(String audioPath) async {
    final String lrcPath = p.setExtension(audioPath, '.lrc');
    final File file = File(lrcPath);
    return await file.exists() ? file : null;
  }
}
