import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme_tokens.dart';

/// Devuelve el valor de [value] tras avanzar [direction] pasos de [step].
///
/// El paso se aplica de forma exacta y se acota a [min]/[max]. El redondeo a
/// seis decimales solo evita el ruido de coma flotante en Q y mezcla.
double precisionStepValue(
  double value,
  double direction, {
  required double min,
  required double max,
  required double step,
}) {
  final double raw = (value + direction * step).clamp(min, max).toDouble();
  return double.parse(raw.toStringAsFixed(6));
}

class _ParsedValue {
  const _ParsedValue(this.value, this.error);

  final double? value;
  final String? error;
}

_ParsedValue _parseValue(
  String raw, {
  required double min,
  required double max,
  required int decimals,
  required String unit,
}) {
  final String normalized = raw
      .trim()
      .replaceAll('−', '-')
      .replaceFirst(',', '.');
  final double? parsed = double.tryParse(normalized);
  String? error;
  if (parsed == null || parsed.isNaN || parsed.isInfinite) {
    error = 'Introduce un número válido.';
  } else if (parsed < min || parsed > max) {
    final String suffix = unit.isEmpty ? '' : ' $unit';
    error =
        'Rango permitido: ${min.toStringAsFixed(decimals)} a '
        '${max.toStringAsFixed(decimals)}$suffix';
  }
  return _ParsedValue(error == null ? parsed : null, error);
}

/// Botón compacto de `-` o `+` que aplica un paso exacto al valor actual.
class PrecisionStepButton extends StatelessWidget {
  const PrecisionStepButton({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.direction,
    required this.onChanged,
    required this.label,
    this.stepLabel = '1',
    this.size = 24,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final double direction;
  final ValueChanged<double> onChanged;
  final String label;
  final String stepLabel;
  final double size;

  double get _next =>
      precisionStepValue(value, direction, min: min, max: max, step: step);

  bool get _enabled =>
      direction < 0 ? _next < value - 1e-9 : _next > value + 1e-9;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final bool down = direction < 0;
    final String sign = down ? '−' : '+';
    return Tooltip(
      message: '$label $sign$stepLabel',
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _enabled
                ? accent.withValues(alpha: 0.14)
                : context.inkAlpha(0.03),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _enabled
                  ? accent.withValues(alpha: 0.32)
                  : context.inkAlpha(0.08),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? () => onChanged(_next) : null,
            child: Icon(
              down ? Icons.remove_rounded : Icons.add_rounded,
              size: size * 0.62,
              color: _enabled ? context.ink : context.inkAlpha(0.26),
            ),
          ),
        ),
      ),
    );
  }
}

