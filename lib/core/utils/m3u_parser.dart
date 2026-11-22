import 'dart:io';

import 'package:path/path.dart' as p;

/// Una entrada de un archivo M3U (ruta o URL de una pista).
class M3uEntry {
  const M3uEntry({required this.location, this.title, this.durationSeconds});

  final String location;
  final String? title;
  final int? durationSeconds;
}

/// Lector y escritor de M3U/M3U8 extremadamente tolerante.
///
/// Se queda con las rutas/URLs y los títulos de `#EXTINF`; ignora el resto de
/// directivas (`#EXTM3U`, `#PLAYLIST`, etc.). Las rutas relativas se resuelven
/// contra la carpeta del archivo para que el playlist funcione aunque se mueva.
class M3uDocument {
  M3uDocument(this.entries);

  final List<M3uEntry> entries;

  static final RegExp _extInf = RegExp(
    r'^#EXTINF:(-?\d+)(?:\s*,)?(.*)$',
    caseSensitive: false,
  );

  factory M3uDocument.parse(
    String content, {
    String? basePath,
    bool Function(String location)? keep,
  }) {
    final List<M3uEntry> entries = <M3uEntry>[];
    String? title;
    int? seconds;
    final List<String> lines = const LineSplitter().convert(
      content.replaceFirst('\uFEFF', ''),
    );
    for (final String raw in lines) {
      final String line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        final RegExpMatch? match = _extInf.firstMatch(line);
        if (match != null) {
          final int parsed = int.tryParse(match.group(1) ?? '') ?? -1;
          seconds = parsed >= 0 ? parsed : null;
          final String label = (match.group(2) ?? '').trim();
          title = label.isEmpty ? null : label;
        }
        continue;
      }
      String location = line;
      // Las URLs (http, file:, content:) no se tocan; las rutas relativas sí.
      final bool isUrl =
          location.contains('://') || location.startsWith('file:');
      if (!isUrl && basePath != null && !p.isAbsolute(location)) {
        location = p.normalize(p.join(basePath, location));
      }
      if (keep != null && !keep(location)) {
        title = null;
        seconds = null;
        continue;
      }
      entries.add(
        M3uEntry(location: location, title: title, durationSeconds: seconds),
      );
      title = null;
      seconds = null;
    }
    return M3uDocument(entries);
  }

  /// Lee un archivo M3U desde disco. Devuelve una lista vacía si no existe.
  static Future<M3uDocument> read(
    String filePath, {
    bool Function(String location)? keep,
  }) async {
    final File file = File(filePath);
    if (!await file.exists()) return M3uDocument(const <M3uEntry>[]);
    final String content = await file.readAsString();
    return M3uDocument.parse(
      content,
      basePath: p.dirname(filePath),
      keep: keep,
    );
  }

  /// Serializa en M3U extendido con títulos y duraciones cuando se conocen.
  String serialize() {
    final StringBuffer out = StringBuffer('#EXTM3U\n');
    for (final M3uEntry entry in entries) {
      final int duration = entry.durationSeconds ?? -1;
      if (entry.title != null) {
        out.writeln('#EXTINF:$duration,${entry.title}');
      }
      out.writeln(entry.location);
    }
    return out.toString();
  }

  Future<File> write(String filePath) =>
      File(filePath).writeAsString(serialize());
}

/// `LineSplitter` local para no arrastrar `dart:convert` en este módulo.
class LineSplitter {
  const LineSplitter();

  List<String> convert(String input) => input.split(RegExp(r'\r\n|\n|\r'));
}
