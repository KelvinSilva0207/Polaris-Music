import 'dart:async' show unawaited;
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/update_info.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/app_shutdown.dart';
import '../../../core/services/app_updater_service.dart';
import '../../../core/theme/theme_tokens.dart';

/// Aviso de nueva versión que aparece 3 s después del arranque.
///
/// Reutiliza los tokens del tema activo y el mismo `AppUpdaterService` que la
/// sección manual de Ajustes, para que no haya dos caminos de descarga. El
/// permiso de instalación se pide ANTES de descargar y el APK queda guardado:
/// al volver de Ajustes se reanuda la instalación sin descargar dos veces.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => UpdateDialog(info: info),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog>
    with WidgetsBindingObserver {
  double? _progress;
  String? _status;
  bool _working = false;
  String? _apkPath;
  bool _awaitingPermission = false;
  bool _awaitingInstallOutcome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// El usuario vuelve de "instalar aplicaciones desconocidas": continuamos
  /// con el APK ya descargado (o lo descargamos una sola vez si aún no estaba).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingPermission) return;
    _awaitingPermission = false;
    unawaited(_resumeAfterPermission());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(apkInstallOutcomeProvider, (
      _,
      AsyncValue<ApkInstallOutcome> next,
    ) {
      final ApkInstallOutcome? outcome = next.valueOrNull;
      if (outcome == null || !_awaitingInstallOutcome) return;
      _awaitingInstallOutcome = false;
      if (!mounted) return;
      setState(() {
        _working = false;
        _progress = outcome == ApkInstallOutcome.installed ? 1 : null;
        _status = switch (outcome) {
          ApkInstallOutcome.installed =>
            'Actualización instalada. El sistema abrirá Polaris al terminar.',
          ApkInstallOutcome.cancelled =>
            'Instalación cancelada. El APK sigue listo: pulsa «Instalar '
                'descarga» para reintentarlo.',
          ApkInstallOutcome.failed =>
            'El sistema no pudo instalar el APK. Comprueba el archivo '
                'descargado e inténtalo de nuevo.',
        };
      });
    });
    final PolarisTokens tokens = context.tokens;
    final UpdateInfo info = widget.info;

    final String buttonLabel = _working
        ? 'Actualizando…'
        : _apkPath != null && Platform.isAndroid
        ? 'Instalar descarga'
        : 'Descargar e instalar';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: tokens.panelDecoration(
            radius: 24,
            glow: tokens.accent.withValues(alpha: 0.22),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nueva versión disponible',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    _VersionChip(label: 'Instalada: v${info.currentVersion}'),
                    _VersionChip(
                      label: 'Disponible: v${info.latestVersion}',
                      highlight: true,
                    ),
                  ],
                ),
                if (info.title.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    info.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
                if (info.publishedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Publicada el ${info.publishedAt!.toLocal().toString().split(' ').first}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                  ),
                if (info.changelog.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Novedades',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Text(
                        info.changelog.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: context.inkAlpha(0.70),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_progress != null || _status != null) ...<Widget>[
                  const SizedBox(height: 18),
                  if (_progress != null)
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: context.inkAlpha(0.12),
                      color: tokens.accent,
                      minHeight: 6,
                    ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _status!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.inkAlpha(0.70),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Más tarde'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _working || info.downloadUrl == null
                          ? null
                          : () => unawaited(_update()),
                      icon: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _apkPath == null
                                  ? Icons.download_rounded
                                  : Icons.install_mobile_rounded,
                              size: 18,
                            ),
                      label: Text(buttonLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _update() async {
    if (_working) return;
    final AppUpdaterService updater = ref.read(appUpdaterServiceProvider);

    // En Android el permiso va PRIMERO: así no se descargan ~100 MB para
    // después descubrir que no se puede instalar. Al volver de Ajustes se
    // reanuda automáticamente (ver didChangeAppLifecycleState).
    if (Platform.isAndroid && !await updater.canInstallApk()) {
      if (!mounted) return;
      _awaitingPermission = true;
      setState(() {
        _status =
            'Activa «Instalar aplicaciones desconocidas» en Ajustes. '
            'Al volver continuará la descarga y la instalación.';
      });
      final bool opened = await updater.openInstallPermissionSettings();
      if (!mounted || opened) return;
      setState(() {
        _status =
            'No se pudieron abrir los ajustes de instalación. Activa '
            '«Instalar aplicaciones desconocidas» manualmente y vuelve.';
      });
      return;
    }

    await _downloadAndInstall(updater);
  }

  Future<void> _resumeAfterPermission() async {
    if (!mounted || _working) return;
    final AppUpdaterService updater = ref.read(appUpdaterServiceProvider);
    if (!await updater.canInstallApk()) {
      if (!mounted) return;
      setState(() {
        _status =
            'El permiso sigue desactivado. Actívalo en Ajustes y vuelve '
            'a Polaris Music para continuar.';
      });
      return;
    }
    await _downloadAndInstall(updater);
  }

  Future<void> _downloadAndInstall(AppUpdaterService updater) async {
    setState(() {
      _working = true;
      _progress = _apkPath == null ? 0 : 1;
      _status = _apkPath == null
          ? 'Descargando actualización…'
          : 'Preparando la instalación…';
    });

    String? path = _apkPath;
    if (path == null ||
        !File(path).existsSync() ||
        File(path).lengthSync() <= 0) {
      path = await updater.download(
        widget.info,
        onProgress: (int received, int total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _progress = (received / total).clamp(0.0, 1.0);
            _status =
                'Descargando ${(received / 1048576).toStringAsFixed(1)} MB '
                'de ${(total / 1048576).toStringAsFixed(1)} MB';
          });
        },
      );
    }
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _working = false;
        _progress = null;
        _status = 'La descarga no se pudo completar. Inténtalo de nuevo.';
      });
      return;
    }
    _apkPath = path;

    if (Platform.isWindows) {
      setState(() => _status = 'Preparando el instalador…');
      final bool started = await updater.installDownloadedUpdate(path);
      if (!mounted) return;
      if (!started) {
        setState(() {
          _working = false;
          _progress = null;
          _status = 'No se pudo iniciar el instalador.';
        });
        return;
      }
      // El helper ya lanzado espera a que este proceso termine. Cerramos Drift,
      // bandeja y DLLs antes de salir para que Inno Setup no encuentre bloqueos.
      await AppShutdown.forWindowsUpdate();
      return;
    }

    if (Platform.isAndroid) {
      setState(() {
        _status = 'Confirma la instalación en el sistema…';
        _awaitingInstallOutcome = true;
      });
      final ApkInstallResult result = await updater.installApk(path);
      if (!mounted) return;
      if (result != ApkInstallResult.started) _awaitingInstallOutcome = false;
      switch (result) {
        case ApkInstallResult.permissionRequired:
          // El permiso pudo revocarse mientras se descargaba: conservamos el
          // APK y reanudamos al volver de Ajustes, sin descargarlo otra vez.
          _awaitingPermission = true;
          final bool opened = await updater.openInstallPermissionSettings();
          if (!mounted) return;
          setState(() {
            _working = false;
            _status = opened
                ? 'Activa el permiso de instalación y vuelve a Polaris '
                      'Music. La descarga ya está lista.'
                : 'No se pudieron abrir los ajustes de instalación. Activa '
                      '«Instalar aplicaciones desconocidas» manualmente.';
          });
        case ApkInstallResult.wrongPackage:
          setState(() {
            _working = false;
            _status =
                'El APK descargado no corresponde a Polaris Music. '
                'Abre la release desde Ajustes para instalarlo manualmente.';
          });
        case ApkInstallResult.signatureMismatch:
          setState(() {
            _working = false;
            _status =
                'La copia instalada tiene otra firma (viene de una '
                'versión anterior a la firma definitiva). Desinstala Polaris '
                'Music una sola vez e instala el APK de la release; desde '
                'entonces las actualizaciones conservarán tus datos.';
          });
        case ApkInstallResult.olderVersion:
          setState(() {
            _working = false;
            _status =
                'El APK descargado es más antiguo que la versión '
                'instalada. Comprueba «Buscar actualizaciones» en Ajustes.';
          });
        case ApkInstallResult.failed:
          setState(() {
            _working = false;
            _status =
                'No se pudo abrir el instalador. Comprueba el APK '
                'descargado y vuelve a intentarlo.';
          });
        case ApkInstallResult.started:
          setState(() {
            _working = false;
            _progress = 1;
            _status = 'Descarga lista. Confirma la instalación en el sistema.';
          });
      }
      return;
    }

    await updater.openDownloadedFile(path);
    if (mounted) Navigator.of(context).pop();
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: 0.16)
            : context.inkAlpha(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: 0.5)
              : context.inkAlpha(0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          color: highlight ? accent : context.inkAlpha(0.70),
        ),
      ),
    );
  }
}
