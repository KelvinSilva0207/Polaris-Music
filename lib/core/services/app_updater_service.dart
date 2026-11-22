import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/update_info.dart';
import '../utils/logger.dart';
import 'update_service.dart';

/// Resultado de abrir el instalador de Android.
enum ApkInstallResult {
  /// El instalador del sistema se abrió correctamente.
  started,

  /// Falta conceder "instalar aplicaciones desconocidas".
  permissionRequired,

  /// El APK pertenece a otra app (no debería ocurrir con nuestros assets).
  wrongPackage,

  /// El APK tiene otra firma: Android exige desinstalar una vez.
  signatureMismatch,

  /// El APK es más antiguo que la versión instalada.
  olderVersion,

  /// El APK no es válido o el sistema rechazó el intent.
  failed,
}

/// Resultado final del instalador del sistema, notificado por el canal nativo.
///
/// [installApk] solo confirma que el intent se abrió; el usuario puede cancelar
/// o el sistema puede rechazar la instalación después de ese momento.
enum ApkInstallOutcome {
  /// El sistema confirmó que la instalación terminó correctamente.
  installed,

  /// El usuario canceló el instalador.
  cancelled,

  /// El sistema rechazó el APK o el instalador terminó con error.
  failed;

  static ApkInstallOutcome? fromMap(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return null;
    return switch (raw['status']) {
      'installed' => ApkInstallOutcome.installed,
      'cancelled' => ApkInstallOutcome.cancelled,
      'failed' => ApkInstallOutcome.failed,
      _ => null,
    };
  }
}

/// Datos del APK leídos por el canal nativo antes de abrir el instalador.
class ApkInspection {
  const ApkInspection({
    required this.samePackage,
    required this.signatureMatches,
    required this.versionCode,
    required this.installedVersionCode,
  });

  factory ApkInspection.fromMap(Object? raw) {
    final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
    return ApkInspection(
      samePackage: map['samePackage'] == true,
      signatureMatches: map['signatureMatches'] == true,
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      installedVersionCode: (map['installedVersionCode'] as num?)?.toInt() ?? 0,
    );
  }

  final bool samePackage;
  final bool signatureMatches;
  final int versionCode;
  final int installedVersionCode;
}

/// Fachada de actualización usada por la app.
///
/// Hereda la lógica de GitHub Releases de [UpdateService] y añade la instalación
/// de APK en Android mediante un intent nativo (que gestiona el permiso de
/// "instalar aplicaciones desconocidas" y un `FileProvider`).
///
/// El APK descargado se conserva en memoria mientras la app siga viva: si el
/// usuario sale a conceder el permiso y vuelve, se reutiliza ese mismo archivo
/// en lugar de descargarlo otra vez.
class AppUpdaterService extends UpdateService {
  AppUpdaterService({super.dio, super.updatesDirectory}) {
    if (Platform.isAndroid) {
      _events.setMethodCallHandler(_onNativeCall);
    }
  }

  static const String _tag = 'AppUpdater';
  static const MethodChannel _channel = MethodChannel(
    'com.polaris.polaris_music/updater',
  );
  static const MethodChannel _events = MethodChannel(
    'com.polaris.polaris_music/updater_events',
  );

  final StreamController<ApkInstallOutcome> _outcomes =
      StreamController<ApkInstallOutcome>.broadcast();

  /// Estado final del instalador del sistema (éxito, cancelación o error).
  Stream<ApkInstallOutcome> get installOutcomes => _outcomes.stream;

