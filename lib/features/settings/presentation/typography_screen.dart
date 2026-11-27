import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/compact_style_provider.dart';
import '../../../core/providers/typography_provider.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/font_catalog.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/theme/typography_config.dart';

const String _inherit = '__inherit__';

/// Editor de identidad tipográfica de Polaris.
///
/// Todas las fuentes se guardan como copias internas y se registran en el
/// motor en cada arranque, así el archivo original del usuario puede moverse
/// o borrarse sin romper la app.
class TypographyScreen extends ConsumerStatefulWidget {
  const TypographyScreen({super.key});

  @override
  ConsumerState<TypographyScreen> createState() => _TypographyScreenState();
}

class _TypographyScreenState extends ConsumerState<TypographyScreen> {
  Future<void> _importFont() async {
    List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Importar fuente (.ttf o .otf)',
        type: FileType.custom,
        allowedExtensions: <String>['ttf', 'otf'],
      );
    } catch (error) {
      if (mounted) _toast('No se pudo abrir el selector: $error');
      return;
    }
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    try {
      final ImportedFont font = await ref
          .read(fontLibraryProvider.notifier)
          .importFont(path);
      if (!mounted) return;
      ref.read(typographyProvider.notifier).setFamily(font.configId);
      _toast('«${font.name}» importada y aplicada');
    } on FormatException catch (error) {
      if (mounted) _toast(error.message);
    } on FileSystemException catch (error) {
      if (mounted) _toast('No se pudo leer la fuente: ${error.message}');
    } catch (error) {
      if (mounted) _toast('No se pudo importar: $error');
    }
  }

  Future<void> _removeFont(ImportedFont font) async {
    final bool current = ref.read(typographyProvider).familyId == font.configId;
    await ref.read(fontLibraryProvider.notifier).removeFont(font.id);
    if (!mounted) return;
    if (current) {
      ref.read(typographyProvider.notifier).setFamily(fontIdPolarisSans);
    }
    _toast('Fuente eliminada de la copia interna');
  }

  Future<void> _resetAll() async {
    ref.read(typographyProvider.notifier).reset();
    final Map<CompactSurface, CompactStyleConfig> styles = ref.read(
      compactStylesProvider,
    );
    final CompactStyleController controller = ref.read(
      compactStylesProvider.notifier,
    );
    for (final MapEntry<CompactSurface, CompactStyleConfig> entry
        in styles.entries) {
      await controller.update(
        entry.key,
        entry.value.copyWith(fontFamilyId: null, fontScale: null),
      );
    }
    if (mounted) _toast('Tipografía restablecida');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<FontOption> _options(List<ImportedFont> imported) => <FontOption>[
    ...builtInFonts,
    for (final ImportedFont font in imported)
      FontOption(
        id: font.configId,
        label: font.name,
        family: font.family,
        description: 'Importada · copia interna en tus datos',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final TypographyConfig config = ref.watch(typographyProvider);
    final List<ImportedFont> imported = ref.watch(fontLibraryProvider);
    final List<FontOption> options = _options(imported);
    final Color accent = context.accent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipografía'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restablecer tipografía global',
            onPressed: _resetAll,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: <Widget>[
          Text(
            'Identidad Polaris',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Familia, tamaño y peso se aplican en vivo a toda la app.',
            style: TextStyle(color: context.inkAlpha(0.60)),
          ),
          const SizedBox(height: 18),
          _Preview(config: config, options: options, accent: accent),
          const SizedBox(height: 18),
          _Section(
            title: 'Fuente base',
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options
                    .map(
                      (FontOption option) => ChoiceChip(
                        label: Text(option.label),
                        selected: option.id == config.familyId,
                        onSelected: (_) => ref
                            .read(typographyProvider.notifier)
                            .setFamily(option.id),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              Text(
                '${options.where((FontOption o) => o.id == config.familyId).map((FontOption o) => o.description ?? '').firstOrNull ?? ''}'
                ' · Los colores siguen el acento RGB/HSL activo.',
                style: TextStyle(color: context.inkAlpha(0.54), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Tamaño y jerarquía',
            children: <Widget>[
              _Slider(
                label: 'Escala global',
                value: config.scale,
                min: 0.8,
                max: 1.4,
                format: (double v) => '${(v * 100).round()}%',
                onChanged: (double v) =>
                    ref.read(typographyProvider.notifier).setScale(v),
              ),
              const SizedBox(height: 12),
              _WeightSelector(
                label: 'Títulos',
                value: config.headlineWeight,
                onChanged: (int v) =>
                    ref.read(typographyProvider.notifier).setHeadlineWeight(v),
              ),
              _WeightSelector(
                label: 'Metadatos',
                value: config.metadataWeight,
                onChanged: (int v) =>
                    ref.read(typographyProvider.notifier).setMetadataWeight(v),
              ),
              _WeightSelector(
                label: 'Letras de canciones',
                value: config.lyricsWeight,
                onChanged: (int v) =>
                    ref.read(typographyProvider.notifier).setLyricsWeight(v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Mis fuentes importadas',
            children: <Widget>[
              if (imported.isEmpty)
                Text(
                  'Todavía no has importado fuentes. Puedes usar .ttf y .otf; '
                  ' Polaris guarda una copia segura en sus datos.',
                  style: TextStyle(color: context.inkAlpha(0.54), fontSize: 12),
                ),
              for (final ImportedFont font in imported)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.font_download_outlined, color: accent),
                  title: Text(font.name),
                  subtitle: Text(
                    font.fileName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar copia interna',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeFont(font),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _importFont,
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: const Text('Importar fuente propia'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Tipografía por vista',
            children: <Widget>[
              Text(
                'Actívala solo donde quieras una identidad distinta: isla, '
                'mini-reproductor, teléfono o reproductor principal.',
                style: TextStyle(color: context.inkAlpha(0.54), fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (final CompactSurface surface in CompactSurface.values)
                _SurfaceFontTile(surface: surface, options: options),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.config,
    required this.options,
    required this.accent,
  });

  final TypographyConfig config;
  final List<FontOption> options;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String? family = resolveFontFamily(config.familyId);
    final TextStyle base = TextStyle(
      fontFamily: family,
      color: context.inkAlpha(0.90),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Polaris Music',
            style: base.copyWith(
              fontSize: 30 * config.scale,
              fontWeight: config.headline,
              letterSpacing: -0.8,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ahora suena · Título de la canción',
            style: base.copyWith(
              fontSize: 16 * config.scale,
              fontWeight: config.metadata,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Entre luces de neón\nse escribe esta canción',
            style: base.copyWith(
              fontSize: 19 * config.scale,
              fontWeight: config.lyrics,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ARTISTA · ÁLBUM · 04:32',
            style: base.copyWith(
              fontSize: 11 * config.scale,
              fontWeight: config.metadata,
              letterSpacing: 0.6,
              color: context.inkAlpha(0.54),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceFontTile extends ConsumerWidget {
  const _SurfaceFontTile({required this.surface, required this.options});

  final CompactSurface surface;
  final List<FontOption> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CompactStyleConfig style = ref.watch(compactStyleProvider(surface));
    final bool custom = style.fontFamilyId != null || style.fontScale != null;
    final String selected = style.fontFamilyId ?? _inherit;
    final double scale = style.fontScale ?? ref.watch(typographyProvider).scale;
    final Color accent = context.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.inkAlpha(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.inkAlpha(0.07)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(surface.label),
                subtitle: Text(
                  custom ? 'Tipografía propia' : 'Hereda la tipografía global',
                  style: const TextStyle(fontSize: 11),
                ),
                value: custom,
                onChanged: (bool value) {
                  final CompactStyleController controller = ref.read(
                    compactStylesProvider.notifier,
                  );
                  if (value) {
                    controller.update(
                      surface,
                      style.copyWith(
                        fontFamilyId: ref.read(typographyProvider).familyId,
                        fontScale: ref.read(typographyProvider).scale,
                      ),
                    );
                  } else {
                    controller.update(
                      surface,
                      style.copyWith(fontFamilyId: null, fontScale: null),
                    );
                  }
                },
              ),
              if (custom) ...<Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Heredar fuente'),
                      selected: selected == _inherit,
                      onSelected: (_) => ref
                          .read(compactStylesProvider.notifier)
                          .setFontFamily(surface, null),
                    ),
                    for (final FontOption option in options)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: selected == option.id,
                        onSelected: (_) => ref
                            .read(compactStylesProvider.notifier)
                            .setFontFamily(surface, option.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _Slider(
                  label: 'Escala',
                  value: scale,
                  min: 0.8,
                  max: 1.4,
                  format: (double v) => '${(v * 100).round()}%',
                  onChanged: (double v) => ref
                      .read(compactStylesProvider.notifier)
                      .setFontScale(surface, v),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vista previa tipográfica',
                  style: TextStyle(
                    fontFamily: resolveFontFamily(
                      selected == _inherit
                          ? ref.watch(typographyProvider).familyId
                          : selected,
                    ),
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.inkAlpha(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.inkAlpha(0.07)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              format(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.accent,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 20).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _WeightSelector extends StatelessWidget {
  const _WeightSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  static const List<int> weights = <int>[400, 500, 600, 700, 800];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: ValueKey<int>(weights.contains(value) ? value : 500),
              initialValue: weights.contains(value) ? value : 500,
              decoration: const InputDecoration(isDense: true),
              items: <DropdownMenuItem<int>>[
                for (final int weight in weights)
                  DropdownMenuItem<int>(
                    value: weight,
                    child: Text('${weight ~/ 100}00 · ${_weightName(weight)}'),
                  ),
              ],
              onChanged: (int? next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _weightName(int weight) => switch (weight) {
    400 => 'Regular',
    500 => 'Medium',
    600 => 'Semibold',
    700 => 'Bold',
    800 => 'Extrabold',
    _ => 'Regular',
  };
}
