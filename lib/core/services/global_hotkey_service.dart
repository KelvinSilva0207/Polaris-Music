import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

/// Acciones que se pueden disparar desde cualquier aplicación de Windows.
enum HotkeyAction { playPause, next, previous }

/// Combinación de teclas global expresada como modificadores + código VK.
@immutable
class HotkeyBinding {
  const HotkeyBinding({required this.modifiers, required this.vk});

  final int modifiers;
  final int vk;

  static const int _modAlt = 0x0001;
  static const int _modCtrl = 0x0002;
  static const int _modShift = 0x0004;
  static const int _modWin = 0x0008;

  bool get hasModifier => (modifiers & (_modAlt | _modCtrl | _modWin)) != 0;

  String get label {
    final List<String> parts = <String>[];
    if (modifiers & _modCtrl != 0) parts.add('Ctrl');
    if (modifiers & _modAlt != 0) parts.add('Alt');
    if (modifiers & _modShift != 0) parts.add('Shift');
    if (modifiers & _modWin != 0) parts.add('Win');
    parts.add(_vkLabel(vk));
    return parts.join(' + ');
  }

  String toStorage() {
    final List<String> parts = <String>[];
    if (modifiers & _modCtrl != 0) parts.add('ctrl');
    if (modifiers & _modAlt != 0) parts.add('alt');
    if (modifiers & _modShift != 0) parts.add('shift');
    if (modifiers & _modWin != 0) parts.add('win');
    parts.add(_vkToken(vk));
    return parts.join('+');
  }

