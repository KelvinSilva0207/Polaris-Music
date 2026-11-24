import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/features/online_music/data/source_helpers.dart';
import 'package:polaris_music/features/online_music/data/youtube_music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/request_cancellation.dart';

/// Responde `browse` con una página distinta según el token de continuación.
class _BrowseAdapter implements HttpClientAdapter {
  _BrowseAdapter(this.pages, {this.statusCode = 200});

  final Map<String, Map<String, dynamic>> pages;
  final int statusCode;
  final List<RequestOptions> requests = <RequestOptions>[];

  static const Map<String, List<String>> _headers = <String, List<String>>{
    'Content-Type': <String>['application/json; charset=utf-8'],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        '<script>{"INNERTUBE_CLIENT_VERSION":"9.9.9"}</script>',
        200,
        headers: _headers,
      );
    }
    final Object? continuation =
        (options.data as Map<String, dynamic>)['continuation'];
    final String key = continuation == null ? 'first' : '$continuation';
    return ResponseBody.fromString(
      jsonEncode(pages[key] ?? <String, dynamic>{}),
      statusCode,
      headers: _headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _renderer(String id, String title) => <String, dynamic>{
  'musicResponsiveListItemRenderer': <String, dynamic>{
    'playlistItemData': <String, dynamic>{'videoId': id},
    'overlay': <String, dynamic>{
      'musicItemThumbnailOverlayRenderer': <String, dynamic>{
        'content': <String, dynamic>{
          'musicPlayButtonRenderer': <String, dynamic>{
            'playNavigationEndpoint': <String, dynamic>{
              'watchEndpoint': <String, dynamic>{'videoId': id},
            },
          },
        },
      },
    },
    'flexColumns': <Object?>[
      <String, dynamic>{
        'musicResponsiveListItemFlexColumnRenderer': <String, dynamic>{
          'text': <String, dynamic>{
            'runs': <Object?>[
              <String, dynamic>{'text': title},
            ],
          },
        },
      },
      <String, dynamic>{
        'musicResponsiveListItemFlexColumnRenderer': <String, dynamic>{
          'text': <String, dynamic>{
            'runs': <Object?>[
              <String, dynamic>{'text': 'Artista demo'},
              <String, dynamic>{'text': '3:27'},
            ],
          },
        },
      },
    ],
  },
};

Map<String, dynamic> _page(Map<String, dynamic> track, String? next) =>
    <String, dynamic>{
      'onResponseReceivedActions': <Object?>[
        <String, dynamic>{
          'appendContinuationItemsAction': <String, dynamic>{
            'continuationItems': <Object?>[
              track,
              if (next != null)
                <String, dynamic>{
                  'continuationItemRenderer': <String, dynamic>{
                    'continuationEndpoint': <String, dynamic>{
                      'continuationCommand': <String, dynamic>{'token': next},
                    },
                  },
                },
            ],
          },
        },
      ],
    };

_YoutubeHarness _harness(
  Map<String, Map<String, dynamic>> pages, {
  int statusCode = 200,
}) {
  final _BrowseAdapter adapter = _BrowseAdapter(pages, statusCode: statusCode);
  final Dio dio = Dio()..httpClientAdapter = adapter;
  return _YoutubeHarness(
    adapter: adapter,
    source: YouTubeMusicSource(
      dio: dio,
      artworkCache: ArtworkCache(dio: dio),
    ),
  );
}

class _YoutubeHarness {
  _YoutubeHarness({required this.adapter, required this.source});

  final _BrowseAdapter adapter;
  final YouTubeMusicSource source;
}

const OnlineCollectionRef _collection = OnlineCollectionRef(
  externalId: 'youtube:VL123456',
  id: 'VL123456',
  title: 'Playlist demo',
  source: MusicSourceId.youtube,
  kind: OnlineSearchType.playlists,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube Music: paginación de colecciones', () {
    test('continuation se reenvía y se parsea desde actions', () async {
      final _YoutubeHarness harness = _harness(<String, Map<String, dynamic>>{
        'first': _page(_renderer('aaaaaaaaaaa', 'Pista 1'), 'next-1'),
        'next-1': _page(_renderer('bbbbbbbbbbb', 'Pista 2'), 'next-2'),
      });

      final CollectionPage first = await harness.source.collectionPage(
        _collection,
        token: const NoOpOnlineRequestToken(),
      );
      expect(first.tracks.single.externalId, 'youtube:aaaaaaaaaaa');
      expect(first.continuation, 'next-1');
      expect(first.hasMore, isTrue);
      expect(
        (harness.adapter.requests.last.data!
            as Map<String, dynamic>)['browseId'],
        'VL123456',
      );

      final CollectionPage second = await harness.source.collectionPage(
        _collection,
        continuation: 'next-1',
        token: const NoOpOnlineRequestToken(),
      );
      expect(second.tracks.single.externalId, 'youtube:bbbbbbbbbbb');
      expect(second.continuation, 'next-2');
      expect(
        (harness.adapter.requests.last.data!
            as Map<String, dynamic>)['continuation'],
        'next-1',
      );
    });

    test(
      'un fallo de paginación devuelve página vacía sin borrar nada',
      () async {
        final _YoutubeHarness harness = _harness(<String, Map<String, dynamic>>{
          'first': _page(_renderer('aaaaaaaaaaa', 'Pista 1'), 'next-1'),
        }, statusCode: 500);

        final CollectionPage page = await harness.source.collectionPage(
          _collection,
          continuation: 'next-1',
          token: const NoOpOnlineRequestToken(),
        );

        expect(page.tracks, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );
  });
}
