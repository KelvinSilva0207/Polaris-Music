import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/features/library/domain/library_folder.dart';
import 'package:polaris_music/features/library/presentation/library_providers.dart';
import 'package:polaris_music/features/library/presentation/library_views.dart';

Future<void> _pumpFolders(
  WidgetTester tester, {
  required Stream<List<Track>> tracks,
  required Stream<List<LibraryFolder>> folders,
  VoidCallback? onManageFolders,
  String? scanError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        libraryAllTracksProvider.overrideWith((Ref ref) => tracks),
        libraryFoldersProvider.overrideWith((Ref ref) => folders),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FoldersView(
            onManageFolders: onManageFolders,
            scanError: scanError,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('el estado vacío ofrece añadir carpeta', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await _pumpFolders(
      tester,
      tracks: Stream<List<Track>>.value(const <Track>[]),
      folders: Stream<List<LibraryFolder>>.value(const <LibraryFolder>[]),
      onManageFolders: () => tapped = true,
    );

    expect(find.text('Todavía no hay carpetas indexadas'), findsOneWidget);
    expect(find.text('Añadir carpeta'), findsOneWidget);
    await tester.tap(find.text('Añadir carpeta'));
    expect(tapped, isTrue);
  });

  testWidgets('el estado vacío explica un error de carga', (
    WidgetTester tester,
  ) async {
    await _pumpFolders(
      tester,
      tracks: Stream<List<Track>>.value(const <Track>[]),
      folders: Stream<List<LibraryFolder>>.error(StateError('DB bloqueada')),
    );

    expect(
      find.textContaining('No se pudieron cargar las carpetas'),
      findsOneWidget,
    );
    expect(find.textContaining('DB bloqueada'), findsOneWidget);
  });

  testWidgets('el estado vacío explica un escaneo fallido', (
    WidgetTester tester,
  ) async {
    await _pumpFolders(
      tester,
      tracks: Stream<List<Track>>.value(const <Track>[]),
      folders: Stream<List<LibraryFolder>>.value(const <LibraryFolder>[]),
      scanError: 'No se pudo completar la operación: permiso denegado',
    );

    expect(find.textContaining('permiso denegado'), findsOneWidget);
  });

  testWidgets('muestra raíces aunque todavía no haya pistas', (
    WidgetTester tester,
  ) async {
    await _pumpFolders(
      tester,
      tracks: Stream<List<Track>>.value(const <Track>[]),
      folders: Stream<List<LibraryFolder>>.value(<LibraryFolder>[
        const LibraryFolder(id: 1, path: r'C:\Music', recursive: true),
      ]),
    );

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Todavía no hay carpetas indexadas'), findsNothing);
  });
}
