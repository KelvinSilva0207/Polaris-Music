import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/downloaded_track.dart';
import 'package:polaris_music/features/online_music/data/download_manager.dart';
import 'package:polaris_music/features/online_music/data/metadata_audio_bridge.dart';
import 'package:polaris_music/features/online_music/data/source_helpers.dart';
import 'package:polaris_music/features/online_music/domain/download_task.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source_catalog.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_music_repository.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

OnlineTrack _track(
  String source,
  String id,
  String title,
  String artist, {
  int durationMs = 200000,
}) => OnlineTrack(
  externalId: '$source:$id',
  sourceId: id,
  title: title,
  artist: artist,
  durationMs: durationMs,
  sourceLabel: source == 'spotify' ? 'Spotify' : 'Tidal',
);

class _BridgeSource implements MusicSourceProvider {
  _BridgeSource(
    this.id, {
    this.tracks = const <OnlineTrack>[],
    this.stream,
    this.collections = const <OnlineCollectionRef>[],
    this.collectionItems = const <OnlineTrack>[],
  });

  @override
  final MusicSourceId id;
  final List<OnlineTrack> tracks;
  final ResolvedStream? stream;
  final List<OnlineCollectionRef> collections;
  final List<OnlineTrack> collectionItems;
  @override
  bool get canStream => true;

  int resolveCalls = 0;
  OnlineSearchType? lastType;
  String? lastCollectionId;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => false;

  @override
  bool get canDownload => canStream;

  @override
  MusicSourceStatus get status => const MusicSourceStatus();

  @override
  Future<MusicSourceStatus> checkAvailability() async => status;

  @override
  Future<SourceResult> search(String query, {int limit = 25}) async =>
      SourceResult(source: id, items: tracks.take(limit).toList());

  @override
  Future<SourceResult> trending({int limit = 25}) async =>
      SourceResult(source: id);

  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) async {
    lastType = type;
    return collections
        .where((OnlineCollectionRef item) => item.kind == type)
        .take(limit)
        .toList();
  }

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async {
    lastCollectionId = collection.id;
    return collectionItems.take(limit).toList();
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    resolveCalls++;
    if (stream == null) {
      throw MusicSourceException(
        'Sin audio en ${id.label}',
        source: id,
        issue: MusicSourceIssue.unsupported,
      );
    }
    return stream!;
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async => null;
}

class _DownloadRepository implements OnlineMusicRepository {
  _DownloadRepository({this.resolveError});

  final String? resolveError;

  static const ResolvedStream stream = ResolvedStream(
    url: 'https://media.example/audio.m4a',
    extension: 'm4a',
    mimeType: 'audio/mp4',
    httpHeaders: <String, String>{
      'Referer': 'https://music.youtube.com/',
      'X-Test-Token': 'token-123',
    },
    resolvedVia: 'Spotify → YouTube Music',
  );

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async =>
      const <OnlineTrack>[];

  @override
  Future<List<OnlineTrack>> trending({int limit = 25}) async =>
      const <OnlineTrack>[];

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    final String? error = resolveError;
    if (error != null) {
      throw MusicSourceException(
        error,
        source: MusicSourceId.spotify,
        issue: MusicSourceIssue.unsupported,
      );
    }
    return stream;
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async => null;

  @override
  Future<String?> cacheArtworkFor(OnlineTrack track) async => null;

  @override
  bool canStreamTrack(OnlineTrack track) => true;

