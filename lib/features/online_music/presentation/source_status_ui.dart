import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../domain/music_source.dart';

/// Presentación común de estados de fuente para listas y diálogos.
abstract final class SourceStatusUi {
  static Color color(MusicSourceStatus status, BuildContext context) {
    if (status.available) return const Color(0xFF4ADE80);
    final Color muted = context.inkAlpha(0.54);
    return switch (status.issue) {
      MusicSourceIssue.authentication => const Color(0xFFFBBF24),
      MusicSourceIssue.region => const Color(0xFFF87171),
      MusicSourceIssue.rateLimited => const Color(0xFFFB923C),
      MusicSourceIssue.notConfigured => muted,
      MusicSourceIssue.offline => const Color(0xFF94A3B8),
      MusicSourceIssue.unsupported => context.inkAlpha(0.38),
      MusicSourceIssue.unavailable => const Color(0xFFF87171),
      MusicSourceIssue.canceled => muted,
      null => muted,
    };
  }

  static String shortLabel(MusicSourceStatus status) {
    if (status.available) return 'Lista';
    return switch (status.issue) {
      MusicSourceIssue.notConfigured => 'Sin configurar',
      MusicSourceIssue.authentication => 'Token',
      MusicSourceIssue.region => 'Región',
      MusicSourceIssue.rateLimited => 'Límite',
      MusicSourceIssue.offline => 'Sin red',
      MusicSourceIssue.unsupported => 'No disponible',
      MusicSourceIssue.unavailable => 'Error',
      MusicSourceIssue.canceled => 'Cancelada',
      null => 'Error',
    };
  }

  static String explain(MusicSourceIssue? issue) => switch (issue) {
    MusicSourceIssue.notConfigured => 'Falta configuración del usuario.',
    MusicSourceIssue.authentication =>
      'Revisa el token OAuth. Puede haber '
          'caducado o no tener los permisos necesarios.',
    MusicSourceIssue.region => 'El catálogo está restringido en tu región.',
    MusicSourceIssue.rateLimited => 'El proveedor limitó las peticiones.',
    MusicSourceIssue.offline => 'No hay conexión con el proveedor.',
    MusicSourceIssue.unsupported => 'El proveedor no ofrece esta función.',
    MusicSourceIssue.unavailable => 'El servicio no responde correctamente.',
    MusicSourceIssue.canceled => 'Consulta reemplazada por una más reciente.',
    null => 'Estado desconocido.',
  };

  static bool isActionable(MusicSourceIssue? issue) => switch (issue) {
    MusicSourceIssue.authentication ||
    MusicSourceIssue.region ||
    MusicSourceIssue.rateLimited ||
    MusicSourceIssue.offline ||
    MusicSourceIssue.unavailable => true,
    MusicSourceIssue.notConfigured ||
    MusicSourceIssue.unsupported ||
    MusicSourceIssue.canceled ||
    null => false,
  };
}
