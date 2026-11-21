import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/update_info.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/update_prompt_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/app_shutdown.dart';
import '../../../core/services/app_updater_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/global_hotkey_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/dynamic_island/presentation/island_providers.dart';
import '../../../features/equalizer/presentation/equalizer_providers.dart';
import '../../../features/equalizer/presentation/equalizer_screen.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/library/presentation/library_providers.dart';
import '../../../features/player/domain/player_controller.dart';
import '../../../features/player/presentation/player_providers.dart';
import '../../../features/profiles_backup/domain/profiles_service.dart';
import '../../../features/profiles_backup/presentation/profiles_providers.dart';
import '../../../features/stats_sync/presentation/stats_screen.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/polaris_surface.dart';
import 'color_picker_dialog.dart';
import 'compact_styles_screen.dart';
import 'customization_screen.dart';
import 'typography_screen.dart';

/// Ajustes de Polaris Music: apariencia, audio, ventana, respaldos y más.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onNavigate});

  final ValueChanged<AppSection> onNavigate;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final ThemeState theme = ref.watch(themeControllerProvider);
    final AppThemeConfig config = theme.config;
    final Color accent = config.accent;
    final bool replayGain = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.replayGainEnabled),
    );
    final bool gapless = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.gaplessEnabled),
    );
    final bool crossfade = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.crossfadeEnabled),
    );
    final int crossfadeMs = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.crossfadeMs),
    );
    final bool silenceTrim = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.silenceTrimEnabled,
      ),
    );
    final int trimStartMs = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.silenceTrimStartMs,
      ),
    );
    final int trimEndMs = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.silenceTrimEndMs),
    );
    final bool islandEnabled = ref.watch(
      dynamicIslandControllerProvider.select((s) => s.enabled),
    );
    final WindowService window = ref.watch(windowServiceProvider);
    final SettingsService settings = ref.watch(settingsServiceProvider);
    // Suscripción reactiva: los interruptores se actualizan al persistir.
    ref.watch(settingsValuesProvider);
    final bool scanOnStartup = settings.boolOr(
      AppConstants.keyScanOnStartup,
      fallback: true,
    );
    final bool pauseOnHeadphonesDisconnect =
        settings.pauseOnHeadphonesDisconnect;
    final bool pauseOnVolumeZero = settings.pauseOnVolumeZero;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: <Widget>[
        Text(
          'Ajustes',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 2),
        Text(
          'Personaliza Polaris a tu manera',
          style: TextStyle(color: context.inkAlpha(0.54)),
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
              subtitle: 'Rueda cromática libre con HEX, HSL/HSV y RGB',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final Color? picked = await ColorPickerDialog.show(
                  context,
                  title: 'Color de acento',
                  initial: accent,
                );
                if (picked != null && mounted) {
                  await ref
                      .read(themeControllerProvider.notifier)
                      .setAccent(picked);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ColorMath.toHex(accent, withAlpha: true),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.colorize_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const CustomizationScreen(),
                ),
              ),
              icon: Icon(Icons.tune_rounded, size: 18),
              label: Text('Personalización avanzada'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const CompactStylesScreen(),
                ),
              ),
              icon: Icon(Icons.dashboard_customize_outlined, size: 18),
              label: Text('Diseños compactos (isla, mini, teléfono…)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const TypographyScreen(),
                ),
              ),
              icon: Icon(Icons.text_fields_rounded, size: 18),
              label: Text('Tipografía y fuentes propias'),
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
              title: Text('ReplayGain'),
              subtitle: Text(
                'Normaliza el volumen usando las etiquetas de la pista',
              ),
              value: replayGain,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setReplayGainEnabled(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pausar al desconectar auriculares'),
              subtitle: Text(
                'Detecta la desconexión o el cambio de salida de audio',
              ),
              value: pauseOnHeadphonesDisconnect,
              onChanged: (bool value) => settings.setBool(
                AppConstants.keyPauseOnHeadphonesDisconnect,
                value,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pausar si el volumen llega a cero'),
              subtitle: Text(
                'Tanto el deslizador de la app como el volumen multimedia',
              ),
              value: pauseOnVolumeZero,
              onChanged: (bool value) =>
                  settings.setBool(AppConstants.keyPauseOnVolumeZero, value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Reproducción sin pausas (gapless)'),
              subtitle: Text(
                'Delegado al motor mpv: une pistas del mismo álbum',
              ),
              value: gapless,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setGaplessEnabled(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Crossfade entre pistas'),
              subtitle: Text(
                'Dos decks mpv: la pista entrante se funde con la saliente',
              ),
              value: crossfade,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setCrossfade(enabled: value),
            ),
            if (crossfade)
              Row(
                children: <Widget>[
                  const SizedBox(width: 4),
                  Text('Duración', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: crossfadeMs.toDouble().clamp(0, 12000),
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
                      '${(crossfadeMs / 1000).toStringAsFixed(1)} s',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Omitir silencios largos'),
              subtitle: Text(
                'Recorta el inicio y el final de cada pista (offsets de mpv)',
              ),
              value: silenceTrim,
              onChanged: (bool value) => ref
                  .read(playerControllerProvider.notifier)
                  .setSilenceTrim(enabled: value),
            ),
            if (silenceTrim) ...<Widget>[
              _TrimSlider(
                label: 'Inicio',
                value: trimStartMs,
                onChanged: (int ms) => ref
                    .read(playerControllerProvider.notifier)
                    .setSilenceTrim(enabled: true, startMs: ms),
              ),
              _TrimSlider(
                label: 'Final',
                value: trimEndMs,
                onChanged: (int ms) => ref
                    .read(playerControllerProvider.notifier)
                    .setSilenceTrim(enabled: true, endMs: ms),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Biblioteca',
          icon: Icons.library_music_outlined,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Escanear al iniciar'),
              subtitle: Text(
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
                  onPressed: () => widget.onNavigate(AppSection.library),
                  icon: Icon(Icons.folder_outlined, size: 18),
                  label: Text('Gestionar carpetas'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(scanControllerProvider.notifier).scan(),
                  icon: Icon(Icons.radar_rounded, size: 18),
                  label: Text('Escanear ahora'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text('Duplicados'),
                      content: Text(
                        'La detección de duplicados está disponible en la '
                        'pantalla de Biblioteca.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Entendido'),
                        ),
                      ],
                    ),
                  ),
                  icon: Icon(Icons.copy_all_rounded, size: 18),
                  label: Text('Duplicados'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Inicio y estadísticas',
          icon: Icons.dashboard_customize_outlined,
          children: <Widget>[
            Text(
              'Polaris abre directamente en el reproductor. El resumen de '
              'bienvenida y las estadísticas de escucha están aquí para no '
              'ocupar la navegación principal.',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => Scaffold(
                        appBar: AppBar(title: Text('Resumen')),
                        body: HomeScreen(onNavigate: widget.onNavigate),
                      ),
                    ),
                  ),
                  icon: Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text('Resumen y bienvenida'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const Scaffold(body: StatsScreen()),
                    ),
                  ),
                  icon: Icon(Icons.insights_rounded, size: 18),
                  label: Text('Estadísticas'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Ecualizador',
          icon: Icons.graphic_eq_rounded,
          children: <Widget>[
            Text(
              'Diez bandas de estudio, preamplificador y curvas guardadas. '
              'También disponible desde los controles del reproductor.',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => Scaffold(
                    appBar: AppBar(title: Text('Ecualizador')),
                    body: const EqualizerScreen(),
                  ),
                ),
              ),
              icon: Icon(Icons.equalizer_rounded, size: 18),
              label: Text('Abrir ecualizador'),
            ),
          ],
        ),
        if (Platform.isWindows) ...<Widget>[
          const SizedBox(height: 16),
          const _HotkeysSection(),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Isla dinámica',
          icon: Icons.picture_in_picture_alt_rounded,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Minimizar a isla flotante'),
              subtitle: Text(
                'Al minimizar, la ventana se transforma en una isla siempre '
                'encima con carátula y controles rápidos',
              ),
              value: islandEnabled,
              onChanged: (bool value) => ref
                  .read(dynamicIslandControllerProvider.notifier)
                  .setEnabled(value),
            ),
          ],
        ),
        if (window.isSupported) ...<Widget>[
          const SizedBox(height: 16),
          ValueListenableBuilder<WindowUiState>(
            valueListenable: ref.watch(windowStateProvider),
            builder: (BuildContext context, WindowUiState state, Widget? _) {
              return _Section(
                title: 'Ventana',
                icon: Icons.desktop_windows_outlined,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Siempre encima'),
                    subtitle: Text('Mantiene la ventana sobre otras apps'),
                    value: state.alwaysOnTop,
                    onChanged: window.setAlwaysOnTop,
                  ),
                  const SizedBox(height: 6),
                  const _SettingLabel(
                    title: 'Modo de ventana',
                    subtitle: 'Normal, isla, mini barra o teléfono flotante',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _ModeButton(
                        icon: Icons.crop_square_rounded,
                        label: 'Normal',
                        selected: state.mode == WindowMode.normal,
                        onPressed: () => window.setMode(WindowMode.normal),
                      ),
                      _ModeButton(
                        icon: Icons.picture_in_picture_alt_rounded,
                        label: 'Isla',
                        selected: state.mode == WindowMode.island,
                        onPressed: () => window.showIsland(),
                      ),
                      _ModeButton(
                        icon: Icons.view_agenda_outlined,
                        label: 'Mini barra',
                        selected: state.mode == WindowMode.mini,
                        onPressed: () => window.setMode(WindowMode.mini),
                      ),
                      _ModeButton(
                        icon: Icons.phone_android_rounded,
                        label: 'Teléfono',
                        selected: state.mode == WindowMode.phone,
                        onPressed: () => window.setMode(WindowMode.phone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: window.toggleSideHidden,
                    icon: Icon(
                      state.sideHidden
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 18,
                    ),
                    label: Text(
                      state.sideHidden
                          ? 'Mostrar ventana'
                          : 'Ocultar al borde (estilo AIMP)',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        const _ProfilesSection(),
        const SizedBox(height: 16),
        const _PermissionsSection(),
        if (Platform.isAndroid) ...<Widget>[
          const SizedBox(height: 16),
          _Section(
            title: 'Cierre de la aplicación',
            icon: Icons.power_settings_new_rounded,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.power_off_rounded),
                title: Text('Cerrar aplicación completamente'),
                subtitle: Text(
                  'Detiene el audio, quita la notificación y finaliza Polaris.',
                ),
                onTap: _confirmFullExit,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const _UpdateSection(),
        const SizedBox(height: 16),
        _Section(
          title: 'Acerca de',
          icon: Icons.info_outline_rounded,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.code_rounded),
              title: Text('Créditos y tecnologías'),
              subtitle: Text('Flutter, media_kit, Drift y más'),
              trailing: Icon(Icons.chevron_right_rounded),
              onTap: () => _showCredits(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const PolarisLogo(size: 26),
              title: Text('Repositorio en GitHub'),
              subtitle: Text(
                '${AppConstants.githubOwner}/${AppConstants.githubRepo}',
              ),
              trailing: Icon(Icons.chevron_right_rounded),
              onTap: () => ref
                  .read(updateServiceProvider)
                  .openReleasePage(UpdateInfo.upToDate),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.replay_rounded),
              title: Text('Repetir introducción'),
              subtitle: Text('Vuelve a ver la bienvenida y los permisos'),
              trailing: Icon(Icons.chevron_right_rounded),
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

  Future<void> _confirmFullExit() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Cerrar Polaris por completo'),
        content: Text(
          'Se detendrá la reproducción y desaparecerá la notificación '
          'persistente de Android. ¿Continuar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ServiceLocator.shutdownAndroid();
    exit(0);
  }

  void _showCredits(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersionFallback,
      applicationIcon: const PolarisLogo(size: 44),
      applicationLegalese:
          '© ${DateTime.now().year} Kelvin Silva · Hecho con cariño para '
          'escuchar música como se merece.',
      children: <Widget>[
        const SizedBox(height: 12),
        Text(
          'Polaris Music es un reproductor modular para Windows y Android.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Text(
          'Tecnologías principales:',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
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
        Text(
          'El ecualizador de 10 bandas aplica filtros reales mediante libmpv en '
          'Windows y Android. El crossfade sigue pendiente porque requiere dos '
          'motores reproduciendo a la vez.',
          style: TextStyle(fontSize: 12, color: context.inkAlpha(0.60)),
        ),
      ],
    );
  }
}

class _TrimSlider extends StatelessWidget {
  const _TrimSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 4),
        SizedBox(width: 42, child: Text(label, style: TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(0, 15000),
            min: 0,
            max: 15000,
            divisions: 30,
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(
            '${(value / 1000).toStringAsFixed(1)} s',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12),
          ),
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
        Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
        ),
      ],
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
        duration: context.motion.duration(const Duration(milliseconds: 220)),
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

/// Atajos globales de Windows: funcionan aunque Polaris esté minimizado.
class _HotkeysSection extends ConsumerWidget {
  const _HotkeysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalHotkeyService service = ref.watch(globalHotkeyServiceProvider);
    if (!service.isSupported) return const SizedBox.shrink();

    return ValueListenableBuilder<Map<HotkeyAction, HotkeyBinding>>(
      valueListenable: service.bindings,
      builder:
          (
            BuildContext context,
            Map<HotkeyAction, HotkeyBinding> bindings,
            Widget? _,
          ) {
            return ValueListenableBuilder<String?>(
              valueListenable: service.lastError,
              builder: (BuildContext context, String? error, Widget? _) {
                final PolarisTokens tokens = context.tokens;
                return _Section(
                  title: 'Atajos de teclado',
                  icon: Icons.keyboard_alt_outlined,
                  children: <Widget>[
                    Text(
                      'Funcionan con Polaris minimizado o en la bandeja. '
                      'Dentro de la app, la barra espaciadora reproduce o '
                      'pausa.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final HotkeyAction action in HotkeyAction.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(switch (action) {
                          HotkeyAction.playPause =>
                            Icons.play_circle_outline_rounded,
                          HotkeyAction.next => Icons.skip_next_rounded,
                          HotkeyAction.previous => Icons.skip_previous_rounded,
                        }, color: tokens.accent),
                        title: Text(GlobalHotkeyService.labelFor(action)),
                        subtitle: Text(
                          (bindings[action] ?? service.bindingFor(action))
                              .label,
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed: () => _capture(context, service, action),
                          child: Text('Cambiar'),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                error,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: service.resetDefaults,
                      icon: Icon(Icons.restore_rounded, size: 18),
                      label: Text('Restablecer atajos'),
                    ),
                  ],
                );
              },
            );
          },
    );
  }

  Future<void> _capture(
    BuildContext context,
    GlobalHotkeyService service,
    HotkeyAction action,
  ) async {
    final HotkeyBinding? binding = await showDialog<HotkeyBinding>(
      context: context,
      builder: (BuildContext context) => _HotkeyCaptureDialog(action: action),
    );
    if (binding != null) await service.setBinding(action, binding);
  }
}

/// Diálogo que escucha la siguiente combinación de teclas del usuario.
class _HotkeyCaptureDialog extends StatefulWidget {
  const _HotkeyCaptureDialog({required this.action});

  final HotkeyAction action;

  @override
  State<_HotkeyCaptureDialog> createState() => _HotkeyCaptureDialogState();
}

class _HotkeyCaptureDialogState extends State<_HotkeyCaptureDialog> {
  static final Set<LogicalKeyboardKey> _modifiers = <LogicalKeyboardKey>{
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  String? _error;

  /// Modificadores vistos por este diálogo.
  ///
  /// Se combinan con el estado global de [HardwareKeyboard] para que la
  /// captura funcione igual con teclados reales y con entradas sintéticas.
  final Set<LogicalKeyboardKey> _pressed = <LogicalKeyboardKey>{};
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return AlertDialog(
      title: Text('Atajo para ${GlobalHotkeyService.labelFor(widget.action)}'),
      content: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pulsa la combinación que quieras usar. Debe incluir Ctrl, Alt '
              'o Win para no interferir mientras escribes en otras apps.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.accent.withValues(alpha: 0.5)),
                color: tokens.accent.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.keyboard_rounded, size: 20, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Esperando teclas…',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
      ],
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_done) return KeyEventResult.handled;
    if (event is KeyUpEvent) {
      _pressed.remove(event.logicalKey);
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Esc cancela sin capturar.
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _done = true;
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    // Los modificadores solos no forman una combinación.
    if (_modifiers.contains(event.logicalKey)) {
      if (event is KeyDownEvent) _pressed.add(event.logicalKey);
      return KeyEventResult.handled;
    }

    final HotkeyBinding? binding = HotkeyBinding.fromLogicalKey(
      event.logicalKey,
      pressed: <LogicalKeyboardKey>{
        ...HardwareKeyboard.instance.logicalKeysPressed,
        ..._pressed,
      },
    );

    if (binding == null) {
      setState(() => _error = 'Esa tecla no se puede usar como atajo global.');
      return KeyEventResult.handled;
    }
    if (!binding.hasModifier) {
      setState(() => _error = 'Añade Ctrl, Alt o Win a la combinación.');
      return KeyEventResult.handled;
    }

    _done = true;
    Navigator.of(context).pop(binding);
    return KeyEventResult.handled;
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
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text(
            'No se pudieron cargar los perfiles: $error',
            style: TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          data: (List<ProfileSummary> list) => list.isEmpty
              ? Text(
                  'Sin perfiles todavía. Crea uno para separar preferencias.',
                  style: TextStyle(color: context.inkAlpha(0.54), fontSize: 12),
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
                                : context.inkAlpha(0.38),
                          ),
                          title: Text(profile.name),
                          subtitle: Text(
                            profile.isActive
                                ? 'Perfil activo'
                                : 'Toca para activar',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: profile.isActive
                              ? null
                              : IconButton(
                                  tooltip: 'Eliminar perfil',
                                  icon: Icon(
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
              icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text('Nuevo perfil'),
            ),
            OutlinedButton.icon(
              onPressed: () => _export(context, ref),
              icon: Icon(Icons.archive_outlined, size: 18),
              label: Text('Exportar respaldo'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(context, ref),
              icon: Icon(Icons.unarchive_outlined, size: 18),
              label: Text('Importar respaldo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'El respaldo v2 incluye preferencias (también las de cada salida de '
          'audio), perfiles, presets de EQ con DSP completo, listas, favoritos, '
          'letras y temas RGB/HSL. Los respaldos v1 también se pueden importar. '
          'Las pistas se referencian por ruta, así que la música debe estar en '
          'la misma ubicación para restaurarlas.',
          style: TextStyle(fontSize: 11, color: context.inkAlpha(0.38)),
        ),
      ],
    );
  }

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    final TextEditingController name = TextEditingController();
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Nuevo perfil'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del perfil'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Crear'),
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
        title: Text('Exportar respaldo'),
        content: Text(
          'Elige el formato. El ZIP ocupa menos y está listo para compartir; '
          'el JSON es legible y fácil de inspeccionar.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ZIP'),
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
            title: Text('Respaldo creado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Archivo guardado en:'),
                const SizedBox(height: 8),
                SelectableText(path, style: TextStyle(fontSize: 12)),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
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

      // Los controladores leen la caché de SettingsService al construirse, así
      // que se reciclan para reflejar temas, EQ y audio sin reiniciar la app.
      ref.invalidate(themeControllerProvider);
      ref.invalidate(equalizerControllerProvider);
      ref.invalidate(playerControllerProvider);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Respaldo importado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${summary.settings} preferencias · '
                  '${summary.profiles} perfiles · '
                  '${summary.eqPresets} presets de EQ · '
                  '${summary.playlists} listas · '
                  '${summary.favorites} favoritos · '
                  '${summary.lyrics} letras · '
                  '${summary.themes} temas',
                ),
                if (summary.warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Avisos:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ...summary.warnings.map(
                    (String warning) => Text(
                      '• $warning',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
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
          style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
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
              icon: Icon(Icons.audio_file_outlined, size: 18),
              label: Text('Acceso a audio'),
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
              icon: Icon(Icons.folder_shared_outlined, size: 18),
              label: Text('Acceso total'),
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
              icon: Icon(Icons.notifications_outlined, size: 18),
              label: Text('Notificaciones'),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(permissionServiceProvider).openSettings(),
              icon: Icon(Icons.settings_outlined, size: 18),
              label: Text('Abrir ajustes del sistema'),
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
              loading: () => Text('…'),
              error: (_, _) => Text('desconocida'),
              data: (String value) => Text('v$value'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        latest.when(
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (Object error, StackTrace stack) => Text(
            'No se pudo consultar GitHub: $error',
            style: TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          data: (UpdateInfo? info) {
            if (info == null) {
              return Text(
                'Sin conexión con GitHub o no hay releases publicadas.',
                style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
              );
            }
            if (!info.isUpdateAvailable) {
              return Text(
                'Estás al día. Última versión publicada: v${info.latestVersion}',
                style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: context.inkAlpha(0.70),
                    ),
                  ),
                if (info.publishedAt != null)
                  Text(
                    'Publicada el ${Formatters.date(info.publishedAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.inkAlpha(0.38),
                    ),
                  ),
                if (info.changelog.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Text(
                        info.changelog,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: context.inkAlpha(0.60),
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
                    style: TextStyle(fontSize: 11),
                  ),
                ],
                if (_downloaded != null) ...<Widget>[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Descargado en: $_downloaded',
                    style: TextStyle(fontSize: 11),
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
                          : Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(
                        _installing
                            ? 'Iniciando instalador…'
                            : 'Instalar ahora',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La app se cerrará para instalar la nueva versión y se '
                      'volverá a abrir automáticamente.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(_openOrInstall(_downloaded!)),
                      icon: Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        Platform.isAndroid
                            ? 'Instalar APK'
                            : 'Abrir instalador',
                      ),
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
                        icon: Icon(Icons.download_rounded, size: 18),
                        label: Text('Descargar'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(updateServiceProvider).openReleasePage(info),
                      icon: Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('Ver release'),
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
                ref.read(updatePromptProvider.notifier).check();
              },
              icon: Icon(Icons.refresh_rounded, size: 18),
              label: Text('Buscar actualizaciones'),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(updateServiceProvider).openDownloadsFolder(),
              icon: Icon(Icons.folder_open_rounded, size: 18),
              label: Text('Carpeta del instalador'),
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

  /// Abre el instalador en escritorio o lanza el intent de instalación de APK
  /// en Android, usando el mismo canal nativo que el aviso automático.
  Future<void> _openOrInstall(String path) async {
    if (Platform.isAndroid && path.toLowerCase().endsWith('.apk')) {
      final AppUpdaterService updater = ref.read(appUpdaterServiceProvider);
      final ApkInstallResult result = await updater.installApk(path);
      if (!mounted) return;
      switch (result) {
        case ApkInstallResult.permissionRequired:
          await updater.openInstallPermissionSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permite instalar aplicaciones desconocidas y vuelve a pulsar '
                '«Instalar APK».',
              ),
            ),
          );
        case ApkInstallResult.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el instalador.')),
          );
        case ApkInstallResult.started:
          break;
      }
      return;
    }
    await ref.read(updateServiceProvider).openDownloadedFile(path);
  }

  Future<void> _install(UpdateInfo info) async {
    final String? path = _downloaded;
    if (path == null || _installing) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Instalar actualización'),
        content: Text(
          'Polaris Music se cerrará para instalar la versión '
          '${info.latestVersion}.\n\n'
          'Al terminar, la app se abrirá automáticamente con la nueva '
          'versión. ¿Quieres continuar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Instalar y reiniciar'),
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

    // El helper ya lanzado espera a que salimos; cerramos servicios y mutex
    // antes de liberar EXE/DLLs para que Inno Setup no encuentre bloqueos.
    await AppShutdown.forWindowsUpdate();
  }
}