  static HotkeyBinding? fromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    int modifiers = 0;
    int? vk;
    for (final String token in raw.toLowerCase().split('+')) {
      switch (token.trim()) {
        case 'ctrl':
        case 'control':
          modifiers |= _modCtrl;
        case 'alt':
          modifiers |= _modAlt;
        case 'shift':
          modifiers |= _modShift;
        case 'win':
        case 'super':
        case 'meta':
          modifiers |= _modWin;
        case '':
          break;
        default:
          vk = _tokenVk(token.trim());
      }
    }
    if (vk == null) return null;
    return HotkeyBinding(modifiers: modifiers, vk: vk);
  }

  /// Construye una combinación a partir de una tecla capturada en la UI.
  static HotkeyBinding? fromLogicalKey(
    LogicalKeyboardKey key, {
    required Set<LogicalKeyboardKey> pressed,
  }) {
    final int? vk = _logicalVk(key);
    if (vk == null) return null;
    int modifiers = 0;
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      modifiers |= _modCtrl;
    }
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) {
      modifiers |= _modAlt;
    }
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) {
      modifiers |= _modShift;
    }
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) {
      modifiers |= _modWin;
    }
    return HotkeyBinding(modifiers: modifiers, vk: vk);
  }

  static int? _tokenVk(String token) {
    switch (token) {
      case 'space':
        return 0x20;
      case 'left':
      case 'arrowleft':
        return 0x25;
      case 'up':
      case 'arrowup':
        return 0x26;
      case 'right':
      case 'arrowright':
        return 0x27;
      case 'down':
      case 'arrowdown':
        return 0x28;
      case 'enter':
        return 0x0D;
      case 'tab':
        return 0x09;
      case 'backspace':
        return 0x08;
      case 'delete':
        return 0x2E;
      case 'insert':
        return 0x2D;
      case 'home':
        return 0x24;
      case 'end':
        return 0x23;
      case 'pageup':
        return 0x21;
      case 'pagedown':
        return 0x22;
      case 'escape':
        return 0x1B;
      case 'mediaplaypause':
        return 0xB3;
      case 'medianext':
      case 'mediatracknext':
        return 0xB0;
      case 'mediaprevious':
      case 'mediatrackprevious':
        return 0xB1;
      case 'volumeup':
        return 0xAF;
      case 'volumedown':
        return 0xAE;
      case 'volumemute':
        return 0xAD;
    }
    final RegExpMatch? fn = RegExp(r'^f(\d{1,2})$').firstMatch(token);
    if (fn != null) {
      final int number = int.parse(fn.group(1)!);
      if (number >= 1 && number <= 24) return 0x70 + number - 1;
    }
    if (token.length == 1) {
      final int code = token.toUpperCase().codeUnitAt(0);
      if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A)) {
        return code;
      }
    }
    return null;
  }

  static String _vkToken(int vk) {
    if (vk == 0x20) return 'space';
    if (vk == 0x25) return 'left';
    if (vk == 0x26) return 'up';
    if (vk == 0x27) return 'right';
    if (vk == 0x28) return 'down';
    if (vk == 0x0D) return 'enter';
    if (vk >= 0x70 && vk <= 0x87) return 'f${vk - 0x70 + 1}';
    if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)) {
      return String.fromCharCode(vk).toLowerCase();
    }
    return 'vk$vk';
  }

  static String _vkLabel(int vk) {
    switch (vk) {
      case 0x20:
        return 'Espacio';
      case 0x25:
        return '←';
      case 0x26:
        return '↑';
      case 0x27:
        return '→';
      case 0x28:
        return '↓';
      case 0x0D:
        return 'Enter';
      case 0x1B:
        return 'Esc';
      case 0xB3:
        return 'Reproducir/Pausa';
      case 0xB0:
        return 'Siguiente';
      case 0xB1:
        return 'Anterior';
    }
    if (vk >= 0x70 && vk <= 0x87) return 'F${vk - 0x70 + 1}';
    if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)) {
      return String.fromCharCode(vk);
    }
    return 'Tecla $vk';
  }

  static int? _logicalVk(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 0x20;
    if (key == LogicalKeyboardKey.arrowLeft) return 0x25;
    if (key == LogicalKeyboardKey.arrowUp) return 0x26;
    if (key == LogicalKeyboardKey.arrowRight) return 0x27;
    if (key == LogicalKeyboardKey.arrowDown) return 0x28;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return 0x0D;
    }
    if (key == LogicalKeyboardKey.escape) return 0x1B;
    if (key == LogicalKeyboardKey.tab) return 0x09;
    if (key == LogicalKeyboardKey.backspace) return 0x08;
    if (key == LogicalKeyboardKey.delete) return 0x2E;
    if (key == LogicalKeyboardKey.insert) return 0x2D;
    if (key == LogicalKeyboardKey.home) return 0x24;
    if (key == LogicalKeyboardKey.end) return 0x23;
    if (key == LogicalKeyboardKey.pageUp) return 0x21;
    if (key == LogicalKeyboardKey.pageDown) return 0x22;
    if (key == LogicalKeyboardKey.mediaPlayPause) return 0xB3;
    if (key == LogicalKeyboardKey.mediaTrackNext) return 0xB0;
    if (key == LogicalKeyboardKey.mediaTrackPrevious) return 0xB1;
    if (key == LogicalKeyboardKey.audioVolumeUp) return 0xAF;
    if (key == LogicalKeyboardKey.audioVolumeDown) return 0xAE;
    if (key == LogicalKeyboardKey.audioVolumeMute) return 0xAD;

    final String label = key.keyLabel.toUpperCase();
    if (label.length == 1) {
      final int code = label.codeUnitAt(0);
      if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A)) {
        return code;
      }
    }
    final RegExpMatch? fn = RegExp(r'^F(\d{1,2})$').firstMatch(label);
    if (fn != null) {
      final int number = int.parse(fn.group(1)!);
      if (number >= 1 && number <= 24) return 0x70 + number - 1;
    }
    return null;
  }
}

/// Atajos globales reales en Windows (`RegisterHotKey` vía FFI).
///
/// Vive en un isolate dedicado con su propio bucle de mensajes Win32, por lo
/// que funciona con la ventana minimizada o en la bandeja. Si la plataforma no
/// es Windows el servicio queda inerte y la UI oculta la sección.
class GlobalHotkeyService {
  GlobalHotkeyService({required this._settings, required this._onAction});

  static const String _tag = 'Hotkeys';

  final SettingsService _settings;
  final void Function(HotkeyAction action) _onAction;

