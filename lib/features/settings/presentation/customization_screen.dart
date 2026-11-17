import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/polaris_surface.dart';
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
    final PlayerUiState ui = ref.watch(playerControllerProvider);

    final Color accent = config.usesDynamicPalette
        ? (ref
                  .watch(artworkAccentProvider(ui.track?.artworkPath))
                  .valueOrNull ??
              config.accent)
        : config.accent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalización'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restablecer tema Polaris',
            onPressed: () {
              ref.read(themeControllerProvider.notifier).resetToDefaults();
              _toast('Tema restablecido a Polaris Violet Glass');
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: <Widget>[
          const Text(
            'Diseña tu reproductor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Los cambios se aplican en vivo y se guardan automáticamente en tu '
            'equipo.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
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
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Estilo de contenedores',
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
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                const Text(
                  'Comparte tu diseño como archivo .json o cárgalo en otro '
                  'equipo. La importación aplica el tema y añade sus perfiles.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _exportTheme,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Exportar .json'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importTheme,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Importar .json'),
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
      if (!mounted) return;
      _toast(
        count == 0
            ? 'Tema importado correctamente'
            : 'Tema y $count perfil(es) importados',
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
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? tokens.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? tokens.accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.07),
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
                  color: selected ? tokens.accent : Colors.white38,
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
              style: const TextStyle(fontSize: 10.5, color: Colors.white54),
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
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Guarda la combinación actual y recupérala cuando quieras.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
        if (profiles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...profiles.map(
            (CustomThemeProfile profile) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.bookmark_rounded, size: 20),
              title: Text(profile.name),
              subtitle: Text(
                '${profile.config.cardStyle.label} · '
                '${profile.config.artworkShape.label} · '
                '${profile.config.progressBarType.label}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: 'Eliminar perfil',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
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
                      accent: accent,
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
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
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.10,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accent,
                                  ),
                                ),
                              )
                            else if (config.progressBarType ==
                                ProgressBarType.waveform)
                              SizedBox(
                                height: 26,
                                child: CustomPaint(
                                  painter: _PreviewWaveform(accent: accent),
                                  size: const Size(double.infinity, 26),
                                ),
                              )
                            else
                              const SizedBox(height: 4),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.skip_previous_rounded,
                                  size: 24,
                                  color: Colors.white70,
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
                                    color: Colors.black,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                const Icon(
                                  Icons.skip_next_rounded,
                                  size: 24,
                                  color: Colors.white70,
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
      ArtworkShape.circleVinyl => _PreviewVinyl(
        path: path,
        accent: accent,
        playing: playing,
        size: artSize,
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
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
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
    return Image.file(
      File(artwork),
      width: size,
      height: size,
      fit: BoxFit.cover,
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
        color: Colors.white.withValues(alpha: 0.85),
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
  });

  final String? path;
  final Color accent;
  final bool playing;
  final double size;

  @override
  State<_PreviewVinyl> createState() => _PreviewVinylState();
}

class _PreviewVinylState extends State<_PreviewVinyl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PreviewVinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _sync();
  }

  void _sync() {
    if (widget.playing) {
      _spin.repeat();
    } else {
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
                      decoration: const BoxDecoration(
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
