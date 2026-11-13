import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/update_info.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/dynamic_island/domain/dynamic_island_controller.dart';
import '../../../features/dynamic_island/presentation/island_providers.dart';
import '../../../features/library/presentation/library_providers.dart';
import '../../../features/player/domain/player_controller.dart';
import '../../../features/player/presentation/player_providers.dart';
import '../../../features/profiles_backup/domain/profiles_service.dart';
import '../../../features/profiles_backup/presentation/profiles_providers.dart';
import '../../../shared/widgets/polaris_surface.dart';
import 'customization_screen.dart';

/// Ajustes de Polaris Music: apariencia, audio, ventana, respaldos y más.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final ThemeState theme = ref.watch(themeControllerProvider);
    final AppThemeConfig config = theme.config;
    final Color accent = config.accent;
    final PlayerUiState player = ref.watch(playerControllerProvider);
    final DynamicIslandState island = ref.watch(
      dynamicIslandControllerProvider,
    );
    final WindowService window = ref.watch(windowServiceProvider);
    final bool scanOnStartup = ref
        .watch(settingsServiceProvider)
        .boolOr(AppConstants.keyScanOnStartup, fallback: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: <Widget>[
        Text(
          'Ajustes',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 2),
        const Text(
          'Personaliza Polaris a tu manera',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 22),
        _Section(
          title: 'Apariencia',
          icon: Icons.palette_outlined,
          children: <Widget>[
            const _SettingLabel(
              title: 'Temas base',
              subtitle: 'Aplica un diseño completo con un solo toque',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppThemeConfig.builtInPresets
                  .map(
                    (AppThemeConfig preset) => _PresetChip(
                      config: preset,
                      selected: config.preset == preset.preset,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .applyPreset(preset.preset),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            const _SettingLabel(
              title: 'Color de acento',
              subtitle: 'Se aplica al instante en toda la app',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppTheme.accentChoices
                  .map(
                    (Color color) => _AccentDot(
                      color: color,
                      selected: color.toARGB32() == accent.toARGB32(),
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .setAccent(color),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const CustomizationScreen(),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Personalización avanzada'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Reproducción',
          icon: Icons.graphic_eq_rounded,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ReplayGain'),
              subtitle: const Text(
                'Normaliza el volumen usando las etiquetas de la pista',
              ),
              value: player.replayGainEnabled,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setReplayGainEnabled(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reproducción sin pausas (gapless)'),
              subtitle: const Text(
                'Delegado al motor mpv: une pistas del mismo álbum',
              ),
              value: player.gaplessEnabled,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setGaplessEnabled(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Crossfade entre pistas'),
              subtitle: const Text(
                'El fundido real requiere dos motores simultáneos; pendiente',
              ),
              value: player.crossfadeEnabled,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setCrossfade(enabled: value),
            ),
            if (player.crossfadeEnabled)
              Row(
                children: <Widget>[
                  const SizedBox(width: 4),
                  const Text('Duración', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: player.crossfadeMs.toDouble().clamp(0, 12000),
                      min: 0,
                      max: 12000,
                      divisions: 24,
                      onChanged: (double value) => ref
                          .read(playerControllerProvider.notifier)
                          .setCrossfade(enabled: true, ms: value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      '${(player.crossfadeMs / 1000).toStringAsFixed(1)} s',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Biblioteca',
          icon: Icons.library_music_outlined,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Escanear al iniciar'),
              subtitle: const Text(
                'Reindexa las carpetas configuradas al abrir la app',
              ),
              value: scanOnStartup,
              onChanged: (bool value) async {
                await ref
                    .read(settingsServiceProvider)
                    .setBool(AppConstants.keyScanOnStartup, value);
                setState(() {});
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate(1),
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('Gestionar carpetas'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(scanControllerProvider.notifier).scan(),
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('Escanear ahora'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Duplicados'),
                      content: const Text(
                        'La detección de duplicados está disponible en la '
                        'pantalla de Biblioteca.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Duplicados'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Isla dinámica',
          icon: Icons.picture_in_picture_alt_rounded,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar isla flotante'),
              subtitle: const Text(
                'Muestra la pista actual y controles rápidos sobre la interfaz',
              ),
              value: island.enabled,
              onChanged: (bool value) => ref
                  .read(dynamicIslandControllerProvider.notifier)
                  .setEnabled(value),
            ),
          ],
        ),
        if (window.isSupported) ...<Widget>[
          const SizedBox(height: 16),
          _Section(
            title: 'Ventana',
            icon: Icons.desktop_windows_outlined,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Siempre encima'),
                subtitle: const Text('Mantiene la ventana sobre otras apps'),
                value: window.alwaysOnTop,
                onChanged: (bool value) async {
                  await window.setAlwaysOnTop(value);
                  setState(() {});
                },
              ),
              const SizedBox(height: 6),
              const _SettingLabel(
                title: 'Modo de ventana',
                subtitle: 'Normal, mini barra o teléfono flotante',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _ModeButton(
                    icon: Icons.crop_square_rounded,
                    label: 'Normal',
                    selected: window.mode == WindowMode.normal,
                    onPressed: () async {
                      await window.setMode(WindowMode.normal);
                      setState(() {});
                    },
                  ),
                  _ModeButton(
                    icon: Icons.view_agenda_outlined,
                    label: 'Mini barra',
                    selected: window.mode == WindowMode.mini,
                    onPressed: () async {
                      await window.setMode(WindowMode.mini);
                      setState(() {});
                    },
                  ),
                  _ModeButton(
                    icon: Icons.phone_android_rounded,
                    label: 'Teléfono',
                    selected: window.mode == WindowMode.phone,
                    onPressed: () async {
                      await window.setMode(WindowMode.phone);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await window.toggleSideHidden();
                  setState(() {});
                },
                icon: const Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  size: 18,
                ),
                label: Text(
                  window.sideHidden
                      ? 'Mostrar ventana'
                      : 'Ocultar al borde (estilo AIMP)',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const _ProfilesSection(),
        const SizedBox(height: 16),
        const _PermissionsSection(),
        const SizedBox(height: 16),
        const _UpdateSection(),
        const SizedBox(height: 16),
        _Section(
          title: 'Acerca de',
          icon: Icons.info_outline_rounded,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code_rounded),
              title: const Text('Créditos y tecnologías'),
              subtitle: const Text('Flutter, media_kit, Drift y más'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showCredits(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public_rounded),
              title: const Text('Repositorio en GitHub'),
              subtitle: Text(
                '${AppConstants.githubOwner}/${AppConstants.githubRepo}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => ref
                  .read(updateServiceProvider)
                  .openReleasePage(UpdateInfo.upToDate),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.replay_rounded),
              title: const Text('Repetir introducción'),
              subtitle: const Text('Vuelve a ver la bienvenida y los permisos'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await ref
                    .read(settingsServiceProvider)
                    .setBool(AppConstants.keyOnboardingDone, false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La introducción se mostrará la próxima vez que abras '
                        'Polaris.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showCredits(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersionFallback,
      applicationIcon: const Icon(Icons.public_rounded, size: 40),
      applicationLegalese:
          '© ${DateTime.now().year} Kelvin Silva · Hecho con cariño para '
          'escuchar música como se merece.',
      children: <Widget>[
        const SizedBox(height: 12),
        const Text(
          'Polaris Music es un reproductor modular para Windows y Android.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tecnologías principales:',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '· Flutter + Riverpod + GetIt\n'
          '· media_kit (libmpv) para decodificación\n'
          '· Drift + SQLite para la biblioteca\n'
          '· audio_service y smtc_windows para la sesión de medios\n'
          '· LRCLIB para letras sincronizadas\n'
          '· audio_metadata_reader para etiquetas\n'
          '· window_manager y tray_manager para el escritorio',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 10),
        const Text(
          'El ecualizador de 10 bandas aplica filtros reales mediante libmpv en '
          'Windows y Android. El crossfade sigue pendiente porque requiere dos '
          'motores reproduciendo a la vez.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return PolarisSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
            : null,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.config,
    required this.selected,
    required this.onTap,
  });

  final AppThemeConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: config.accent.withValues(alpha: selected ? 0.20 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: config.accent.withValues(alpha: selected ? 0.85 : 0.25),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: config.backdrop),
                border: Border.all(color: config.accent.withValues(alpha: 0.9)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              config.preset.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, size: 15, color: config.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: tokens.accent),
            label: Text(label),
          );
  }
}

class _ProfilesSection extends ConsumerWidget {
  const _ProfilesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProfileSummary>> profiles = ref.watch(
      profilesProvider,
    );

    return _Section(
      title: 'Perfiles y respaldo',
      icon: Icons.group_outlined,
      children: <Widget>[
        profiles.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text(
            'No se pudieron cargar los perfiles: $error',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          data: (List<ProfileSummary> list) => list.isEmpty
              ? const Text(
                  'Sin perfiles todavía. Crea uno para separar preferencias.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                )
              : Column(
                  children: list
                      .map(
                        (ProfileSummary profile) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            profile.isActive
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: profile.isActive
                                ? context.tokens.accent
                                : Colors.white38,
                          ),
                          title: Text(profile.name),
                          subtitle: Text(
                            profile.isActive
                                ? 'Perfil activo'
                                : 'Toca para activar',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: profile.isActive
                              ? null
                              : IconButton(
                                  tooltip: 'Eliminar perfil',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => ref
                                      .read(profilesServiceProvider)
                                      .delete(profile.id),
                                ),
                          onTap: profile.isActive
                              ? null
                              : () => ref
                                    .read(profilesServiceProvider)
                                    .activate(profile.id),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => _createProfile(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Nuevo perfil'),
            ),
            OutlinedButton.icon(
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Exportar respaldo'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(context, ref),
              icon: const Icon(Icons.unarchive_outlined, size: 18),
              label: const Text('Importar respaldo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El respaldo incluye preferencias, presets de EQ, listas, favoritos, '
          'letras y perfiles. Las pistas se referencian por ruta, así que la '
          'música debe estar en la misma ubicación para restaurarlas.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    final TextEditingController name = TextEditingController();
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nuevo perfil'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del perfil'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      await ref.read(profilesServiceProvider).create(name.text);
    }
    name.dispose();
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final bool? zip = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Exportar respaldo'),
        content: const Text(
          'Elige el formato. El ZIP ocupa menos y está listo para compartir; '
          'el JSON es legible y fácil de inspeccionar.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ZIP'),
          ),
        ],
      ),
    );
    if (zip == null) return;
    try {
      final String path = await ref
          .read(backupActionsProvider)
          .export(compress: zip);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Respaldo creado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Archivo guardado en:'),
                const SizedBox(height: 8),
                SelectableText(path, style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Selecciona un respaldo de Polaris',
        type: FileType.custom,
        allowedExtensions: <String>['zip', 'json'],
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el selector: $error')),
        );
      }
      return;
    }
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    try {
      final BackupSummary summary = await ref
          .read(backupActionsProvider)
          .import(File(path), merge: true);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Respaldo importado'),
          content: Text(
            '${summary.settings} preferencias · '
            '${summary.profiles} perfiles · '
            '${summary.eqPresets} presets de EQ · '
            '${summary.playlists} listas · '
            '${summary.favorites} favoritos · '
            '${summary.lyrics} letras',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
      }
    }
  }
}

class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool android = ref.read(permissionServiceProvider).isAndroid;
    return _Section(
      title: 'Permisos',
      icon: Icons.lock_outline_rounded,
      children: <Widget>[
        Text(
          android
              ? 'Android necesita acceso a los archivos de audio. El acceso '
                    'total solo es necesario para carpetas fuera de la colección '
                    'multimedia.'
              : 'Windows no requiere permisos en tiempo de ejecución: Polaris '
                    'solo lee las carpetas que añadas manualmente.',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () async {
                final result = await ref
                    .read(permissionServiceProvider)
                    .requestLibraryAccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.granted
                            ? 'Acceso a audio concedido'
                            : (result.message ?? 'Permiso denegado'),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.audio_file_outlined, size: 18),
              label: const Text('Acceso a audio'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final bool granted = await ref
                    .read(permissionServiceProvider)
                    .requestAllFilesAccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? 'Acceso total concedido'
                            : 'Acceso total no concedido',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.folder_shared_outlined, size: 18),
              label: const Text('Acceso total'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final bool granted = await ref
                    .read(permissionServiceProvider)
                    .requestNotifications();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? 'Notificaciones concedidas'
                            : 'Notificaciones no concedidas',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_outlined, size: 18),
              label: const Text('Notificaciones'),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(permissionServiceProvider).openSettings(),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Abrir ajustes del sistema'),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateSection extends ConsumerStatefulWidget {
  const _UpdateSection();

  @override
  ConsumerState<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<_UpdateSection> {
  double? _progress;
  String? _downloaded;
  bool _installing = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<String> current = ref.watch(currentVersionProvider);
    final AsyncValue<UpdateInfo?> latest = ref.watch(latestUpdateProvider);
    final bool canInstallHere = ref
        .watch(updateServiceProvider)
        .canInstallSilently;

    return _Section(
      title: 'Actualizaciones',
      icon: Icons.system_update_alt_rounded,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Versión instalada',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            current.when(
              loading: () => const Text('…'),
              error: (_, _) => const Text('desconocida'),
              data: (String value) => Text('v$value'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        latest.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text(
            'No se pudo consultar GitHub: $error',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          data: (UpdateInfo? info) {
            if (info == null) {
              return const Text(
                'Sin conexión con GitHub o no hay releases publicadas.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              );
            }
            if (!info.isUpdateAvailable) {
              return Text(
                'Estás al día. Última versión publicada: v${info.latestVersion}',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '¡Nueva versión disponible! v${info.latestVersion}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.tokens.accent,
                  ),
                ),
                if (info.title.isNotEmpty)
                  Text(
                    info.title,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                if (info.publishedAt != null)
                  Text(
                    'Publicada el ${Formatters.date(info.publishedAt!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                if (info.changelog.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Text(
                        info.changelog,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_progress != null) ...<Widget>[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${((_progress ?? 0) * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
                if (_downloaded != null) ...<Widget>[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Descargado en: $_downloaded',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (canInstallHere &&
                      _downloaded!.toLowerCase().endsWith('.exe')) ...<Widget>[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _installing ? null : () => _install(info),
                      icon: _installing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(
                        _installing
                            ? 'Iniciando instalador…'
                            : 'Instalar ahora',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'La app se cerrará para instalar la nueva versión y se '
                      'volverá a abrir automáticamente.',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(updateServiceProvider)
                          .openDownloadedFile(_downloaded!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir instalador'),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (info.downloadUrl != null)
                      FilledButton.icon(
                        onPressed: _progress != null || _installing
                            ? null
                            : () => _download(info),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Descargar'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(updateServiceProvider).openReleasePage(info),
                      icon: const Icon(Icons.public_rounded, size: 18),
                      label: const Text('Ver release'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(latestUpdateProvider);
                ref.invalidate(currentVersionProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Buscar actualizaciones'),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(updateServiceProvider).openDownloadsFolder(),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Carpeta de descargas'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _download(UpdateInfo info) async {
    setState(() {
      _progress = 0;
      _downloaded = null;
    });
    final String? path = await ref
        .read(updateServiceProvider)
        .download(
          info,
          onProgress: (int received, int total) {
            if (!mounted || total <= 0) return;
            setState(() => _progress = received / total);
          },
        );
    if (!mounted) return;
    setState(() {
      _progress = null;
      _downloaded = path;
    });
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descarga no se pudo completar')),
      );
    }
  }

  Future<void> _install(UpdateInfo info) async {
    final String? path = _downloaded;
    if (path == null || _installing) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Instalar actualización'),
        content: Text(
          'Polaris Music se cerrará para instalar la versión '
          '${info.latestVersion}.\n\n'
          'Al terminar, la app se abrirá automáticamente con la nueva '
          'versión. ¿Quieres continuar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Instalar y reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _installing = true);
    final bool started = await ref
        .read(updateServiceProvider)
        .installDownloadedUpdate(path);
    if (!mounted) return;

    if (!started) {
      setState(() => _installing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo iniciar el instalador. Inténtalo de nuevo.',
          ),
        ),
      );
      return;
    }

    // Da tiempo al instalador a arrancar antes de liberar el ejecutable.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    exit(0);
  }
}
