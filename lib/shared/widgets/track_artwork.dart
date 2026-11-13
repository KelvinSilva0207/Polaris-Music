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
        color: Colors.white.withValues(alpha: 0.85),
        size: size * 0.45,
      ),
    );

    final String? artwork = path;
    if (artwork == null || artwork.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(artwork),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            fallback,
      ),
    );
  }
}
