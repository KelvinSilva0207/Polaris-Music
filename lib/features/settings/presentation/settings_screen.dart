import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_navigation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/scrobble_config.dart';
import '../../../core/models/update_info.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/providers/motion_provider.dart';
import '../../../core/providers/typography_provider.dart';
import '../../../core/providers/update_prompt_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/app_shutdown.dart';
import '../../../core/services/app_updater_service.dart';
import '../../../core/services/audio_device_profile_service.dart';
import '../../../core/services/beta_crash_logger.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/global_hotkey_service.dart';
import '../../../core/services/scrobble_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/storage_paths_service.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/diagnostics.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/dynamic_island/presentation/island_providers.dart';
import '../../../features/equalizer/presentation/equalizer_providers.dart';
import '../../../features/equalizer/presentation/equalizer_screen.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/player/domain/player_controller.dart';
import '../../../features/player/presentation/player_providers.dart';
import '../../../features/profiles_backup/domain/profiles_service.dart';
import '../../../features/profiles_backup/presentation/profiles_providers.dart';
import '../../../features/stats_sync/presentation/stats_screen.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/polaris_surface.dart';
import 'customization_screen.dart';

/// Áreas en las que se agrupan los ajustes para no mostrar 17 bloques a la vez.
enum _SettingsArea {
  appearance('Apariencia', Icons.palette_outlined),
  audio('Audio', Icons.graphic_eq_rounded),
  content('Biblioteca', Icons.library_music_outlined),
  accounts('Cuentas', Icons.person_outline_rounded),
  system('Sistema', Icons.tune_rounded),
  about('Acerca de', Icons.info_outline_rounded);

