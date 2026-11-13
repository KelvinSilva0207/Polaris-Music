import 'package:flutter/foundation.dart';

/// Carpeta indexada, sin dependencias de Drift.
@immutable
class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.path,
    required this.recursive,
    this.lastScanAt,
  });

  final int id;
  final String path;
  final bool recursive;
  final DateTime? lastScanAt;

  String get name {
    final List<String> parts = path
        .split(RegExp(r'[\\/]'))
        .where((String s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? path : parts.last;
  }
}