/// Par de botones de precisión. En vertical el `+` queda arriba, siguiendo la
/// orientación de los potenciómetros de las bandas.
class PrecisionStepButtons extends StatelessWidget {
  const PrecisionStepButtons({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.label,
    this.stepLabel = '1',
    this.axis = Axis.horizontal,
    this.size = 24,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String label;
  final String stepLabel;
  final Axis axis;
  final double size;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = <Widget>[
      PrecisionStepButton(
        value: value,
        min: min,
        max: max,
        step: step,
        direction: -1,
        onChanged: onChanged,
        label: label,
        stepLabel: stepLabel,
        size: size,
      ),
      PrecisionStepButton(
        value: value,
        min: min,
        max: max,
        step: step,
        direction: 1,
        onChanged: onChanged,
        label: label,
        stepLabel: stepLabel,
        size: size,
      ),
    ];
    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[buttons[1], const SizedBox(height: 4), buttons[0]],
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

/// Diálogo limpio para escribir un valor exacto dentro de un rango.
///
/// El valor se previsualiza mientras se escribe (el controlador ya aplica
/// debounce al DSP). Si se cancela o se cierra el diálogo, se restaura el valor
/// original para que no quede un cambio accidental.
Future<double?> showPrecisionValueDialog({
  required BuildContext context,
  required String title,
  required String label,
  required double current,
  required double min,
  required double max,
  required int decimals,
  required String unit,
  required ValueChanged<double> onPreview,
}) async {
  final double? result = await showDialog<double>(
    context: context,
    builder: (BuildContext context) => _PrecisionValueDialog(
      title: title,
      label: label,
      current: current,
      min: min,
      max: max,
      decimals: decimals,
      unit: unit,
      onPreview: onPreview,
    ),
  );
  if (result == null) onPreview(current);
  return result;
}

class _PrecisionValueDialog extends StatefulWidget {
  const _PrecisionValueDialog({
    required this.title,
    required this.label,
    required this.current,
    required this.min,
    required this.max,
    required this.decimals,
    required this.unit,
    required this.onPreview,
  });

  final String title;
  final String label;
  final double current;
  final double min;
  final double max;
  final int decimals;
  final String unit;
  final ValueChanged<double> onPreview;

  @override
  State<_PrecisionValueDialog> createState() => _PrecisionValueDialogState();
}

class _PrecisionValueDialogState extends State<_PrecisionValueDialog> {
  late final TextEditingController _field;
  double? _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(
      text: widget.current.toStringAsFixed(widget.decimals),
    );
    _field.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _field.text.length,
    );
    _validate(notify: false);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _validate({bool preview = false, bool notify = true}) {
    final _ParsedValue parsed = _parseValue(
      _field.text,
      min: widget.min,
      max: widget.max,
      decimals: widget.decimals,
      unit: widget.unit,
    );
    if (notify) {
      setState(() {
        _value = parsed.value;
        _error = parsed.error;
      });
    } else {
      _value = parsed.value;
      _error = parsed.error;
    }
    if (preview && _value != null) widget.onPreview(_value!);
  }

  void _apply() {
    if (_value != null) Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent;
    final Color errorColor = Theme.of(context).colorScheme.error;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        decoration: context.tokens.panelDecoration(
          radius: 22,
          // El borde especular es direccional; con radio redondeado Flutter
          // exige un color uniforme en los cuatro lados.
          borderColor: accent.withValues(alpha: 0.28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.tune_rounded, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-−]')),
              ],
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                suffixText: widget.unit.isEmpty ? null : widget.unit,
                errorText: _error,
                filled: true,
                fillColor: context.inkAlpha(0.05),
                labelStyle: TextStyle(color: context.inkAlpha(0.60)),
                errorStyle: TextStyle(fontSize: 11, color: errorColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.inkAlpha(0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
              onChanged: (_) => _validate(preview: true),
              onSubmitted: (_) => _apply(),
            ),
            const SizedBox(height: 8),
            Text(
              'El valor se aplica mientras escribes. Cancelar lo devuelve al '
              'original.',
              style: TextStyle(fontSize: 11, color: context.inkAlpha(0.48)),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: context.inkAlpha(0.70)),
                  ),
                ),
                FilledButton(
                  onPressed: _value == null ? null : _apply,
                  style: FilledButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal con paso de 1 y doble toque para escritura manual.
///
/// [displayScale] permite mostrar unidades amigables (por ejemplo, 0.22 de
/// mezcla como 22 %) sin cambiar el valor real que consume el DSP. Para un
/// deslizador no lineal, [sliderValue] usa su propia escala visual.
class PrecisionSliderRow extends StatelessWidget {
  const PrecisionSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.unit,
    required this.onChanged,
    this.displayScale = 1,
    this.formatter,
    this.sliderValue,
    this.sliderMin,
    this.sliderMax,
    this.divisions,
    this.stepLabel,
    this.onSliderChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String unit;
  final ValueChanged<double> onChanged;
  final double displayScale;
  final String Function(double value)? formatter;
  final double? sliderValue;
  final double? sliderMin;
  final double? sliderMax;
  final int? divisions;
  final String? stepLabel;
  final ValueChanged<double>? onSliderChanged;

  String get _resolvedStepLabel {
    if (stepLabel != null) return stepLabel!;
    if (step >= 1) return step.toStringAsFixed(0);
    return step.toStringAsFixed(step >= 0.1 ? 1 : 2);
  }

  String _format(double raw) {
    if (formatter != null) return formatter!(raw);
    final String sign = raw > 0 ? '+' : '';
    final String suffix = unit.isEmpty ? '' : ' $unit';
    return '$sign${raw.toStringAsFixed(decimals)}$suffix';
  }

  void _openDialog(BuildContext context) {
    showPrecisionValueDialog(
      context: context,
      title: label,
      label: 'Valor exacto',
      current: value * displayScale,
      min: min * displayScale,
      max: max * displayScale,
      decimals: decimals,
      unit: unit,
      onPreview: (double displayed) => onChanged(displayed / displayScale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double lower = sliderMin ?? min;
    final double upper = sliderMax ?? max;
    final int steps = divisions ?? ((max - min) / step).round().clamp(1, 1000);
    final String hint = 'Doble toque en la barra para escribir $label';
    return Row(
      children: <Widget>[
        Flexible(
          flex: 2,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
          ),
        ),
        const SizedBox(width: 4),
        PrecisionStepButton(
          value: value,
          min: min,
          max: max,
          step: step,
          direction: -1,
          onChanged: onChanged,
          label: label,
          stepLabel: _resolvedStepLabel,
          size: 22,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Tooltip(
            message: hint,
            child: GestureDetector(
              onDoubleTap: () => _openDialog(context),
              child: Slider(
                value: (sliderValue ?? value).clamp(lower, upper).toDouble(),
                min: lower,
                max: upper,
                divisions: steps,
                onChanged: onSliderChanged ?? onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        PrecisionStepButton(
          value: value,
          min: min,
          max: max,
          step: step,
          direction: 1,
          onChanged: onChanged,
          label: label,
          stepLabel: _resolvedStepLabel,
          size: 22,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 66,
          child: Tooltip(
            message: hint,
            child: GestureDetector(
              onDoubleTap: () => _openDialog(context),
              child: Text(
                _format(value),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, color: context.inkAlpha(0.70)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
