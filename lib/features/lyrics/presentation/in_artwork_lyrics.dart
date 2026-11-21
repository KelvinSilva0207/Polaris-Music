import 'package:flutter/material.dart';

import '../../../core/models/track.dart';
import 'expanded_lyrics_view.dart';

/// Compatibilidad: la letra ya no se limita al cuadro de la carátula.
///
/// Se conserva este nombre para no romper imports antiguos, pero delega en la
/// vista expandida del reproductor, que ocupa todo el_area libre disponible.
class InArtworkLyrics extends StatelessWidget {
  const InArtworkLyrics({
    super.key,
    required this.track,
    required this.size,
    required this.accent,
    required this.onClose,
  });

  final Track track;
  final double size;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ExpandedLyricsView(track: track, accent: accent, onClose: onClose);
  }
}