  /// Combinaciones activas; la UI las observa para reflejar cambios al vuelo.
  final ValueNotifier<Map<HotkeyAction, HotkeyBinding>> bindings =
      ValueNotifier<Map<HotkeyAction, HotkeyBinding>>(
        const <HotkeyAction, HotkeyBinding>{},
      );

  /// Último error legible (combo ocupado por otra app, por ejemplo).
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  Isolate? _isolate;
  ReceivePort? _messages;
  ReceivePort? _exitPort;
  StreamSubscription<dynamic>? _exitSub;
  Completer<void>? _exited;
  Pointer<Int32>? _stopFlag;
  bool _disposed = false;

  bool get isSupported => !kIsWeb && Platform.isWindows;

  static String keyFor(HotkeyAction action) => switch (action) {
    HotkeyAction.playPause => AppConstants.keyHotkeyPlayPause,
    HotkeyAction.next => AppConstants.keyHotkeyNext,
    HotkeyAction.previous => AppConstants.keyHotkeyPrevious,
  };

  static String defaultFor(HotkeyAction action) => switch (action) {
    HotkeyAction.playPause => AppConstants.defaultHotkeyPlayPause,
    HotkeyAction.next => AppConstants.defaultHotkeyNext,
    HotkeyAction.previous => AppConstants.defaultHotkeyPrevious,
  };

  static String labelFor(HotkeyAction action) => switch (action) {
    HotkeyAction.playPause => 'Reproducir / Pausar',
    HotkeyAction.next => 'Siguiente pista',
    HotkeyAction.previous => 'Pista anterior',
  };

  HotkeyBinding bindingFor(HotkeyAction action) =>
      bindings.value[action] ??
      HotkeyBinding.fromStorage(defaultFor(action)) ??
      const HotkeyBinding(modifiers: 0x0002, vk: 0x20);

  Future<void> initialize() async {
    _reloadFromSettings();
    if (!isSupported) return;
    await _restart();
  }

  void _reloadFromSettings() {
    bindings.value = Map<HotkeyAction, HotkeyBinding>.unmodifiable(
      <HotkeyAction, HotkeyBinding>{
        for (final HotkeyAction action in HotkeyAction.values)
          if (HotkeyBinding.fromStorage(
                _settings.stringOr(keyFor(action), defaultFor(action)),
              )
              case final HotkeyBinding binding)
            action: binding,
      },
    );
  }

  Future<void> setBinding(HotkeyAction action, HotkeyBinding binding) async {
    await _settings.setString(keyFor(action), binding.toStorage());
    bindings.value = Map<HotkeyAction, HotkeyBinding>.unmodifiable(
      <HotkeyAction, HotkeyBinding>{...bindings.value, action: binding},
    );
    await _restart();
  }

  Future<void> resetDefaults() async {
    for (final HotkeyAction action in HotkeyAction.values) {
      await _settings.setString(keyFor(action), defaultFor(action));
    }
    _reloadFromSettings();
    await _restart();
  }

  Future<void> _restart() async {
    if (_disposed || !isSupported) return;
    await _stop();
    lastError.value = null;

    final Map<HotkeyAction, HotkeyBinding> active = bindings.value;
    if (active.isEmpty) return;

    final ReceivePort messages = ReceivePort();
    final ReceivePort exitPort = ReceivePort();
    _messages = messages;
    _exitPort = exitPort;
    _exited = Completer<void>();

    final Map<int, HotkeyAction> byId = <int, HotkeyAction>{};
    final List<List<int>> entries = <List<int>>[];
    int id = 1;
    for (final MapEntry<HotkeyAction, HotkeyBinding> entry in active.entries) {
      byId[id] = entry.key;
      entries.add(<int>[id, entry.value.modifiers, entry.value.vk]);
      id++;
    }

    final Pointer<Int32> stop = calloc<Int32>();
    _stopFlag = stop;

    messages.listen((dynamic message) {
      if (message is int) {
        final HotkeyAction? action = byId[message];
        if (action != null) _onAction(action);
      } else if (message is List<int> && message.isNotEmpty) {
        final List<String> names = message
            .map((int failedId) => byId[failedId])
            .whereType<HotkeyAction>()
            .map(labelFor)
            .toList(growable: false);
        lastError.value = names.isEmpty
            ? null
            : 'Windows no permitió registrar: ${names.join(', ')}. '
                  'Otra aplicación puede estar usando esa combinación.';
      }
    });

    _exitSub = exitPort.listen((dynamic _) {
      if (!(_exited?.isCompleted ?? true)) _exited!.complete();
    });

    try {
      _isolate = await Isolate.spawn<_HotkeyConfig>(
        _hotkeyLoop,
        _HotkeyConfig(
          sendPort: messages.sendPort,
          entries: entries,
          stopAddress: stop.address,
        ),
        debugName: 'polaris-hotkeys',
        onExit: exitPort.sendPort,
        errorsAreFatal: false,
      );
      AppLog.i(
        _tag,
        'Atajos globales activos: '
        '${active.values.map((HotkeyBinding b) => b.label).join(', ')}',
      );
    } catch (error, stack) {
      lastError.value = 'No se pudieron iniciar los atajos globales.';
      AppLog.w(_tag, 'Fallo al iniciar el isolate de atajos', error, stack);
    }
  }

