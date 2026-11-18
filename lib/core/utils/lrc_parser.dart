/// Parser de letras LRC (sincronizadas) y texto plano.
///
/// Soporta timestamps `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss:xx]`, varias marcas por
/// línea, metadatos (`[ar:...]`, `[ti:...]`, `[offset:...]`) y líneas vacías.
class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;

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

  factory LrcDocument.empty() =>
      LrcDocument(lines: const <LyricLine>[], synced: false);

  /// ¿El texto contiene marcas de tiempo?
  static bool looksSynced(String raw) => _timePattern.hasMatch(raw);

  factory LrcDocument.parse(String raw) {
    final List<LyricLine> lines = <LyricLine>[];
    String title = '';
    String artist = '';
    Duration offset = Duration.zero;

    for (final String rawLine in const LineSplitter().convert(raw)) {
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

      final String text = line.replaceAll(_timePattern, '').trim();
      for (final RegExpMatch match in matches) {
        final int minutes = int.parse(match.group(1)!);
        final int seconds = int.parse(match.group(2)!);
        final String? fraction = match.group(3);
        int millis = 0;
        if (fraction != null) {
          final double value = double.parse('0.$fraction');
          millis = (value * 1000).round();
        }
        lines.add(
          LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
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

/// `LineSplitter` local para no arrastrar `dart:convert` en tests puros.
class LineSplitter {
  const LineSplitter();

  List<String> convert(String input) => input.split(RegExp(r'\r\n|\r|\n'));
}
