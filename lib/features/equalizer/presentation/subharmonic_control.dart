import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/theme/theme_tokens.dart';
import 'precision_controls.dart';

/// Controles del sintetizador sub-armónico.
///
/// La rama toma solo lo que queda por debajo del corte, lo desplaza una octava
/// hacia abajo y lo mezcla a bajo nivel; el DSP termina con un limitador para
/// que el refuerzo no recorte.
class SubharmonicControl extends StatelessWidget {
  const SubharmonicControl({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final SubHarmonicSettings settings;
  final ValueChanged<SubHarmonicSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final bool active = settings.enabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.07) : context.inkAlpha(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? accent.withValues(alpha: 0.40)
              : context.inkAlpha(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.graphic_eq_rounded,
                size: 20,
                color: active ? accent : context.inkAlpha(0.54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sintetizador sub-armónico',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? context.onPanel : context.inkAlpha(0.54),
                  ),
                ),
              ),
              Switch(
                value: settings.enabled,
                onChanged: (bool value) =>
                    onChanged(settings.copyWith(enabled: value)),
              ),
            ],
          ),
          Text(
            'Una octava por debajo de los graves, con limitador.',
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: active ? 1 : 0.55,
            child: Column(
              children: <Widget>[
                PrecisionSliderRow(
                  label: 'Mezcla',
                  value: settings.mix,
                  min: AppConstants.subMinMix,
                  max: AppConstants.subMaxMix,
                  step: 0.01,
                  decimals: 0,
                  unit: '%',
                  displayScale: 100,
                  stepLabel: '1',
                  onChanged: (double value) =>
                      onChanged(settings.copyWith(mix: value)),
                  formatter: (double v) => '${(v * 100).toStringAsFixed(0)} %',
                ),
                PrecisionSliderRow(
                  label: 'Corte',
                  value: settings.crossoverHz,
                  min: AppConstants.subMinCrossover,
                  max: AppConstants.subMaxCrossover,
                  step: 1,
                  decimals: 0,
                  unit: 'Hz',
                  onChanged: (double value) =>
                      onChanged(settings.copyWith(crossoverHz: value)),
                  formatter: (double v) => '${v.toStringAsFixed(0)} Hz',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
