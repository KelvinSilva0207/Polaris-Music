import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/motion_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/polaris_surface.dart';
import 'color_picker_dialog.dart';
import 'typography_screen.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';

/// Panel de personalización en vivo del motor de temas.
///
/// Cada selector escribe en [ThemeController], que persiste la configuración
/// en Drift. La vista previa y el resto de la app se reconstruyen al instante,
/// sin reiniciar.
class CustomizationScreen extends ConsumerStatefulWidget {
  const CustomizationScreen({super.key});

  @override
  ConsumerState<CustomizationScreen> createState() =>
      _CustomizationScreenState();
}

class _CustomizationScreenState extends ConsumerState<CustomizationScreen> {
  final TextEditingController _profileName = TextEditingController();

  @override
  void dispose() {
    _profileName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeState theme = ref.watch(themeControllerProvider);
    final AppThemeConfig config = theme.config;
    final MotionConfig motion = ref.watch(motionConfigProvider);
    final PlayerUiState ui = ref.watch(playerControllerProvider);

    final Color accent = config.usesDynamicPalette
        ? (ref
                  .watch(artworkAccentProvider(ui.track?.artworkPath))
                  .valueOrNull ??
              config.accent)
        : config.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text('Personalización'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restablecer tema Polaris',
            onPressed: () {
              ref.read(themeControllerProvider.notifier).resetToDefaults();
              _toast('Tema restablecido a Polaris Violet Glass');
            },
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: <Widget>[
          Text(
            'Diseña tu reproductor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Los cambios se aplican en vivo y se guardan automáticamente en tu '
            'equipo.',
            style: TextStyle(fontSize: 13, color: context.inkAlpha(0.54)),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Vista previa',
            icon: Icons.visibility_outlined,
            child: _ThemePreview(
              config: config,
              track: ui.track,
              accent: accent,
              playing: ui.playback.playing,
              progress: ui.playback.progress,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const TypographyScreen(),
              ),
            ),
            icon: Icon(Icons.text_fields_rounded, size: 18),
            label: Text('Tipografía, tamaño y fuentes propias'),
          ),
          const SizedBox(height: 22),
          Text(
            'Temas y acabados visuales',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige una paleta y combínala con cualquier material de superficie.',
            style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Galería de temas',
            icon: Icons.grid_view_rounded,
            child: _ThemeGallery(
              config: config,
              onSelect: (AppThemePreset preset) => ref
                  .read(themeControllerProvider.notifier)
                  .applyCatalogTheme(preset),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Acabado de superficie',
            icon: Icons.blur_circular_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _OptionGrid(
                  children: SurfaceFinish.values
                      .map(
                        (SurfaceFinish finish) => _OptionTile(
                          label: finish.label,
                          description: finish.description,
                          selected: config.finish == finish,
                          onTap: () => ref
                              .read(themeControllerProvider.notifier)
                              .setFinish(finish),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                Text(
                  'Mate desactiva el desenfoque y el brillo continuo: es el '
                  'acabado más ligero para Windows y Android.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.inkAlpha(0.38),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'RGB Dinámico',
            icon: Icons.auto_awesome_rounded,
            child: _RgbControls(
              config: config,
              onHue: (double value) =>
                  ref.read(themeControllerProvider.notifier).setRgb(hue: value),
              onSaturation: (double value) => ref
                  .read(themeControllerProvider.notifier)
                  .setRgb(saturation: value),
              onBrightness: (double value) => ref
                  .read(themeControllerProvider.notifier)
                  .setRgb(brightness: value),
              onFlow: (bool value) => ref
                  .read(themeControllerProvider.notifier)
                  .setRgb(flow: value),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Editor libre',
            icon: Icons.tune_rounded,
            child: _FreeFinishEditor(
              config: config,
              onPick: (ThemeColorTarget target, Color current) async {
                final Color? picked = await ColorPickerDialog.show(
                  context,
                  title: target.label,
                  initial: current,
                );
                if (picked == null || !mounted) return;
                await ref
                    .read(themeControllerProvider.notifier)
                    .setColor(target, picked);
              },
              onOpacity: (double value) => ref
                  .read(themeControllerProvider.notifier)
                  .setSurfaceOpacity(value),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Animaciones y movimiento',
            icon: Icons.animation_rounded,
            child: _MotionControls(
              motion: motion,
              onProfile: (MotionProfile profile) => ref
                  .read(motionControllerProvider.notifier)
                  .applyProfile(profile),
              onSpeed: (double value) =>
                  ref.read(motionControllerProvider.notifier).setSpeed(value),
              onCategory: (MotionCategory category, bool value) => ref
                  .read(motionControllerProvider.notifier)
                  .setCategory(category, value),
              onReset: () =>
                  ref.read(motionControllerProvider.notifier).reset(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Estilo de contenedores (avanzado)',
            icon: Icons.layers_outlined,
            child: _OptionGrid(
              children: CardStyle.values
                  .map(
                    (CardStyle style) => _OptionTile(
                      label: style.label,
                      description: style.description,
                      selected: config.cardStyle == style,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .setCardStyle(style),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Forma de la carátula',
            icon: Icons.album_outlined,
            child: _OptionGrid(
              children: ArtworkShape.values
                  .map(
                    (ArtworkShape shape) => _OptionTile(
                      label: shape.label,
                      description: shape.description,
                      selected: config.artworkShape == shape,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .setArtworkShape(shape),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Barra de progreso',
            icon: Icons.linear_scale_rounded,
            child: _OptionGrid(
              children: ProgressBarType.values
                  .map(
                    (ProgressBarType type) => _OptionTile(
                      label: type.label,
                      description: type.description,
                      selected: config.progressBarType == type,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .setProgressBarType(type),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Paleta de color',
            icon: Icons.color_lens_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ColorPaletteMode>(
                    segments: ColorPaletteMode.values
                        .map(
                          (ColorPaletteMode mode) =>
                              ButtonSegment<ColorPaletteMode>(
                                value: mode,
                                label: Text(mode.label),
                                icon: Icon(
                                  mode == ColorPaletteMode.dynamicArtwork
                                      ? Icons.auto_awesome_rounded
                                      : Icons.palette_outlined,
                                  size: 18,
                                ),
                              ),
                        )
                        .toList(growable: false),
                    selected: <ColorPaletteMode>{config.paletteMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<ColorPaletteMode> value) => ref
                        .read(themeControllerProvider.notifier)
                        .setPaletteMode(value.first),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  config.paletteMode.description,
                  style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Colores libres (RGB / HSV / HEX)',
            icon: Icons.colorize_rounded,
            child: _ColorEditorList(
              config: config,
              onPick: (ThemeColorTarget target, Color current) async {
                final Color? picked = await ColorPickerDialog.show(
                  context,
                  title: target.label,
                  initial: current,
                );
                if (picked == null || !mounted) return;
                await ref
                    .read(themeControllerProvider.notifier)
                    .setColor(target, picked);
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Vidrio y transparencia',
            icon: Icons.blur_on_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ThemeSlider(
                  label: 'Desenfoque de tarjetas',
                  value: config.glassBlur.clamp(0, 32),
                  max: 32,
                  suffix: 'px',
                  onChanged: (double value) => ref
                      .read(themeControllerProvider.notifier)
                      .setGlassBlur(value),
                ),
                _ThemeSlider(
                  label: 'Opacidad del cristal',
                  value: config.glassOpacity.clamp(0, 1),
                  max: 1,
                  suffix: '%',
                  onChanged: (double value) => ref
                      .read(themeControllerProvider.notifier)
                      .setGlassOpacity(value),
                ),
                Text(
                  'Un desenfoque alto y mucha transparencia aumentan el coste '
                  'de CPU/GPU en Windows. El rango está limitado a 32 px.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.inkAlpha(0.38),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Mis perfiles',
            icon: Icons.bookmark_border_rounded,
            child: _ProfilesEditor(
              profileName: _profileName,
              profiles: theme.profiles,
              onSave: () async {
                final CustomThemeProfile profile = await ref
                    .read(themeControllerProvider.notifier)
                    .saveProfile(_profileName.text);
                _profileName.clear();
                _toast('Perfil “${profile.name}” guardado');
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Exportar e importar',
            icon: Icons.import_export_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Comparte tu diseño como archivo .json o cárgalo en otro '
                  'equipo. La importación aplica el tema, sus animaciones y '
                  'añade sus perfiles.',
                  style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _exportTheme,
                      icon: Icon(Icons.ios_share_rounded, size: 18),
                      label: Text('Exportar .json'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importTheme,
                      icon: Icon(Icons.file_open_outlined, size: 18),
                      label: Text('Importar .json'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTheme() async {
    try {
      final String raw = ref
          .read(themeControllerProvider.notifier)
          .exportJson();
      final Uint8List bytes = Uint8List.fromList(utf8.encode(raw));
      final Uri? result = await FilePicker.saveFile(
        dialogTitle: 'Guardar diseño de Polaris',
        fileName: 'polaris-theme-${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      if (result == null) {
        _toast('Exportación cancelada');
      } else {
        _toast('Diseño exportado correctamente');
      }
    } catch (error) {
      if (mounted) _toast('No se pudo exportar: $error');
    }
  }

  Future<void> _importTheme() async {
    List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Selecciona un diseño de Polaris',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
    } catch (error) {
      if (mounted) _toast('No se pudo abrir el selector: $error');
      return;
    }
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    try {
      final String raw = await File(path).readAsString();
      final int count = await ref
          .read(themeControllerProvider.notifier)
          .importJson(raw);
      await ref.read(motionControllerProvider.notifier).reload();
      if (!mounted) return;
      _toast(
        count == 0
            ? 'Tema y animaciones importados correctamente'
            : 'Tema, animaciones y $count perfil(es) importados',
      );
    } catch (error) {
      if (mounted) _toast('Archivo no válido: $error');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Temas y acabados visuales
// ---------------------------------------------------------------------------

/// Galería visual de la segunda capa del sistema de temas.
class _ThemeGallery extends StatelessWidget {
  const _ThemeGallery({required this.config, required this.onSelect});

  final AppThemeConfig config;
  final ValueChanged<AppThemePreset> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1000
            ? 3
            : (constraints.maxWidth >= 620 ? 2 : 1);
        const double spacing = 10;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: AppThemeConfig.catalog
              .map(
                (AppThemeConfig entry) => SizedBox(
                  width: width < 0 ? 0 : width,
                  child: _ThemeCard(
                    config: entry,
                    selected:
                        config.preset == entry.preset ||
                        (config.preset == AppThemePreset.custom &&
                            config.finish == entry.finish &&
                            config.accent == entry.accent &&
                            config.background == entry.background),
                    onTap: () => onSelect(entry.preset),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.config,
    required this.selected,
    required this.onTap,
  });

  final AppThemeConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = ColorMath.onColor(config.surface);
    final IconData finishIcon = switch (config.finish) {
      SurfaceFinish.glass => Icons.blur_on_rounded,
      SurfaceFinish.liquid => Icons.waves_rounded,
      SurfaceFinish.matte => Icons.crop_square_rounded,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: context.motion.duration(const Duration(milliseconds: 220)),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? config.accent : ink.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[...config.backdrop, config.background],
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: config.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ink.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: config.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Icon(
                        finishIcon,
                        size: 18,
                        color: ink.withValues(alpha: 0.85),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: config.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    config.preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  config.finish.label,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.65),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              config.preset.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink.withValues(alpha: 0.62),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controles HSV del tema RGB Dinámico.
class _RgbControls extends StatelessWidget {
  const _RgbControls({
    required this.config,
    required this.onHue,
    required this.onSaturation,
    required this.onBrightness,
    required this.onFlow,
  });

  final AppThemeConfig config;
  final ValueChanged<double> onHue;
  final ValueChanged<double> onSaturation;
  final ValueChanged<double> onBrightness;
  final ValueChanged<bool> onFlow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: config.rgbColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: config.secondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tono, saturación y brillo se aplican al acento, '
                'secundario y degradado.',
                style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ThemeSlider(
          label: 'Tono',
          value: config.rgbHue,
          max: 360,
          suffix: '°',
          onChanged: onHue,
        ),
        _ThemeSlider(
          label: 'Saturación',
          value: config.rgbSaturation,
          max: 1,
          suffix: '%',
          onChanged: onSaturation,
        ),
        _ThemeSlider(
          label: 'Brillo',
          value: config.rgbBrightness,
          max: 1,
          suffix: '%',
          onChanged: onBrightness,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Flujo cromático suave'),
          subtitle: Text(
            'Cruce lento entre tonos, sin pulsos ni shaders continuos.',
            style: TextStyle(fontSize: 10.5, color: context.inkAlpha(0.54)),
          ),
          value: config.rgbFlow,
          onChanged: onFlow,
        ),
      ],
    );
  }
}

/// Editor libre de color primario, secundario, fondo y opacidad.
class _FreeFinishEditor extends StatelessWidget {
  const _FreeFinishEditor({
    required this.config,
    required this.onPick,
    required this.onOpacity,
  });

  final AppThemeConfig config;
  final Future<void> Function(ThemeColorTarget target, Color current) onPick;
  final ValueChanged<double> onOpacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ColorEditorList(config: config, onPick: onPick),
        const SizedBox(height: 10),
        _ThemeSlider(
          label: 'Opacidad de superficie',
          value: config.surfaceOpacity,
          max: 1,
          suffix: '%',
          onChanged: onOpacity,
        ),
      ],
    );
  }
}

/// Perfiles, velocidad e interruptores de Animaciones y Movimiento.
class _MotionControls extends StatelessWidget {
  const _MotionControls({
    required this.motion,
    required this.onProfile,
    required this.onSpeed,
    required this.onCategory,
    required this.onReset,
  });

  final MotionConfig motion;
  final ValueChanged<MotionProfile> onProfile;
  final ValueChanged<double> onSpeed;
  final void Function(MotionCategory category, bool value) onCategory;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _OptionGrid(
          children: MotionConfig.presets
              .map(
                (MotionConfig preset) => _OptionTile(
                  label: preset.profile.label,
                  description: preset.profile.description,
                  selected: motion.profile == preset.profile,
                  onTap: () => onProfile(preset.profile),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        _ThemeSlider(
          label: 'Velocidad',
          value: motion.speed,
          min: 0.4,
          max: 1.6,
          suffix: '×',
          decimals: 1,
          onChanged: onSpeed,
        ),
        for (final MotionCategory category in MotionCategory.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(category.label),
            subtitle: Text(
              category.description,
              style: TextStyle(fontSize: 10.5, color: context.inkAlpha(0.54)),
            ),
            value: motion.enabled(category),
            onChanged: (bool value) => onCategory(category, value),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Restablecer'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Secciones y selectores
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return PolarisSurface(
      borderRadius: 20,
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: context.motion.duration(const Duration(milliseconds: 220)),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? tokens.accent.withValues(alpha: 0.18)
              : context.inkAlpha(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? tokens.accent.withValues(alpha: 0.85)
                : context.inkAlpha(0.07),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 16,
                  color: selected ? tokens.accent : context.inkAlpha(0.38),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.inkAlpha(0.54)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rejilla adaptable de opciones: una, dos o todas las columnas según ancho.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = switch (width) {
          >= 880 => children.length,
          >= 560 => 2,
          _ => 1,
        };
        const double spacing = 8;
        final int safeColumns = columns <= 0 ? 1 : columns;
        final double itemWidth =
            (width - spacing * (safeColumns - 1)) / safeColumns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (Widget child) => SizedBox(
                  width: itemWidth < 0 ? 0 : itemWidth,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// Rejilla con todos los objetivos cromáticos editables.
class _ColorEditorList extends StatelessWidget {
  const _ColorEditorList({required this.config, required this.onPick});

  final AppThemeConfig config;
  final Future<void> Function(ThemeColorTarget target, Color current) onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 560 ? 2 : 1);
        const double spacing = 8;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: ThemeColorTarget.values
              .map((ThemeColorTarget target) {
                final Color color = config.colorFor(target);
                return SizedBox(
                  width: width < 0 ? 0 : width,
                  child: InkWell(
                    onTap: () => onPick(target, color),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.inkAlpha(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.inkAlpha(0.24)),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  target.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  ColorMath.toHex(color),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.inkAlpha(0.54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _ThemeSlider extends StatelessWidget {
  const _ThemeSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.min = 0,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              suffix == '%'
                  ? '${(value * 100).round()} %'
                  : decimals == 0
                  ? '${value.round()} $suffix'
                  : '${value.toStringAsFixed(decimals)} $suffix',
              style: TextStyle(fontSize: 10, color: context.inkAlpha(0.54)),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          activeColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ProfilesEditor extends ConsumerWidget {
  const _ProfilesEditor({
    required this.profileName,
    required this.profiles,
    required this.onSave,
  });

  final TextEditingController profileName;
  final List<CustomThemeProfile> profiles;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: profileName,
                decoration: const InputDecoration(
                  labelText: 'Nombre del perfil',
                  hintText: 'Mi estilo nocturno',
                ),
                onSubmitted: (String _) => onSave(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onSave,
              icon: Icon(Icons.save_outlined, size: 18),
              label: Text('Guardar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Guarda la combinación actual y recupérala cuando quieras.',
          style: TextStyle(fontSize: 11, color: context.inkAlpha(0.38)),
        ),
        if (profiles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...profiles.map(
            (CustomThemeProfile profile) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.bookmark_rounded, size: 20),
              title: Text(profile.name),
              subtitle: Text(
                '${profile.config.cardStyle.label} · '
                '${profile.config.artworkShape.label} · '
                '${profile.config.progressBarType.label}',
                style: TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: 'Eliminar perfil',
                icon: Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => ref
                    .read(themeControllerProvider.notifier)
                    .deleteProfile(profile.id),
              ),
              onTap: () => ref
                  .read(themeControllerProvider.notifier)
                  .applyProfile(profile),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vista previa
// ---------------------------------------------------------------------------

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.config,
    required this.track,
    required this.accent,
    required this.playing,
    required this.progress,
  });

  final AppThemeConfig config;
  final Track? track;
  final Color accent;
  final bool playing;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = config.usesDynamicPalette
        ? <Color>[
            Color.lerp(config.background, accent, 0.36) ?? config.background,
            config.background,
            Color.lerp(config.background, accent, 0.22) ?? config.background,
          ]
        : config.backdrop;

    final String title = track?.title ?? 'Canción de ejemplo';
    final String artist = track?.artist ?? 'Polaris Music';
    final double artworkSize = 118;
    final Color progressColor = config.usesDynamicPalette
        ? accent
        : config.progressColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: context.motion.duration(const Duration(milliseconds: 600)),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -70,
              right: -50,
              child: _PreviewGlow(color: accent, size: 220),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _PreviewGlow(
                color: accent.withValues(alpha: 0.6),
                size: 240,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PreviewArtwork(
                      config: config,
                      path: track?.artworkPath,
                      accent: progressColor,
                      playing: playing,
                      size: artworkSize,
                      progress: progress,
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: PolarisSurface(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        borderRadius: 18,
                        glowColor: accent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.60),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Letra activa · karaoke',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: config.karaokeColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (config.progressBarType ==
                                ProgressBarType.linearClassic)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: context.inkAlpha(0.10),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progressColor,
                                  ),
                                ),
                              )
                            else if (config.progressBarType ==
                                ProgressBarType.waveform)
                              SizedBox(
                                height: 26,
                                child: CustomPaint(
                                  painter: _PreviewWaveform(
                                    accent: progressColor,
                                  ),
                                  size: const Size(double.infinity, 26),
                                ),
                              )
                            else
                              const SizedBox(height: 4),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.skip_previous_rounded,
                                  size: 24,
                                  color: context.inkAlpha(0.70),
                                ),
                                const SizedBox(width: 18),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: ColorMath.onColor(accent),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Icon(
                                  Icons.skip_next_rounded,
                                  size: 24,
                                  color: context.inkAlpha(0.70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewGlow extends StatelessWidget {
  const _PreviewGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.30),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewArtwork extends StatelessWidget {
  const _PreviewArtwork({
    required this.config,
    required this.path,
    required this.accent,
    required this.playing,
    required this.size,
    required this.progress,
  });

  final AppThemeConfig config;
  final String? path;
  final Color accent;
  final bool playing;
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bool ring =
        config.progressBarType == ProgressBarType.circularAroundArtwork;
    // La carátula se encoge para dejar respirar el anillo (Vinilo incluido).
    final double artSize = ring ? size * 0.82 : size;

    final Widget artwork = switch (config.artworkShape) {
      ArtworkShape.squareRounded => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _PreviewImage(path: path, accent: accent, size: artSize),
      ),
      ArtworkShape.circleVinyl => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return ValueListenableBuilder<WindowUiState>(
            valueListenable: ref.watch(windowStateProvider),
            builder: (BuildContext context, WindowUiState state, Widget? _) {
              return _PreviewVinyl(
                path: path,
                accent: accent,
                playing: playing,
                paused: state.backgrounded,
                size: artSize,
              );
            },
          );
        },
      ),
      ArtworkShape.card3D => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(0.06)
          ..rotateY(-0.10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: context.inkAlpha(0.06),
            border: Border.all(color: context.inkAlpha(0.12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: context.tokens.shadowColor.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(10, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _PreviewImage(path: path, accent: accent, size: artSize - 8),
          ),
        ),
      ),
    };

    if (!ring) return artwork;

    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size + 18),
            painter: _PreviewRing(progress: progress, accent: accent),
          ),
          artwork,
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({
    required this.path,
    required this.accent,
    required this.size,
  });

  final String? path;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? artwork = path;
    if (artwork == null || artwork.isEmpty) {
      return _fallback();
    }
    final int decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(24, 160);
    return Image.file(
      File(artwork),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: decodeSize,
      cacheHeight: decodeSize,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.72),
            accent.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.38,
        color: const Color(0xD9FFFFFF),
      ),
    );
  }
}

class _PreviewVinyl extends StatefulWidget {
  const _PreviewVinyl({
    required this.path,
    required this.accent,
    required this.playing,
    required this.size,
    this.paused = false,
  });

  final String? path;
  final Color accent;
  final bool playing;
  final double size;
  final bool paused;

  @override
  State<_PreviewVinyl> createState() => _PreviewVinylState();
}

class _PreviewVinylState extends State<_PreviewVinyl>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(seconds: 14);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _period,
  );
  MotionConfig? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = context.motion;
    final Duration duration = _motion!.duration(
      _period,
      category: MotionCategory.ambient,
    );
    _spin.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PreviewVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.paused != widget.paused) {
      _sync();
    }
  }

  void _sync() {
    if (widget.playing && (_motion?.ambient ?? false) && !widget.paused) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double label = widget.size * 0.48;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: <Color>[
                  Color(0xFF2A2A2A),
                  Color(0xFF121212),
                  Color(0xFF050505),
                ],
                stops: <double>[0, 0.7, 1],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.32),
                  blurRadius: 34,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size.square(widget.size),
            painter: _PreviewGrooves(),
          ),
          RotationTransition(
            turns: _spin,
            child: ClipOval(
              child: SizedBox(
                width: label,
                height: label,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _PreviewImage(
                      path: widget.path,
                      accent: widget.accent,
                      size: label,
                    ),
                    Container(
                      width: label * 0.12,
                      height: label * 0.12,
                      decoration: BoxDecoration(
                        color: Color(0xFF0A0A0A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewGrooves extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double maxRadius = size.shortestSide / 2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 14; i++) {
      paint.color = Colors.white.withValues(alpha: i.isEven ? 0.05 : 0.025);
      canvas.drawCircle(center, maxRadius * (0.54 + i * 0.03), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewGrooves oldDelegate) => false;
}

class _PreviewRing extends CustomPainter {
  _PreviewRing({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 4;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double start = -math.pi / 2;

    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, base);

    final Paint active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(
      rect,
      start,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewRing oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _PreviewWaveform extends CustomPainter {
  _PreviewWaveform({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const int bars = 42;
    final double gap = 2;
    final double barWidth = math.max(
      1.4,
      (size.width - gap * (bars - 1)) / bars,
    );
    final Paint paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < bars; i++) {
      final double t = i / (bars - 1);
      final double noise = math.sin(i * 12.9898) * 43758.5453;
      final double random = noise - noise.floorToDouble();
      final double envelope =
          (0.32 + 0.68 * math.sin(math.pi * t)) * (0.5 + 0.5 * random);
      final double height = (size.height * envelope).clamp(3, size.height);
      final double x = i * (barWidth + gap);
      final double top = (size.height - height) / 2;
      paint.color = t <= 0.42 ? accent : accent.withValues(alpha: 0.20);
      paint.strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x + barWidth / 2, top),
        Offset(x + barWidth / 2, top + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewWaveform oldDelegate) =>
      oldDelegate.accent != accent;
}
