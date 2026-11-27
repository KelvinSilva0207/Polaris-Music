import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/track_tile.dart';

/// Orden del índice lateral: primero los títulos que no empiezan por letra
/// (números, símbolos, emojis) y después el alfabeto español.
const List<String> alphabetLetters = <String>[
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'Ñ',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

/// Acentos habituales en títulos españoles. Se plegaban a su letra base para
/// que «Ángel» aparezca bajo la A y «Ñandú» bajo la Ñ.
const Map<String, String> _accentFold = <String, String>{
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'Ç': 'C',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ý': 'Y',
};

/// Inicial normalizada de un título, lista para el índice lateral.
///
/// Recorre los caracteres hasta encontrar una letra A-Z/Ñ; los números y los
/// símbolos iniciales caen en `'#'`. Los acentos se pliegan a su letra base.
String trackInitial(String title) {
  final String upper = title.trim().toUpperCase();
  for (final int rune in upper.runes) {
    final String char = String.fromCharCode(rune);
    final String folded = _accentFold[char] ?? char;
    final int code = folded.codeUnitAt(0);
    if ((code >= 65 && code <= 90) || folded == 'Ñ') return folded;
    // El primer carácter no alfabético manda el título a '#' aunque después
    // venga una letra: «!!! Difícil» no debe aparecer bajo la D.
    return '#';
  }
  return '#';
}

/// Primera posición de cada inicial en la lista tal como se muestra.
Map<String, int> buildAlphabetPositions(List<Track> tracks) {
  final Map<String, int> positions = <String, int>{};
  for (int index = 0; index < tracks.length; index++) {
    positions.putIfAbsent(trackInitial(tracks[index].title), () => index);
  }
  return positions;
}

/// Altura fija de cada fila. `TrackTile` es un `ListTile` de dos líneas con una
/// carátula de 46 * escala: fijar la altura permite saltos exactos por letra.
double alphabetTileExtent(double artworkScale) =>
    math.max<double>(72, 46 * artworkScale + 26);

/// Lista de pistas con índice A-Z lateral, como el de una agenda de contactos.
///
/// Toca o arrastra una letra para ir a la primera canción que empieza por ella.
/// El rail solo aparece cuando hay suficientes pistas para que compense.
class AlphabetizedTrackList extends StatefulWidget {
  const AlphabetizedTrackList({
    super.key,
    required this.tracks,
    required this.storageKey,
    this.artworkScale = 1,
    this.showIndex = true,
  });

  final List<Track> tracks;
  final String storageKey;
  final double artworkScale;
  final bool showIndex;

  @override
  State<AlphabetizedTrackList> createState() => _AlphabetizedTrackListState();
}

class _AlphabetizedTrackListState extends State<AlphabetizedTrackList> {
  final ScrollController _controller = ScrollController();
  late Map<String, int> _positions;
  String? _active;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _positions = buildAlphabetPositions(widget.tracks);
    _controller.addListener(_syncActiveLetter);
  }

  /// Mantiene resaltada la letra de la fila superior también al desplazarse a
  /// mano. Con `itemExtent` fijo el cálculo es exacto y no necesita medir.
  void _syncActiveLetter() {
    if (_programmaticScroll || !mounted || widget.tracks.isEmpty) return;
    final double extent = alphabetTileExtent(widget.artworkScale);
    final int index = (_controller.offset / extent).floor().clamp(
      0,
      widget.tracks.length - 1,
    );
    final String letter = trackInitial(widget.tracks[index].title);
    if (_active != letter) setState(() => _active = letter);
  }

  @override
  void didUpdateWidget(covariant AlphabetizedTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.tracks, oldWidget.tracks)) {
      _positions = buildAlphabetPositions(widget.tracks);
      if (_active != null && !_positions.containsKey(_active)) _active = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(String letter) {
    final int? index = _positions[letter];
    if (index == null) return;
    if (_active != letter) setState(() => _active = letter);
    final double target = index * alphabetTileExtent(widget.artworkScale);
    _programmaticScroll = true;
    _controller
        .animateTo(
          target.clamp(0.0, _controller.position.maxScrollExtent).toDouble(),
          duration: context.motion.duration(const Duration(milliseconds: 260)),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _programmaticScroll = false);
  }

  @override
  Widget build(BuildContext context) {
    final double extent = alphabetTileExtent(widget.artworkScale);
    final bool showRail = widget.tracks.length >= 12 && _positions.length > 1;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView.builder(
            key: PageStorageKey<String>(widget.storageKey),
            controller: _controller,
            padding: EdgeInsets.fromLTRB(16, 0, showRail ? 42 : 16, 120),
            itemExtent: extent,
            itemCount: widget.tracks.length,
            itemBuilder: (BuildContext context, int index) => TrackTile(
              track: widget.tracks[index],
              queue: widget.tracks,
              index: index,
              showIndex: widget.showIndex,
              artworkSize: 46 * widget.artworkScale,
            ),
          ),
        ),
        if (showRail)
          Positioned(
            right: 2,
            top: 8,
            bottom: 112,
            child: _AlphabetRail(
              available: _positions.keys.toSet(),
              active: _active,
              onSelected: _select,
            ),
          ),
      ],
    );
  }
}

class _AlphabetRail extends StatelessWidget {
  const _AlphabetRail({
    required this.available,
    required this.active,
    required this.onSelected,
  });

  final Set<String> available;
  final String? active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemHeight =
            (constraints.maxHeight / alphabetLetters.length)
                .clamp(13.0, 24.0)
                .toDouble();

        void selectAt(double dy) {
          final int index = (dy / itemHeight).floor().clamp(
            0,
            alphabetLetters.length - 1,
          );
          onSelected(alphabetLetters[index]);
        }

        void selectFromGlobal(Offset globalPosition) {
          final RenderBox box = context.findRenderObject()! as RenderBox;
          selectAt(box.globalToLocal(globalPosition).dy);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) =>
              selectFromGlobal(details.globalPosition),
          onVerticalDragStart: (DragStartDetails details) =>
              selectFromGlobal(details.globalPosition),
          onVerticalDragUpdate: (DragUpdateDetails details) =>
              selectFromGlobal(details.globalPosition),
          child: SizedBox(
            width: 26,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String letter in alphabetLetters)
                  SizedBox(
                    height: itemHeight,
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: itemHeight * 0.60,
                          fontWeight: active == letter
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: !available.contains(letter)
                              ? context.inkAlpha(0.18)
                              : active == letter
                              ? tokens.accent
                              : context.inkAlpha(0.62),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
