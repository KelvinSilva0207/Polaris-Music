import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_preset.dart';
import '../../../core/theme/theme_tokens.dart';
import '../domain/equalizer_controller.dart';
import 'equalizer_providers.dart';

/// Ecualizador de 10 bandas + preamplificador.
///
/// Los ajustes se aplican al audio mediante los filtros `lavfi` de libmpv
/// (Windows y Android). En plataformas sin DSP la pantalla lo indica y los
/// valores se siguen guardando como preset.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EqualizerState state = ref.watch(equalizerControllerProvider);
    final EqualizerController controller = ref.read(
      equalizerControllerProvider.notifier,
    );
    final bool backend = ref.watch(equalizerBackendAvailableProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Ecualizador',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '10 bandas de estudio + preamplificador',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
            Switch(value: state.enabled, onChanged: controller.setEnabled),
          ],
        ),
        const SizedBox(height: 14),
        if (backend) _DspStatus(enabled: state.enabled) else const _DspNotice(),
        const SizedBox(height: 10),
        _PresetSelector(state: state, controller: controller),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 230,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List<Widget>.generate(
                      AppConstants.eqBands.length,
                      (int index) => _BandSlider(
                        frequency: AppConstants.eqBands[index],
                        gain: index < state.bands.length
                            ? state.bands[index]
                            : 0,
                        enabled: state.enabled,
                        onChanged: (double value) =>
                            controller.setBand(index, value),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
              _PreampControl(
                value: state.preampDb,
                enabled: state.enabled,
                onChanged: controller.setPreamp,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => _saveAs(context, controller),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar como preset'),
            ),
            TextButton.icon(
              onPressed: controller.reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Restablecer a plano'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Presets incluidos: Plano, Rock, Pop, Jazz, Clásica, Electrónica, '
          'Hip-Hop, Vocal y Bass Boost. Mantén pulsado un preset propio para '
          'eliminarlo.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white38),
        ),
      ],
    );
  }

  Future<void> _saveAs(
    BuildContext context,
    EqualizerController controller,
  ) async {
    final TextEditingController name = TextEditingController();
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Guardar preset'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del preset',
            hintText: 'Mi firma sonora',
          ),
          onSubmitted: (String _) => Navigator.pop(context, true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      await controller.saveAs(name.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preset “${name.text.trim()}” guardado')),
        );
      }
    }
    name.dispose();
  }
}

class _DspStatus extends StatelessWidget {
  const _DspStatus({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final Color color = enabled ? accent : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            enabled
                ? Icons.graphic_eq_rounded
                : Icons.power_settings_new_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enabled
                  ? 'DSP activo: 10 bandas aplicadas al audio mediante libmpv.'
                  : 'DSP en espera. Activa el interruptor para escuchar el '
                        'ecualizador.',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _DspNotice extends StatelessWidget {
  const _DspNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFFF59E0B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta plataforma no permite aplicar filtros de audio. Los ajustes '
              'se guardan como preset, pero no modifican la reproducción.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({required this.state, required this.controller});

  final EqualizerState state;
  final EqualizerController controller;

  @override
  Widget build(BuildContext context) {
    if (state.presets.isEmpty) {
      return const Text(
        'Cargando presets…',
        style: TextStyle(color: Colors.white54),
      );
    }
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final EqualizerPreset preset = state.presets[index];
          final bool selected = preset.name == state.selectedPreset;
          return GestureDetector(
            onLongPress: preset.isBuiltIn
                ? null
                : () => _confirmDelete(context, preset),
            child: ChoiceChip(
              label: Text(preset.name),
              selected: selected,
              onSelected: (bool value) {
                if (value) controller.applyPreset(preset.name);
              },
              selectedColor: context.tokens.accent.withValues(alpha: 0.24),
              labelStyle: TextStyle(
                color: selected ? context.tokens.accent : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EqualizerPreset preset,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar preset'),
        content: Text('¿Eliminar el preset “${preset.name}”?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deletePreset(preset);
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.frequency,
    required this.gain,
    required this.enabled,
    required this.onChanged,
  });

  final double frequency;
  final double gain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  String get _label {
    if (frequency >= 1000) {
      final double k = frequency / 1000;
      return k == k.roundToDouble()
          ? '${k.toStringAsFixed(0)}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return frequency.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            gain == 0 ? '0' : gain.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gain == 0 ? Colors.white54 : accent,
            ),
          ),
          SizedBox(
            height: 168,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: gain.clamp(
                  AppConstants.eqMinGain,
                  AppConstants.eqMaxGain,
                ),
                min: AppConstants.eqMinGain,
                max: AppConstants.eqMaxGain,
                divisions: 24,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          Text(
            '$_label Hz',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _PreampControl extends StatelessWidget {
  const _PreampControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 8),
        const Text(
          'Preamplificador',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(-12.0, 12.0),
            min: -12,
            max: 12,
            divisions: 24,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
