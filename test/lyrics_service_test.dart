import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/features/lyrics/data/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late LyricsService service;
  late Directory folder;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = LyricsService(db.lyricsDao);
    folder = Directory.systemTemp.createTempSync('polaris-lyrics-');
  });

  tearDown(() async {
    await db.close();
    folder.deleteSync(recursive: true);
  });

  Track track(String name) => Track(
    id: 1,
    path: '${folder.path}/$name.mp3',
    title: name,
    artist: 'Artista',
    album: 'Álbum',
    durationMs: 120000,
  );

  test(
    'sin letra devuelve un resultado vacío informativo, no un error',
    () async {
      final LyricsResult result = (await service.resolve(
        track('sin-letra'),
        allowOnline: false,
      ))!;

      expect(result.isEmpty, isTrue);
      expect(result.issue, LyricsIssue.none);
      expect(result.source, 'none');
    },
  );

  test('lee un .lrc hermano y no marca ningún problema', () async {
    File('${folder.path}/con-letra.lrc')
        .writeAsStringSync('[00:01.00] Primera línea');

    final LyricsResult result = (await service.resolve(
      track('con-letra'),
      allowOnline: false,
    ))!;

    expect(result.isEmpty, isFalse);
    expect(result.issue, LyricsIssue.none);
    expect(result.source, 'local');
    expect(result.document.lines.single.text, 'Primera línea');
  });
}
