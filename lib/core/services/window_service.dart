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
  });

  final WindowMode mode;
  final bool alwaysOnTop;
  final bool sideHidden;
  final bool maximized;
  final bool visible;

  /// `true` cuando la ventana está minimizada, oculta o sin foco. Se usa para
  /// reducir animaciones y timers de UI. Nunca afecta a la reproducción.
  final bool backgrounded;

  WindowUiState copyWith({
    WindowMode? mode,
    bool? alwaysOnTop,
    bool? sideHidden,
    bool? maximized,
    bool? visible,
    bool? backgrounded,
  }) => WindowUiState(
    mode: mode ?? this.mode,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    sideHidden: sideHidden ?? this.sideHidden,
    maximized: maximized ?? this.maximized,
    visible: visible ?? this.visible,
    backgrounded: backgrounded ?? this.backgrounded,
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
    windowManager.removeListener(this);
    state.dispose();
  }
}