  String? _cachedPath;
  String? _cachedKey;

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'installOutcome') return;
    final ApkInstallOutcome? outcome = ApkInstallOutcome.fromMap(
      call.arguments,
    );
    if (outcome == null) {
      AppLog.w(_tag, 'Estado de instalación desconocido: ${call.arguments}');
      return;
    }
    AppLog.i(_tag, 'Resultado del instalador de Android: ${outcome.name}');
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  /// Libera el controlador de eventos al descartar el servicio.
  void disposeOutcomes() {
    if (!_outcomes.isClosed) _outcomes.close();
  }

  static String _cacheKey(UpdateInfo info) =>
      '${info.latestVersion}|${info.downloadUrl}';

  /// Verifica el tamaño del binario antes de darlo por bueno.
  ///
  /// Si ya descargamos exactamente esta release, devuelve la ruta anterior:
  /// el permiso de instalación se pide antes de descargar, pero si el usuario
  /// sale a Ajustes y vuelve, el botón nunca debe repetir la descarga.
  @override
  Future<String?> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String key = _cacheKey(info);
    final String? cached = _cachedPath;
    if (cached != null && _cachedKey == key) {
      final File file = File(cached);
      if (file.existsSync() && file.lengthSync() > 0) {
        AppLog.i(_tag, 'Reutilizando descarga existente: $cached');
        onProgress?.call(file.lengthSync(), file.lengthSync());
        return cached;
      }
      _cachedPath = null;
      _cachedKey = null;
    }

    final String? path = await super.download(
      info,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (path == null) return null;

    try {
      final File file = File(path);
      final int size = file.existsSync() ? file.lengthSync() : 0;
      if (size <= 0) {
        AppLog.w(_tag, 'La descarga está vacía: $path');
        if (file.existsSync()) await file.delete();
        return null;
      }
      _cachedPath = path;
      _cachedKey = key;
      AppLog.i(_tag, 'Descarga verificada: $path ($size bytes)');
      return path;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo verificar la descarga', error, stack);
      return null;
    }
  }

  /// Descarta la copia reutilizable (por ejemplo al cambiar de release).
  void clearCachedDownload() {
    _cachedPath = null;
    _cachedKey = null;
  }

  /// Comprueba si Android permite instalar el APK descargado.
  ///
  /// En Android O+ depende de `REQUEST_INSTALL_PACKAGES`. Se consulta antes de
  /// abrir el instalador para no confundir un permiso ausente con un error de
  /// firma o de archivo corrupto.
  Future<bool> canInstallApk() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo consultar el permiso de instalación',
        error,
        stack,
      );
      return false;
    }
  }

  /// Huella SHA256 de la firma de la app instalada (solo Android).
  ///
  /// Se usa en el informe de diagnóstico para explicar de un vistazo por qué
  /// Android podría rechazar una actualización.
  Future<String?> installedSignatureFingerprint() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'installedSignatureFingerprint',
      );
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo leer la huella de la firma instalada',
        error,
        stack,
      );
      return null;
    }
  }

  /// Pide el permiso de "instalar aplicaciones desconocidas" si falta.
  ///
  /// Devuelve `true` cuando ya se puede instalar. Cuando abre los ajustes el
  /// llamador debe esperar al reinicio de la app y volver a comprobarlo.
  Future<bool> ensureInstallPermission() async {
    if (!Platform.isAndroid) return false;
    if (await canInstallApk()) return true;
    return openInstallPermissionSettings();
  }

  /// Lee la firma/versión del APK sin instalarlo.
  Future<ApkInspection?> inspectApk(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final Object? raw = await _channel.invokeMethod<Object?>(
        'inspectApk',
        <String, Object?>{'path': path},
      );
      return raw == null ? null : ApkInspection.fromMap(raw);
    } on PlatformException catch (error) {
      AppLog.w(_tag, 'No se pudo inspeccionar el APK (${error.code})', error);
      return null;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo inspeccionar el APK', error, stack);
      return null;
    }
  }

  /// Instala un APK descargado en Android mediante `FileProvider`.
  ///
  /// El APK descargado queda en `Descargas/Polaris Music/Updates`; el canal
  /// nativo lo copia a `cacheDir/updates`, comprueba el permiso de instalación
  /// y lo comparte con el instalador del sistema mediante `FileProvider`.
  /// Antes de abrirlo se valida paquete, firma y versión para convertir el
  /// genérico "conflicto para instalar este paquete" en un mensaje útil.
  ///
  /// El resultado indica únicamente que el intent se abrió. El desenlace real
  /// llega después por [installOutcomes] porque el usuario puede cancelar el
  /// instalador del sistema o este puede rechazar el APK.
  Future<ApkInstallResult> installApk(String path) async {
    if (!Platform.isAndroid) return ApkInstallResult.failed;

    final File file = File(path);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      AppLog.w(_tag, 'APK no válido antes de instalar: $path');
      return ApkInstallResult.failed;
    }

    try {
      if (!await canInstallApk()) {
        return ApkInstallResult.permissionRequired;
      }

      final ApkInspection? inspection = await inspectApk(path);
      if (inspection != null) {
        if (!inspection.samePackage) return ApkInstallResult.wrongPackage;
        if (!inspection.signatureMatches) {
          AppLog.w(
            _tag,
            'Firma distinta: instalada ${inspection.installedVersionCode}, '
            'APK ${inspection.versionCode}',
          );
          return ApkInstallResult.signatureMismatch;
        }
        if (inspection.versionCode < inspection.installedVersionCode &&
            inspection.installedVersionCode > 0) {
          return ApkInstallResult.olderVersion;
        }
      }

      final bool? started = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object?>{'path': path},
      );
      return started == true
          ? ApkInstallResult.started
          : ApkInstallResult.failed;
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION_REQUIRED') {
        return ApkInstallResult.permissionRequired;
      }
      AppLog.w(
        _tag,
        'El instalador de Android rechazó el APK (${error.code}): '
        '${error.details ?? error.message}',
        error,
      );
      return ApkInstallResult.failed;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir el instalador de Android', error, stack);
      return ApkInstallResult.failed;
    }
  }

  /// Abre los ajustes de "instalar aplicaciones desconocidas".
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openInstallSettings',
      );
      return opened ?? false;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo abrir los ajustes de instalación',
        error,
        stack,
      );
      return false;
    }
  }
}
