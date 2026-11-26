import 'dart:convert';
import 'dart:io';

/// Huella barata de un archivo: basta para decidir si vale la pena releerlo.
///
/// `stat()` no abre el archivo ni decodifica etiquetas, así que recorrer miles
/// de pistas es órdenes de magnitud más barato que volver a parsearlas.
class FileSignature {
  const FileSignature(this.size, this.modifiedMs);

  factory FileSignature.fromStat(FileStat stat) =>
      FileSignature(stat.size, stat.modified.millisecondsSinceEpoch);

  final int size;
  final int modifiedMs;

  String get encoded => '$size@$modifiedMs';

  static FileSignature? read(String path) {
    try {
      final FileStat stat = File(path).statSync();
      // En algunas plataformas `statSync` no lanza para una ruta ausente:
      // devuelve size -1. No debe convertirse en una firma "válida".
      if (stat.type == FileSystemEntityType.notFound || stat.size < 0) {
        return null;
      }
      return FileSignature.fromStat(stat);
    } on Object {
      // Un archivo inaccesible se envía al isolate: allí se contabiliza como
      // error y no se marca como "sin cambios" en el índice.
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FileSignature &&
      other.size == size &&
      other.modifiedMs == modifiedMs;

  @override
  int get hashCode => Object.hash(size, modifiedMs);

  @override
  String toString() => encoded;
}

/// Índice local `ruta -> huella` persistido en preferencias.
///
/// Permite que un escaneo solo procese archivos nuevos o modificados. Si el
/// índice no existe (primera ejecución o tras restaurar ajustes), todas las
/// pistas conocidas se tratan como pending una sola vez para reconstruirlo.
class ScanIndex {
  ScanIndex(Map<String, String> entries)
    : _entries = Map<String, String>.unmodifiable(entries);

  factory ScanIndex.decode(String? raw) {
    if (raw == null || raw.isEmpty) return ScanIndex(const <String, String>{});
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return ScanIndex(const <String, String>{});
      return ScanIndex(
        decoded.map(
          (Object? key, Object? value) =>
              MapEntry<String, String>('$key', '$value'),
        ),
      );
    } on Object {
      return ScanIndex(const <String, String>{});
    }
  }

  final Map<String, String> _entries;

  int get length => _entries.length;

  bool isUnchanged(String path, FileSignature signature) =>
      _entries[path] == signature.encoded;

  ScanIndex withSignature(String path, FileSignature signature) {
    final Map<String, String> next = <String, String>{..._entries};
    next[path] = signature.encoded;
    return ScanIndex(next);
  }

  ScanIndex retainAll(Iterable<String> paths) {
    final Set<String> keep = paths.toSet();
    return ScanIndex(
      Map<String, String>.fromEntries(
        _entries.entries.where(
          (MapEntry<String, String> e) => keep.contains(e.key),
        ),
      ),
    );
  }

  Map<String, String> toMap() => Map<String, String>.unmodifiable(_entries);

  String encode() => jsonEncode(_entries);
}
