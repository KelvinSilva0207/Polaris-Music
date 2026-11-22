import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/polaris_logo.dart';
import 'color_picker_dialog.dart';

/// Editor de las cuatro superficies compactas.
///
/// Cada cambio se escribe en su propia clave, por lo que se puede afinar la
/// isla sin alterar el mini-reproductor, el modo Teléfono ni el reproductor
/// principal. Los colores «Heredar» vuelven a seguir el tema global.
class CompactStylesScreen extends ConsumerStatefulWidget {
  const CompactStylesScreen({super.key});

  @override
  ConsumerState<CompactStylesScreen> createState() =>
      _CompactStylesScreenState();
}

class _CompactStylesScreenState extends ConsumerState<CompactStylesScreen> {
  CompactSurface _surface = CompactSurface.island;

  CompactStyleController get _controller =>
      ref.read(compactStylesProvider.notifier);

  Future<void> _pickColor({required bool accent}) async {
    final PolarisTokens tokens = context.tokens;
    final CompactStyleConfig style = ref.read(compactStyleProvider(_surface));
    final Color initial =
        (accent ? style.accent : style.background) ??
        (accent ? tokens.accent : tokens.background);
    await _pickChannel(
      title: accent
          ? 'Acento de ${_surface.label}'
          : 'Fondo de ${_surface.label}',
      initial: initial,
      setter: (Color? color) => accent
          ? _controller.setAccent(_surface, color)
          : _controller.setBackground(_surface, color),
    );
  }

  /// Selector genérico para los colores propios de cada superficie. `null`
  /// significa «heredar el acento del modo» y se ofrece como opción explícita.
  Future<void> _pickChannel({
    required String title,
    required Color initial,
    required Future<void> Function(Color? color) setter,
  }) async {
    final Color? picked = await ColorPickerDialog.show(
      context,
      title: title,
      initial: initial,
    );
    if (!mounted) return;
    if (picked != null) await setter(picked);
  }