  const _SettingsArea(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Índices de `_buildSections` que pertenecen a cada área.
///
/// La lista de secciones mantiene siempre 17 entradas (las condicionales
/// devuelven `SizedBox.shrink()`) para que estos índices no cambien según la
/// plataforma.
const Map<_SettingsArea, List<int>> _areaSections = <_SettingsArea, List<int>>{
  _SettingsArea.appearance: <int>[0, 6],
  _SettingsArea.audio: <int>[1, 4, 5],
  _SettingsArea.content: <int>[2, 3],
  _SettingsArea.accounts: <int>[8, 13],
  _SettingsArea.system: <int>[7, 9, 10, 11],
  _SettingsArea.about: <int>[12, 14, 15, 16],
};

/// Ajustes de Polaris Music: apariencia, audio, ventana, respaldos y más.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onNavigate});

  final ValueChanged<AppSection> onNavigate;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsArea _area = _SettingsArea.appearance;

  @override
  Widget build(BuildContext context) {
    final bool replayGain = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.replayGainEnabled),
    );
    final bool pureAudio = ref.watch(
      equalizerControllerProvider.select((s) => s.pure),
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

    // Las secciones se construyen una sola vez; el selector de áreas decide
    // cuáles se insertan en el árbol para no saturar la pantalla.
    final List<Widget> sections = <Widget>[
      _Section(
        title: 'Apariencia',
        icon: Icons.palette_outlined,
        children: <Widget>[
          _SettingCard(
            icon: Icons.palette_outlined,
            title: 'Apariencia',
            subtitle: 'Temas, colores, acabados, movimiento, tipografía y diseños compactos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const CustomizationScreen(),
              ),
            ),
          ),
        ],
      ),
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
            title: Text('Modo puro / sin filtros'),
            subtitle: Text(
              'Bypass temporal del ecualizador, el sub-armónico y el '
              'limitador. Tu curva se conserva intacta al volver a activarlos.',
            ),
            value: pureAudio,
            onChanged: (bool value) =>
                ref.read(equalizerControllerProvider.notifier).setPure(value),
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
              'mpv encadena pistas sin hueco. Se desactiva al usar crossfade.',
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
              'Dos decks mpv: funde pistas y desactiva el gapless estricto.',
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
          _SettingCard(
            icon: Icons.library_music_outlined,
            title: 'Administrar biblioteca',
            subtitle: 'Escanear, gestionar carpetas y revisar duplicados',
            onTap: () => widget.onNavigate(AppSection.library),
          ),
        ],
      ),
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
      _Section(
        title: 'Ecualizador',
        icon: Icons.graphic_eq_rounded,
        children: <Widget>[
          Text(
            'Diez bandas de estudio, preamplificador y curvas guardadas. '
            'Con filtros activos se aplica preamp automático y un limitador '
            'suave para evitar recortes; el modo puro los deja a todos fuera.',
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
      if (Platform.isWindows)
        const _HotkeysSection()
      else
        const SizedBox.shrink(),
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
      if (window.isSupported)
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
        )
      else
        const SizedBox.shrink(),
      const _ProfilesSection(),
      const _PermissionsSection(),
      const _StorageSection(),
      if (Platform.isAndroid)
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
        )
      else
        const SizedBox.shrink(),
      const _UpdateSection(),
      const _ScrobbleSection(),
      _Section(
        title: 'Restablecer ajustes',
        icon: Icons.restart_alt_rounded,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restablecer ajustes por defecto'),
            subtitle: const Text(
              'Tema, animaciones, estilos, ecualizador, atajos y carpetas '
              'vuelven a su estado inicial. Biblioteca y cuentas se conservan.',
            ),
            onTap: _confirmResetSettings,
          ),
        ],
      ),
      _Section(
        title: 'Diagnóstico Beta',
        icon: Icons.bug_report_outlined,
        children: <Widget>[
          const _BetaDiagnosticsCard(),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_rounded),
            title: Text('Copiar informe de diagnóstico'),
            subtitle: Text(
              'Versión, permiso de instalación y huella de la firma',
            ),
            onTap: () async {
              final String report = await buildDiagnosticsReport(
                sl<AppUpdaterService>(),
              );
              await Clipboard.setData(ClipboardData(text: report));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Diagnóstico copiado al portapapeles'),
                  ),
                );
              }
            },
          ),
        ],
      ),
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
    ];

    final List<int> indices = _areaSections[_area]!;
    return ListView(
      // KEY por área: al cambiar, la lista se reconstruye y el scroll vuelve
      // arriba en lugar de quedarse a media altura del área anterior.
      key: ValueKey<_SettingsArea>(_area),
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
        const SizedBox(height: 20),
        Text(
          'Áreas',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: context.inkAlpha(0.48),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final _SettingsArea area in _SettingsArea.values)
              _ModeButton(
                icon: area.icon,
                label: area.label,
                selected: area == _area,
                onPressed: () => setState(() => _area = area),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final int index in indices) ...<Widget>[
          if (index != indices.first) const SizedBox(height: 16),
          sections[index],
        ],
      ],
    );
  }

  /// Limpia una configuración de prueba sin tocar datos del usuario.
  ///
  /// La confirmación explica exactamente qué se restablece y qué se conserva.
  /// Los controladores que escriben al hacer `dispose` se invalidan antes de
  /// borrar las claves para que no vuelvan a persistir valores antiguos.
  Future<void> _confirmResetSettings() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Restablecer ajustes por defecto'),
        content: const Text(
          'Se devuelven al estado inicial el tema activo, las animaciones, '
          'los estilos compactos, el ecualizador, los atajos, las preferencias '
          'de reproducción y las carpetas elegidas.\n\n'
          'No se borran tu biblioteca, tus listas, la introducción, la sesión '
          'de reproducción, los perfiles de tema guardados ni las cuentas '
          'conectadas. Los archivos de tus carpetas tampoco se eliminan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.invalidate(equalizerControllerProvider);
    ref.invalidate(playerControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final SettingsService settings = ref.read(settingsServiceProvider);
    await settings.resetPreferences();
    await settings.resetDeviceScopes();
    await sl<GlobalHotkeyService>().resetDefaults();
    await sl<AudioDeviceProfileService>().setEnabled(false);
    await ref.read(motionControllerProvider.notifier).reload();

    ref.invalidate(themeControllerProvider);
    ref.invalidate(typographyProvider);
    ref.invalidate(compactStylesProvider);
    ref.invalidate(dynamicIslandControllerProvider);
    ref.invalidate(equalizerControllerProvider);
    ref.invalidate(playerControllerProvider);

    await ref.read(equalizerControllerProvider.notifier).load();
    final double volume = ref.read(settingsServiceProvider).volume;
    await ref.read(audioEngineProvider).setVolume(volume * 100);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajustes restablecidos por defecto')),
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

    await AppShutdown.quit('Ajustes');
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
          'Windows y Android. El crossfade encadena pistas de forma suave y su '
          'duración se ajusta en Reproducción.',
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

class _ScrobbleSection extends ConsumerWidget {
  const _ScrobbleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsService settings = ref.watch(settingsServiceProvider);
    final ScrobbleConfig config = settings.scrobbleConfig;
    final String subtitle;
    if (config.pendingToken.isNotEmpty) {
      subtitle = 'Autoriza la app en la web y pulsa «Ya autoricé»';
    } else if (config.connected) {
      subtitle = config.username.isEmpty
          ? 'Cuenta conectada'
          : 'Conectado como ${config.username}';
    } else {
      subtitle = 'Envía las escuchas completadas a Last.fm';
    }

    return _Section(
      title: 'Scrobbling',
      icon: Icons.music_note_outlined,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enviar escuchas'),
          subtitle: Text(subtitle),
          value: config.enabled,
          onChanged: config.connected
              ? (bool value) async {
                  await settings.setScrobbleConfig(
                    config.copyWith(enabled: value),
                  );
                }
              : null,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _configureScrobbling(context, settings),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(
              config.pendingToken.isNotEmpty
                  ? 'Continuar autorización'
                  : config.connected
                  ? 'Cambiar cuenta'
                  : 'Conectar Last.fm',
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _configureScrobbling(
  BuildContext context,
  SettingsService settings,
) async {
  final ScrobbleService scrobbler = sl<ScrobbleService>();
  final ScrobbleConfig current = settings.scrobbleConfig;

  if (current.pendingToken.isNotEmpty) {
    final bool? authorized = await _askScrobbleAuthorization(
      context,
      scrobbler,
      current.pendingToken,
    );
    if (authorized != true || !context.mounted) return;
    await _finishScrobbleLogin(context, scrobbler);
    return;
  }

  final String? token = await showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _ScrobbleCredentialsDialog(config: current),
  );
  if (token == null || !context.mounted) return;

  final bool? authorized = await _askScrobbleAuthorization(
    context,
    scrobbler,
    token,
  );
  if (authorized != true || !context.mounted) return;
  await _finishScrobbleLogin(context, scrobbler);
}

/// Diálogo de credenciales con estado de espera y errores en línea.
///
/// La cuenta es opcional: si la región bloquea Last.fm o la red falla, el
/// diálogo se cierra sin tocar la configuración local y la reproducción sigue.
class _ScrobbleCredentialsDialog extends StatefulWidget {
  const _ScrobbleCredentialsDialog({required this.config});

  final ScrobbleConfig config;

  @override
  State<_ScrobbleCredentialsDialog> createState() =>
      _ScrobbleCredentialsDialogState();
}

class _ScrobbleCredentialsDialogState
    extends State<_ScrobbleCredentialsDialog> {
  late final TextEditingController _key = TextEditingController(
    text: widget.config.apiKey,
  );
  late final TextEditingController _secret = TextEditingController(
    text: widget.config.apiSecret,
  );
  late final TextEditingController _endpoint = TextEditingController(
    text: widget.config.endpoint,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _secret.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String token = await sl<ScrobbleService>().beginLogin(
        apiKey: _key.text,
        apiSecret: _secret.text,
        endpoint: _endpoint.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop<String>(token);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo conectar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Conectar Last.fm (opcional)'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Polaris funciona por completo sin cuenta. Si la conexión falla, '
            'tu biblioteca, ajustes y reproducción siguen igual.',
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa tu API key de Last.fm. También admite servidores '
            'compatibles indicando su endpoint.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'API key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _secret,
            enabled: !_busy,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API secret',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _endpoint,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Endpoint (opcional)',
              hintText: ScrobbleService.defaultEndpoint,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_busy) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Continuar'),
      ),
    ],
  );
}

Future<bool?> _askScrobbleAuthorization(
  BuildContext context,
  ScrobbleService scrobbler,
  String token,
) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Autorizar Polaris'),
      content: const Text(
        'Se abrirá la página de Last.fm. Autoriza la aplicación y vuelve '
        'a Polaris para terminar la conexión.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            try {
              final Uri url = scrobbler.authorizationUrl(token);
              final bool launched =
                  await canLaunchUrl(url) &&
                  await launchUrl(url, mode: LaunchMode.externalApplication);
              if (!launched && context.mounted) {
                _scrobbleToast(context, 'No se pudo abrir el navegador');
              }
            } catch (_) {
              if (context.mounted) {
                _scrobbleToast(context, 'No se pudo abrir el navegador');
              }
            }
          },
          child: const Text('Abrir Last.fm'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ya autoricé'),
        ),
      ],
    ),
  );
}