  Future<void> _stop() async {
    final Pointer<Int32>? stop = _stopFlag;
    if (stop != null) stop.value = 1;

    final Completer<void>? exited = _exited;
    if (_isolate != null && exited != null && !exited.isCompleted) {
      try {
        await exited.future.timeout(const Duration(milliseconds: 800));
      } on TimeoutException {
        _isolate?.kill(priority: Isolate.immediate);
      }
    }

    _isolate = null;
    _exited = null;
    await _exitSub?.cancel();
    _exitSub = null;
    _exitPort?.close();
    _exitPort = null;
    _messages?.close();
    _messages = null;
    if (stop != null) calloc.free(stop);
    _stopFlag = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _stop();
    bindings.dispose();
    lastError.dispose();
  }
}

class _HotkeyConfig {
  const _HotkeyConfig({
    required this.sendPort,
    required this.entries,
    required this.stopAddress,
  });

  final SendPort sendPort;
  final List<List<int>> entries;
  final int stopAddress;
}

const int _wmHotkey = 0x0312;
const int _pmRemove = 0x0001;

/// Bucle Win32 aislado: registra las teclas y bombea la cola de mensajes.
void _hotkeyLoop(_HotkeyConfig config) {
  final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
  final int Function(int, int, int, int) registerHotKey = user32
      .lookupFunction<
        Int32 Function(IntPtr, Int32, Uint32, Uint32),
        int Function(int, int, int, int)
      >('RegisterHotKey');
  final int Function(int, int) unregisterHotKey = user32
      .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
        'UnregisterHotKey',
      );
  final int Function(Pointer<Uint8>, int, int, int, int) peekMessage = user32
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, IntPtr, Uint32, Uint32, Uint32),
        int Function(Pointer<Uint8>, int, int, int, int)
      >('PeekMessageW');

  final Pointer<Int32> stop = Pointer<Int32>.fromAddress(config.stopAddress);
  final Pointer<Uint8> message = calloc<Uint8>(64);
  final List<int> registered = <int>[];
  final List<int> failed = <int>[];

  for (final List<int> entry in config.entries) {
    final int ok = registerHotKey(0, entry[0], entry[1], entry[2]);
    if (ok == 0) {
      failed.add(entry[0]);
    } else {
      registered.add(entry[0]);
    }
  }
  config.sendPort.send(failed);

  final int pointerSize = sizeOf<IntPtr>();
  final int messageOffset = pointerSize == 8 ? 8 : 4;
  final int wParamOffset = pointerSize == 8 ? 16 : 8;

  int readUint32(Pointer<Uint8> base, int offset) =>
      (base + offset).cast<Uint32>().value;

  try {
    while (stop.value == 0) {
      while (peekMessage(message, 0, 0, 0, _pmRemove) != 0) {
        if (readUint32(message, messageOffset) == _wmHotkey) {
          config.sendPort.send(readUint32(message, wParamOffset));
        }
      }
      sleep(const Duration(milliseconds: 24));
    }
  } finally {
    for (final int id in registered) {
      unregisterHotKey(0, id);
    }
    calloc.free(message);
  }
}
