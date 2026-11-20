import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Sondeo de memoria **solo en debug**: imprime una línea por hito con el
/// working set real (Windows) y el estado de `ImageCache`.
///
/// No escribe en `AppLog` (que también funciona en release) para no ensuciar
/// el registro de usuario. En release el cuerpo se compila a un `return`.
class MemoryProbe {
  const MemoryProbe._();

  static const String _tag = 'MemProbe';

  /// Etiquetas cortas: `scan`, `track`, `view:island`, `online:search`...
  static void mark(String label) {
    if (!kDebugMode) return;

    final ImageCache cache = PaintingBinding.instance.imageCache;
    final StringBuffer line = StringBuffer(label)
      ..write(' images=${cache.currentSize}')
      ..write(
        ' cacheMB=${(cache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(1)}',
      );

    if (Platform.isWindows) {
      final int? workingSet = _windowsWorkingSet();
      if (workingSet != null) {
        line.write(' wsMB=${(workingSet / (1024 * 1024)).toStringAsFixed(1)}');
      }
    }
    debugPrint('[$_tag] $line');
  }

  static int? _windowsWorkingSet() {
    final _Native? api = _load();
    if (api == null) return null;

    final Pointer<_ProcessMemoryCounters> counters =
        calloc<_ProcessMemoryCounters>();
    try {
      counters.ref.cb = sizeOf<_ProcessMemoryCounters>();
      final int ok = api.memoryInfo(
        api.currentProcess(),
        counters,
        sizeOf<_ProcessMemoryCounters>(),
      );
      return ok == 0 ? null : counters.ref.workingSetSize;
    } catch (_) {
      return null;
    } finally {
      calloc.free(counters);
    }
  }

  static _Native? _cached;

  static _Native? _load() {
    if (_cached != null) return _cached;
    try {
      final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
      _cached = _Native(
        currentProcess: kernel32
            .lookupFunction<_GetCurrentProcessNative, _GetCurrentProcessDart>(
              'GetCurrentProcess',
            ),
        memoryInfo: kernel32
            .lookupFunction<_GetMemoryInfoNative, _GetMemoryInfoDart>(
              'K32GetProcessMemoryInfo',
            ),
      );
    } catch (_) {
      return null;
    }
    return _cached;
  }
}

typedef _GetCurrentProcessNative = IntPtr Function();
typedef _GetCurrentProcessDart = int Function();
typedef _GetMemoryInfoNative = Int32 Function(
  IntPtr,
  Pointer<_ProcessMemoryCounters>,
  Uint32,
);
typedef _GetMemoryInfoDart = int Function(
  int,
  Pointer<_ProcessMemoryCounters>,
  int,
);

/// `PROCESS_MEMORY_COUNTERS` de la API de Windows (layout de 64 bits).
final class _ProcessMemoryCounters extends Struct {
  @Uint32()
  external int cb;

  @Uint32()
  external int pageFaultCount;

  @UintPtr()
  external int peakWorkingSetSize;

  @UintPtr()
  external int workingSetSize;

  @UintPtr()
  external int quotaPeakPagedPoolUsage;

  @UintPtr()
  external int quotaPagedPoolUsage;

  @UintPtr()
  external int quotaPeakNonPagedPoolUsage;

  @UintPtr()
  external int quotaNonPagedPoolUsage;

  @UintPtr()
  external int pagefileUsage;

  @UintPtr()
  external int peakPagefileUsage;
}

class _Native {
  const _Native({required this.currentProcess, required this.memoryInfo});

  final _GetCurrentProcessDart currentProcess;
  final _GetMemoryInfoDart memoryInfo;
}
