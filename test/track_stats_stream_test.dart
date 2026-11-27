import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late int trackId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.trackDao.upsertScanned(
      TracksCompanion.insert(path: r'C:\Music\cancion.mp3', title: 'Canción'),
    );
    trackId = (await db.trackDao.getAll()).single.id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<int>> watchEmissions() async {
    final List<int> emissions = <int>[];
    final StreamSubscription<List<TrackRow>> subscription = db.trackDao
        .watchAll()
        .listen((List<TrackRow> rows) {
          emissions.add(rows.length);
        });
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return emissions;
  }

  test(
    'registrar una escucha actualiza la fila sin reemitir la biblioteca',
    () async {
      final List<int> emissions = await watchEmissions();
      expect(emissions, hasLength(1));

      await db.trackDao.registerPlay(trackId, completed: true);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(emissions, hasLength(1));
      final TrackRow updated = (await db.trackDao.getAll()).single;
      expect(updated.playCount, 1);
      expect(updated.lastPlayedAt != null, isTrue);
    },
  );

  test('incrementar skips tampoco reemite la biblioteca', () async {
    final List<int> emissions = await watchEmissions();
    expect(emissions, hasLength(1));

    await db.trackDao.incrementSkip(trackId);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(emissions, hasLength(1));
    expect((await db.trackDao.getAll()).single.skipCount, 1);
  });
}
