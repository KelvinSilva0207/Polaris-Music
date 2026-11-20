import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/app_paths.dart';
import 'file_utils.dart';

/// Extensiones usadas por el escáner al cachear carátulas en disco.
const List<String> _artworkExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
];

/// Devuelve una ruta de carátula utilizable para [audioPath].
///
/// La ruta persistida tiene prioridad, pero si quedó vacía o el archivo se
/// movió se busca la copia cacheada por el hash estable de la ruta del audio.
/// Solo comprueba existencia de archivos: no decodifica imágenes.
String? resolveArtworkPath(String? storedPath, String? audioPath) {
  if (storedPath != null &&
      storedPath.isNotEmpty &&
      File(storedPath).existsSync()) {
    return storedPath;
  }

  final String? root = AppPaths.artworkPathSync;
  if (root == null || audioPath == null || audioPath.isEmpty) return null;

  final String hash = FileUtils.fnv1a(audioPath);
  for (final String extension in _artworkExtensions) {
    final String candidate = p.join(root, '$hash.$extension');
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}
