import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/models/equalizer_preset.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../domain/equalizer_controller.dart';
import 'eq_curve_painter.dart';
import 'equalizer_providers.dart';
import 'parametric_eq_view.dart';
import 'subharmonic_control.dart';

/// Ecualizador gráfico configurable + paramétrico + sub-armónico.
///
/// Los ajustes se aplican al audio mediante los filtros `lavfi` de libmpv
/// (Windows y Android). En plataformas sin DSP la pantalla lo indica y los
/// valores se siguen guardando como perfil.
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
                  Text(
                    '${state.config.frequencies.length} bandas, paramétrico y '
                    'sub-armónico',
                    style: TextStyle(color: context.inkAlpha(0.54)),
                  ),
                ],
              ),
            ),
            Switch(value: state.enabled, onChanged: controller.setEnabled),
          ],
        ),
        const SizedBox(height: 14),
        if (backend)
          _DspStatus(
            enabled: state.enabled,
            mode: state.mode,
            subEnabled: state.sub.enabled,
          )
        else
          const _DspNotice(),
        const SizedBox(height: 10),
        _DeviceProfileCard(state: state, controller: controller),
        const SizedBox(height: 10),
        _PresetSelector(state: state, controller: controller),
        const SizedBox(height: 16),
        SegmentedButton<EqMode>(
          segments: const <ButtonSegment<EqMode>>[
            ButtonSegment<EqMode>(
              value: EqMode.graphic,
              label: Text('Gráfico'),
              icon: Icon(Icons.bar_chart_rounded, size: 16),
            ),
            ButtonSegment<EqMode>(
              value: EqMode.parametric,
              label: Text('Paramétrico'),
              icon: Icon(Icons.tune_rounded, size: 16),
            ),
          ],
          selected: <EqMode>{state.mode},
          onSelectionChanged: (Set<EqMode> selection) {
            if (selection.isEmpty) return;
            controller.setMode(selection.first);
          },
        ),
        const SizedBox(height: 14),
        EqCurveView(config: state.config),
        const SizedBox(height: 14),
        if (state.mode == EqMode.graphic)
          _GraphicPanel(state: state, controller: controller)
        else
          ParametricEqView(
            filters: state.filters,
            onFilterChanged: controller.setParametricFilter,
            onAdd: controller.addParametricFilter,
            onRemove: controller.removeParametricFilter,
          ),
        const SizedBox(height: 14),
        SubharmonicControl(
          settings: state.sub,
          onChanged: (SubHarmonicSettings value) => controller.setSub(
            enabled: value.enabled,
            mix: value.mix,
            crossoverHz: value.crossoverHz,
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
              label: const Text('Guardar perfil'),
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
          'Elige 5, 10, 15, 20 o 31 bandas, ajusta cada frecuencia o usa hasta '
          '8 filtros paramétricos. Los perfiles se guardan con su curva, modo '
          'y sub-armónico. Mantén pulsado un perfil propio para eliminarlo.',
          style: TextStyle(fontSize: 12, color: context.inkAlpha(0.38)),
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
        title: const Text('Guardar perfil'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del perfil',
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
          SnackBar(content: Text('Perfil “${name.text.trim()}” guardado')),
        );
      }
    }
    name.dispose();
  }
}

class _GraphicPanel extends StatelessWidget {
  const _GraphicPanel({required this.state, required this.controller});

  final EqualizerState state;
  final EqualizerController controller;

  @override
  Widget build(BuildContext context) {
    final String layoutId = state.config.layoutId;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: context.tokens.panelDecoration(radius: 20, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final MapEntry<String, List<double>> entry
                    in AppConstants.eqBandLayouts.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${entry.key} bandas'),
                      selected: layoutId == entry.key,
                      onSelected: (bool value) {
                        if (value) controller.setBandLayout(entry.key);
                      },
                    ),
                  ),
                ChoiceChip(
                  label: const Text('Personalizada'),
                  selected: layoutId == AppConstants.eqCustomLayout,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(
                  state.frequencies.length,
                  (int index) => _BandSlider(
                    frequency: state.frequencies[index],
                    gain: index < state.bands.length ? state.bands[index] : 0,
                    onChanged: (double value) =>
                        controller.setBand(index, value),
                    onRemove: state.frequencies.length > 2
                        ? () => controller.removeBand(index)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.addBand,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Añadir banda personalizada'),
            ),
          ),
          const Divider(height: 16),
          _PreampControl(
            value: state.preampDb,
            onChanged: controller.setPreamp,
          ),
        ],
      ),
    );
  }
}

