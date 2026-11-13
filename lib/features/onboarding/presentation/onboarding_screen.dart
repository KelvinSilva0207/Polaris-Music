import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../library/presentation/library_providers.dart';

/// Introducción de 3 pasos: bienvenida, permisos y selección de carpetas.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _busy = false;
  int _foldersAdded = 0;
  String? _permissionMessage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= 2) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _pages.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish({bool scan = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (scan && _foldersAdded > 0) {
        await ref.read(scanControllerProvider.notifier).scan();
      }
      await ref.read(settingsServiceProvider).markOnboardingDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(permissionServiceProvider)
          .requestLibraryAccess();
      setState(() {
        _permissionMessage = result.granted
            ? 'Acceso concedido. Ya puedes elegir tus carpetas de música.'
            : (result.message ?? 'Permiso denegado.');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFolder() async {
    setState(() => _busy = true);
    try {
      final String? path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona tu carpeta de música',
      );
      if (path == null) return;
      await ref
          .read(libraryRepositoryProvider)
          .addFolderFromPicker(path, recursive: true);
      if (mounted) {
        setState(() => _foldersAdded++);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo añadir la carpeta: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF0B0710),
              tokens.accent.withValues(alpha: 0.18),
              const Color(0xFF0B0710),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (int value) =>
                          setState(() => _index = value),
                      children: <Widget>[
                        _WelcomePage(accent: tokens.accent),
                        _PermissionsPage(
                          message: _permissionMessage,
                          busy: _busy,
                          onRequest: _requestPermission,
                        ),
                        _LibraryPage(
                          foldersAdded: _foldersAdded,
                          busy: _busy,
                          onPick: _pickFolder,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(3, (int index) {
                            final bool active = index == _index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? tokens.accent
                                    : Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            if (_index > 0)
                              TextButton(
                                onPressed: _busy ? null : _back,
                                child: const Text('Atrás'),
                              ),
                            const Spacer(),
                            if (_index == 2)
                              TextButton(
                                onPressed: _busy ? null : () => _finish(),
                                child: const Text('Omitir por ahora'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _busy ? null : _next,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _index == 2
                                          ? Icons.check_rounded
                                          : Icons.arrow_forward_rounded,
                                    ),
                              label: Text(
                                _index == 2
                                    ? 'Empezar a escuchar'
                                    : 'Continuar',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 12),
      child: Column(
        children: <Widget>[
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.9),
                  accent.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Icon(
              Icons.public_rounded,
              size: 62,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 38, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu universo sonoro, en orden.',
            style: TextStyle(color: Colors.white60, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const <Widget>[
              _FeatureChip(
                icon: Icons.hd_rounded,
                label: 'Audio de alta calidad',
              ),
              _FeatureChip(
                icon: Icons.lyrics_outlined,
                label: 'Letras y karaoke',
              ),
              _FeatureChip(
                icon: Icons.graphic_eq_rounded,
                label: 'EQ de 10 bandas',
              ),
              _FeatureChip(icon: Icons.bedtime_outlined, label: 'Temporizador'),
              _FeatureChip(icon: Icons.insights_rounded, label: 'Estadísticas'),
              _FeatureChip(
                icon: Icons.desktop_windows_outlined,
                label: 'Windows y Android',
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Polaris indexa tu música local, lee sus etiquetas y carátulas, '
            'y te deja escucharla sin distracciones. Todo se guarda en tu '
            'equipo: sin cuentas ni nube obligatoria.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: context.tokens.accent),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({
    required this.message,
    required this.busy,
    required this.onRequest,
  });

  final String? message;
  final bool busy;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Permisos',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Polaris solo lee los archivos de las carpetas que elijas. Nada se '
            'sube a internet salvo las búsquedas de letras que tú provoques.',
            style: TextStyle(color: Colors.white60, height: 1.5),
          ),
          const SizedBox(height: 24),
          const _PermissionRow(
            icon: Icons.audio_file_outlined,
            title: 'Leer archivos de audio',
            subtitle:
                'Necesario en Android (READ_MEDIA_AUDIO). En Windows no hace '
                'falta ningún permiso.',
          ),
          const _PermissionRow(
            icon: Icons.folder_shared_outlined,
            title: 'Acceso a carpetas (opcional)',
            subtitle:
                'Solo si guardas música fuera de las carpetas multimedia del '
                'sistema. Puedes activarlo más tarde en Ajustes.',
          ),
          const _PermissionRow(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones (opcional)',
            subtitle:
                'Para mostrar los controles de reproducción en la pantalla de '
                'bloqueo de Android.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onRequest,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Conceder acceso a la música'),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              message!,
              style: TextStyle(
                color: message!.toLowerCase().contains('concedido')
                    ? context.tokens.accent
                    : Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.tokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: context.tokens.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.foldersAdded,
    required this.busy,
    required this.onPick,
  });

  final int foldersAdded;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tu música',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Añade una o varias carpetas. Polaris recorrerá sus subcarpetas y '
            'leerá título, artista, álbum, carátula y letras embebidas.',
            style: TextStyle(color: Colors.white60, height: 1.5),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.create_new_folder_outlined,
                  size: 48,
                  color: context.tokens.accent,
                ),
                const SizedBox(height: 14),
                Text(
                  foldersAdded == 0
                      ? 'Todavía no has añadido carpetas'
                      : '$foldersAdded carpeta${foldersAdded == 1 ? '' : 's'} añadida${foldersAdded == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Puedes añadir más desde Ajustes → Biblioteca.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: busy ? null : onPick,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Seleccionar carpeta'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Formatos habituales: MP3, FLAC, WAV, AAC/M4A, OGG, Opus, WMA, '
            'APEv2, AIFF, DSF y más.',
            style: TextStyle(fontSize: 12, color: Colors.white38, height: 1.5),
          ),
        ],
      ),
    );
  }
}
