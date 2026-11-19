/// Claves de preferencias de las fuentes online.
///
/// Se mantienen aquí (y no en `AppConstants`) para que el módulo online sea
/// autocontenido. Solo se guardan tokens OAuth introducidos por el usuario:
/// la app no distribuye `client_secret` ni credenciales de socios.
abstract final class OnlineSourceSettings {
  static const String soundCloudToken = 'online.soundcloud.oauth_token';
  static const String spotifyToken = 'online.spotify.oauth_token';
  static const String spotifyMarket = 'online.spotify.market';
  static const String tidalToken = 'online.tidal.oauth_token';

  static const String defaultSpotifyMarket = 'US';
}
