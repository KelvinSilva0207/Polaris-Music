import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/features/online_music/data/online_diagnostics.dart';
import 'package:polaris_music/features/online_music/data/source_helpers.dart';
import 'package:polaris_music/features/online_music/data/youtube_music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

/// Adaptador que responde sin red para comprobar las peticiones InnerTube.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    required this.homeHtml,
    required this.responses,
    this.statuses = const <String, int>{},
  });

  final String homeHtml;
  final Map<String, Map<String, dynamic>> responses;
  final Map<String, int> statuses;
  final List<RequestOptions> requests = <RequestOptions>[];

  static const Map<String, List<String>> _htmlHeaders = <String, List<String>>{
    'Content-Type': <String>['text/html; charset=utf-8'],
  };
  static const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
    'Content-Type': <String>['application/json; charset=utf-8'],
  };
  static const Map<String, List<String>> _audioHeaders = <String, List<String>>{
    'Content-Type': <String>['audio/mp4'],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'GET') {
      if (options.headers['Range'] == 'bytes=0-0') {
        return ResponseBody.fromString('x', 206, headers: _audioHeaders);
      }
      return ResponseBody.fromString(homeHtml, 200, headers: _htmlHeaders);
    }
    final String endpoint = options.path.split('?').first.split('/').last;
    return ResponseBody.fromString(
      jsonEncode(responses[endpoint] ?? <String, dynamic>{}),
      statuses[endpoint] ?? 200,
      headers: _jsonHeaders,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Devuelve un payload distinto según el cliente InnerTube que pregunta, para
/// comprobar la cadena IOS → ANDROID_MUSIC sin depender de la red.
class _ClientAwareAdapter implements HttpClientAdapter {
  _ClientAwareAdapter(
    this.payloads, {
    this.probeStatuses = const <String, int>{},
  });

  final Map<String, Map<String, dynamic>> payloads;

  /// Estado de la sonda por fragmento de URL; por defecto responde 206.
  final Map<String, int> probeStatuses;
  final List<RequestOptions> requests = <RequestOptions>[];

  static const Map<String, List<String>> _audioHeaders = <String, List<String>>{
    'Content-Type': <String>['audio/mp4'],
  };
  static const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
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
      if (options.headers['Range'] == 'bytes=0-0') {
        int status = 206;
        for (final MapEntry<String, int> entry in probeStatuses.entries) {
          if (options.uri.toString().contains(entry.key)) status = entry.value;
        }
        return ResponseBody.fromString(
          'x',
          status,
          headers: status >= 200 && status < 300 ? _audioHeaders : _jsonHeaders,
        );
      }
      return ResponseBody.fromString(
        '<script>{"INNERTUBE_CLIENT_VERSION":"9.9.9"}</script>',
        200,
        headers: const <String, List<String>>{
          'Content-Type': <String>['text/html; charset=utf-8'],
        },
      );
    }
    final Map<String, dynamic> context =
        (options.data as Map<String, dynamic>)['context']
            as Map<String, dynamic>;
    final String client =
        (context['client'] as Map<String, dynamic>)['clientName'] as String;
    return ResponseBody.fromString(
      jsonEncode(payloads[client] ?? <String, dynamic>{}),
      200,
      headers: const <String, List<String>>{
        'Content-Type': <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  _Harness({
    required Map<String, Map<String, dynamic>> responses,
    Map<String, int> statuses = const <String, int>{},
  }) : adapter = _FakeAdapter(
         homeHtml:
             '<script>{"INNERTUBE_CLIENT_VERSION":"9.9.9",'
             '"VISITOR_DATA":"visitor-123"}</script>',
         responses: responses,
         statuses: statuses,
       ) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    source = YouTubeMusicSource(
      dio: dio,
      artworkCache: ArtworkCache(dio: dio),
    );
  }

  late final _FakeAdapter adapter;
  late final YouTubeMusicSource source;

  RequestOptions postFor(String endpoint) => adapter.requests.firstWhere(
    (RequestOptions request) =>
        request.method == 'POST' && request.path.contains('/$endpoint?'),
  );
}

Map<String, dynamic> _catalogPayload() => <String, dynamic>{
  'responseContext': <String, dynamic>{'visitorData': 'visitor-456'},
  'contents': <String, dynamic>{
    'twoColumnSearchResultsRenderer': <String, dynamic>{
      'primaryContents': <String, dynamic>{
        'sectionListRenderer': <String, dynamic>{
          'contents': <Object?>[
            <String, dynamic>{
              'itemSectionRenderer': <String, dynamic>{
                'contents': <Object?>[
                  <String, dynamic>{
                    'musicResponsiveListItemRenderer': <String, dynamic>{
                      'overlay': <String, dynamic>{
                        'musicItemThumbnailOverlayRenderer': <String, dynamic>{
                          'content': <String, dynamic>{
                            'musicPlayButtonRenderer': <String, dynamic>{
                              'playNavigationEndpoint': <String, dynamic>{
                                'watchEndpoint': <String, dynamic>{
                                  'videoId': 'abc12345678',
                                },
                              },
                            },
                          },
                        },
                      },
                      'thumbnail': <String, dynamic>{
                        'musicThumbnailRenderer': <String, dynamic>{
                          'thumbnail': <String, dynamic>{
                            'thumbnails': <Object?>[
                              <String, dynamic>{
                                'url': 'https://i.ytimg.com/vi/a/hq.jpg',
                              },
                            ],
                          },
                        },
                      },
                      'flexColumns': <Object?>[
                        <String, dynamic>{
                          'musicResponsiveListItemFlexColumnRenderer':
                              <String, dynamic>{
                                'text': <String, dynamic>{
                                  'runs': <Object?>[
                                    <String, dynamic>{'text': 'Canción demo'},
                                  ],
                                },
                              },
                        },
                        <String, dynamic>{
                          'musicResponsiveListItemFlexColumnRenderer':
                              <String, dynamic>{
                                'text': <String, dynamic>{
                                  'runs': <Object?>[
                                    <String, dynamic>{'text': 'Canción'},
                                    <String, dynamic>{'text': 'Artista demo'},
                                    <String, dynamic>{'text': '3:27'},
                                  ],
                                },
                              },
                        },
                      ],
                    },
                  },
                ],
              },
            },
          ],
        },
      },
    },
  },
};

Map<String, dynamic> _collectionPayload() => <String, dynamic>{
  'contents': <String, dynamic>{
    'twoColumnSearchResultsRenderer': <String, dynamic>{
      'primaryContents': <String, dynamic>{
        'sectionListRenderer': <String, dynamic>{
          'contents': <Object?>[
            <String, dynamic>{
              'itemSectionRenderer': <String, dynamic>{
                'contents': <Object?>[
                  <String, dynamic>{
                    'musicResponsiveListItemRenderer': <String, dynamic>{
                      'navigationEndpoint': <String, dynamic>{
                        'browseEndpoint': <String, dynamic>{
                          'browseId': 'VL123456',
                        },
                      },
                      'flexColumns': <Object?>[
                        <String, dynamic>{
                          'musicResponsiveListItemFlexColumnRenderer':
                              <String, dynamic>{
                                'text': <String, dynamic>{
                                  'runs': <Object?>[
                                    <String, dynamic>{'text': 'Playlist demo'},
                                  ],
                                },
                              },
                        },
                        <String, dynamic>{
                          'musicResponsiveListItemFlexColumnRenderer':
                              <String, dynamic>{
                                'text': <String, dynamic>{
                                  'runs': <Object?>[
                                    <String, dynamic>{'text': 'Artista demo'},
                                  ],
                                },
                              },
                        },
                      ],
                    },
                  },
                ],
              },
            },
          ],
        },
      },
    },
  },
};

Map<String, dynamic> _playerPayload() => <String, dynamic>{
  'playabilityStatus': <String, dynamic>{'status': 'OK'},
  'streamingData': <String, dynamic>{
    'adaptiveFormats': <Object?>[
      <String, dynamic>{
        'itag': 140,
        'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
        'url': 'https://googlevideo.example/audio.m4a?expire=1',
        'httpHeaders': <String, dynamic>{
          'Referer': 'https://music.youtube.com/',
        },
      },
    ],
  },
};

Map<String, dynamic> _signedOnlyPayload() => <String, dynamic>{
  'playabilityStatus': <String, dynamic>{'status': 'OK'},
  'streamingData': <String, dynamic>{
    'adaptiveFormats': <Object?>[
      <String, dynamic>{
        'mimeType': 'audio/mp4',
        'url': 'https://googlevideo.example/signed.m4a?s=firma',
        'signatureCipher': 's=firma&url=xxx',
      },
    ],
  },
};

Map<String, dynamic> _cipherOnlyPayload() => <String, dynamic>{
  'playabilityStatus': <String, dynamic>{'status': 'OK'},
  'streamingData': <String, dynamic>{
    'adaptiveFormats': <Object?>[
      <String, dynamic>{
        'mimeType': 'audio/mp4',
        'url': 'https://googlevideo.example/cifrado.m4a',
        'cipher': 's=firma&url=xxx',
      },
    ],
  },
};

Map<String, dynamic> _directPayload(
  String url, {
  String mime = 'audio/mp4; codecs="mp4a.40.2"',
}) => <String, dynamic>{
  'playabilityStatus': <String, dynamic>{'status': 'OK'},
  'streamingData': <String, dynamic>{
    'adaptiveFormats': <Object?>[
      <String, dynamic>{'mimeType': mime, 'url': url},
    ],
  },
};

const OnlineTrack _demoTrack = OnlineTrack(
  externalId: 'youtube:abc12345678',
  sourceId: 'abc12345678',
  title: 'Canción demo',
  artist: 'Artista demo',
  durationMs: 207000,
);

Map<String, dynamic> _clientOf(RequestOptions request) =>
    ((request.data! as Map<String, dynamic>)['context']
            as Map<String, dynamic>)['client']
        as Map<String, dynamic>;

void main() {
  group('YouTubeMusicSource (InnerTube anónimo)', () {
    test(
      'search usa la versión detectada, visitorData y parsea pistas',
      () async {
        final _Harness harness = _Harness(
          responses: <String, Map<String, dynamic>>{
            'search': _catalogPayload(),
          },
        );

        final SourceResult result = await harness.source.search('demo');

        expect(result.status.available, isTrue);
        expect(result.items, hasLength(1));
        final OnlineTrack track = result.items.single;
        expect(track.externalId, 'youtube:abc12345678');
        expect(track.title, 'Canción demo');
        expect(track.artist, 'Artista demo');
        expect(track.durationMs, 207000);
        expect(track.artworkUrl, 'https://i.ytimg.com/vi/a/hq.jpg');

        final RequestOptions request = harness.postFor('search');
        expect(request.path, endsWith('/youtubei/v1/search?prettyPrint=false'));
        final Map<String, dynamic> client = _clientOf(request);
        expect(client['clientName'], 'WEB_REMIX');
        expect(client['clientVersion'], '9.9.9');
        expect(client['hl'], 'es');
        expect(client['gl'], 'ES');
        expect(client['visitorData'], 'visitor-123');
        expect(request.headers['X-YouTube-Client-Name'], '67');
        expect(request.headers['X-Goog-Visitor-Id'], 'visitor-123');
      },
    );

    test(
      'detecta versión y visitor con comillas escapadas como \\u0022',
      () async {
        final _FakeAdapter adapter = _FakeAdapter(
          homeHtml:
              r'<script>{\u0022INNERTUBE_CLIENT_VERSION\u0022:'
              r'\u00227.7.7\u0022,\u0022VISITOR_DATA\u0022:'
              r'\u0022visitor-escape\u0022}</script>',
          responses: <String, Map<String, dynamic>>{
            'search': _catalogPayload(),
          },
        );
        final Dio dio = Dio()..httpClientAdapter = adapter;
        final YouTubeMusicSource source = YouTubeMusicSource(
          dio: dio,
          artworkCache: ArtworkCache(dio: dio),
        );

        final SourceResult result = await source.search('demo');

        expect(result.status.available, isTrue);
        final RequestOptions request = adapter.requests.firstWhere(
          (RequestOptions r) =>
              r.method == 'POST' && r.path.contains('/search?'),
        );
        final Map<String, dynamic> client = _clientOf(request);
        expect(client['clientVersion'], '7.7.7');
        expect(client['visitorData'], 'visitor-escape');
      },
    );

    test('trending usa browse con un browseId válido', () async {
      final _Harness harness = _Harness(
        responses: <String, Map<String, dynamic>>{'browse': _catalogPayload()},
      );

      final SourceResult result = await harness.source.trending();

      expect(result.items, hasLength(1));
      final RequestOptions request = harness.postFor('browse');
      expect(request.path, endsWith('/youtubei/v1/browse?prettyPrint=false'));
      expect(
        (request.data! as Map<String, dynamic>)['browseId'],
        'FEmusic_home',
      );
      expect(_clientOf(request)['clientName'], 'WEB_REMIX');
    });

    test(
      'searchCollections usa params tipado y parsea playlists públicas',
      () async {
        final _Harness harness = _Harness(
          responses: <String, Map<String, dynamic>>{
            'search': _collectionPayload(),
          },
        );

        final List<OnlineCollectionRef> items = await harness.source
            .searchCollections('demo', type: OnlineSearchType.playlists);

        expect(items, hasLength(1));
        final OnlineCollectionRef item = items.single;
        expect(item.id, 'VL123456');
        expect(item.externalId, 'youtube:VL123456');
        expect(item.title, 'Playlist demo');
        expect(item.subtitle, 'Artista demo');
        expect(item.kind, OnlineSearchType.playlists);
        expect(item.source, MusicSourceId.youtube);
        expect(harness.source.canDownload, isTrue);

        final RequestOptions request = harness.postFor('search');
        expect(
          (request.data! as Map<String, dynamic>)['params'],
          contains('Eg-KAQwI'),
        );
      },
    );

    test('resolveStream usa IOS y devuelve audio con cabeceras', () async {
      final _Harness harness = _Harness(
        responses: <String, Map<String, dynamic>>{'player': _playerPayload()},
      );
      const OnlineTrack track = OnlineTrack(
        externalId: 'youtube:abc12345678',
        sourceId: 'abc12345678',
        title: 'Canción demo',
        artist: 'Artista demo',
        durationMs: 207000,
      );

      final ResolvedStream stream = await harness.source.resolveStream(track);

      expect(stream.url, 'https://googlevideo.example/audio.m4a?expire=1');
      expect(stream.extension, 'm4a');
      expect(stream.mimeType, contains('audio/mp4'));
      expect(stream.httpHeaders['Referer'], 'https://music.youtube.com/');

      final RequestOptions request = harness.postFor('player');
      expect(request.uri.host, 'www.youtube.com');
      expect(request.path, endsWith('/youtubei/v1/player?prettyPrint=false'));
      expect(_clientOf(request)['clientName'], 'IOS');
      expect(request.headers['X-YouTube-Client-Name'], '5');
    });

    test('resolveStream descarta firmas sin descifrar y guarda alternativas por cliente', () async {
      final _ClientAwareAdapter adapter = _ClientAwareAdapter(
        <String, Map<String, dynamic>>{
          'IOS': <String, dynamic>{
            'playabilityStatus': <String, dynamic>{'status': 'OK'},
            'streamingData': <String, dynamic>{
              'adaptiveFormats': <Object?>[
                <String, dynamic>{
                  'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
                  'url': 'https://googlevideo.example/ios.m4a?c=IOS',
                  'httpHeaders': <String, dynamic>{
                    // Un User-Agent ajeno no debe filtrarse a mpv.
                    'User-Agent': 'ios-agent-falso',
                    'Referer': 'https://music.youtube.com/',
                  },
                },
                <String, dynamic>{
                  'mimeType': 'audio/mp4',
                  'signatureCipher': 's=sin_descifrar&url=xxx',
                },
              ],
            },
          },
          'ANDROID_MUSIC': <String, dynamic>{
            'playabilityStatus': <String, dynamic>{'status': 'OK'},
            'streamingData': <String, dynamic>{
              'adaptiveFormats': <Object?>[
                <String, dynamic>{
                  'mimeType': 'audio/mp4',
                  'url': 'https://googlevideo.example/android.m4a?c=ANDROID',
                },
              ],
            },
          },
        },
      );
      final Dio dio = Dio()..httpClientAdapter = adapter;
      final YouTubeMusicSource source = YouTubeMusicSource(
        dio: dio,
        artworkCache: ArtworkCache(dio: dio),
      );
      const OnlineTrack track = OnlineTrack(
        externalId: 'youtube:abc12345678',
        sourceId: 'abc12345678',
        title: 'Canción demo',
        artist: 'Artista demo',
        durationMs: 207000,
      );

      final ResolvedStream stream = await source.resolveStream(track);

      expect(stream.url, endsWith('ios.m4a?c=IOS'));
      expect(stream.clientLabel, 'IOS');
      expect(
        stream.httpHeaders['User-Agent'],
        startsWith('com.google.ios.youtube/'),
      );
      expect(stream.httpHeaders['User-Agent'], isNot('ios-agent-falso'));
      expect(stream.httpHeaders['X-YouTube-Client-Name'], '5');
      expect(stream.httpHeaders['X-YouTube-Client-Version'], isNotEmpty);
      expect(stream.alternatives, hasLength(1));
      expect(stream.alternatives.single.url, endsWith('android.m4a?c=ANDROID'));
      expect(
        stream.alternatives.single.httpHeaders['User-Agent'],
        contains('com.google.android.apps.youtube.music/'),
      );
      // Solo IOS y ANDROID_MUSIC: WEB_REMIX no se consulta si ya hay respaldo.
      final List<RequestOptions> posts = adapter.requests
          .where((RequestOptions r) => r.method == 'POST')
          .toList();
      expect(posts, hasLength(2));
      expect(_clientOf(posts[0])['clientName'], 'IOS');
      expect(_clientOf(posts[1])['clientName'], 'ANDROID_MUSIC');
    });

    test('sin URL directa en IOS/Android se prueba ANDROID_VR', () async {
      final _ClientAwareAdapter adapter = _ClientAwareAdapter(
        <String, Map<String, dynamic>>{
          'IOS': _signedOnlyPayload(),
          'ANDROID_MUSIC': _signedOnlyPayload(),
          'ANDROID_VR': _directPayload(
            'https://googlevideo.example/vr.m4a?c=VR',
          ),
        },
      );
      final Dio dio = Dio()..httpClientAdapter = adapter;
      final YouTubeMusicSource source = YouTubeMusicSource(
        dio: dio,
        artworkCache: ArtworkCache(dio: dio),
      );

      final ResolvedStream stream = await source.resolveStream(_demoTrack);

      expect(stream.clientLabel, 'ANDROID_VR');
      expect(stream.url, endsWith('vr.m4a?c=VR'));
      expect(
        stream.httpHeaders['User-Agent'],
        contains('youtube.vr.oculus/1.60.19'),
      );
      expect(stream.httpHeaders['X-YouTube-Client-Name'], '28');
      expect(stream.alternatives, isEmpty);

      final List<RequestOptions> posts = adapter.requests
          .where((RequestOptions r) => r.method == 'POST')
          .toList();
      expect(
        posts.map((RequestOptions r) => _clientOf(r)['clientName']),
        <Object?>['IOS', 'ANDROID_MUSIC', 'ANDROID_VR'],
      );
      final List<RequestOptions> probes = adapter.requests
          .where(
            (RequestOptions r) =>
                r.method == 'GET' && r.headers['Range'] == 'bytes=0-0',
          )
          .toList();
      expect(probes, hasLength(1));
    });

    test(
      'el reproductor incrustado es el último respaldo con URL directa',
      () async {
        final _ClientAwareAdapter adapter = _ClientAwareAdapter(
          <String, Map<String, dynamic>>{
            'IOS': _cipherOnlyPayload(),
            'ANDROID_MUSIC': _signedOnlyPayload(),
            'ANDROID_VR': _cipherOnlyPayload(),
            'TVHTML5_SIMPLY_EMBEDDED_PLAYER': _directPayload(
              'https://googlevideo.example/embed.webm?c=TV',
              mime: 'audio/webm; codecs="opus"',
            ),
          },
        );
        final Dio dio = Dio()..httpClientAdapter = adapter;
        final YouTubeMusicSource source = YouTubeMusicSource(
          dio: dio,
          artworkCache: ArtworkCache(dio: dio),
        );

        final ResolvedStream stream = await source.resolveStream(_demoTrack);

        expect(stream.clientLabel, 'TVHTML5_SIMPLY_EMBEDDED_PLAYER');
        expect(stream.extension, 'webm');
        expect(stream.httpHeaders['X-YouTube-Client-Name'], '85');
        expect(stream.httpHeaders['User-Agent'], startsWith('Mozilla/'));

        final List<RequestOptions> posts = adapter.requests
            .where((RequestOptions r) => r.method == 'POST')
            .toList();
        expect(_clientOf(posts.last)['clientScreen'], 'EMBED');
        expect(
          (posts.last.data! as Map<String, dynamic>)['thirdParty'],
          <String, dynamic>{'embedUrl': 'https://www.youtube.com/'},
        );
        expect(
          posts.map((RequestOptions r) => _clientOf(r)['clientName']),
          isNot(contains('WEB_REMIX')),
        );
      },
    );

    test(
      'una URL que no responde se descarta en favor de su alternativa',
      () async {
        final _ClientAwareAdapter adapter = _ClientAwareAdapter(
          <String, Map<String, dynamic>>{
            'IOS': _directPayload('https://googlevideo.example/ios.m4a?c=IOS'),
            'ANDROID_MUSIC': _directPayload(
              'https://googlevideo.example/android.m4a?c=ANDROID',
            ),
          },
          probeStatuses: <String, int>{'ios.m4a': 403},
        );
        final Dio dio = Dio()..httpClientAdapter = adapter;
        final YouTubeMusicSource source = YouTubeMusicSource(
          dio: dio,
          artworkCache: ArtworkCache(dio: dio),
        );

        final ResolvedStream stream = await source.resolveStream(_demoTrack);

        expect(stream.url, endsWith('android.m4a?c=ANDROID'));
        expect(stream.clientLabel, 'ANDROID_MUSIC');
      },
    );

    test(
      'los clientes probados quedan registrados en el diagnóstico',
      () async {
        final List<String> reports = <String>[];
        OnlineDiagnostics.setReporter(
          (String tag, String message, {Object? error, StackTrace? stack}) =>
              reports.add(message),
        );
        addTearDown(() => OnlineDiagnostics.setReporter(null));

        final _ClientAwareAdapter adapter = _ClientAwareAdapter(
          <String, Map<String, dynamic>>{
            'IOS': _signedOnlyPayload(),
            'ANDROID_MUSIC': _signedOnlyPayload(),
            'ANDROID_VR': _directPayload(
              'https://googlevideo.example/vr.m4a?c=VR',
            ),
          },
        );
        final Dio dio = Dio()..httpClientAdapter = adapter;
        final YouTubeMusicSource source = YouTubeMusicSource(
          dio: dio,
          artworkCache: ArtworkCache(dio: dio),
        );

        await source.resolveStream(_demoTrack);

        expect(
          reports.any((String message) => message.contains('ANDROID_VR')),
          isTrue,
        );
        expect(
          reports.any((String message) => message.contains('IOS')),
          isTrue,
        );
      },
    );

    test(
      'los errores de apertura se muestran sin la URL de googlevideo',
      () async {
        const String raw =
            'Failed to open https://googlevideo.com/videoplayback?'
            'id=abc&pot=secret&c=IOS';

        final String retry = AudioEngineService.sanitizePlaybackError(
          raw,
          sourceLabel: 'YouTube Music',
        );
        final String exhausted = AudioEngineService.sanitizePlaybackError(
          raw,
          sourceLabel: 'YouTube Music',
          exhausted: true,
        );

        expect(retry, contains('No se pudo abrir el audio de YouTube Music'));
        expect(retry, contains('Reintentando'));
        expect(exhausted, contains('No hay más fuentes'));
        for (final String message in <String>[retry, exhausted]) {
          expect(message, isNot(contains('googlevideo')));
          expect(message, isNot(contains('videoplayback')));
          expect(message, isNot(contains('pot=secret')));
        }
      },
    );

    test('un 404 informa del código y del detalle técnico', () async {
      final _Harness harness = _Harness(
        responses: <String, Map<String, dynamic>>{
          'search': <String, dynamic>{
            'error': <String, dynamic>{
              'message': 'Requested entity was not found.',
            },
          },
        },
        statuses: <String, int>{'search': 404},
      );

      final SourceResult result = await harness.source.search('demo');

      expect(result.ok, isFalse);
      expect(result.status.issue, MusicSourceIssue.unavailable);
      expect(result.status.detail, contains('(404)'));
      expect(result.status.detail, contains('requested entity was not found'));
    });

    test('un 404 vuelve a leer la homepage una sola vez', () async {
      final _Harness harness = _Harness(
        responses: <String, Map<String, dynamic>>{
          'search': <String, dynamic>{
            'error': <String, dynamic>{
              'message': 'Requested entity was not found.',
            },
          },
        },
        statuses: <String, int>{'search': 404},
      );

      await harness.source.search('demo');

      final int homeReads = harness.adapter.requests
          .where(
            (RequestOptions request) =>
                request.method == 'GET' &&
                request.headers['Range'] != 'bytes=0-0',
          )
          .length;
      expect(homeReads, 2); // inicial + refresco tras el 404, sin duplicado.
    });

    test('el mapper conserva el motivo de errores de parseo', () {
      final MusicSourceStatus status = MusicSourceErrorMapper.map(
        const FormatException('unexpected token'),
        MusicSourceId.youtube,
      );

      expect(status.issue, MusicSourceIssue.unavailable);
      expect(status.detail, contains('FormatException'));
      expect(status.detail, contains('unexpected token'));
    });

    test('el mapper oculta URLs firmadas en el detalle técnico', () {
      final RequestOptions request = RequestOptions(path: '/x');
      final MusicSourceStatus status = MusicSourceErrorMapper.map(
        DioException(
          requestOptions: request,
          response: Response<dynamic>(
            statusCode: 404,
            data: <String, dynamic>{
              'message':
                  'No encontrado: https://rr3.googlevideo.com/'
                  'videoplayback?id=abc&pot=secret&sig=firma'
                  '&expire=1700000000',
            },
            requestOptions: request,
          ),
        ),
        MusicSourceId.youtube,
      );

      expect(status.issue, MusicSourceIssue.unavailable);
      expect(status.detail, contains('(404)'));
      expect(status.detail, contains('no encontrado'));
      expect(status.detail, isNot(contains('googlevideo.com')));
      expect(status.detail, isNot(contains('videoplayback')));
      expect(status.detail, isNot(contains('pot=secret')));
      expect(status.detail, isNot(contains('sig=firma')));
      expect(status.detail, isNot(contains('expire=1700000000')));
    });
  });
}
