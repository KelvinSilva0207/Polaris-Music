import 'dart:io';

import 'package:path/path.dart' as p;

/// Ubicaciones donde Metrolist guarda las descargas en Android.
///
/// Metrolist usa el almacenamiento externo de la app (directorios públicos) y
/// puede elegir carpeta propia. Se comprueban las rutas conocidas y, además, se
/// permite al usuario seleccionar otra desde la interfaz.
abstract final class MetrolistPaths {
  static const List<String> candidates = <String>[
    'Android/media/com.metrolist.app/Music',
    'Android/data/com.metrolist.app/files/Music',
    'Metrolist',
    'Metrolist/Music',
    'Music/Metrolist',
    'Download/Metrolist',
  ];

  /// Rutas existentes, deduplicadas y ordenadas por especificidad.
  static Future<List<Directory>> existing({String? additional}) async {
    final List<String> raw = <String>[
      if (additional != null && additional.trim().isNotEmpty) additional.trim(),
      ...candidates,
    ];
    final Set<String> seen = <String>{};
    final List<Directory> dirs = <Directory>[];
    for (final String entry in raw) {
      final String normalized = p.normalize(entry);
      if (!seen.add(normalized.toLowerCase())) continue;
      final Directory directory = Directory(normalized);
      try {
        if (await directory.exists()) dirs.add(directory);
      } on Object {
        // Una ruta inaccesible no invalida el resto de candidatos.
      }
    }
    return dirs;
  }
}
