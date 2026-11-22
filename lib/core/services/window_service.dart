// La API "legacy" de window_manager 0.6 sigue siendo la vía estable para
// Windows y es la que el propio paquete mantiene como puente. Se silencia el
// aviso de deprecación a propósito.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nativeapi/nativeapi.dart' as native;
import 'package:window_manager/legacy.dart';

import '../constants/app_constants.dart';
import '../debug/memory_probe.dart';
import '../theme/compact_style_config.dart';
import '../utils/logger.dart';
import 'island_shape.dart';

/// Modos de presentación de escritorio.
enum WindowMode { normal, mini, phone, island }

/// Instantánea que la interfaz observa para adaptarse al modo de ventana.
@immutable
class WindowUiState {
  const WindowUiState({
    this.mode = WindowMode.normal,
    this.alwaysOnTop = false,
    this.sideHidden = false,
    this.maximized = false,
    this.visible = true,
    this.backgrounded = false,
    this.islandPeeked = false,
  });

  final WindowMode mode;
  final bool alwaysOnTop;
  final bool sideHidden;
  final bool maximized;
  final bool visible;

  /// `true` cuando la ventana está minimizada, oculta o sin foco. Se usa para
  /// reducir animaciones y timers de UI. Nunca afecta a la reproducción.
  final bool backgrounded;

  /// `true` cuando la isla se ha apartado al borde superior y solo asoma una
  /// franja. La ventana sigue visible: no es lo mismo que [visible] a false.
  final bool islandPeeked;

  WindowUiState copyWith({
    WindowMode? mode,
    bool? alwaysOnTop,
    bool? sideHidden,
    bool? maximized,
    bool? visible,
    bool? backgrounded,
    bool? islandPeeked,
  }) => WindowUiState(
    mode: mode ?? this.mode,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    sideHidden: sideHidden ?? this.sideHidden,
    maximized: maximized ?? this.maximized,
    visible: visible ?? this.visible,
    backgrounded: backgrounded ?? this.backgrounded,
    islandPeeked: islandPeeked ?? this.islandPeeked,
  );
}

/// Control de la ventana de Windows.
///
/// Cubre los modos solicitados: normal, mini reproductor de bandeja, modo
/// teléfono acoplado al lateral y ocultación lateral estilo AIMP. En Android
/// todos los métodos son no-op y [state] permanece en modo normal.
class WindowService with WindowListener {
  static const String _tag = 'Window';

  static const double sidePeekWidth = 14;

  bool _initialized = false;
  bool _alwaysOnTop = false;
  bool _sideHidden = false;
  bool _quitting = false;
  bool _maximized = false;
  bool _backgrounded = false;
  bool _frameless = false;
  WindowMode _mode = WindowMode.normal;
  Rect? _savedBounds;
  native.Window? _nativeWindow;
  Size _capsuleSize = islandCompactCapsule;
  double _capsuleRadius = islandDefaultRadius;
  bool _islandPeeked = false;
  bool _peekArmed = false;
  double _islandNormalLeft = 0;
  double _islandNormalTop = 0;
  Rect _islandDisplayBounds = Rect.zero;
  IslandPeekEdge _islandPeekEdge = IslandPeekEdge.top;
  Timer? _islandPeekPoll;

  /// Fondo nativo de la ventana. Lo fija el tema activo desde `PolarisApp` para
  /// que los bordes visibles durante el resize no muestren un negro fijo.
  Color _windowBackground = const Color(0xFF0B0710);

  /// Estado observable por la UI (shell, ajustes y barra de título).
  final ValueNotifier<WindowUiState> state = ValueNotifier<WindowUiState>(
    const WindowUiState(),
  );

  bool get isSupported => !kIsWeb && Platform.isWindows;
  bool get isInitialized => _initialized;
  bool get alwaysOnTop => _alwaysOnTop;
  WindowMode get mode => _mode;
  bool get sideHidden => _sideHidden;
  bool get maximized => _maximized;
  bool get backgrounded => _backgrounded;
  bool get islandPeeked => _islandPeeked;
  IslandPeekEdge get islandPeekEdge => _islandPeekEdge;

