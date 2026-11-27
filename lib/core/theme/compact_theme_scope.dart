import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/compact_style_provider.dart';
import 'compact_style_config.dart';
import 'theme_tokens.dart';
import 'typography_theme.dart';

/// Aplica el diseño guardado de una superficie compacta a todo su subárbol.
///
/// Los widgets siguen leyendo `context.tokens`, pero reciben los tokens de esa
/// superficie en lugar de los globales. Así cada vista tiene acento, radios,
/// desenfoque y estilo de tarjeta propios sin duplicar lógica de dibujo.
class CompactThemeScope extends ConsumerWidget {
  const CompactThemeScope({
    super.key,
    required this.surface,
    required this.child,
  });

  final CompactSurface surface;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CompactStyleConfig style = ref.watch(compactStyleProvider(surface));
    final PolarisTokens parent = context.tokens;
    final ResolvedCompactStyle resolved = style.resolve(parent);
    final ThemeData base = Theme.of(context);

    final ColorScheme scheme = base.colorScheme.copyWith(
      primary: resolved.accent,
      secondary: resolved.accent.withValues(alpha: 0.78),
      surface: resolved.background,
    );
    final PolarisTokens tokens = parent.copyWith(
      accent: resolved.accent,
      background: resolved.background,
      surface: resolved.background,
      cardStyle: resolved.tokens.cardStyle,
      panelRadius: resolved.radius,
      glassOpacity: resolved.opacity,
      glassBlur: resolved.blur,
      borderColor: resolved.accent.withValues(alpha: 0.26),
    );
    final List<ThemeExtension<dynamic>> extensions = base.extensions.values
        .where((ThemeExtension<dynamic> e) => e is! PolarisTokens)
        .toList();
    extensions.add(tokens);

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        extensions: extensions,
        textTheme: buildPolarisTextTheme(
          base.textTheme,
          resolved.fontFamily,
          resolved.typography,
        ),
      ),
      child: child,
    );
  }
}