  @override
  Widget build(BuildContext context) {
    final CompactStyleConfig style = ref.watch(compactStyleProvider(_surface));
    final PolarisTokens tokens = context.tokens;
    final Color accent = style.accent ?? tokens.accent;
    final Color background = style.background ?? tokens.background;

    return Scaffold(
      appBar: AppBar(
        title: Text('Diseños compactos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restablecer diseño de esta superficie',
            onPressed: () => _controller.reset(_surface),
            icon: Icon(Icons.restore_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: <Widget>[
          Text(
            'Personaliza cada vista por separado',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Los cambios se guardan al instante y no afectan a las otras vistas.',
            style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CompactSurface.values
                .map((CompactSurface surface) {
                  return ChoiceChip(
                    label: Text(surface.label),
                    avatar: Icon(surface.icon, size: 16),
                    selected: surface == _surface,
                    onSelected: (_) => setState(() => _surface = surface),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            _surface.description,
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.38)),
          ),
          const SizedBox(height: 18),
          _Preview(surface: _surface, style: style),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Colores'),
          _ColorRow(
            title: 'Acento',
            color: accent,
            inherited: style.accent == null,
            onPick: () => _pickColor(accent: true),
            onInherit: () => _controller.setAccent(_surface, null),
          ),
          const SizedBox(height: 8),
          _ColorRow(
            title: 'Fondo',
            color: background,
            inherited: style.background == null,
            onPick: () => _pickColor(accent: false),
            onInherit: () => _controller.setBackground(_surface, null),
          ),
          const SizedBox(height: 8),
          _ColorRow(
            title: 'Progreso',
            color: style.progressColor ?? accent,
            inherited: style.progressColor == null,
            onPick: () => _pickChannel(
              title: 'Progreso de ${_surface.label}',
              initial: style.progressColor ?? accent,
              setter: (Color? color) =>
                  _controller.setProgressColor(_surface, color),
            ),
            onInherit: () => _controller.setProgressColor(_surface, null),
          ),
          const SizedBox(height: 8),
          _ColorRow(
            title: 'Volumen',
            color: style.volumeColor ?? accent,
            inherited: style.volumeColor == null,
            onPick: () => _pickChannel(
              title: 'Volumen de ${_surface.label}',
              initial: style.volumeColor ?? accent,
              setter: (Color? color) =>
                  _controller.setVolumeColor(_surface, color),
            ),
            onInherit: () => _controller.setVolumeColor(_surface, null),
          ),
          const SizedBox(height: 22),
          _SectionTitle(title: 'Forma y acabado'),
          _Label(
            title: 'Estilo de tarjeta (solo esta superficie)',
            subtitle: style.cardStyle.description,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<CardStyle>(
            initialValue: style.cardStyle,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: CardStyle.values
                .map(
                  (CardStyle value) => DropdownMenuItem<CardStyle>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (CardStyle? value) {
              if (value != null) _controller.setCardStyle(_surface, value);
            },
          ),
          const SizedBox(height: 14),
          _Label(
            title: 'Forma de carátula (override por superficie)',
            subtitle: style.artworkShape == null
                ? 'Hereda la forma global'
                : style.artworkShape!.description,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<ArtworkShape?>(
            initialValue: style.artworkShape,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: <DropdownMenuItem<ArtworkShape?>>[
              const DropdownMenuItem<ArtworkShape?>(
                value: null,
                child: Text('Heredar (global)'),
              ),
              ...ArtworkShape.values.map(
                (ArtworkShape value) => DropdownMenuItem<ArtworkShape?>(
                  value: value,
                  child: Text(value.label),
                ),
              ),
            ],
            onChanged: (ArtworkShape? value) =>
                _controller.setArtworkShape(_surface, value),
          ),
          const SizedBox(height: 14),
          _Slider(
            title: 'Radio',
            value: style.cornerRadius,
            min: 8,
            max: 56,
            suffix: 'px',
            onChanged: (double value) =>
                _controller.setCornerRadius(_surface, value.roundToDouble()),
          ),
          _Slider(
            title: 'Opacidad de esta superficie',
            value: style.opacity,
            min: 0.35,
            max: 1,
            suffix: '%',
            scale: 100,
            onChanged: (double value) =>
                _controller.setOpacity(_surface, value),
          ),
          _Slider(
            title: 'Desenfoque de esta superficie',
            value: style.blur,
            min: 0,
            max: 32,
            suffix: 'px',
            onChanged: (double value) =>
                _controller.setBlur(_surface, value.roundToDouble()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Resplandor'),
            subtitle: Text('Sombras de color alrededor de la superficie'),
            value: style.glow,
            onChanged: (bool value) => _controller.setGlow(_surface, value),
          ),
          if (_surface == CompactSurface.island) ...<Widget>[
            const Divider(height: 28),
            _SectionTitle(title: 'Ocultado automático'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Apartar la isla al borde sin interacción'),
              subtitle: Text(
                'Se desliza hacia arriba y vuelve al acercar el ratón al borde',
              ),
              value: style.autoHide,
              onChanged: (bool value) =>
                  _controller.setAutoHide(_surface, value),
            ),
            if (style.autoHide)
              _Slider(
                title: 'Espera',
                value: style.autoHideSeconds.toDouble(),
                min: 2,
                max: 60,
                suffix: 's',
                onChanged: (double value) =>
                    _controller.setAutoHideSeconds(_surface, value.round()),
              ),
          ],
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.surface, required this.style});

  final CompactSurface surface;
  final CompactStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final resolved = style.resolve(context.tokens);
    final double width = switch (surface) {
      CompactSurface.island => 260,
      CompactSurface.mini || CompactSurface.phone => 320,
      CompactSurface.player => 340,
    };
    final double height = switch (surface) {
      CompactSurface.island => 82,
      CompactSurface.phone => 128,
      CompactSurface.mini => 74,
      CompactSurface.player => 150,
    };

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: CompactPanel(
          style: resolved,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              PolarisLogo(size: surface == CompactSurface.player ? 64 : 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      surface.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vista previa en vivo',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.inkAlpha(0.60),
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: 0.42,
                      minHeight: 3,
                      color: resolved.accent,
                      backgroundColor: context.inkAlpha(0.12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: context.inkAlpha(0.70),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: context.inkAlpha(0.38)),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.title,
    required this.color,
    required this.inherited,
    required this.onPick,
    required this.onInherit,
  });

  final String title;
  final Color color;
  final bool inherited;
  final VoidCallback onPick;
  final VoidCallback onInherit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: context.inkAlpha(0.24)),
        ),
      ),
      title: Text(title),
      subtitle: Text(
        inherited
            ? 'Heredado del tema'
            : ColorMath.toHex(color, withAlpha: true),
        style: TextStyle(fontSize: 10, color: context.inkAlpha(0.54)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(onPressed: onInherit, child: Text('Heredar')),
          IconButton(
            tooltip: 'Elegir color',
            onPressed: onPick,
            icon: Icon(Icons.colorize_rounded, size: 18),
          ),
        ],
      ),
      onTap: onPick,
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.scale = 1,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final double scale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(title, style: TextStyle(fontSize: 12)),
            const Spacer(),
            Text(
              '${(value * scale).round()}$suffix',
              style: TextStyle(fontSize: 10, color: context.inkAlpha(0.54)),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
