import 'package:dio/dio.dart';

import '../../../core/models/track.dart' show StreamAlternative;
import '../../../core/utils/logger.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import 'dio_request_cancellation.dart';
import 'online_diagnostics.dart';
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

/// Cliente anónimo del endpoint `player` y host al que se le pregunta.
class _PlayerClient {
  const _PlayerClient(this.client, this.host);

  final String client;
  final String host;
}

/// Cliente InnerTube anónimo de YouTube Music (sin cuenta de Google).
///
/// `search` y `browse` usan el cliente web de música. `player` prueba una cadena
/// de clientes (IOS → ANDROID_MUSIC → ANDROID_VR → TVHTML5_SIMPLY_EMBEDDED_
/// PLAYER → WEB_REMIX) hasta encontrar URLs de audio directas sin firma: si un
/// cliente solo devuelve `signatureCipher`/`cipher` se pasa al siguiente sin
/// descifrar nada. Nunca se envían credenciales: solo el `context` público y
/// las cabeceras propias de cada cliente.
class YouTubeMusicSource
    implements MusicSourceProvider, CancellableMusicSourceProvider {
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
  static const String _androidVr = 'ANDROID_VR';
  static const String _tvEmbedded = 'TVHTML5_SIMPLY_EMBEDDED_PLAYER';

  /// El cliente web cambia de versión cada pocas semanas; una versión fija
  /// acaba devolviendo 404. Se intenta leer de la homepage y este valor es el
  /// último recurso conocido.
  static const String _fallbackWebVersion = '1.20261117.06.00';
  static const String _fallbackAndroidMusicVersion = '7.20250311.01.00';
  static const String _iosVersion = '20.10.4';
  static const String _androidVrVersion = '1.60.19';
  static const String _tvEmbeddedVersion = '2.0';

  /// Sonda de rango acotada: una URL caducada se descarta antes de llegar a
  /// `media_kit` o al descargador, sin dejar la cola esperando indefinidamente.
  static const Duration _probeTimeout = Duration(seconds: 5);
  static const Duration _probeCacheTtl = Duration(minutes: 2);

  /// YouTube solo sirve la página completa con un User-Agent de navegador; con
  /// el User-Agent de la app responde una página mínima sin los datos del
  /// cliente, que era la causa del 404.
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) '
      'Gecko/20100101 Firefox/120.0';
  static const String _iosUserAgent =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_1 '
      'like Mac OS X;)';
  static const String _androidVrUserAgent =
      'com.google.android.apps.youtube.vr.oculus/1.60.19 '
      '(Linux; U; Android 12L; en_US; Quest 3; Build/SQ3A.220705.003; gzip)';

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
        OnlineSearchType.playlists: 'Eg-KAQwIABAAGAAgACgBMABqChAEEAMQCRAFEAo=',
      };

  final Dio _dio;
  final ArtworkCache _artworkCache;
  final Map<String, String> _versions = <String, String>{
    _web: _fallbackWebVersion,
    _androidMusic: _fallbackAndroidMusicVersion,
    _ios: _iosVersion,
    _androidVr: _androidVrVersion,
    _tvEmbedded: _tvEmbeddedVersion,
  };

  /// URLs ya sondadas recientemente. Reproductor y descargas comparten la
  /// misma instancia del proveedor, así que no repiten la sonda por cada uso.
  final Map<String, DateTime> _probedUrls = <String, DateTime>{};

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
    } on Object catch (error, stack) {
      // Sin homepage no hay versión fresca: se conserva el último valor known
      // y el reintento ante un 404 fuerza una nueva lectura.
      OnlineDiagnostics.report(
        _tag,
        'No se pudo actualizar el contexto de InnerTube',
        error: error,
        stack: stack,
      );
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
      case _androidVr:
        data
          ..['androidSdkVersion'] = 32
          ..['osName'] = 'Android'
          ..['osVersion'] = '12L'
          ..['deviceMake'] = 'Oculus'
          ..['deviceModel'] = 'Quest 3';
      case _tvEmbedded:
        data['clientScreen'] = 'EMBED';
    }
    return <String, dynamic>{'client': data};
  }

  Map<String, String> _headersFor(String client) {
    final String version = _versions[client] ?? _fallbackWebVersion;
    final int clientId = switch (client) {
      _web => 67,
      _ios => 5,
      _androidMusic => 21,
      _androidVr => 28,
      _tvEmbedded => 85,
      _ => 67,
    };
    final String host = client == _web ? _musicHost : _wwwHost;
    final String userAgent = switch (client) {
      _ios => _iosUserAgent,
      _androidVr => _androidVrUserAgent,
      _ => _browserUserAgent,
    };
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
      'X-YouTube-Client-Name': '$clientId',
      'X-YouTube-Client-Version': version,
      'Origin': 'https://$host',
      'Referer': 'https://$host/',
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
    String client, [
    CancelToken? cancel,
  ]) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      'https://$host/youtubei/v1/$path?prettyPrint=false',
      data: payload,
      cancelToken: cancel,
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
    CancelToken? cancel,
  }) async {
    if (cancel?.isCancelled ?? false) throw const RequestCanceledException();
    await _ensureContext();
    if (cancel?.isCancelled ?? false) throw const RequestCanceledException();
    final Map<String, dynamic> payload = <String, dynamic>{
      ...body,
      'context': _contextFor(client),
      if (client == _web) 'contentCheckOk': true,
    };
    try {
      final Map<String, dynamic> result = await _send(
        host,
        path,
        payload,
        client,
        cancel,
      );
      if (cancel?.isCancelled ?? false) throw const RequestCanceledException();
      return result;
    } on RequestCanceledException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) ||
          error.type == DioExceptionType.cancel) {
        throw const RequestCanceledException();
      }
      if (error.response?.statusCode != 404 || !retryOn404) rethrow;
      _contextLoaded = false;
      await _discoverContext();
      return _post(
        path,
        body,
        client: client,
        host: host,
        retryOn404: false,
        cancel: cancel,
      );
    }
  }

  /// Intenta con el cliente web y, si el proveedor lo rechaza, con el cliente
  /// Android Music. Ninguno de los dos requiere inicio de sesión.
  Future<Map<String, dynamic>> _postCatalog(
    String path,
    Map<String, dynamic> body, [
    CancelToken? cancel,
  ]) async {
    try {
      return await _post(
        path,
        body,
        client: _web,
        host: _musicHost,
        cancel: cancel,
      );
    } on RequestCanceledException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) ||
          error.type == DioExceptionType.cancel) {
        throw const RequestCanceledException();
      }
      if (error.response?.statusCode != 404) rethrow;
      return _post(
        path,
        body,
        client: _androidMusic,
        host: _wwwHost,
        retryOn404: false,
        cancel: cancel,
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
    } on Object catch (error, stack) {
      if (error is! RequestCanceledException) {
        OnlineDiagnostics.report(
          _tag,
          'Fallo al comprobar la disponibilidad de YouTube Music',
          error: error,
          stack: stack,
        );
      }
      _status = MusicSourceErrorMapper.map(error, id);
    }
    return _status;
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) =>
      _search(query, limit: limit);

  @override
  Future<SourceResult> searchCancellable(
    String query, {
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _search(query, limit: limit, token: token);
  }

  Future<SourceResult> _search(
    String query, {
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
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
        dioCancelTokenOf(token),
      );
      return SourceResult(source: id, items: _parse(_shelves(payload), limit));
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'Fallo al buscar en YouTube Music',
        error: error,
        stack: stack,
      );
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) => _trending(limit: limit);

  @override
  Future<SourceResult> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _trending(limit: limit, token: token);
  }

  Future<SourceResult> _trending({
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
    try {
      final Map<String, dynamic> payload = await _postCatalog(
        'browse',
        <String, dynamic>{'browseId': _homeBrowseId},
        dioCancelTokenOf(token),
      );
      return SourceResult(source: id, items: _parse(_shelves(payload), limit));
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'Fallo al cargar tendencias de YouTube Music',
        error: error,
        stack: stack,
      );
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
  }) => _searchCollections(query, type: type, limit: limit);

  @override
  Future<List<OnlineCollectionRef>> searchCollectionsCancellable(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _searchCollections(query, type: type, limit: limit, token: token);
  }

  Future<List<OnlineCollectionRef>> _searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
    // En la vista `all` es el catálogo quien pide cada tipo por separado.
    if (query.trim().isEmpty ||
        type == OnlineSearchType.songs ||
        type == OnlineSearchType.all) {
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
      final Map<String, dynamic> payload = await _postCatalog(
        'search',
        body,
        dioCancelTokenOf(token),
      );
      return _parseCollections(_shelves(payload), type, limit);
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'Fallo al buscar colecciones en YouTube Music',
        error: error,
        stack: stack,
      );
      return const <OnlineCollectionRef>[];
    }
  }

  /// Abre un álbum (`MPRE...`), artista (`UC...`) o playlist (`VL...`) público
  /// usando el mismo `browse` que la homepage.
  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) => _collectionTracks(collection, limit: limit);

  @override
  Future<CollectionPage> collectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    required OnlineRequestToken token,
  }) async {
    token.throwIfCancelled();
    if (collection.id.isEmpty && continuation == null) {
      return CollectionPage.empty;
    }
    try {
      final String? next = continuation ?? collection.continuation;
      final Map<String, dynamic> body = next != null && next.isNotEmpty
          ? <String, dynamic>{'continuation': next}
          : <String, dynamic>{'browseId': collection.id};
      // `continuation` usa el mismo endpoint `browse` que la apertura.
      final Map<String, dynamic> payload = await _postCatalog(
        'browse',
        body,
        dioCancelTokenOf(token),
      );
      token.throwIfCancelled();
      return CollectionPage(
        tracks: _parse(_shelves(payload), limit),
        continuation: _continuationToken(payload),
        hasMore: _continuationToken(payload) != null,
      );
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'Fallo al paginar la colección ${collection.externalId}',
        error: error,
        stack: stack,
      );
      // La página previa se conserva en el controlador; aquí no se borra nada.
      return CollectionPage.empty;
    }
  }

  Future<List<OnlineTrack>> _collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
    OnlineRequestToken? token,
  }) async {
    if (collection.id.isEmpty) return const <OnlineTrack>[];
    try {
      final Map<String, dynamic> payload = await _postCatalog(
        'browse',
        <String, dynamic>{'browseId': collection.id},
        dioCancelTokenOf(token),
      );
      return _parse(_shelves(payload), limit);
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'Fallo al abrir la colección ${collection.externalId}',
        error: error,
        stack: stack,
      );
      return const <OnlineTrack>[];
    }
  }

  /// Busca el `continuationCommand.token` que InnerTube coloca al final de la
  /// estantería. Se recorre todo el payload (incluidas las acciones de
  /// continuación) para encontrar el más reciente.
  String? _continuationToken(Map<String, dynamic> payload) {
    String? found;
    void walk(Object? node, int depth) {
      if (depth > 16) return;
      final Map<String, dynamic>? map = SourceJson.map(node);
      if (map == null) {
        if (node is List) {
          for (final Object? value in node) {
            walk(value, depth + 1);
          }
        }
        return;
      }
      final String token = SourceJson.text(
        SourceJson.map(map['continuationCommand'])?['token'] ??
            map['continuation'],
      );
      if (token.isNotEmpty) found = token;
      for (final Object? value in map.values) {
        if (value is Map || value is List) walk(value, depth + 1);
      }
    }

    walk(payload, 0);
    return found;
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
  String _browseId(Object? node, [int depth = 0, OnlineSearchType? wanted]) {
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
    // Las páginas sucesivas llegan en `onResponseReceivedActions`, no en
    // `contents`: sin esto "Cargar más" no mostraría ninguna pista nueva.
    walk(payload['onResponseReceivedActions'], 0);
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
    _androidVr =>
      'com.google.android.apps.youtube.vr.oculus/'
          '${_versions[_androidVr] ?? _androidVrVersion} '
          '(Linux; U; Android 12L; en_US; Quest 3; Build/SQ3A.220705.003; gzip)',
    _ => _browserUserAgent,
  };

  int _clientIdFor(String client) => switch (client) {
    _ios => 5,
    _androidMusic => 21,
    _androidVr => 28,
    _tvEmbedded => 85,
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
      'Referer': client == _web ? 'https://$_musicHost/' : 'https://$_wwwHost/',
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

  /// InnerTube marca los formatos protegidos con `signatureCipher`, con la
  /// clave `cipher` o con un parámetro `s` en la URL. Sin descifrar esa firma
  /// mpv solo obtiene 403, así que el formato se descarta y se prueba otro
  /// cliente antes de rendirse.
  static bool _needsCipher(Map<String, dynamic> format, String url) {
    if (SourceJson.text(format['signatureCipher']).isNotEmpty) return true;
    if (SourceJson.text(format['cipher']).isNotEmpty) return true;
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
          // El reproductor incrustado exige declarar la página que lo aloja.
          if (client == _tvEmbedded)
            'thirdParty': <String, dynamic>{'embedUrl': 'https://$host/'},
        },
        client: client,
        host: host,
      );
      final String state = SourceJson.text(
        SourceJson.map(payload['playabilityStatus'])?['status'],
      );
      if (state.isNotEmpty && state != 'OK') {
        OnlineDiagnostics.report(
          _tag,
          'Cliente $client sin acceso al vídeo ($state)',
        );
        return const <_AudioCandidate>[];
      }

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
      found.sort(
        (_AudioCandidate a, _AudioCandidate b) =>
            (b.isMp4 ? 1 : 0) - (a.isMp4 ? 1 : 0),
      );
      if (found.isEmpty) {
        OnlineDiagnostics.report(
          _tag,
          'Cliente $client solo entregó formatos con firma o sin URL directa',
        );
      }
      return found;
    } on RequestCanceledException {
      rethrow;
    } on Object catch (error, stack) {
      // Un cliente caído no impide probar los siguientes de la cadena.
      OnlineDiagnostics.report(
        _tag,
        'Cliente $client falló al pedir el stream; se prueba el siguiente',
        error: error,
        stack: stack,
      );
      return const <_AudioCandidate>[];
    }
  }

  /// Comprueba con un GET de un byte que la URL sigue sirviendo audio.
  ///
  /// La sonda está acotada a 5 s y su resultado se reutiliza unos minutos:
  /// reproductor y descargas comparten esta instancia, así que una URL ya
  /// comprobada no se vuelve a consultar. Un cliente rechazado solo provoca
  /// que se pruebe el siguiente, nunca que se detenga la cola.
  Future<bool> _probeAudioUrl(_AudioCandidate candidate) async {
    final DateTime? probedAt = _probedUrls[candidate.url];
    if (probedAt != null &&
        DateTime.now().difference(probedAt) < _probeCacheTtl) {
      return true;
    }
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        candidate.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, dynamic>{
            ...candidate.headers,
            'Range': 'bytes=0-0',
            'Accept-Encoding': 'identity',
          },
          connectTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      final int? status = response.statusCode;
      final List<String>? types = response.headers['content-type'];
      final String contentType = (types == null || types.isEmpty)
          ? ''
          : types.first.toLowerCase();
      final bool plausible =
          contentType.isEmpty ||
          contentType.startsWith('audio/') ||
          contentType.startsWith('application/octet-stream') ||
          contentType.startsWith('video/');
      if ((status == 200 || status == 206) && plausible) {
        _probedUrls[candidate.url] = DateTime.now();
        return true;
      }
      OnlineDiagnostics.report(
        _tag,
        'URL de ${candidate.client} rechazada por la sonda '
        '(HTTP $status, tipo ${contentType.isEmpty ? 'desconocido' : contentType})',
      );
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        _tag,
        'No se pudo validar el audio de ${candidate.client}; se descarta esa URL',
        error: error,
        stack: stack,
      );
    }
    _probedUrls.remove(candidate.url);
    return false;
  }

  /// Clientes `player`, en orden, hasta conseguir una URL directa válida.
  ///
  /// IOS y ANDROID_MUSIC suelen entregarla; ANDROID_VR y el reproductor
  /// incrustado son el respaldo cuando el vídeo solo ofrece `signatureCipher`.
  /// WEB_REMIX queda de último porque casi siempre firma sus formatos.
  static const List<_PlayerClient> _playerClients = <_PlayerClient>[
    _PlayerClient(_ios, _wwwHost),
    _PlayerClient(_androidMusic, _wwwHost),
    _PlayerClient(_androidVr, _wwwHost),
    _PlayerClient(_tvEmbedded, _wwwHost),
    _PlayerClient(_web, _musicHost),
  ];

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    if (track.sourceId.isEmpty) {
      throw const MusicSourceException(
        'YouTube Music no devolvió un identificador de vídeo válido.',
        source: MusicSourceId.youtube,
        issue: MusicSourceIssue.unavailable,
      );
    }

    final List<_AudioCandidate> candidates = <_AudioCandidate>[];
    final Set<String> seen = <String>{};
    for (int i = 0; i < _playerClients.length; i++) {
      final _PlayerClient entry = _playerClients[i];
      final List<_AudioCandidate> found = await _collectAudioCandidates(
        entry.client,
        entry.host,
        track.sourceId,
      );
      if (found.isEmpty) continue;
      final List<bool> valid = await Future.wait<bool>(
        found.map(_probeAudioUrl),
      );
      for (int j = 0; j < found.length; j++) {
        if (!valid[j] || !seen.add(found[j].url)) continue;
        candidates.add(found[j]);
      }
      // Con principal y respaldo ya validados no seguimos consultando. Si solo
      // hay una URL, se insiste hasta ANDROID_VR antes de aceptarla.
      if (candidates.length >= 2 || (candidates.isNotEmpty && i >= 2)) break;
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
    if (primary.client == _playerClients.first.client) {
      AppLog.i(
        _tag,
        'Stream de audio resuelto y validado con ${primary.client}',
      );
    } else {
      // El cambio de cliente es el dato útil para el diagnóstico Beta; el
      // éxito del cliente habitual se queda solo en el log de la app.
      OnlineDiagnostics.report(
        _tag,
        'Stream de audio validado con ${primary.client} '
        'después de probar otros clientes',
      );
    }
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
