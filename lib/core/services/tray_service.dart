// La API "legacy" de tray_manager 0.8 sigue siendo la vía estable para la
// bandeja del sistema en Windows y es el puente oficial del paquete. El aviso
// de deprecación es intencional.
// ignore_for_file: deprecated_member_use, prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tray_manager/legacy.dart';

import '../constants/app_constants.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import '../utils/logger.dart';
import 'audio_engine_service.dart';
import 'window_service.dart';

/// Icono de bandeja + menú contextual de Polaris Music (solo Windows).
///
/// El menú se reconstruye solo cuando cambia algo visible (título, estado de
/// reproducción) para no recrear recursos nativos en cada _tick_ de posición.
class TrayService with TrayListener {
  TrayService({
    required AudioEngineService engine,
    required WindowService window,
  }) : _engine = engine,
       _window = window;

  static const String _tag = 'Tray';
  static const String _icon = 'assets/icons/app.ico';

  final AudioEngineService _engine;
  final WindowService _window;

  StreamSubscription<PlaybackSnapshot>? _stateSub;
  MenuItem? _playPauseItem;
  MenuItem? _alwaysOnTopItem;

  bool _initialized = false;
  bool _quitting = false;
  String _lastTooltip = '';
  bool _lastPlaying = false;

  bool get isSupported => !kIsWeb && Platform.isWindows;
  bool get isInitialized => _initialized;

  /// Se dispara cuando el usuario elige "Salir" en la bandeja.
  final StreamController<void> _quitRequests =
      StreamController<void>.broadcast();
  Stream<void> get quitRequests => _quitRequests.stream;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(_icon);
      await trayManager.setToolTip(AppConstants.appName);
      await _rebuildMenu();
      _stateSub = _engine.states.listen(_onState);
      _initialized = true;
      AppLog.i(_tag, 'Bandeja del sistema inicializada');
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo iniciar la bandeja del sistema', error, stack);
    }
  }

  void _onState(PlaybackSnapshot snapshot) {
    final Track? track = snapshot.currentTrack;
    final String tooltip = track == null || track.title.isEmpty
        ? AppConstants.appName
        : '${track.artist} - ${track.title}';

    if (tooltip != _lastTooltip) {
      _lastTooltip = tooltip;
      // Windows limita el tooltip de la bandeja; recortamos con elegancia.
      final String safe = tooltip.length > 120
          ? '${tooltip.substring(0, 117)}…'
          : tooltip;
      unawaited(trayManager.setToolTip(safe));
    }

    if (snapshot.playing != _lastPlaying) {
      _lastPlaying = snapshot.playing;
      final MenuItem? playPause = _playPauseItem;
      if (playPause != null) {
        playPause.label = snapshot.playing ? 'Pausar' : 'Reproducir';
      }
    }
  }

  Future<void> _rebuildMenu() async {
    final bool playing = _engine.state.playing;

    _playPauseItem = MenuItem(
      key: 'play_pause',
      label: playing ? 'Pausar' : 'Reproducir',
      onClick: (MenuItem _) => unawaited(_engine.playOrPause()),
    );
    _alwaysOnTopItem = MenuItem.checkbox(
      key: 'always_on_top',
      label: 'Siempre encima',
      checked: _window.alwaysOnTop,
      onClick: (MenuItem _) => unawaited(_toggleAlwaysOnTop()),
    );

    final Menu menu = Menu(
      items: <MenuItem>[
        _playPauseItem!,
        MenuItem(
          key: 'previous',
          label: 'Anterior',
          onClick: (MenuItem _) => unawaited(_engine.previous()),
        ),
        MenuItem(
          key: 'next',
          label: 'Siguiente',
          onClick: (MenuItem _) => unawaited(_engine.next()),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'show',
          label: 'Mostrar ventana principal',
          onClick: (MenuItem _) => unawaited(_window.restoreNormal()),
        ),
        MenuItem(
          key: 'mini',
          label: 'Reproductor mini',
          onClick: (MenuItem _) => unawaited(_window.showTrayMiniPlayer()),
        ),
        MenuItem(
          key: 'island',
          label: 'Isla dinámica',
          onClick: (MenuItem _) => unawaited(_window.showIsland()),
        ),
        MenuItem.submenu(
          key: 'window_mode',
          label: 'Modo de ventana',
          submenu: Menu(
            items: <MenuItem>[
              MenuItem(
                key: 'mode_normal',
                label: 'Normal',
                onClick: (MenuItem _) =>
                    unawaited(_window.setMode(WindowMode.normal)),
              ),
              MenuItem(
                key: 'mode_island',
                label: 'Isla',
                onClick: (MenuItem _) => unawaited(_window.showIsland()),
              ),
              MenuItem(
                key: 'mode_mini',
                label: 'Mini barra',
                onClick: (MenuItem _) =>
                    unawaited(_window.setMode(WindowMode.mini)),
              ),
              MenuItem(
                key: 'mode_phone',
                label: 'Modo teléfono',
                onClick: (MenuItem _) =>
                    unawaited(_window.setMode(WindowMode.phone)),
              ),
            ],
          ),
        ),
        _alwaysOnTopItem!,
        MenuItem(
          key: 'side_hide',
          label: 'Ocultar al borde',
          onClick: (MenuItem _) => unawaited(_window.toggleSideHidden()),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Salir',
          onClick: (MenuItem _) => unawaited(_quit()),
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  Future<void> _toggleAlwaysOnTop() async {
    await _window.toggleAlwaysOnTop();
    final MenuItem? item = _alwaysOnTopItem;
    if (item != null) {
      item.checked = _window.alwaysOnTop;
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    if (!_quitRequests.isClosed) {
      _quitRequests.add(null);
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Clic izquierdo: minirreproductor flotante estilo MusicBee.
    unawaited(_window.showTrayMiniPlayer());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    // `tray_manager` ya invoca `menuItem.onClick`; no lo duplicamos aquí.
  }

  Future<void> dispose() async {
    await _stateSub?.cancel();
    _stateSub = null;
    if (!isSupported) return;
    try {
      trayManager.removeListener(this);
      await trayManager.destroy();
    } catch (error, stack) {
      AppLog.w(_tag, 'Error al liberar la bandeja', error, stack);
    }
    await _quitRequests.close();
    _initialized = false;
  }
}
