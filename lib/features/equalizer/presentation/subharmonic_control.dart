import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/theme/theme_tokens.dart';

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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: context.tokens.panelDecoration(radius: 18, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.graphic_eq_rounded, size: 20, color: accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sintetizador sub-armónico',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
            'Genera una octava por debajo de los graves para realzar el '
            'subwoofer. Nivel y corte se limitan de forma segura.',
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const SizedBox(width: 78, child: Text('Mezcla')),
              Expanded(
                child: Slider(
                  value: settings.mix.clamp(
                    AppConstants.subMinMix,
                    AppConstants.subMaxMix,
                  ),
                  min: AppConstants.subMinMix,
                  max: AppConstants.subMaxMix,
                  divisions: 35,
                  activeColor: accent,
                  onChanged: (double value) =>
                      onChanged(settings.copyWith(mix: value)),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  '${(settings.mix * 100).toStringAsFixed(0)} %',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.inkAlpha(0.70),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 78, child: Text('Corte')),
              Expanded(
                child: Slider(
                  value: settings.crossoverHz.clamp(
                    AppConstants.subMinCrossover,
                    AppConstants.subMaxCrossover,
                  ),
                  min: AppConstants.subMinCrossover,
                  max: AppConstants.subMaxCrossover,
                  divisions: 32,
                  activeColor: accent,
                  onChanged: (double value) =>
                      onChanged(settings.copyWith(crossoverHz: value)),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  '${settings.crossoverHz.toStringAsFixed(0)} Hz',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.inkAlpha(0.70),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