class _DspStatus extends StatelessWidget {
  const _DspStatus({
    required this.enabled,
    required this.mode,
    required this.subEnabled,
  });

  final bool enabled;
  final EqMode mode;
  final bool subEnabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final Color color = enabled ? accent : context.inkAlpha(0.54);
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
                  ? 'DSP activo: modo ${mode.label} mediante libmpv'
                        '${subEnabled ? ' + sub-armónico' : ''}.'
                  : 'DSP en espera. Activa el interruptor para escuchar los '
                        'filtros.',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.70)),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta plataforma no permite aplicar filtros de audio. Los ajustes '
              'se guardan como perfil, pero no modifican la reproducción.',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.70)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Perfiles de ecualizador por dispositivo de salida (altavoces vs. BT).
class _DeviceProfileCard extends StatelessWidget {
  const _DeviceProfileCard({required this.state, required this.controller});

  final EqualizerState state;
  final EqualizerController controller;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final String? deviceName = state.activeDeviceName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.headphones_rounded, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Perfil por dispositivo de salida',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deviceName == null
                          ? 'No se ha detectado la salida activa'
                          : 'Salida: $deviceName',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.perDeviceProfilesEnabled,
                onChanged: (bool value) =>
                    controller.setPerDeviceProfiles(value),
              ),
            ],
          ),
          if (controller.perDeviceProfilesEnabled &&
              deviceName != null) ...<Widget>[
            const SizedBox(height: 8),
            if (state.usingDeviceProfile)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'Aplicando el perfil guardado de $deviceName',
                      style: TextStyle(fontSize: 11, color: accent),
                    ),
                  ],
                ),
              ),
            FutureBuilder<bool>(
              future: controller.hasProfileForCurrentDevice(),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                final bool hasProfile = snapshot.data ?? false;
                return Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => controller.saveProfileForCurrentDevice(),
                      icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                      label: const Text('Guardar para este dispositivo'),
                    ),
                    if (hasProfile)
                      TextButton.icon(
                        onPressed: () =>
                            controller.deleteProfileForCurrentDevice(),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Borrar perfil'),
                      ),
                  ],
                );
              },
            ),
          ],
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
      return Text(
        'Cargando perfiles…',
        style: TextStyle(color: context.inkAlpha(0.54)),
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
            // Respuesta elástica al elegir un perfil: el chip "rebota" con
            // easeOutBack en lugar de cambiar de color sin movimiento.
            child: AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: context.motion.duration(
                const Duration(milliseconds: 280),
                category: MotionCategory.gestures,
              ),
              curve: Curves.easeOutBack,
              child: ChoiceChip(
                label: Text(preset.name),
                selected: selected,
                onSelected: (bool value) {
                  if (value) controller.applyPreset(preset.name);
                },
                selectedColor: context.tokens.accent.withValues(alpha: 0.24),
                labelStyle: TextStyle(
                  color: selected
                      ? context.tokens.accent
                      : context.inkAlpha(0.70),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
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
        title: const Text('Eliminar perfil'),
        content: Text('¿Eliminar el perfil “${preset.name}”?'),
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
    required this.onChanged,
    required this.onRemove,
  });

  final double frequency;
  final double gain;
  final ValueChanged<double> onChanged;
  final VoidCallback? onRemove;

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
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                gain == 0 ? '0' : gain.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: gain == 0 ? context.inkAlpha(0.54) : accent,
                ),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: context.inkAlpha(0.30),
                  ),
                ),
            ],
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
                onChanged: onChanged,
              ),
            ),
          ),
          Text(
            '$_label Hz',
            style: TextStyle(fontSize: 10, color: context.inkAlpha(0.54)),
          ),
        ],
      ),
    );
  }
}

class _PreampControl extends StatelessWidget {
  const _PreampControl({required this.value, required this.onChanged});

  final double value;
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
            value: value.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain),
            min: AppConstants.eqMinGain,
            max: AppConstants.eqMaxGain,
            divisions: 24,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
