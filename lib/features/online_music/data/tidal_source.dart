import '../../../core/services/settings_service.dart';
import '../domain/music_source.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Proveedor de Tidal deliberadamente limitado a información de estado.
///
/// El acceso de datos de Tidal requiere un acuerdo de socio y credenciales que
/// no pueden distribuirse en una app de escritorio. En lugar de fingir una
/// integración frágil, el proveedor se registra y expone un estado claro:
/// `notConfigured` o `unsupported`. Las búsquedas unificadas siguen
/// funcionando con el resto de fuentes.
class TidalSource implements MusicSourceProvider {
  TidalSource({required this.settings, ArtworkCache? artworkCache})
    : _artworkCache = artworkCache ?? ArtworkCache();

  final SettingsService settings;
  final ArtworkCache _artworkCache;

  bool get _hasToken =>
      (settings.getString(OnlineSourceSettings.tidalToken)?.trim() ?? '')
          .isNotEmpty;

  @override
  MusicSourceId get id => MusicSourceId.tidal;

  @override
  bool get canSearch => false;

  @override
  bool get canTrending => false;

  @override
  bool get canStream => false;

  @override
  bool get canDownload => false;

  @override
  MusicSourceStatus get status => MusicSourceStatus(
    available: false,
    issue: _hasToken
        ? MusicSourceIssue.unsupported
        : MusicSourceIssue.notConfigured,
    detail: _hasToken
        ? 'Tidal requiere un plan de datos de socio; el token personal no '
              'habilita búsqueda en esta app.'
        : 'Tidal no ofrece una API pública estable para esta app. Se muestra '
              'su estado, pero no se pueden consultar sus pistas.',
    checkedAt: DateTime.now(),
  );

  @override
  Future<MusicSourceStatus> checkAvailability() =>
      Future<MusicSourceStatus>.value(status);

  @override
  Future<SourceResult> search(String query, {int limit = 25}) =>
      Future<SourceResult>.value(SourceResult(source: id, status: status));

  @override
  Future<SourceResult> trending({int limit = 25}) =>
      Future<SourceResult>.value(SourceResult(source: id, status: status));

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) => Future.error(
    const MusicSourceException(
      'Tidal no está habilitado como fuente reproducible.',
      source: MusicSourceId.tidal,
      issue: MusicSourceIssue.unsupported,
    ),
  );

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);
}
