import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/theme/theme_tokens.dart';

/// Editor de filtros paramétricos (frecuencia, ganancia y Q).
class ParametricEqView extends StatelessWidget {
  const ParametricEqView({
    super.key,
    required this.filters,
    required this.onFilterChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ParametricFilter> filters;
  final Function(int index, ParametricFilter value) onFilterChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < filters.length; i++)
          _FilterCard(
            index: i,
            filter: filters[i],
            onChanged: onFilterChanged,
            onRemove: onRemove,
          ),
        if (filters.length < AppConstants.eqMaxParametricFilters)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Añadir filtro'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Máximo de filtros alcanzado (8).',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.38)),
            ),
          ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.index,
    required this.filter,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final ParametricFilter filter;
  final Function(int index, ParametricFilter value) onChanged;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: context.inkAlpha(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Switch(
                value: filter.enabled,
                onChanged: (bool value) =>
                    onChanged(index, filter.copyWith(enabled: value)),
              ),
              Text(
                'Filtro ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              DropdownButton<ParametricFilterType>(
                value: filter.type,
                dropdownColor: context.tokens.panelOverlay,
                style: TextStyle(color: context.onPanel, fontSize: 12),
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<ParametricFilterType>>[
                  for (final ParametricFilterType type
                      in ParametricFilterType.values)
                    DropdownMenuItem<ParametricFilterType>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (ParametricFilterType? type) {
                  if (type != null) {
                    onChanged(index, filter.copyWith(type: type));
                  }
                },
              ),
              IconButton(
                tooltip: 'Eliminar filtro',
                icon: const Icon(Icons.close_rounded, size: 18),
                color: context.inkAlpha(0.38),
                onPressed: () => onRemove(index),
              ),
            ],
          ),
          _ControlRow(
            label: 'Frecuencia',
            value: _formatFrequency(filter.frequencyHz),
            child: Slider(
              value: _toSlider(filter.frequencyHz),
              min: 0,
              max: 1000,
              divisions: 1000,
              activeColor: accent,
              onChanged: (double value) => onChanged(
                index,
                filter.copyWith(frequencyHz: _fromSlider(value)),
              ),
            ),
          ),
          _ControlRow(
            label: 'Ganancia',
            value:
                '${filter.gainDb >= 0 ? '+' : ''}'
                '${filter.gainDb.toStringAsFixed(1)} dB',
            child: Slider(
              value: filter.gainDb.clamp(
                AppConstants.eqMinGain,
                AppConstants.eqMaxGain,
              ),
              min: AppConstants.eqMinGain,
              max: AppConstants.eqMaxGain,
              divisions: 48,
              activeColor: accent,
              onChanged: (double value) =>
                  onChanged(index, filter.copyWith(gainDb: value)),
            ),
          ),
          _ControlRow(
            label: 'Ancho / Q',
            value: filter.q.toStringAsFixed(2),
            child: Slider(
              value: filter.q.clamp(AppConstants.eqMinQ, AppConstants.eqMaxQ),
              min: AppConstants.eqMinQ,
              max: AppConstants.eqMaxQ,
              divisions: 100,
              activeColor: accent,
              onChanged: (double value) =>
                  onChanged(index, filter.copyWith(q: value)),
            ),
          ),
        ],
      ),
    );
  }

  static double _toSlider(double hz) {
    final double clamped = hz.clamp(
      AppConstants.eqMinFrequency,
      AppConstants.eqMaxFrequency,
    );
    return 1000 *
        math.log(clamped / AppConstants.eqMinFrequency) /
        math.log(AppConstants.eqMaxFrequency / AppConstants.eqMinFrequency);
  }

  static double _fromSlider(double value) {
    final double hz =
        AppConstants.eqMinFrequency *
        math.pow(
          AppConstants.eqMaxFrequency / AppConstants.eqMinFrequency,
          value / 1000,
        );
    return hz.clamp(AppConstants.eqMinFrequency, AppConstants.eqMaxFrequency);
  }

  static String _formatFrequency(double hz) {
    if (hz >= 1000) {
      final double k = hz / 1000;
      return '${k.toStringAsFixed(k < 10 ? 2 : 1)} kHz';
    }
    return '${hz.toStringAsFixed(0)} Hz';
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
          ),
        ),
        Expanded(child: child),
        SizedBox(
          width: 68,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.70)),
          ),
        ),
      ],
    );
  }
}
