import 'dart:async' show unawaited;
import 'dart:io' show Platform;

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
/// sección manual de Ajustes, para que no haya dos caminos de descarga.
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

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  double? _progress;
  String? _status;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final UpdateInfo info = widget.info;

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
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _working ? 'Actualizando…' : 'Descargar e instalar',
                      ),
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
    setState(() {
      _working = true;
      _progress = 0;
      _status = 'Descargando actualización…';
    });

    final updater = ref.read(appUpdaterServiceProvider);
    final String? path = await updater.download(
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
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _working = false;
        _progress = null;
        _status = 'La descarga no se pudo completar. Inténtalo de nuevo.';
      });
      return;
    }

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
      setState(() => _status = 'Abriendo el instalador de Android…');
      final ApkInstallResult result = await updater.installApk(path);
      if (!mounted) return;
      switch (result) {
        case ApkInstallResult.permissionRequired:
          await updater.openInstallPermissionSettings();
          if (!mounted) return;
          setState(() {
            _working = false;
            _progress = null;
            _status =
                'Permite instalar aplicaciones desconocidas y pulsa '
                '«Descargar e instalar» de nuevo.';
          });
        case ApkInstallResult.failed:
          setState(() {
            _working = false;
            _progress = null;
            _status =
                'No se pudo abrir el instalador. Comprueba el APK descargado '
                'y vuelve a intentarlo.';
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