  @override
  bool canDownloadTrack(OnlineTrack track) => true;

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async => const <OnlineTrack>[];
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      'audio-de-prueba',
      200,
      headers: <String, List<String>>{
        'Content-Type': <String>['audio/mp4'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('MetadataAudioBridge', () {
    test('elige el primer resolutor válido y etiqueta el origen real', () async {
      const OnlineTrack metadata = OnlineTrack(
        externalId: 'spotify:abc',
        sourceId: 'abc',
        title: 'Canción example',
        artist: 'Artista Example',
        durationMs: 200000,
        sourceLabel: 'Spotify',
      );
      final _BridgeSource youtube = _BridgeSource(
        MusicSourceId.youtube,
        tracks: <OnlineTrack>[
          _track('youtube', 'vid', 'Canción example', 'Artista Example'),
        ],
        stream: const ResolvedStream(
          url: 'https://media.example/yt.m4a',
          extension: 'm4a',
          httpHeaders: <String, String>{'Referer': 'https://music.youtube.com/'},
        ),
      );
      final _BridgeSource audius = _BridgeSource(
        MusicSourceId.audius,
        tracks: <OnlineTrack>[
          _track('audius', 'aud', 'Canción example', 'Artista Example'),
        ],
        stream: const ResolvedStream(url: 'https://media.example/audius.mp3'),
      );
      // El orden del catálogo es distinto: el puente impone su propio orden.
      final MetadataAudioBridge bridge = MetadataAudioBridge(
        MusicSourceCatalog(<MusicSourceProvider>[audius, youtube]),
      );

      final ResolvedStream stream = await bridge.resolve(metadata);

      expect(stream.url, 'https://media.example/yt.m4a');
      expect(stream.httpHeaders['Referer'], 'https://music.youtube.com/');
      expect(stream.resolvedVia, 'Spotify → YouTube Music');
      expect(youtube.resolveCalls, 1);
      expect(audius.resolveCalls, 0);
    });

    test('descarta candidatos que no parecen la misma canción', () async {
      final _BridgeSource youtube = _BridgeSource(
        MusicSourceId.youtube,
        tracks: <OnlineTrack>[
          _track('youtube', 'bad', 'Otra canción', 'Otro artista'),
        ],
        stream: const ResolvedStream(url: 'https://media.example/wrong.m4a'),
      );
      final _BridgeSource audius = _BridgeSource(
        MusicSourceId.audius,
        tracks: <OnlineTrack>[
          _track('audius', 'good', 'Canción example', 'Artista Example'),
        ],
        stream: const ResolvedStream(url: 'https://media.example/good.mp3'),
      );
      final MetadataAudioBridge bridge = MetadataAudioBridge(
        MusicSourceCatalog(<MusicSourceProvider>[youtube, audius]),
      );

      final ResolvedStream stream = await bridge.resolve(
        _track('tidal', 'tid', 'Canción example', 'Artista Example'),
      );

      expect(stream.url, 'https://media.example/good.mp3');
      expect(stream.resolvedVia, 'Tidal → Audius');
      expect(youtube.resolveCalls, 0);
      expect(audius.resolveCalls, 1);
    });

    test('sin equivalente razonable falla con un motivo explícito', () async {
      final MetadataAudioBridge bridge = MetadataAudioBridge(
        MusicSourceCatalog(<MusicSourceProvider>[
          _BridgeSource(MusicSourceId.youtube),
        ]),
      );

      expect(
        bridge.resolve(
          _track('spotify', 'abc', 'Canción example', 'Artista Example'),
        ),
        throwsA(
          isA<MusicSourceException>().having(
            (MusicSourceException error) => error.issue,
            'issue',
            MusicSourceIssue.unsupported,
          ),
        ),
      );
    });
  });

  group('Búsqueda tipada y colecciones', () {
    test('searchType reparte colecciones y collectionTracks usa el proveedor de origen', () async {
      const OnlineCollectionRef album = OnlineCollectionRef(
        externalId: 'audius:album-1',
        id: 'album-1',
        title: 'Álbum demo',
        source: MusicSourceId.audius,
        kind: OnlineSearchType.albums,
      );
      final _BridgeSource audius = _BridgeSource(
        MusicSourceId.audius,
        collections: <OnlineCollectionRef>[album],
        collectionItems: <OnlineTrack>[
          _track('audius', 'track-1', 'Canción demo', 'Artista demo'),
        ],
      );
      final MusicSourceCatalog catalog = MusicSourceCatalog(
        <MusicSourceProvider>[audius],
      );

      final CatalogResult albums = await catalog.searchType(
        'demo',
        type: OnlineSearchType.albums,
      );
      final CatalogResult playlists = await catalog.searchType(
        'demo',
        type: OnlineSearchType.playlists,
      );

      expect(albums.tracks, isEmpty);
      expect(albums.collections(OnlineSearchType.albums), <OnlineCollectionRef>[
        album,
      ]);
      expect(albums.collections(OnlineSearchType.playlists), isEmpty);
      expect(playlists.collections(OnlineSearchType.albums), isEmpty);
      expect(audius.lastType, OnlineSearchType.playlists);

      final List<OnlineTrack> loaded = await catalog.collectionTracks(album);
      expect(loaded, hasLength(1));
      expect(loaded.single.externalId, 'audius:track-1');
      expect(audius.lastCollectionId, 'album-1');
    });
  });

  group('DownloadManager', () {
    test('reenvía cabeceras del stream y guarda el origen resuelto', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'polaris-download-',
      );
      final _RecordingAdapter adapter = _RecordingAdapter();
      final Dio dio = Dio()..httpClientAdapter = adapter;
      DownloadManager? manager;
      DownloadedTrack? saved;
      final List<List<DownloadTask>> snapshots = <List<DownloadTask>>[];

      try {
        manager = DownloadManager(
          repository: _DownloadRepository(),
          registerDownloaded: (DownloadedTrack track) async {
            saved = track;
            return 1;
          },
          hasDownloaded: (String externalId) async => false,
          dio: dio,
          musicDirectory: () async => dir,
        );

        final subscription = manager.changes.listen(snapshots.add);
        final Future<List<DownloadTask>> finished = manager.changes.firstWhere(
          (List<DownloadTask> tasks) => tasks.any(
            (DownloadTask task) =>
                task.status == DownloadStatus.completed ||
                task.status == DownloadStatus.failed,
          ),
        );
        manager.enqueue(
          _track('spotify', 'abc', 'Canción example', 'Artista Example'),
        );

        final List<DownloadTask> tasks = await finished.timeout(
          const Duration(seconds: 10),
        );
        await subscription.cancel();

        expect(tasks.single.status, DownloadStatus.completed);
        expect(
          snapshots
              .expand((List<DownloadTask> batch) => batch)
              .any(
                (DownloadTask task) =>
                    task.status == DownloadStatus.downloading &&
                    task.indeterminate,
              ),
          isTrue,
          reason: 'sin Content-Length el progreso debe ser indefinido',
        );
        expect(adapter.request!.headers['Referer'], 'https://music.youtube.com/');
        expect(adapter.request!.headers['X-Test-Token'], 'token-123');
        expect(adapter.request!.headers['Accept'], contains('audio/*'));
        expect(saved, isNotNull);
        expect(saved!.sourceLabel, 'Spotify → YouTube Music');
        expect(saved!.album, contains('Spotify → YouTube Music'));
        expect(File(saved!.path).existsSync(), isTrue);
      } finally {
        await manager?.dispose();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('una pista sin equivalente reproducible falla con motivo visible',
        () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'polaris-download-error-',
      );
      DownloadManager? manager;

      try {
        manager = DownloadManager(
          repository: _DownloadRepository(
            resolveError: 'No encontramos una versión reproducible de esta '
                'canción en fuentes abiertas.',
          ),
          registerDownloaded: (DownloadedTrack track) async => 1,
          hasDownloaded: (String externalId) async => false,
          musicDirectory: () async => dir,
        );
        final Future<List<DownloadTask>> finished = manager.changes.firstWhere(
          (List<DownloadTask> tasks) => tasks.any(
            (DownloadTask task) => task.status == DownloadStatus.failed,
          ),
        );
        manager.enqueue(
          _track('tidal', 'tid', 'Canción example', 'Artista Example'),
        );

        final List<DownloadTask> tasks = await finished.timeout(
          const Duration(seconds: 10),
        );

        expect(tasks.single.status, DownloadStatus.failed);
        expect(
          tasks.single.error,
          contains('No encontramos una versión reproducible'),
        );
        expect(
          dir.listSync().whereType<File>(),
          isEmpty,
          reason: 'no debe quedar un archivo .part tras el fallo',
        );
      } finally {
        await manager?.dispose();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });
}
