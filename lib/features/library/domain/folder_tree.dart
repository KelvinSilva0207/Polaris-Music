import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/models/track.dart';
import 'library_folder.dart';

/// Nodo de la jerarquía real de carpetas derivada de las rutas indexadas.
@immutable
class FolderNode {
  const FolderNode._({
    required this.path,
    required this.name,
    this.parent,
    required this.children,
    required this.directTracks,
    required this.descendantTracks,
  });

  final String path;
  final String name;
  final FolderNode? parent;
  final List<FolderNode> children;
  final List<Track> directTracks;
  final List<Track> descendantTracks;

  int get count => descendantTracks.length;

  String get breadcrumb {
    final List<String> parts = <String>[name];
    FolderNode? node = parent;
    while (node != null) {
      parts.add(node.name);
      node = node.parent;
    }
    return parts.reversed.join(' / ');
  }
}

/// Biblioteca jerárquica: raíces de escaneo + descendientes reales.
@immutable
class FolderLibrary {
  const FolderLibrary._({
    required this.roots,
    required this.byPath,
    required this.unclassified,
  });

  final List<FolderNode> roots;
  final Map<String, FolderNode> byPath;

  /// Descargas internas y pistas sin raíz de escaneo conocida (Metrolist).
  final FolderNode? unclassified;

  bool get isEmpty => roots.isEmpty && (unclassified?.count ?? 0) == 0;
}

String _normalizePath(String path) {
  String normalized = path.replaceAll(r'\', '/');
  while (normalized.contains('//')) {
    normalized = normalized.replaceAll('//', '/');
  }
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.toLowerCase();
}

String _displayName(String path) {
  final List<String> parts = path
      .split(RegExp(r'[\\/]'))
      .where((String part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? path : parts.last;
}

String _parentPath(String path) {
  final int index = path.lastIndexOf('/');
  if (index <= 0) return '';
  return path.substring(0, index);
}

String _dirName(String path) {
  final String normalized = path.replaceAll(r'\', '/');
  final int index = normalized.lastIndexOf('/');
  if (index <= 0) return '';
  return normalized.substring(0, index);
}

class _MutableNode {
  _MutableNode(this.path, this.name, this.parent);

  final String path;
  final String name;
  final _MutableNode? parent;
  final List<_MutableNode> children = <_MutableNode>[];
  final List<Track> direct = <Track>[];
  List<Track> descendants = const <Track>[];
}

/// Construye el árbol **sin acceso a disco**: funciona aunque la tarjeta SD
/// esté desmontada. Las rutas absolutas de [Track] nunca se modifican; solo se
/// normalizan como claves de búsqueda (Windows es insensible a mayúsculas).
FolderLibrary buildFolderTree(
  Iterable<Track> tracks,
  Iterable<LibraryFolder> folders,
) {
  final Map<String, _MutableNode> nodes = <String, _MutableNode>{};

  _MutableNode ensure(String rawPath, {String? displayName}) {
    final String key = _normalizePath(rawPath);
    final _MutableNode? existing = nodes[key];
    if (existing != null) return existing;

    final String parentKey = _parentPath(key);
    final _MutableNode? parent = parentKey.isEmpty || parentKey == key
        ? null
        : ensure(parentKey);
    final _MutableNode node = _MutableNode(
      key,
      displayName ?? _displayName(rawPath),
      parent,
    );
    nodes[key] = node;
    parent?.children.add(node);
    return node;
  }

  final List<_MutableNode> scanRoots = <_MutableNode>[];
  for (final LibraryFolder folder in folders) {
    if (folder.path.trim().isEmpty) continue;
    final _MutableNode root = ensure(folder.path, displayName: folder.name);
    if (!scanRoots.contains(root)) scanRoots.add(root);
  }

  _MutableNode? downloads;
  _MutableNode? other;

  for (final Track track in tracks) {
    if (track.path.trim().isEmpty) continue;
    if (!track.isLocal && !track.isDownloaded) continue;

    if (track.isDownloaded) {
      downloads ??= ensure('polaris://descargas', displayName: 'Descargas');
      downloads.direct.add(track);
      continue;
    }

    final String directory = _dirName(track.path);
    final String key = _normalizePath(directory);
    _MutableNode? owner;
    for (final _MutableNode root in scanRoots) {
      final bool inside = key == root.path || key.startsWith('${root.path}/');
      if (inside && (owner == null || root.path.length > owner.path.length)) {
        owner = root;
      }
    }

    if (owner == null) {
      other ??= ensure('polaris://otros', displayName: 'Otros');
      other.direct.add(track);
      continue;
    }

    ensure(key.isEmpty ? owner.path : key).direct.add(track);
  }

  List<Track> collect(_MutableNode node) {
    final List<Track> all = <Track>[...node.direct];
    for (final _MutableNode child in node.children) {
      all.addAll(collect(child));
    }
    node.descendants = List<Track>.unmodifiable(all);
    return all;
  }

  for (final _MutableNode root in scanRoots) {
    collect(root);
  }
  if (other != null) collect(other);
  if (downloads != null) collect(downloads);

  final Map<_MutableNode, FolderNode> frozen = <_MutableNode, FolderNode>{};
  FolderNode freeze(_MutableNode node) {
    final FolderNode? cached = frozen[node];
    if (cached != null) return cached;
    final FolderNode result = FolderNode._(
      path: node.path,
      name: node.name,
      parent: node.parent == null ? null : freeze(node.parent!),
      children: <FolderNode>[
        for (final _MutableNode child in node.children) freeze(child),
      ],
      directTracks: List<Track>.unmodifiable(node.direct),
      descendantTracks: node.descendants,
    );
    frozen[node] = result;
    return result;
  }

  final List<FolderNode> roots = <FolderNode>[
    for (final _MutableNode root in scanRoots) freeze(root),
  ];
  if (other != null && !scanRoots.contains(other)) {
    roots.add(freeze(other));
  }

  final Map<String, FolderNode> byPath = <String, FolderNode>{};
  void index(FolderNode node) {
    byPath[node.path] = node;
    for (final FolderNode child in node.children) {
      index(child);
    }
  }

  for (final FolderNode root in roots) {
    index(root);
  }
  final FolderNode? downloadsNode = downloads == null
      ? null
      : freeze(downloads);
  if (downloadsNode != null) byPath[downloadsNode.path] = downloadsNode;

  return FolderLibrary._(
    roots: List<FolderNode>.unmodifiable(roots),
    byPath: UnmodifiableMapView<String, FolderNode>(byPath),
    unclassified: downloadsNode,
  );
}
