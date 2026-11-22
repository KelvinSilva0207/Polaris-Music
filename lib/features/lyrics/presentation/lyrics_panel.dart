import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';
import '../data/lyrics_service.dart';
import 'lyrics_providers.dart';

/// Panel de letras sincronizadas con resaltado de la línea activa.
///
/// La línea activa se resalta sin etiquetar modos. En [immersive] la
/// tipografía crece y el scroll se enmascara con degradados suaves en los
/// bordes.
class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({
    super.key,
    required this.track,
    this.immersive = false,
    this.showTools = false,
    this.onDownload,
    this.onImport,
    this.onEdit,
    this.karaoke = false,
    this.onSeek,
  });

  final Track track;
  final bool immersive;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onImport;
  final VoidCallback? onEdit;

  /// Resaltado palabra por palabra sobre la línea activa.
  final bool karaoke;

  /// Al tocar una línea, la canción salta a esa marca de tiempo.
  final ValueChanged<Duration>? onSeek;

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  /// Claves estables por línea: permiten centrar la activa aunque las Alturas
  /// cambien al crecer la tipografía de la línea resaltada.
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};
  int? _lastActive;

  @override
  void didUpdateWidget(covariant LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) {
      _lastActive = null;
      _lineKeys.clear();
    }
  }

  GlobalKey _keyFor(int index) =>
      _lineKeys.putIfAbsent(index, () => GlobalKey());

  /// Desplaza suavemente hasta la línea activa sin recalcular fracciones:
  /// `ensureVisible` respeta alturas variables y no interrumpe el scroll del
  /// usuario más de lo estrictamente necesario.
  void _scrollToActive(int index) {
    if (index == _lastActive) return;
    _lastActive = index;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final BuildContext? lineContext = _keyFor(index).currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        alignment: widget.immersive ? 0.42 : 0.5,
        duration: context.motion.duration(const Duration(milliseconds: 420)),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LyricsResult?> lyrics = ref.watch(
      lyricsForTrackProvider(widget.track),
    );
    // El proveedor convierte el tick de posición en un índice: solo cambia
    // cuando pasa a la línea siguiente, no 5 veces por segundo.
    final int? active = ref.watch(lyricsActiveIndexProvider(widget.track));

    return lyrics.when(
      loading: () => const _LyricsLoading(),
      error: (Object error, StackTrace stack) => _LyricsEmpty(
        immersive: widget.immersive,
        title: 'No se pudo cargar la letra',
        retryLabel: 'Reintentar',
        onRetry: () => ref.invalidate(lyricsForTrackProvider(widget.track)),
        onImport: widget.onImport,
      ),
      data: (LyricsResult? result) {
        if (result == null || result.isEmpty) {
          return _LyricsEmpty(
            immersive: widget.immersive,
            title: 'Sin letra para esta canción',
            retryLabel: 'Buscar letra',
            onRetry:
                widget.onDownload ??
                () => ref.invalidate(lyricsForTrackProvider(widget.track)),
            onImport: widget.onImport,
          );
        }

        final LrcDocument document = result.document;
        if (!document.synced) {
          return _PlainLyrics(
            text: document.plainText,
            source: result.source,
            immersive: widget.immersive,
          );
        }

        if (active != null) _scrollToActive(active);

        final PolarisTokens tokens = context.tokens;
        final FontWeight bodyWeight =
            tokens.typography?.lyrics ?? FontWeight.w600;
        final double activeSize = widget.immersive ? 34 : 22;
        final double normalSize = widget.immersive ? 24 : 17;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _LyricsMeta(
              source: result.source,
              synced: document.synced,
              immersive: widget.immersive,
              showTools: widget.showTools,
              onDownload: widget.onDownload,
              onImport: widget.onImport,
              onEdit: widget.onEdit,
            ),
            if (widget.onSeek != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.immersive ? 18 : 12,
                  vertical: 2,
                ),
                child: Text(
                  'Toca una línea para saltar a ese instante',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.onPanel.withValues(alpha: 0.5),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ShaderMask(
                // Los bordes se desvanecen para que la letra aparezca y
                // desaparezca sin cortes bruscos al hacer scroll.
                shaderCallback: (Rect bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: const <double>[0, 0.12, 0.88, 1],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: ListView.builder(
                  key: const PageStorageKey<String>('polaris-lyrics'),
                  padding: widget.immersive
                      ? const EdgeInsets.fromLTRB(28, 44, 28, 96)
                      : const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  itemCount: document.lines.length,
                  itemBuilder: (BuildContext context, int index) {
                    final LyricLine line = document.lines[index];
                    final bool isActive = index == active;
                    final bool isPast = active != null && index < active;

                    return TweenAnimationBuilder<double>(
                      key: _keyFor(index),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: context.motion.duration(
                        Duration(milliseconds: 280 + (index % 6) * 26),
                      ),
                      curve: Curves.easeOutCubic,
                      builder:
                          (BuildContext context, double value, Widget? child) =>
                              Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 12),
                                  child: child,
                                ),
                              ),
                      child: Semantics(
                        button: document.synced && widget.onSeek != null,
                        label: document.synced && widget.onSeek != null
                            ? 'Saltar al segundo ${(line.time + document.offset).inSeconds} de ${line.text}'
                            : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: !document.synced || widget.onSeek == null
                              ? null
                              : () {
                                  unawaited(HapticFeedback.selectionClick());
                                  widget.onSeek!(line.time + document.offset);
                                },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: widget.immersive ? 11 : 6,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: context.motion.duration(
                                const Duration(milliseconds: 220),
                              ),
                              style: TextStyle(
                                fontSize: isActive ? activeSize : normalSize,
                                height: 1.32,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : bodyWeight,
                                color: isActive
                                    ? tokens.karaokeColor
                                    : isPast
                                    ? context.onPanel.withValues(alpha: 0.52)
                                    : context.onPanel.withValues(alpha: 0.92),
                                shadows: isActive
                                    ? <Shadow>[
                                        Shadow(
                                          color: tokens.karaokeColor.withValues(
                                            alpha: 0.42,
                                          ),
                                          blurRadius: widget.immersive
                                              ? 24
                                              : 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              textAlign: TextAlign.center,
                              child:
                                  widget.karaoke &&
                                      isActive &&
                                      line.words.isNotEmpty
                                  ? _KaraokeLineText(
                                      line: line,
                                      document: document,
                                      index: index,
                                      accent: tokens.karaokeColor,
                                    )
                                  : Text(line.text.isEmpty ? '♪' : line.text),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Línea activa con resaltado palabra por palabra.
///
/// Solo se monta para la línea en curso, así que el tick de posición no
/// reconstruye toda la lista. Las marcas `<mm:ss.xx>` se usan si existen; si no,
/// se reparte la duración de la línea entre sus palabras.
class _KaraokeLineText extends ConsumerWidget {
  const _KaraokeLineText({
    required this.line,
    required this.document,
    required this.index,
    required this.accent,
  });

  final LyricLine line;
  final LrcDocument document;
  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration raw = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration position = raw - document.offset;
    final Duration end = document.endTimeFor(index);
    final int active = line.wordIndexAt(position, end);
    final double progress = line.wordProgressAt(position, end);
    final TextStyle base = DefaultTextStyle.of(context).style;
    final Color idle = base.color ?? accent;

    final List<TextSpan> spans = <TextSpan>[];
    final List<String> words = line.words;
    for (int i = 0; i < words.length; i++) {
      final Color color;
      if (i < active) {
        color = accent;
      } else if (i == active) {
        color = Color.lerp(idle, accent, 0.35 + 0.65 * progress) ?? accent;
      } else {
        color = idle.withValues(alpha: 0.5);
      }
      spans.add(
        TextSpan(
          text: i == 0 ? words[i] : ' ${words[i]}',
          style: base.copyWith(color: color),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }
}

/// Origen de la letra. Informativo y discreto: nunca anuncia un "modo".
class _LyricsMeta extends StatelessWidget {
  const _LyricsMeta({
    required this.source,
    required this.synced,
    required this.immersive,
    required this.showTools,
    this.onDownload,
    this.onImport,
    this.onEdit,
  });

  final String source;
  final bool synced;
  final bool immersive;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onImport;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String label = switch (source) {
      'local' => 'Archivo .lrc local',
      'embedded' => 'Letra embebida',
      'lrclib' => 'LRCLIB',
      'backup' => 'Respaldo',
      'user' => 'Tu letra',
      _ => source,
    };
    final Color ink = context.onPanel.withValues(
      alpha: immersive ? 0.52 : 0.64,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        immersive ? 18 : 12,
        6,
        showTools ? 4 : 12,
        6,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              synced ? label : '$label · sin sincronía',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: immersive ? 11 : 12, color: ink),
            ),
          ),
          if (showTools) ...<Widget>[
            IconButton(
              tooltip: 'Descargar de LRCLIB',
              onPressed: onDownload,
              icon: Icon(Icons.cloud_download_outlined, size: 18, color: ink),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Importar archivo .lrc',
              onPressed: onImport,
              icon: Icon(Icons.file_open_outlined, size: 18, color: ink),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Crear o sincronizar letra',
              onPressed: onEdit,
              icon: Icon(Icons.edit_note_rounded, size: 18, color: ink),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.tokens.karaokeColor.withValues(alpha: 0.65),
      ),
    ),
  );
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({
    required this.text,
    required this.source,
    this.immersive = false,
  });

  final String text;
  final String source;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: immersive
          ? const EdgeInsets.fromLTRB(28, 28, 28, 96)
          : const EdgeInsets.fromLTRB(20, 20, 20, 48),
      children: <Widget>[
        Text(
          'Letra sin sincronía · $source',
          style: TextStyle(
            fontSize: 11,
            color: context.onPanel.withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          text,
          textAlign: immersive ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: immersive ? 24 : 18,
            height: 1.5,
            color: context.onPanel.withValues(alpha: 0.92),
            fontWeight: context.tokens.typography?.lyrics ?? FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Estado vacío o de fallo silencioso: información mínima y acciones opcionales.
class _LyricsEmpty extends StatelessWidget {
  const _LyricsEmpty({
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.immersive = false,
    this.onImport,
  });

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;
  final bool immersive;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.onPanel.withValues(alpha: 0.62);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lyrics_outlined,
              size: immersive ? 28 : 24,
              color: context.onPanel.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: immersive ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onRetry,
                  icon: Icon(Icons.search_rounded, size: 16, color: ink),
                  label: Text(retryLabel, style: TextStyle(color: ink)),
                ),
                if (onImport != null)
                  TextButton.icon(
                    onPressed: onImport,
                    icon: Icon(Icons.file_open_outlined, size: 16, color: ink),
                    label: Text('Importar .lrc', style: TextStyle(color: ink)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
