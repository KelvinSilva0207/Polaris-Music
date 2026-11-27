import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/features/library/domain/folder_tree.dart';
import 'package:polaris_music/features/library/domain/library_folder.dart';

void main() {
  test('congela un árbol con subcarpetas sin recursión infinita', () {
    const LibraryFolder folder = LibraryFolder(
      id: 1,
      path: r'C:\Music',
      recursive: true,
    );
    final Track track = Track(
      id: 7,
      path: r'C:\Music\Artista\cancion.mp3',
      title: 'Canción',
      artist: 'Artista',
      album: 'Álbum',
      durationMs: 120000,
    );

    final FolderLibrary library = buildFolderTree(
      <Track>[track],
      const <LibraryFolder>[folder],
    );

    expect(library.roots, hasLength(1));
    final FolderNode root = library.roots.single;
    expect(root.name, 'Music');
    expect(root.children, hasLength(1));
    final FolderNode child = root.children.single;
    expect(child.name, 'artista');
    expect(child.parent, same(root));
    expect(child.breadcrumb, 'Music / artista');
    expect(child.descendantTracks, <Track>[track]);
    expect(root.descendantTracks, <Track>[track]);
  });

  test('una raíz sin pistas no arrastra ancestros', () {
    const LibraryFolder folder = LibraryFolder(
      id: 2,
      path: r'C:\Music',
      recursive: true,
    );

    final FolderLibrary library = buildFolderTree(
      const <Track>[],
      const <LibraryFolder>[folder],
    );

    expect(library.roots, hasLength(1));
    expect(library.roots.single.parent, isNull);
    expect(library.roots.single.children, isEmpty);
  });
}
