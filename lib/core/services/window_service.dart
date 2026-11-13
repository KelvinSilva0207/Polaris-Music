// La API "legacy" de window_manager 0.6 sigue siendo la vía estable para
// Windows y es la que el propio paquete mantiene como puente. Se silencia el
// aviso de deprecación a propósito.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/legacy.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Modos de ventana de escritorio.
enum WindowMode { normal, mini, phone }

/// Control de la ventana de Windows.
///
/// Cubre los modos solicitados en Fase 1: siempre encima, mini barra, modo
/// teléfono flotante y ocultación lateral estilo AIMP. En Android todos los
/// métodos son no-op.
class WindowService with WindowListener {
  static const String _tag = 'Window';

  bool _initialized = false;
  bool _alwaysOnTop = false;
  bool _sideHidden = false;
  bool _quitting = false;
  WindowMode _mode = WindowMode.normal;
  Rect? _savedBounds;

  bool get isSupported => !kIsWeb && Platform.isWindows;
  bool get isInitialized => _initialized;
  bool get alwaysOnTop => _alwaysOnTop;
  WindowMode get mode => _mode;
  bool get sideHidden => _sideHidden;

  /// Si la bandeja está disponible, cerrar la ventana la oculta en lugar de
  /// terminar el proceso.
  bool hideOnClose = false;

  static const Size normalSize = Size(1280, 820);
  static const Size normalMinimum = Size(940, 620);
  static const Size miniSize = Size(420, 128);
  static const Size phoneSize = Size(412, 800);

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
        titleBarStyle: TitleBarStyle.normal,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      });
      _initialized = true;
      AppLog.i(_tag, 'Ventana inicializada');
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo inicializar la ventana', error, stack);
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    if (!isSupported) return;
    _alwaysOnTop = value;
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> toggleAlwaysOnTop() => setAlwaysOnTop(!_alwaysOnTop);

  Future<void> setMode(WindowMode mode) async {
    if (!isSupported) return;
    if (_mode == mode) return;

    if (_mode == WindowMode.normal) {
      _savedBounds = await windowManager.getBounds();
    }

    _mode = mode;

    switch (mode) {
      case WindowMode.normal:
        await windowManager.setResizable(true);
        await windowManager.setMaximumSize(const Size(10000, 10000));
        await windowManager.setMinimumSize(normalMinimum);
        final Rect bounds =
            _savedBounds ??
            Rect.fromLTWH(0, 0, normalSize.width, normalSize.height);
        await windowManager.setBounds(bounds);
        await windowManager.setAlwaysOnTop(_alwaysOnTop);
        await windowManager.setSkipTaskbar(false);
      case WindowMode.mini:
        await windowManager.setResizable(false);
        await windowManager.setSize(miniSize);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(false);
        await windowManager.center();
      case WindowMode.phone:
        await windowManager.setResizable(false);
        await windowManager.setSize(phoneSize);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(false);
        await windowManager.center();
    }

    AppLog.i(_tag, 'Modo de ventana: ${mode.name}');
  }

  Future<void> cycleMode() => setMode(switch (_mode) {
    WindowMode.normal => WindowMode.mini,
    WindowMode.mini => WindowMode.phone,
    WindowMode.phone => WindowMode.normal,
  });

  /// Oculta la ventana hacia el borde izquierdo dejando una franja visible.
  Future<void> setSideHidden(bool value) async {
    if (!isSupported) return;
    final Rect bounds = await windowManager.getBounds();
    if (value) {
      if (_sideHidden) return;
      _savedBounds = bounds;
      await windowManager.setPosition(
        Offset(-bounds.width + 10, bounds.top),
        animate: true,
      );
      _sideHidden = true;
    } else {
      if (!_sideHidden) return;
      final Rect target = _savedBounds ?? bounds;
      await windowManager.setPosition(target.topLeft, animate: true);
      _sideHidden = false;
    }
  }

  Future<void> toggleSideHidden() => setSideHidden(!_sideHidden);

  Future<void> show() async {
    if (!isSupported) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hide() async {
    if (!isSupported) return;
    await windowManager.hide();
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
  void onWindowClose() {
    if (hideOnClose && !_quitting) {
      unawaited(hide());
      return;
    }
    _quitting = true;
    unawaited(windowManager.setPreventClose(false));
  }
}
