import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/features/online_music/data/online_sync_repository.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

const OnlineCollectionRef _reference = OnlineCollectionRef(
  externalId: 'youtube:VL123456',
  id: 'VL123456',
  title: 'Playlist demo',
  subtitle: 'Artista demo',
  source: MusicSourceId.youtube,
  kind: OnlineSearchType.playlists,
  permalink: 'https://music.youtube.com/browse?browseId=VL123456&pot=secreto&visitorData=abc',
  trackCount: 2,
);

OnlineTrack _track(String id, String title) => OnlineTrack(
  externalId: 'youtube:$id',
  sourceId: id,
  title: title,
  artist: 'Artista demo',
  durationMs: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late OnlineSyncRepository repository;
  bool online;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    online = true;
    repository = OnlineSyncRepository(db, hasNetwork: () async => online);
  });

  tearDown(() async {
    await db.close();
  });

  test('guarda referencias sin URL firmada ni token', () async {
    await repository.saveReferences(<OnlineCollectionRef>[_reference]);

    final List<OnlineReferenceRow> rows = await db.onlineSyncDao
        .allReferences();
    expect(rows, hasLength(1));
    final OnlineReferenceRow row = rows.single;
    expect(row.externalId, 'youtube:VL123456');
    expect(row.source, 'youtube');
    expect(row.kind, 'playlists');
    expect(row.title, 'Playlist demo');
    expect(row.trackCount, 2);
    expect(row.permalink, isA<String>());
    expect(row.permalink, isNot(contains('pot=')));
    expect(row.permalink, isNot(contains('visitorData')));
  });

  test('sin red conserva datos anteriores y no consulta la fuente', () async {
    online = false;
    bool fetched = false;

    final OnlineSyncOutcome outcome = await repository.syncReference(
      _reference,
      fetchPage: (_) async {
        fetched = true;
        return <OnlineTrack>[_track('aaaaaaaaaaa', 'Pista')];
      },
    );

    expect(outcome, OnlineSyncOutcome.savedOffline);
    expect(fetched, isFalse);
    final List<OnlineReferenceRow> rows = await db.onlineSyncDao
        .allReferences();
    expect(rows.single.title, 'Playlist demo');
    expect(rows.single.lastError, contains('Sin conexión'));
  });

  test('fallo parcial no borra pistas ni favorite/contador local', () async {
    await repository.saveReferences(<OnlineCollectionRef>[_reference]);
    await repository.rememberTracks(_reference.externalId, <OnlineTrack>[
      _track('aaaaaaaaaaa', 'Pista anterior'),
    ]);
    await db.onlineSyncDao.setFavorite(_reference.externalId, true);
    await db.onlineSyncDao.recordPlay(_reference.externalId);

    final OnlineSyncOutcome outcome = await repository.syncReference(
      _reference,
      fetchPage: (_) async => throw StateError('token=secreto al sincronizar'),
    );

    expect(outcome, OnlineSyncOutcome.failed);
    final List<OnlineReferenceRow> rows = await db.onlineSyncDao
        .allReferences();
    expect(rows.single.isFavorite, isTrue);
    expect(rows.single.playCount, 1);
    expect(rows.single.lastError, isNot(contains('secreto')));
    final List<OnlineReferenceTrackRow> tracks = await db.onlineSyncDao
        .tracksFor(_reference.externalId);
    expect(tracks.single.title, 'Pista anterior');
  });

  test('resincroniza metadatos por externalId sin duplicar filas', () async {
    final OnlineSyncOutcome first = await repository.syncReference(
      _reference,
      fetchPage: (_) async => <OnlineTrack>[_track('aaaaaaaaaaa', 'Pista 1')],
    );
    expect(first, OnlineSyncOutcome.synced);

    await db.onlineSyncDao.setFavorite(_reference.externalId, true);
    await db.onlineSyncDao.recordPlay(_reference.externalId);

    final OnlineCollectionRef updated = _reference.copyWith(
      title: 'Nuevo título',
    );
    final OnlineSyncOutcome second = await repository.syncReference(
      updated,
      fetchPage: (_) async => <OnlineTrack>[
        _track('aaaaaaaaaaa', 'Pista 1'),
        _track('bbbbbbbbbbb', 'Pista 2'),
      ],
    );

    expect(second, OnlineSyncOutcome.synced);
    final List<OnlineReferenceRow> rows = await db.onlineSyncDao
        .allReferences();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Nuevo título');
    expect(rows.single.isFavorite, isTrue);
    expect(rows.single.playCount, 1);
    final List<OnlineReferenceTrackRow> tracks = await db.onlineSyncDao
        .tracksFor(_reference.externalId);
    expect(tracks, hasLength(2));
    expect(tracks.map((OnlineReferenceTrackRow t) => t.title), <String>[
      'Pista 1',
      'Pista 2',
    ]);
  });
}