  /// Ventana nativa subyacente. Se guarda una sola referencia: `nativeapi`
  /// asocia un finalizador a cada `Window`, así que conviene no crear una
  /// instancia nueva en cada cambio de forma.
  native.Window? get _native {
    if (!isSupported) return null;
    return _nativeWindow ??= native.WindowManager.instance.getCurrent();
  }

  /// Si la bandeja está disponible, cerrar la ventana la oculta en lugar de
  /// terminar el proceso.
  bool hideOnClose = false;

  static const Size normalSize = Size(1280, 820);
  static const Size normalMinimum = Size(940, 620);
  static const Size miniSize = Size(430, 152);
  static const Size phoneSize = Size(412, 820);
  static const Size islandSize = Size(400, 128);

  /// Tamaños de la cápsula que dibuja `IslandWindow`. La región de la ventana
  /// se recorta a estas medidas para que el escritorio se vea y reciba clics
  /// alrededor de la píldora.
  static const Size islandCompactCapsule = Size(196, 64);
  static const Size islandExpandedCapsule = Size(376, 104);
  static const double islandDefaultRadius = 38;

  /// Mínimo visible cuando la isla se aparta. [IslandShape.visibleSpan] lo
  /// amplía hasta la medida completa de la cápsula para que no se vea solo
  /// la sombra.
  static const double islandPeekHeight = IslandShape.defaultPeekHeight;
  static const Duration islandPeekPollInterval = Duration(milliseconds: 90);
  static const double islandPeekHorizontalPadding =
      IslandShape.peekAlongPadding;
  static const double islandPeekVerticalPadding = IslandShape.peekDepthPadding;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      const WindowOptions options = WindowOptions(
        size: normalSize,
        minimumSize: normalMinimum,
        center: true,
        title: AppConstants.appName,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      });
      // Los accesos a isla/mini desde la bandeja llaman a `_applyMode` sin
      // pasar por `setMode`. Guardar los límites aquí evita que al restaurar
      // se use el fallback (0, 0) y la ventana aparezca en la esquina.
      _savedBounds ??= await windowManager.getBounds();
      _initialized = true;
      _publish();
      AppLog.i(_tag, 'Ventana inicializada con barra de título personalizada');
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo inicializar la ventana', error, stack);
    }
  }

  void _publish() {
    state.value = WindowUiState(
      mode: _mode,
      alwaysOnTop: _alwaysOnTop,
      sideHidden: _sideHidden,
      maximized: _maximized,
      visible: state.value.visible,
      backgrounded: _backgrounded,
      islandPeeked: _islandPeeked,
    );
  }

  void _setVisible(bool value) {
    state.value = state.value.copyWith(visible: value);
  }

  void _setBackgrounded(bool value) {
    if (_backgrounded == value) return;
    _backgrounded = value;
    MemoryProbe.mark(value ? 'view:background' : 'view:foreground');
    if (value) {
      // Al minimizar u ocultar hacia la bandeja no hay carátulas visibles:
      // liberamos también las ya decodificadas, no solo las decodificaciones
      // en curso. Al restaurar se re-decodifican desde disco (sin red y sin
      // pérdida de calidad), así que `clear()` no oculta ninguna imagen visible.
      final ImageCache cache = PaintingBinding.instance.imageCache;
      cache
        ..clearLiveImages()
        ..clear();
    }
    state.value = state.value.copyWith(backgrounded: value);
  }

  /// Lo usa el ciclo de vida de Flutter (Android/iOS y casos que
  /// `window_manager` no reporta). No detiene la reproducción.
  void setBackgrounded(bool value) => _setBackgrounded(value);

  Future<void> setAlwaysOnTop(bool value) async {
    if (!isSupported) return;
    _alwaysOnTop = value;
    await windowManager.setAlwaysOnTop(value);
    _publish();
  }

  Future<void> toggleAlwaysOnTop() => setAlwaysOnTop(!_alwaysOnTop);

  /// Actualiza el color nativo de fondo cuando cambia el preset del tema.
  /// La isla conserva su transparencia real: solo se aplica en los otros modos.
  Future<void> setWindowBackground(Color color) async {
    if (!isSupported || _windowBackground == color) return;
    _windowBackground = color;
    if (_mode != WindowMode.island) {
      await windowManager.setBackgroundColor(color);
    }
  }

  Future<void> setMode(WindowMode mode) async {
    if (!isSupported) return;
    if (_mode == mode && state.value.visible) return;
    await _applyMode(mode);
    _publish();
  }

  Future<void> _applyMode(WindowMode mode) async {
    // Cualquier cambio de modo recoloca la ventana: un estado "apartada" que
    // viniera de la isla dejaría de coincidir con su posición real.
    _resetIslandPeek();
    if (_mode == WindowMode.normal && mode != WindowMode.normal) {
      _savedBounds = await windowManager.getBounds();
    }

    // La isla es la misma ventana de Flutter convertida en isla: se quita el marco
    // nativo por completo (barra de título y botones incluidos) y se vuelve a
    // poner al restaurar cualquier otro modo. `TitleBarStyle.hidden` por sí
    // solo no elimina el marco en Windows.
    if (mode == WindowMode.island) {
      if (!_frameless) {
        await windowManager.setAsFrameless();
        _frameless = true;
      }
      _native?.isWindowControlButtonsVisible = false;
    } else if (_frameless) {
      await _clearIslandShape();
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      _frameless = false;
    }

    _mode = mode;

    switch (mode) {
      case WindowMode.normal:
        await windowManager.setBackgroundColor(_windowBackground);
        await windowManager.setResizable(true);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setMaximumSize(const Size(10000, 10000));
        await windowManager.setMinimumSize(normalMinimum);
        final Rect bounds =
            _savedBounds ??
            Rect.fromLTWH(0, 0, normalSize.width, normalSize.height);
        await windowManager.setBounds(bounds);
        await windowManager.setAlwaysOnTop(_alwaysOnTop);
      case WindowMode.mini:
        await windowManager.setBackgroundColor(_windowBackground);
        await windowManager.setResizable(false);
        await windowManager.setMinimumSize(Size.zero);
        await windowManager.setSize(miniSize);
        await windowManager.setAlwaysOnTop(true);
        // No aparece agrupada en la barra de tareas: vive pegada a la bandeja.
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlignment(Alignment.bottomRight);
      case WindowMode.phone:
        await windowManager.setBackgroundColor(_windowBackground);
        await windowManager.setResizable(false);
        await windowManager.setMinimumSize(Size.zero);
        await windowManager.setSize(phoneSize);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setAlignment(Alignment.centerRight);
        // Deja un pequeño margen para que no quede pegada al borde exacto.
        final Rect current = await windowManager.getBounds();
        await windowManager.setPosition(
          Offset(current.left - 18, current.top),
          animate: false,
        );
      case WindowMode.island:
        // Fondo transparente de verdad: Flutter pinta la píldora y lo demás
        // deja ver el escritorio. Junto con la región redondeada de abajo,
        // tampoco se capturan clics fuera de la cápsula.
        await windowManager.setBackgroundColor(const Color(0x00000000));
        await windowManager.setResizable(false);
        await windowManager.setMinimumSize(Size.zero);
        await windowManager.setSize(islandSize);
        await windowManager.setAlignment(Alignment.topCenter, animate: true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(true);
        _capsuleSize = islandCompactCapsule;
        _capsuleRadius = islandDefaultRadius;
        await _applyIslandShape();
    }

    if (!state.value.visible) {
      await windowManager.show();
      _setVisible(true);
      _setBackgrounded(false);
    }
    AppLog.i(_tag, 'Modo de ventana: ${mode.name}');
  }

  /// La cápsula crece al pasar el ratón o al expandirse la isla. La región de
  /// la ventana se actualiza con ella para que el área libre siga siendo
  /// transparente al ratón y el borde/sombra propios de la píldora no se corten.
  Future<void> setIslandCapsule(Size capsuleSize, double radius) async {
    if (!isSupported || _mode != WindowMode.island) return;
    if (_capsuleSize == capsuleSize && _capsuleRadius == radius) return;
    _capsuleSize = capsuleSize;
    _capsuleRadius = radius;
    await _applyIslandShape();
  }

  /// Apartar la isla hacia el borde elegido dejando asomar una franja.
  ///
  /// A diferencia de [hide], la ventana sigue visible y reproduciendo: la
  /// región nativa se desplaza con ella, así que solo se ve (y recibe ratón)
  /// la franja de la cápsula. Un sondeo ligero del cursor detecta cuándo el
  /// usuario se acerca a ese borde para devolverla desde el mismo lado.
  Future<void> peekIsland() async {
    if (!isSupported || _mode != WindowMode.island || _islandPeeked) return;
    final Rect bounds = await windowManager.getBounds();
    _islandNormalLeft = bounds.left;
    _islandNormalTop = bounds.top;
    _islandDisplayBounds = _displayWorkAreaFor(bounds);
    await _moveIslandToPeekEdge();
    _islandPeeked = true;
    // Si el cursor está aún sobre el botón que acaba de pulsar, no debe
    // reabrirse: primero tiene que salir de la zona del borde.
    _peekArmed = false;
    _publish();
    _startPeekWatcher();
    AppLog.i(_tag, 'Isla apartada al borde ${_islandPeekEdge.name}');
  }

  /// Cambia el borde de la franja en caliente, también si ya está apartada.
  Future<void> setIslandPeekEdge(IslandPeekEdge edge) async {
    if (_islandPeekEdge == edge) return;
    _islandPeekEdge = edge;
    if (!_islandPeeked) return;
    await _moveIslandToPeekEdge();
    _peekArmed = false;
    _startPeekWatcher();
    AppLog.i(_tag, 'Borde de la isla cambiado a ${edge.name}');
  }

  /// Devuelve la isla a su posición flotante sobre el centro superior. La
  /// animación parte de la franja, así que parece salir del borde elegido.
  Future<void> unpeekIsland() async {
    if (!isSupported || !_islandPeeked) return;
    _islandPeeked = false;
    _peekArmed = false;
    _stopPeekWatcher();
    await windowManager.setAlignment(Alignment.topCenter, animate: true);
    _publish();
    AppLog.i(_tag, 'Isla restaurada desde el borde ${_islandPeekEdge.name}');
  }

  Future<void> _moveIslandToPeekEdge() async {
    final Offset target = IslandShape.peekPosition(
      normalTopLeft: Offset(_islandNormalLeft, _islandNormalTop),
      windowSize: islandSize,
      capsuleSize: _capsuleSize,
      displayBounds: _islandDisplayBounds,
      edge: _islandPeekEdge,
      visibleHeight: IslandShape.visibleSpan(
        edge: _islandPeekEdge,
        capsuleSize: _capsuleSize,
        minimum: islandPeekHeight,
      ),
    );
    await windowManager.setPosition(target, animate: true);
  }

  /// Área de trabajo de la pantalla en la que está la ventana. Usamos el área
  /// útil (no el rectángulo completo) para que una franja inferior no quede
  /// debajo de la barra de tareas de Windows.
  Rect _displayWorkAreaFor(Rect bounds) {
    final Offset center = bounds.center;
    final native.DisplayManager manager = native.DisplayManager.instance;
    for (final native.Display display in manager.getAll()) {
      final native.Rectangle area = display.workArea;
      final Rect workArea = Rect.fromLTWH(
        area.x,
        area.y,
        area.width,
        area.height,
      );
      if (workArea.contains(center)) return workArea;
    }
    final native.Display? primary = manager.getPrimary();
    if (primary != null) {
      final native.Rectangle area = primary.workArea;
      return Rect.fromLTWH(area.x, area.y, area.width, area.height);
    }
    return bounds;
  }

  void _resetIslandPeek() {
    if (!_islandPeeked && _islandPeekPoll == null) return;
    _islandPeeked = false;
    _peekArmed = false;
    _stopPeekWatcher();
    _publish();
  }

  void _startPeekWatcher() {
    _stopPeekWatcher();
    _islandPeekPoll = Timer.periodic(islandPeekPollInterval, (Timer _) {
      if (!isSupported || !_islandPeeked) return;
      try {
        final native.Point raw = native.DisplayManager.instance
            .getCursorPosition();
        final Offset cursor = Offset(raw.x, raw.y);
        final Rect zone = IslandShape.peekActivationZone(
          normalTopLeft: Offset(_islandNormalLeft, _islandNormalTop),
          windowSize: islandSize,
          displayBounds: _islandDisplayBounds,
          edge: _islandPeekEdge,
          visibleHeight: IslandShape.visibleSpan(
            edge: _islandPeekEdge,
            capsuleSize: _capsuleSize,
            minimum: islandPeekHeight,
          ),
          alongPadding: islandPeekHorizontalPadding,
          depthPadding: islandPeekVerticalPadding,
        );
        final bool inside = zone.contains(cursor);
        if (!inside) {
          _peekArmed = true;
          return;
        }
        if (_peekArmed) unawaited(unpeekIsland());
      } catch (error, stack) {
        AppLog.w(_tag, 'No se pudo leer el cursor para la isla', error, stack);
        _stopPeekWatcher();
      }
    });
  }

  void _stopPeekWatcher() {
    _islandPeekPoll?.cancel();
    _islandPeekPoll = null;
  }

  Future<void> _applyIslandShape() async {
    final native.Window? window = _native;
    if (window == null || !_frameless || !native.Window.isShapeSupported()) {
      return;
    }
    final List<Offset> points = IslandShape.points(
      windowSize: islandSize,
      capsuleSize: _capsuleSize,
      radius: _capsuleRadius,
    );
    final native.WindowShape? shape = native.WindowShape.create();
    if (shape == null) return;
    try {
      for (final Offset point in points) {
        shape.addPoint(native.Point(x: point.dx, y: point.dy));
      }
      if (!window.setShape(shape)) {
        AppLog.w(_tag, 'No se pudo aplicar la región de la isla');
      }
    } catch (error, stack) {
      AppLog.w(_tag, 'Error al aplicar la región de la isla', error, stack);
    } finally {
      // `SetWindowRgn` copia la región; la lista de puntos ya no es necesaria.
      shape.dispose();
    }
  }

  Future<void> _clearIslandShape() async {
    final native.Window? window = _native;
    if (window == null || !window.isShaped) return;
    window.setShape(null);
  }

  Future<void> cycleMode() => setMode(switch (_mode) {
    WindowMode.normal => WindowMode.island,
    WindowMode.island => WindowMode.mini,
    WindowMode.mini => WindowMode.phone,
    WindowMode.phone => WindowMode.normal,
  });

  /// Alterna entre maximizada y tamaño normal.
  Future<void> toggleMaximize() async {
    if (!isSupported || _mode != WindowMode.normal) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /// Minimiza a la barra de tareas tradicional.
  Future<void> minimize() async {
    if (!isSupported) return;
    _setBackgrounded(true);
    await windowManager.minimize();
  }

  /// Oculta la app en la bandeja del sistema.
  Future<void> minimizeToTray() async {
    if (!isSupported) return;
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();
    _setVisible(false);
    _setBackgrounded(true);
    AppLog.i(_tag, 'Ventana oculta en la bandeja');
  }

  /// Transforma la ventana en una isla flotante Always-on-Top centrada arriba.
  Future<void> showIsland() async {
    if (!isSupported) return;
    await _applyMode(WindowMode.island);
    await windowManager.show();
    await windowManager.focus();
    _setVisible(true);
    _setBackgrounded(false);
    _publish();
    AppLog.i(_tag, 'Isla dinámica activada');
  }

  /// Restaura la ventana principal en modo normal.
  Future<void> restoreNormal() async {
    if (!isSupported) return;
    _sideHidden = false;
    await _applyMode(WindowMode.normal);
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    _setVisible(true);
    _setBackgrounded(false);
    _publish();
  }

  /// Muestra el mini reproductor flotante anclado a la bandeja.
  Future<void> showTrayMiniPlayer() async {
    if (!isSupported) return;
    _sideHidden = false;
    await _applyMode(WindowMode.mini);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
    _setVisible(true);
    _setBackgrounded(false);
    _publish();
  }

  /// Oculta la ventana hacia el borde izquierdo dejando una franja visible.
  Future<void> setSideHidden(bool value) async {
    if (!isSupported || _sideHidden == value) return;
    final Rect bounds = await windowManager.getBounds();
    if (value) {
      _savedBounds = bounds;
      await windowManager.setPosition(
        Offset(-bounds.width + sidePeekWidth, bounds.top),
        animate: true,
      );
      _sideHidden = true;
    } else {
      final Rect target = _savedBounds ?? bounds;
      final Rect current = await windowManager.getBounds();
      await windowManager.setPosition(
        Offset(target.left, current.top),
        animate: true,
      );
      _sideHidden = false;
    }
    _publish();
  }

  Future<void> toggleSideHidden() => setSideHidden(!_sideHidden);

  Future<void> show() async {
    if (!isSupported) return;
    await windowManager.show();
    await windowManager.focus();
    _setVisible(true);
    _setBackgrounded(false);
  }

  Future<void> hide() async {
    if (!isSupported) return;
    await windowManager.hide();
    _setVisible(false);
    _setBackgrounded(true);
  }

  Future<void> setTitle(String title) async {
    if (!isSupported) return;
    await windowManager.setTitle(title);
  }

  /// Progreso en la barra de tareas de Windows (escaneo, descargas...).
  Future<void> setProgress(double progress) async {
    if (!isSupported) return;
    await windowManager.setProgressBar(progress.clamp(0.0, 1.0));
  }

  Future<void> clearProgress() async {
    if (!isSupported) return;
    await windowManager.setProgressBar(-1);
  }

  Future<void> close() async {
    if (!isSupported) return;
    _quitting = true;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Cierre definitivo desde la bandeja o el menú de la app.
  Future<void> quit() => close();

  @override
  void onWindowMinimize() {
    _setBackgrounded(true);
  }

  @override
  void onWindowFocus() {
    _setBackgrounded(false);
  }

  @override
  void onWindowBlur() {
    // No pausamos audio: solo marcamos la UI como en segundo plano.
    _setBackgrounded(true);
  }

  @override
  void onWindowMaximize() {
    _maximized = true;
    _publish();
  }

  @override
  void onWindowUnmaximize() {
    _maximized = false;
    _publish();
  }

  @override
  void onWindowRestore() {
    _maximized = false;
    _setBackgrounded(false);
    _publish();
  }

  @override
  void onWindowClose() {
    if (hideOnClose && !_quitting) {
      unawaited(minimizeToTray());
      return;
    }
    _quitting = true;
    unawaited(windowManager.setPreventClose(false));
  }

  Future<void> dispose() async {
    if (!isSupported) return;
    _stopPeekWatcher();
    windowManager.removeListener(this);
    state.dispose();
  }
}
