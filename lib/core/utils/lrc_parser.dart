import 'metadata_text.dart';

/// Parser de letras LRC (sincronizadas) y texto plano.
///
/// Soporta timestamps `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss:xx]`, varias marcas por
/// línea, metadatos (`[ar:...]`, `[ti:...]`, `[offset:...]`) y líneas vacías.
class LyricLine {
  const LyricLine({required this.time, required this.text, this.wordTimes});

  final Duration time;
  final String text;

  /// Marcas `<mm:ss.xx>` de LRC mejorado, una por palabra. Si no vienen en el
  /// archivo se reparte el tiempo de la línea entre las palabras.
  final List<Duration>? wordTimes;

  List<String> get words => text
      .split(RegExp(r'\s+'))
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);

  @override
  String toString() => '[$time] $text';
}

class LrcDocument {
  LrcDocument({
    required this.lines,
    required this.synced,
    this.title = '',
    this.artist = '',
    this.offset = Duration.zero,
  });

  final List<LyricLine> lines;
  final bool synced;
  final String title;
  final String artist;
  final Duration offset;

  static final RegExp _tagPattern = RegExp(r'^\[([a-zA-Z]+):(.*)\]$');
  static final RegExp _timePattern = RegExp(
    r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _wordTimePattern = RegExp(
    r'<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>',
  );

  static Duration _timeOf(RegExpMatch match) {
    final String? fraction = match.group(3);
    final int millis = fraction == null
        ? 0
        : (double.parse('0.$fraction') * 1000).round();
    return Duration(
      minutes: int.parse(match.group(1)!),
      seconds: int.parse(match.group(2)!),
      milliseconds: millis,
    );
  }

  factory LrcDocument.empty() =>
      LrcDocument(lines: const <LyricLine>[], synced: false);

  /// ¿El texto contiene marcas de tiempo?
  static bool looksSynced(String raw) => _timePattern.hasMatch(raw);

  factory LrcDocument.parse(String raw) {
    final List<LyricLine> lines = <LyricLine>[];
    String title = '';
    String artist = '';
    Duration offset = Duration.zero;

    // Repara el mojibake sin tocar los saltos de línea: el parser necesita
    // que cada marca de tiempo siga en su propia línea.
    final String source = MetadataText.repairLines(raw);
    for (final String rawLine in const LineSplitter().convert(source)) {
      final String line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      final RegExpMatch? tag = _tagPattern.firstMatch(line.trim());
      if (tag != null && _timePattern.firstMatch(line) == null) {
        final String key = tag.group(1)!.toLowerCase();
        final String value = tag.group(2)!.trim();
        if (key == 'ti') title = value;
        if (key == 'ar') artist = value;
        if (key == 'offset') {
          offset = Duration(milliseconds: int.tryParse(value) ?? 0);
        }
        continue;
      }

      final Iterable<RegExpMatch> matches = _timePattern.allMatches(line);
      if (matches.isEmpty) {
        // Letra sin sincronía.
        lines.add(LyricLine(time: Duration.zero, text: line));
        continue;
      }

      final String cleaned = line.replaceAll(_timePattern, '').trim();
      final List<Duration> wordTimes = _wordTimePattern
          .allMatches(cleaned)
          .map(_timeOf)
          .toList(growable: false);
      final String text = cleaned
          .replaceAll(_wordTimePattern, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      for (final RegExpMatch match in matches) {
        lines.add(
          LyricLine(
            time: _timeOf(match),
            text: text,
            wordTimes: wordTimes.isEmpty ? null : wordTimes,
          ),
        );
      }
    }

    lines.sort((LyricLine a, LyricLine b) => a.time.compareTo(b.time));
    final bool hasTiming =
        lines.isNotEmpty && lines.any((LyricLine l) => l.time > Duration.zero);

    return LrcDocument(
      lines: List<LyricLine>.unmodifiable(lines),
      synced: hasTiming,
      title: title,
      artist: artist,
      offset: offset,
    );
  }

  /// Índice de la línea activa para una posición de reproducción.
  ///
  /// Devuelve `null` si aún no empieza la primera línea o no hay sincronía.
  int? activeIndexAt(Duration position) {
    if (!synced || lines.isEmpty) return null;
    final Duration adjusted = position - offset;
    int low = 0;
    int high = lines.length - 1;
    int? found;
    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      if (lines[mid].time <= adjusted) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  String get plainText => lines.map((LyricLine l) => l.text).join('\n');

  /// Momento en que termina la línea [index].
  ///
  /// La siguiente línea marca el final natural; las marcas por palabra solo
  /// afinan el resaltado dentro de ese hueco. Si es la última, se aplica un
  /// margen corto para que la palabra final no se apague de golpe.
  Duration endTimeFor(
    int index, {
    Duration fallback = const Duration(seconds: 3),
  }) {
    if (index < 0 || index >= lines.length) return Duration.zero;
    final LyricLine line = lines[index];
    final Duration end = index + 1 < lines.length
        ? lines[index + 1].time
        : Duration.zero;
    if (end <= line.time) return line.time + fallback;
    return end;
  }

  /// Serializa el documento a LRC para guardarlo en Drift o exportarlo.
  String toLrc() {
    final StringBuffer buffer = StringBuffer();
    if (title.isNotEmpty) buffer.writeln('[ti:$title]');
    if (artist.isNotEmpty) buffer.writeln('[ar:$artist]');
    if (offset != Duration.zero) {
      buffer.writeln('[offset:${offset.inMilliseconds}]');
    }
    for (final LyricLine line in lines) {
      buffer.writeln('[${formatTimestamp(line.time)}]${line.text}');
    }
    return buffer.toString();
  }

  /// Marca de tiempo LRC con centésimas: `[mm:ss.xx]`.
  static String formatTimestamp(Duration time) {
    final int minutes = time.inMinutes;
    final int seconds = time.inSeconds.remainder(60);
    final int hundredths = time.inMilliseconds.remainder(1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}';
  }
}

/// Resaltado palabra por palabra para el modo karaoke.
extension LyricLineKaraoke on LyricLine {
  /// Índice de la palabra en curso, o `-1` si la línea aún no ha empezado.
  int wordIndexAt(Duration position, Duration endTime) {
    final List<String> words = this.words;
    if (words.isEmpty || position < time) return -1;
    final List<Duration>? marks = wordTimes;
    if (marks != null && marks.length == words.length) {
      int found = 0;
      for (int i = 0; i < marks.length; i++) {
        if (marks[i] <= position) found = i;
      }
      return found;
    }
    final int durationMs = (endTime - time).inMilliseconds;
    if (durationMs <= 0) return 0;
    final double ratio = (position - time).inMilliseconds / durationMs;
    return (ratio * words.length).floor().clamp(0, words.length - 1);
  }

  /// Avance (0–1) de la palabra activa, para teñirla progresivamente.
  double wordProgressAt(Duration position, Duration endTime) {
    final int index = wordIndexAt(position, endTime);
    if (index < 0) return 0;
    final List<String> words = this.words;
    if (index >= words.length) return 1;
    final List<Duration>? marks = wordTimes;
    final Duration start = marks != null && marks.length == words.length
        ? marks[index]
        : time +
              Duration(
                milliseconds:
                    (((endTime - time).inMilliseconds) * index / words.length)
                        .round(),
              );
    final Duration next = marks != null && marks.length == words.length
        ? (index + 1 < marks.length ? marks[index + 1] : endTime)
        : time +
              Duration(
                milliseconds:
                    (((endTime - time).inMilliseconds) *
                            (index + 1) /
                            words.length)
                        .round(),
              );
    final int span = (next - start).inMilliseconds;
    if (span <= 0) return 1;
    return ((position - start).inMilliseconds / span).clamp(0.0, 1.0);
  }
}

/// `LineSplitter` local para no arrastrar `dart:convert` en tests puros.
class LineSplitter {
  const LineSplitter();

  List<String> convert(String input) => input.split(RegExp(r'\r\n|\r|\n'));
}
