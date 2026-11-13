/// Formateadores de presentación (duración, tamaño, fechas, contadores).
///
/// Se mantienen libres de dependencias de Flutter para poder testearlos.
class Formatters {
  Formatters._();

  /// `mm:ss` o `h:mm:ss` según corresponda.
  static String duration(Duration d) {
    final int totalSeconds = d.inSeconds.abs();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// Tiempo total escuchado en formato legible: `12 h 05 min`.
  static String listeningTime(int milliseconds) {
    final Duration d = Duration(milliseconds: milliseconds);
    if (d.inHours > 0) {
      final int minutes = d.inMinutes % 60;
      return '${d.inHours} h ${minutes.toString().padLeft(2, '0')} min';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes} min';
    }
    return '${d.inSeconds} s';
  }

  static String bytes(int value) {
    if (value < 1024) return '$value B';
    const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
    double size = value.toDouble();
    int unit = -1;
    do {
      size /= 1024;
      unit++;
    } while (size >= 1024 && unit < units.length - 1);
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
  }

  /// `1.234` / `12,3 mil` / `1,2 M`.
  static String count(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final double k = value / 1000;
      return k >= 100
          ? '${k.toStringAsFixed(0)} mil'
          : '${k.toStringAsFixed(1)} mil';
    }
    return '${(value / 1000000).toStringAsFixed(1)} M';
  }

  /// Fecha corta sin depender de inicialización de locales.
  static String date(DateTime value) {
    final String d = value.day.toString().padLeft(2, '0');
    final String m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  /// `hace 3 días`, `hoy`, `ayer`.
  static String relativeDate(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime a = DateTime(value.year, value.month, value.day);
    final DateTime b = DateTime(reference.year, reference.month, reference.day);
    final int days = b.difference(a).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    if (days < 30) return 'hace $days días';
    if (days < 365) return 'hace ${(days / 30).floor()} meses';
    return 'hace ${(days / 365).floor()} años';
  }
}
