import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/models/track.dart';
import 'library_folder.dart';

/// Nodo de la jerarquía real de carpetas derivada de las rutas indexadas.
class FolderNode {
  FolderNode._({
    required this.path,
    required this.name,
    this.parent,
    required this.directTracks,
    required this.descendantTracks,
  });

  final String path;
  final String name;
  final FolderNode? parent;
  List<FolderNode> _children = const <FolderNode>[];

  /// Los hijos se asignan al congelar el árbol. Se devuelven sin modificar
  /// para que el resto de la app siga tratando el nodo como inmutable.
  List<FolderNode> get children => List<FolderNode>.unmodifiable(_children);
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

  _MutableNode ensure(
    String rawPath, {
    String? displayName,
    bool createParents = true,
  }) {
    final String key = _normalizePath(rawPath);
    final _MutableNode? existing = nodes[key];
    if (existing != null) return existing;

    final String parentKey = _parentPath(key);
    // Las raíces de escaneo y los nodos sintéticos no deben arrastrar a sus
    // ancestros: son la cima de la jerarquía que se muestra al usuario.
    final _MutableNode? parent =
        !createParents || parentKey.isEmpty || parentKey == key
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
    final _MutableNode root = ensure(
      folder.path,
      displayName: folder.name,
      createParents: false,
    );
    if (!scanRoots.contains(root)) scanRoots.add(root);
  }

  _MutableNode? downloads;
  _MutableNode? other;

  for (final Track track in tracks) {
    if (track.path.trim().isEmpty) continue;
    if (!track.isLocal && !track.isDownloaded) continue;

    if (track.isDownloaded) {
      downloads ??= ensure(
        'polaris://descargas',
        displayName: 'Descargas',
        createParents: false,
      );
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
      other ??= ensure(
        'polaris://otros',
        displayName: 'Otros',
        createParents: false,
      );
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
  FolderNode freeze(_MutableNode node, FolderNode? parent) {
    final FolderNode? cached = frozen[node];
    if (cached != null) return cached;
    final FolderNode result = FolderNode._(
      path: node.path,
      name: node.name,
      parent: parent,
      directTracks: List<Track>.unmodifiable(node.direct),
      descendantTracks: node.descendants,
    );
    // Se registra antes de bajar a los hijos: cada hijo apunta a este padre y,
    // sin esta entrada, la recursión volvería a empezar hasta agotar la pila.
    frozen[node] = result;
    result._children = <FolderNode>[
      for (final _MutableNode child in node.children) freeze(child, result),
    ];
    return result;
  }

  final List<FolderNode> roots = <FolderNode>[
    for (final _MutableNode root in scanRoots) freeze(root, null),
  ];
  if (other != null && !scanRoots.contains(other)) {
    roots.add(freeze(other, null));
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
      : freeze(downloads, null);
  if (downloadsNode != null) byPath[downloadsNode.path] = downloadsNode;

  return FolderLibrary._(
    roots: List<FolderNode>.unmodifiable(roots),
    byPath: UnmodifiableMapView<String, FolderNode>(byPath),
    unclassified: downloadsNode,
  );
}
