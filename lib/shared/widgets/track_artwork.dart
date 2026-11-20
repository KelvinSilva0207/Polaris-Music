import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme_tokens.dart';

/// Portada de una pista con degradado de respaldo.
///
/// En Fase 1 se usa la carátula embebida cacheada por el escáner; el extractor
/// de paleta dominante ya existe para la Fase 2 (fondo dinámico).
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    this.path,
    this.size = 56,
    this.radius = 12,
    this.icon = Icons.music_note_rounded,
  });

  final String? path;
  final double size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tokens.accent.withValues(alpha: 0.55),
            tokens.accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Icon(
        icon,
        color: context.inkAlpha(0.85),
        size: size * 0.45,
      ),
    );

    final String? artwork = path;
    // Comprobación barata: evita intentar decodificar un archivo movido o
    // borrado y muestra directamente el respaldo limpio.
    if (artwork == null || artwork.isEmpty || !File(artwork).existsSync()) {
      return fallback;
    }

    // Listas, cola y mini reproductores: nunca hace falta decodizar la carátula
    // completa; 160 px cubre con holgura un tile de ~56 px a 3x.
    final int decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(24, 160);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(artwork),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            fallback,
      ),
    );
  }
}
