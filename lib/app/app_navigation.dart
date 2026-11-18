import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secciones de la navegación principal, en el orden solicitado:
/// 1. Reproductor, 2. Biblioteca, 3. Online, 4. Ajustes.
///
/// El ecualizador queda fuera: se abre desde los controles del reproductor y
/// desde Ajustes, sin ocupar un hueco en la barra superior.
enum AppSection { player, library, online, settings }

extension AppSectionX on AppSection {
  String get label => switch (this) {
    AppSection.player => 'Reproductor',
    AppSection.library => 'Biblioteca',
    AppSection.online => 'Online',
    AppSection.settings => 'Ajustes',
  };

  IconData get icon => switch (this) {
    AppSection.player => Icons.play_circle_outline_rounded,
    AppSection.library => Icons.library_music_outlined,
    AppSection.online => Icons.cloud_outlined,
    AppSection.settings => Icons.settings_outlined,
  };

  IconData get activeIcon => switch (this) {
    AppSection.player => Icons.play_circle_rounded,
    AppSection.library => Icons.library_music_rounded,
    AppSection.online => Icons.cloud_rounded,
    AppSection.settings => Icons.settings_rounded,
  };
}

/// Sección activa. La app arranca siempre en el reproductor.
final StateProvider<AppSection> appSectionProvider = StateProvider<AppSection>(
  (_) => AppSection.player,
);
