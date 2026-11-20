import 'package:dio/dio.dart';

import '../../../core/models/track.dart' show StreamAlternative;
import '../../../core/utils/logger.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Un formato de audio ya filtrado: URL directa + cabeceras de su cliente.
class _AudioCandidate {
  const _AudioCandidate({
    required this.url,
    required this.mime,
    required this.headers,
    required this.client,
    required this.label,
  });

  final String url;
  final String mime;
  final Map<String, String> headers;
  final String client;
  final String label;

  bool get isMp4 => mime.contains('audio/mp4');
}

/// Cliente InnerTube anónimo de YouTube Music (sin cuenta de Google).
///
/// `search` y `browse` usan el cliente web de música; `player` usa el cliente
/// iOS, que entrega URLs de audio directas sin iniciar sesión. Nunca se envían
/// credenciales: solo el `context` público (`clientName`, `clientVersion`,
/// `hl`, `gl` y `visitorData`) y las cabeceras que acompañan a ese cliente.
class YouTubeMusicSource implements MusicSourceProvider {
  YouTubeMusicSource({Dio? dio, ArtworkCache? artworkCache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'Accept-Language': 'es-ES,es;q=0.9',
              },
            ),
          ),
      _artworkCache = artworkCache ?? ArtworkCache();

  static const String _tag = 'YouTubeMusic';
  static const String _musicHost = 'music.youtube.com';
  static const String _wwwHost = 'www.youtube.com';

  static const String _web = 'WEB_REMIX';
  static const String _androidMusic = 'ANDROID_MUSIC';
  static const String _ios = 'IOS';

  /// El cliente web cambia de versión cada pocas semanas; una versión fija
  /// acaba devolviendo 404. Se intenta leer de la homepage y este valor es el
  /// último recurso conocido.
  static const String _fallbackWebVersion = '1.20261117.06.00';
  static const String _fallbackAndroidMusicVersion = '7.20250311.01.00';
  static const String _iosVersion = '20.10.4';

  /// YouTube solo sirve la página completa con un User-Agent de navegador; con
  /// el User-Agent de la app responde una página mínima sin los datos del
  /// cliente, que era la causa del 404.
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) '
      'Gecko/20100101 Firefox/120.0';
  static const String _iosUserAgent =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_1 '
      'like Mac OS X;)';

  /// `browseId` válido para el inicio de YouTube Music: devuelve estanterías
  /// con `musicResponsiveListItemRenderer` y `videoId` anidados.
  static const String _homeBrowseId = 'FEmusic_home';

  /// Filtros de búsqueda de InnerTube (valores base64 usados por el cliente web).
  /// Si YouTube los cambia, la búsqueda sigue funcionando sin `params`.
  static const Map<OnlineSearchType, String> _searchParams =
      <OnlineSearchType, String>{
        OnlineSearchType.songs: 'EgWKAQIIAWoMEA4QChADEAQQCRAF',
        OnlineSearchType.albums: 'EgWKAQIYAWoMEA4QChADEAQQCRAF',
        OnlineSearchType.artists: 'EgWKAQIgAWoMEA4QChADEAQQCRAF',
        OnlineSearchType.playlists:
            'Eg-KAQwIABAAGAAgACgBMABqChAEEAMQCRAFEAo=',
      };

  final Dio _dio;
  final ArtworkCache _artworkCache;
  final Map<String, String> _versions = <String, String>{
    _web: _fallbackWebVersion,
    _androidMusic: _fallbackAndroidMusicVersion,
    _ios: _iosVersion,
  };

  String? _visitorData;
  bool _contextLoaded = false;
  Future<void>? _contextFuture;

  MusicSourceStatus _status = const MusicSourceStatus();

  @override
  MusicSourceId get id => MusicSourceId.youtube;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  /// El endpoint `player` entrega audio sin cuenta de Google.
  @override
  bool get canStream => true;

  /// `resolveStream` entrega una URL directa con cabeceras, así que también se
  /// puede guardar en la biblioteca con la misma calidad que el streaming.
  @override
  bool get canDownload => true;

  @override
  MusicSourceStatus get status => _status;

  /// Carga (una sola vez) la versión real del cliente y el `visitorData`.
  Future<void> _ensureContext() {
    final Future<void>? pending = _contextFuture;
    if (pending != null) return pending;
    if (_contextLoaded) return Future<void>.value();
    final Future<void> future = _discoverContext();
    _contextFuture = future;
    return future.whenComplete(() {
      _contextFuture = null;
      _contextLoaded = true;
    });
  }

  Future<void> _discoverContext() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        'https://$_musicHost/',
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, String>{
            'User-Agent': _browserUserAgent,
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'es-ES,es;q=0.9',
            'Accept-Encoding': 'identity',
          },
        ),
      );
      final String html = '${response.data ?? ''}';
      final String? version =
          _match(html, r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"') ??
          _match(html, r'\\"INNERTUBE_CLIENT_VERSION\\":\\"([^"\\]+)\\"');
      if (version != null && version.isNotEmpty) {
        _versions[_web] = version;
      }
      final String? visitor =
          _match(html, r'"VISITOR_DATA":"([^"]+)"') ??
          _match(html, r'\\"VISITOR_DATA\\":\\"([^"\\]+)\\"');
      if (visitor != null && visitor.isNotEmpty) _visitorData = visitor;
    } on Object {
      // Sin homepage no hay versión fresca: se conserva el último valor known
      // y el reintento ante un 404 fuerza una nueva lectura.
      AppLog.w(_tag, 'No se pudo actualizar el contexto de InnerTube');
    }
  }

  String? _match(String source, String pattern) =>
      RegExp(pattern).firstMatch(source)?.group(1);

  Map<String, dynamic> _contextFor(String client) {
    final Map<String, dynamic> data = <String, dynamic>{
      'clientName': client,
      'clientVersion': _versions[client] ?? _fallbackWebVersion,
      'hl': 'es',
      'gl': 'ES',
    };
    final String? visitor = _visitorData;
    if (visitor != null && visitor.isNotEmpty) {
      data['visitorData'] = visitor;
    }
    switch (client) {
      case _ios:
        data
          ..['deviceMake'] = 'Apple'
          ..['deviceModel'] = 'iPhone16,2'
          ..['osName'] = 'iPhone'
          ..['osVersion'] = '18.3.1.22D72';
      case _androidMusic:
        data
          ..['androidSdkVersion'] = 35
          ..['osName'] = 'Android'
          ..['osVersion'] = '15'
          ..['deviceModel'] = 'Pixel 9';
    }
    return <String, dynamic>{'client': data};
  }

  Map<String, String> _headersFor(String client) {
    final String version = _versions[client] ?? _fallbackWebVersion;
    final int clientId = switch (client) {
      _web => 67,
      _ios => 5,
      _androidMusic => 21,
      _ => 67,
    };
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client == _ios ? _iosUserAgent : _browserUserAgent,
      'X-YouTube-Client-Name': '$clientId',
      'X-YouTube-Client-Version': version,
      'Origin': 'https://$_musicHost',
      'Referer': 'https://$_musicHost/',
    };
    final String? visitor = _visitorData;
    if (visitor != null && visitor.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitor;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _send(
    String host,
    String path,
    Map<String, dynamic> payload,
    String client,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      'https://$host/youtubei/v1/$path?prettyPrint=false',
      data: payload,
      options: Options(
        responseType: ResponseType.json,
        headers: _headersFor(client),
      ),
    );
    final Map<String, dynamic> result =
        SourceJson.map(response.data) ?? <String, dynamic>{};
    // InnerTube devuelve un visitorData nuevo en cada respuesta útil.
    final String visitor = SourceJson.text(
      SourceJson.map(result['responseContext'])?['visitorData'],
    );
    if (visitor.isNotEmpty) _visitorData = visitor;
    return result;
  }

  /// Publica una petición InnerTube. Un 404 casi siempre significa que la
  /// versión del cliente quedó obsoleta: se fuerza una lectura de la homepage
  /// y se repite una sola vez antes de informar del error.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String client = _web,
    String host = _musicHost,
    bool retryOn404 = true,
  }) async {
    await _ensureContext();
    final Map<String, dynamic> payload = <String, dynamic>{
      ...body,
      'context': _contextFor(client),
      if (client == _web) 'contentCheckOk': true,
    };
    try {
      return await _send(host, path, payload, client);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404 || !retryOn404) rethrow;
      _contextLoaded = false;
      await _discoverContext();
      return _post(path, body, client: client, host: host, retryOn404: false);
    }
  }

  /// Intenta con el cliente web y, si el proveedor lo rechaza, con el cliente
  /// Android Music. Ninguno de los dos requiere inicio de sesión.
  Future<Map<String, dynamic>> _postCatalog(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _post(path, body, client: _web, host: _musicHost);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      return _post(
        path,
        body,
        client: _androidMusic,
        host: _wwwHost,
        retryOn404: false,
      );
    }
  }

  @override
  Future<MusicSourceStatus> checkAvailability() async {
    try {
      await _postCatalog('search', <String, dynamic>{
        'query': 'music',
        'searchContext': const <String, dynamic>{
          'clientSearchContext': <String, dynamic>{},
        },
      });
      _status = MusicSourceStatus(available: true, checkedAt: DateTime.now());
    } catch (error) {
      _status = MusicSourceErrorMapper.map(error, id);
    }
    return _status;
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) {
      return const SourceResult(source: MusicSourceId.youtube);
    }
    try {
      final Map<String, dynamic> payload = await _postCatalog(
        'search',
        <String, dynamic>{
          'query': query.trim(),
          'searchContext': const <String, dynamic>{
            'clientSearchContext': <String, dynamic>{},
          },
        },
      );
      return SourceResult(source: id, items: _parse(_shelves(payload), limit));
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) async {
    try {
      final Map<String, dynamic> payload = await _postCatalog(
        'browse',
        <String, dynamic>{'browseId': _homeBrowseId},
      );
      return SourceResult(source: id, items: _parse(_shelves(payload), limit));
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  /// Búsqueda tipada: el filtro se envía como `params` de InnerTube. Las fuentes
  /// que no reconocen el parámetro siguen devolviendo resultados mixtos, por lo
  /// que además se filtran por el prefijo del `browseId`.
  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty || type == OnlineSearchType.songs) {
      return const <OnlineCollectionRef>[];
    }
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'query': query.trim(),
        'searchContext': const <String, dynamic>{
          'clientSearchContext': <String, dynamic>{},
        },
      };
      final String? params = _searchParams[type];
      if (params != null) body['params'] = params;
      final Map<String, dynamic> payload = await _postCatalog('search', body);
      return _parseCollections(_shelves(payload), type, limit);
    } on Object {
      return const <OnlineCollectionRef>[];
    }
  }

  /// Abre un álbum (`MPRE...`), artista (`UC...`) o playlist (`VL...`) público
  /// usando el mismo `browse` que la homepage.
  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async {
    if (collection.id.isEmpty) return const <OnlineTrack>[];
    try {
      final Map<String, dynamic> payload = await _postCatalog(
        'browse',
        <String, dynamic>{'browseId': collection.id},
      );
      return _parse(_shelves(payload), limit);
    } on Object {
      return const <OnlineTrack>[];
    }
  }

  List<OnlineCollectionRef> _parseCollections(
    List<Object?> renderers,
    OnlineSearchType type,
    int limit,
  ) {
    final List<OnlineCollectionRef> result = <OnlineCollectionRef>[];
    final Set<String> seen = <String>{};
    for (final Object? entry in renderers) {
      if (result.length >= limit) break;
      final Map<String, dynamic>? renderer = SourceJson.map(entry);
      if (renderer == null) continue;
      final String browseId = _browseId(renderer, 0, type);
      if (browseId.isEmpty || !seen.add(browseId)) continue;
      final OnlineSearchType? kind = _collectionKind(browseId);
      if (kind == null || kind != type) continue;
      final String title = _title(renderer);
      if (title.isEmpty) continue;
      result.add(
        OnlineCollectionRef(
          externalId: 'youtube:$browseId',
          id: browseId,
          title: title,
          subtitle: _subtitle(renderer),
          artworkUrl: _artwork(renderer),
          permalink:
              'https://music.youtube.com/browse?browseId='
              '${Uri.encodeComponent(browseId)}',
          source: id,
          kind: kind,
        ),
      );
    }
    return result;
  }

  /// Busca un `browseId` de colección dentro de un renderer de búsqueda.
  String _browseId(
    Object? node, [
    int depth = 0,
    OnlineSearchType? wanted,
  ]) {
    if (depth > 10) return '';
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) {
      if (node is List) {
        for (final Object? value in node) {
          final String found = _browseId(value, depth + 1, wanted);
          if (found.isNotEmpty) return found;
        }
      }
      return '';
    }
    final String value = SourceJson.text(map['browseId']);
    final OnlineSearchType? kind = _collectionKind(value);
    if (kind != null && (wanted == null || kind == wanted)) return value;
    for (final Object? child in map.values) {
      if (child is Map || child is List) {
        final String found = _browseId(child, depth + 1, wanted);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  OnlineSearchType? _collectionKind(String browseId) {
    if (browseId.startsWith('MPRE')) return OnlineSearchType.albums;
    if (browseId.startsWith('UC') || browseId.startsWith('MPLA')) {
      return OnlineSearchType.artists;
    }
    if (browseId.startsWith('VL') || browseId.startsWith('PL')) {
      return OnlineSearchType.playlists;
    }
    return null;
  }

  String _subtitle(Map<String, dynamic> renderer) {
    final String owner = _text(renderer['ownerText']) ?? '';
    if (owner.isNotEmpty) return owner;
    final List<Object?> columns = SourceJson.list(renderer['flexColumns']);
    if (columns.length < 2) return '';
    final Map<String, dynamic>? second = SourceJson.map(
      SourceJson.map(columns[1])?['musicResponsiveListItemFlexColumnRenderer'],
    );
    return _text(second?['text']) ?? '';
  }

  List<Object?> _shelves(Map<String, dynamic> payload) {
    final List<Object?> result = <Object?>[];
    void walk(Object? node, int depth) {
      if (depth > 14) return;
      if (node is List) {
        for (final Object? value in node) {
          walk(value, depth + 1);
        }
        return;
      }
      final Map<String, dynamic>? map = SourceJson.map(node);
      if (map == null) return;
      if (map.containsKey('videoRenderer')) result.add(map['videoRenderer']);
      if (map.containsKey('musicResponsiveListItemRenderer')) {
        result.add(map['musicResponsiveListItemRenderer']);
      }
      for (final Object? value in map.values) {
        if (value is Map || value is List) walk(value, depth + 1);
      }
    }

    walk(payload['contents'], 0);
    return result;
  }

  List<OnlineTrack> _parse(List<Object?> renderers, int limit) {
    final List<OnlineTrack> tracks = <OnlineTrack>[];
    final Set<String> seen = <String>{};
    for (final Object? entry in renderers) {
      if (tracks.length >= limit) break;
      final Map<String, dynamic>? renderer = SourceJson.map(entry);
      if (renderer == null) continue;

      final String id = _videoId(renderer);
      if (id.isEmpty || !seen.add(id)) continue;
      final String title = _title(renderer);
      if (title.isEmpty) continue;

      tracks.add(
        OnlineTrack(
          externalId: 'youtube:$id',
          sourceId: id,
          title: title,
          artist: _artist(renderer),
          album: '',
          durationMs: _duration(renderer),
          artworkUrl: _artwork(renderer),
          permalink: 'https://music.youtube.com/watch?v=$id',
          sourceLabel: 'YouTube Music',
        ),
      );
    }
    return tracks;
  }

  /// El `videoId` de `musicResponsiveListItemRenderer` vive dentro de
  /// `watchEndpoint`/`playlistItemData`, no en la raíz como en `videoRenderer`.
  String _videoId(Object? node, [int depth = 0]) {
    if (depth > 10) return '';
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) {
      if (node is List) {
        for (final Object? value in node) {
          final String found = _videoId(value, depth + 1);
          if (found.isNotEmpty) return found;
        }
      }
      return '';
    }
    for (final String key in <String>['videoId', 'contentId']) {
      final String value = SourceJson.text(map[key]);
      if (value.length == 11) return value;
    }
    for (final Object? value in map.values) {
      if (value is Map || value is List) {
        final String found = _videoId(value, depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  String _title(Map<String, dynamic> renderer) {
    final String direct = _text(renderer['title']) ?? '';
    if (direct.isNotEmpty) return direct;
    final List<Object?> columns = SourceJson.list(renderer['flexColumns']);
    if (columns.isEmpty) return '';
    final Map<String, dynamic>? first = SourceJson.map(
      SourceJson.map(
        columns.first,
      )?['musicResponsiveListItemFlexColumnRenderer'],
    );
    return _text(first?['text']) ?? '';
  }

  String _artist(Map<String, dynamic> renderer) {
    final String owner = _text(renderer['ownerText']) ?? '';
    if (owner.isNotEmpty) return owner;
    final List<Object?> columns = SourceJson.list(renderer['flexColumns']);
    if (columns.length < 2) return 'Desconocido';
    final Map<String, dynamic>? second = SourceJson.map(
      SourceJson.map(columns[1])?['musicResponsiveListItemFlexColumnRenderer'],
    );
    final Object? runs = SourceJson.map(second?['text'])?['runs'];
    if (runs is List) {
      for (final Object? run in runs) {
        final String text = SourceJson.text(SourceJson.map(run)?['text'])
            .trim();
        if (_isDecoration(text)) continue;
        return text;
      }
    }
    final String text = _text(second?['text']) ?? '';
    for (final String part in text.split(RegExp(r'[\u0007\u0000•·]'))) {
      final String value = part.trim();
      if (value.isEmpty || _isDecoration(value)) continue;
      return value;
    }
    // En resultados de búsqueda el artista no siempre está en las columnas;
    // la etiqueta accesible del botón de reproducir dice "Título - Artista".
    final String label = _labelWithArtist(renderer, 0);
    final int dash = label.indexOf(' - ');
    if (dash > 0) {
      final String artist = label.substring(dash + 3).trim();
      if (artist.isNotEmpty) return artist;
    }
    return 'Desconocido';
  }

  String _labelWithArtist(Object? node, int depth) {
    if (depth > 10) return '';
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) {
      if (node is List) {
        for (final Object? value in node) {
          final String found = _labelWithArtist(value, depth + 1);
          if (found.isNotEmpty) return found;
        }
      }
      return '';
    }
    final String label = SourceJson.text(map['label']);
    if (label.contains(' - ')) return label;
    for (final Object? value in map.values) {
      if (value is Map || value is List) {
        final String found = _labelWithArtist(value, depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  bool _isDecoration(String value) =>
      value == 'Canción' ||
      value == 'Álbum' ||
      value == 'Artista' ||
      value == 'Video' ||
      value == 'Sencillo' ||
      value == '•' ||
      value == '·' ||
      RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(value) ||
      RegExp(
        r'^\d+[\d.,]*\s*(reproducciones|views|visualizaciones)',
        caseSensitive: false,
      ).hasMatch(value);

  /// Une los `runs` con espacios para poder separar artista y duración.
  String? _text(Object? node) {
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) return null;
    final String value = SourceJson.text(map['simpleText']);
    if (value.isNotEmpty) return value;
    final Object? runs = map['runs'];
    if (runs is List) {
      final StringBuffer buffer = StringBuffer();
      for (final Object? run in runs) {
        final String text = SourceJson.text(SourceJson.map(run)?['text']);
        if (text.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(text);
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }
    return null;
  }

  String? _artwork(Map<String, dynamic> renderer) {
    final Map<String, dynamic>? thumbnail = SourceJson.map(
      renderer['thumbnail'],
    );
    Object? thumbnails = thumbnail?['thumbnails'];
    thumbnails ??= SourceJson.map(
      thumbnail?['musicThumbnailRenderer'],
    )?['thumbnails'];
    thumbnails ??= SourceJson.map(
      SourceJson.map(thumbnail?['musicThumbnailRenderer'])?['thumbnail'],
    )?['thumbnails'];
    final List<Object?> candidates = thumbnails is List
        ? thumbnails
        : SourceJson.list(thumbnails);
    for (final Object? entry in candidates) {
      final String? url = SourceJson.url(SourceJson.map(entry)?['url']);
      if (url != null) return url;
    }
    return null;
  }

  int _duration(Map<String, dynamic> renderer) {
    final String approximate = _firstText(renderer, 'approxDurationMs', 0);
    final int? milliseconds = int.tryParse(approximate);
    if (milliseconds != null) return milliseconds;
    // En `musicResponsiveListItemRenderer` la duración está en la segunda
    // columna (`Canción · 3:27`), no en el título.
    final List<Object?> columns = SourceJson.list(renderer['flexColumns']);
    String text = '';
    if (columns.length > 1) {
      final Map<String, dynamic>? second = SourceJson.map(
        SourceJson.map(
          columns[1],
        )?['musicResponsiveListItemFlexColumnRenderer'],
      );
      text = _text(second?['text']) ?? '';
    }
    final RegExpMatch? match = RegExp(r'\b(\d+):(\d+)(?::(\d+))?\b')
        .firstMatch(text);
    if (match == null) return 0;
    final bool hasHours = match.group(3) != null;
    final int hours = hasHours ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
    final int minutes = int.tryParse(match.group(hasHours ? 2 : 1) ?? '0') ?? 0;
    final int seconds = int.tryParse(match.group(hasHours ? 3 : 2) ?? '0') ?? 0;
    return ((hours * 3600) + (minutes * 60) + seconds) * 1000;
  }

  String _firstText(Object? node, String key, int depth) {
    if (depth > 10) return '';
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) {
      if (node is List) {
        for (final Object? value in node) {
          final String found = _firstText(value, key, depth + 1);
          if (found.isNotEmpty) return found;
        }
      }
      return '';
    }
    final String value = SourceJson.text(map[key]);
    if (value.isNotEmpty) return value;
    for (final Object? child in map.values) {
      if (child is Map || child is List) {
        final String found = _firstText(child, key, depth + 1);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  /// `User-Agent` exacto del cliente que pidió el stream.
  ///
  /// Es la pieza que faltaba: la URL lleva `c=IOS` en la query, pero mpv abría
  /// la petición con su propio User-Agent y Google respondía 403.
  String _userAgentFor(String client) => switch (client) {
    _ios =>
      'com.google.ios.youtube/${_versions[_ios] ?? _iosVersion} '
      '(iPhone16,2; U; CPU iOS 18_3_1 like Mac OS X;)',
    _androidMusic =>
      'com.google.android.apps.youtube.music/'
      '${_versions[_androidMusic] ?? _fallbackAndroidMusicVersion} '
      '(Linux; U; Android 15; Pixel 9; gzip)',
    _ => _browserUserAgent,
  };

  int _clientIdFor(String client) => switch (client) {
    _ios => 5,
    _androidMusic => 21,
    _ => 67,
  };

  /// Cabeceras que viajarán dentro de `Media(url, httpHeaders: ...)`.
  ///
  /// Se parten de las que devuelve InnerTube, se descarta cualquier
  /// `User-Agent` ajeno al cliente y se añaden las marcas del cliente. Nunca se
  /// envía `Content-Type`: es una petición GET de audio, no JSON.
  Map<String, String> _mediaHeaders(
    String client,
    Map<String, dynamic> format,
  ) {
    final Map<String, String> headers = <String, String>{
      'Accept': '*/*',
      'Referer': client == _web
          ? 'https://$_musicHost/'
          : 'https://$_wwwHost/',
      'User-Agent': _userAgentFor(client),
      'X-YouTube-Client-Name': '${_clientIdFor(client)}',
      'X-YouTube-Client-Version':
          _versions[client] ??
          (client == _ios
              ? _iosVersion
              : client == _androidMusic
              ? _fallbackAndroidMusicVersion
              : _fallbackWebVersion),
    };
    final Map<String, dynamic>? raw = SourceJson.map(format['httpHeaders']);
    if (raw != null) {
      for (final MapEntry<Object?, Object?> entry in raw.entries) {
        final String key = '${entry.key}';
        final String value = SourceJson.text(entry.value);
        if (key.toLowerCase() == 'user-agent') continue;
        if (value.isEmpty) continue;
        headers[key] = value;
      }
    }
    return Map<String, String>.unmodifiable(headers);
  }

  /// InnerTube marca los formatos protegidos con `signatureCipher` (o con un
  /// parámetro `s` en la URL). sin descifrar esa firma mpv solo obtiene 403.
  static bool _needsCipher(Map<String, dynamic> format, String url) {
    if (SourceJson.text(format['signatureCipher']).isNotEmpty) return true;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.queryParameters.containsKey('s') ||
        uri.queryParameters.containsKey('sig') ||
        uri.queryParameters.containsKey('lsig');
  }

  Future<List<_AudioCandidate>> _collectAudioCandidates(
    String client,
    String host,
    String videoId,
  ) async {
    try {
      final Map<String, dynamic> payload = await _post(
        'player',
        <String, dynamic>{
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        client: client,
        host: host,
      );
      final String state = SourceJson.text(
        SourceJson.map(payload['playabilityStatus'])?['status'],
      );
      if (state.isNotEmpty && state != 'OK') return const <_AudioCandidate>[];

      final Map<String, dynamic>? streaming = SourceJson.map(
        payload['streamingData'],
      );
      final List<Object?> formats = <Object?>[
        ...SourceJson.list(streaming?['formats']),
        ...SourceJson.list(streaming?['adaptiveFormats']),
      ];
      final List<_AudioCandidate> found = <_AudioCandidate>[];
      final Set<String> seen = <String>{};
      for (final Object? entry in formats) {
        final Map<String, dynamic>? format = SourceJson.map(entry);
        if (format == null) continue;
        final String mime = SourceJson.text(format['mimeType']);
        final String? url = SourceJson.url(format['url']);
        if (url == null || !mime.startsWith('audio/')) continue;
        if (_needsCipher(format, url) || !seen.add(url)) continue;
        found.add(
          _AudioCandidate(
            url: url,
            mime: mime,
            headers: _mediaHeaders(client, format),
            client: client,
            label: '${id.label} · $client',
          ),
        );
      }
      // m4a/AAC primero: es el formato que mejor soporta libmpv en Windows.
      found.sort((_AudioCandidate a, _AudioCandidate b) =>
          (b.isMp4 ? 1 : 0) - (a.isMp4 ? 1 : 0));
      return found;
    } on Object {
      // Un cliente caído no impide probar los demás.
      return const <_AudioCandidate>[];
    }
  }

  /// Resuelve el audio probando IOS → ANDROID_MUSIC → WEB_REMIX.
  ///
  /// Todas las URLs devueltas son directas y llevan las cabeceras de su propio
  /// cliente. La primera es la principal; el resto viajan como alternativas
  /// para que el motor (y la descarga) puedan reintentar sin consultar de nuevo.
  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    if (track.sourceId.isEmpty) {
      throw const MusicSourceException(
        'YouTube Music no devolvió un identificador de vídeo válido.',
        source: MusicSourceId.youtube,
        issue: MusicSourceIssue.unavailable,
      );
    }

    final List<_AudioCandidate> candidates = <_AudioCandidate>[
      ...await _collectAudioCandidates(_ios, _wwwHost, track.sourceId),
      ...await _collectAudioCandidates(_androidMusic, _wwwHost, track.sourceId),
    ];
    // WEB_REMIX suele devolver firmas cifradas; solo merece la pena si aún no
    // tenemos una alternativa distinta del cliente iOS.
    if (candidates.length < 2) {
      candidates.addAll(
        await _collectAudioCandidates(_web, _musicHost, track.sourceId),
      );
    }

    if (candidates.isEmpty) {
      throw const MusicSourceException(
        'YouTube Music no entregó una URL de audio directa compatible '
        '(los formatos disponibles requieren firma).',
        source: MusicSourceId.youtube,
        issue: MusicSourceIssue.unavailable,
      );
    }

    final _AudioCandidate primary = candidates.first;
    return ResolvedStream(
      url: primary.url,
      extension: primary.mime.contains('webm') ? 'webm' : 'm4a',
      mimeType: primary.mime,
      httpHeaders: primary.headers,
      clientLabel: primary.client,
      alternatives: <StreamAlternative>[
        for (final _AudioCandidate candidate in candidates.skip(1))
          StreamAlternative(
            url: candidate.url,
            httpHeaders: candidate.headers,
            label: candidate.label,
          ),
      ],
    );
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);
}