Future<void> _finishScrobbleLogin(
  BuildContext context,
  ScrobbleService scrobbler,
) async {
  try {
    await scrobbler.finishLogin();
    if (context.mounted) _scrobbleToast(context, 'Last.fm conectado');
  } catch (error) {
    if (context.mounted) {
      _scrobbleToast(context, 'No se pudo conectar: $error');
    }
  }
}

void _scrobbleToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

/// Tarjeta de navegación única para agrupar ajustes relacionados.
class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: context.tokens.panelDecoration(radius: 16),
          child: Row(
            children: <Widget>[
              Icon(icon, color: context.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de diagnóstico Beta: ruta del registro, contador de errores y
/// acciones de compartir/exportar/limpiar. Reutiliza los estilos de Ajustes.
class _BetaDiagnosticsCard extends ConsumerWidget {
  const _BetaDiagnosticsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: BetaCrashLogger.errorCount,
      builder: (BuildContext context, int count, Widget? _) {
        final String? directory = BetaCrashLogger.logDirectory;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.bug_report_outlined,
                  size: 18,
                  color: context.accent,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Registro de errores',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Errores registrados: $count',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.75)),
            ),
            const SizedBox(height: 4),
            if (directory != null)
              SelectableText(
                directory,
                style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
              )
            else
              Text(
                'La carpeta de registros no está disponible',
                style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => unawaited(_share(context, ref)),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Compartir'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_export(context, ref)),
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Exportar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_confirmClear(context)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Limpiar Logs'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Texto de versión/firma para el ZIP. Si falla, el informe Beta sigue siendo
  /// útil; por eso el error no bloquea la exportación.
  Future<String> _diagnostics(WidgetRef ref) async {
    try {
      return await buildDiagnosticsReport(ref.read(appUpdaterServiceProvider));
    } catch (_) {
      return 'Polaris Music — diagnóstico Beta';
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await BetaCrashLogger.shareLogs(diagnostics: await _diagnostics(ref));
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo compartir: $error')),
        );
      }
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String path = await BetaCrashLogger.exportLogs(
        diagnostics: await _diagnostics(ref),
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Diagnóstico exportado'),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $error')),
        );
      }
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Limpiar registros Beta'),
        content: const Text(
          'Se borrarán los archivos de registro de esta carpeta y se pondrá '
          'el contador de errores a cero. Tu biblioteca y tus ajustes no se '
          'tocan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final int removed = await BetaCrashLogger.clearLogs();
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$removed archivo(s) de registro eliminado(s)'),
          ),
        );
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudieron limpiar los registros: $error'),
          ),
        );
      }
    }
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
      title: 'Perfiles de usuario y respaldos',
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
              label: Text('Exportar copia completa'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(context, ref),
              icon: Icon(Icons.unarchive_outlined, size: 18),
              label: Text('Importar copia completa'),
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
        title: Text('Exportar copia completa'),
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
      final Directory documents = await ref
          .read(storagePathsServiceProvider)
          .documents();
      final String path = await ref
          .read(backupActionsProvider)
          .export(compress: zip, directory: documents);
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

/// Muestra y permite abrir/cambiar las carpetas estándar de la app.
class _StorageSection extends ConsumerWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Las rutas dependen de las preferencias de carpeta; reconstruir al cambiar.
    ref.watch(settingsValuesProvider);
    final StoragePathsService storage = ref.watch(storagePathsServiceProvider);

    void message(String text) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    }

    return FutureBuilder<List<StoragePathInfo>>(
      future: storage.describe(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StoragePathInfo>> snapshot,
          ) {
            final List<StoragePathInfo> rows =
                snapshot.data ?? const <StoragePathInfo>[];
            return _Section(
              title: 'Carpetas y archivos',
              icon: Icons.folder_open_rounded,
              children: <Widget>[
                Text(
                  'Rutas activas. Puedes abrirlas o elegir otra carpeta cuando el '
                  'sistema lo permita.',
                  style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No se pudieron resolver las rutas: ${snapshot.error}',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                for (final StoragePathInfo info in rows) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        info.kind == StorageFolderKind.downloads
                            ? Icons.system_update_alt_rounded
                            : info.kind == StorageFolderKind.music
                            ? Icons.audiotrack_rounded
                            : info.kind == StorageFolderKind.documents
                            ? Icons.description_rounded
                            : Icons.storage_rounded,
                        size: 20,
                        color: context.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              info.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              info.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.54),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              info.path,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.75),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final bool opened = await storage.open(
                                      info.kind,
                                    );
                                    if (!opened) {
                                      message('No se pudo abrir la carpeta');
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.folder_open_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Abrir'),
                                ),
                                if (info.canChange)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final bool changed = await storage.change(
                                        info.kind,
                                      );
                                      if (changed) {
                                        message('Carpeta actualizada');
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Cambiar'),
                                  ),
                                if (info.canChange)
                                  TextButton(
                                    onPressed: () async {
                                      await storage.reset(info.kind);
                                      message('Ruta estándar restaurada');
                                    },
                                    child: const Text('Restablecer'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
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
  bool _awaitingInstallOutcome = false;

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
      final String message = switch (outcome) {
        ApkInstallOutcome.installed => 'Actualización instalada correctamente.',
        ApkInstallOutcome.cancelled =>
          'Instalación cancelada. El APK se conserva para volver a intentarlo.',
        ApkInstallOutcome.failed => 'El sistema no pudo instalar el APK. Comprueba el archivo e inténtalo de nuevo.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
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
                            : 'Instalar descarga',
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
                        label: Text('Descargar actualización'),
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
              label: Text('Carpeta de actualizaciones'),
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
      final bool canInstall = await updater.canInstallApk();
      if (!canInstall) {
        final bool opened = await updater.openInstallPermissionSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Activa «Instalar aplicaciones desconocidas» y vuelve a '
                        'pulsar «Instalar APK». La descarga se conserva.'
                  : 'No se pudieron abrir los ajustes de instalación. '
                        'Activa «Instalar aplicaciones desconocidas» manualmente.',
            ),
          ),
        );
        return;
      }
      _awaitingInstallOutcome = true;
      final ApkInstallResult result = await updater.installApk(path);
      if (!mounted) return;
      if (result != ApkInstallResult.started) _awaitingInstallOutcome = false;
      switch (result) {
        case ApkInstallResult.permissionRequired:
          final bool opened = await updater.openInstallPermissionSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                opened
                    ? 'Permite instalar aplicaciones desconocidas y vuelve a '
                          'pulsar «Instalar APK». La descarga se conserva.'
                    : 'Android revocó el permiso y no se pudieron abrir sus '
                          'ajustes. Actívalo manualmente para instalar.',
              ),
            ),
          );
        case ApkInstallResult.wrongPackage:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El APK descargado no corresponde a Polaris Music.',
              ),
            ),
          );
        case ApkInstallResult.signatureMismatch:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La copia instalada tiene otra firma. Desinstala una sola vez '
                'e instala el APK de la release para igualar las firmas.',
              ),
            ),
          );
        case ApkInstallResult.olderVersion:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El APK descargado es más antiguo que la versión instalada.',
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
