/// Comparación de versiones semánticas mínima (sin dependencias externas).
///
/// Acepta `1.2.3`, `v1.2.3`, `1.2.3-beta.1+build`.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = '',
    this.build = '',
  });

  final int major;
  final int minor;
  final int patch;
  final String preRelease;
  final String build;

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  static SemanticVersion? tryParse(String input) {
    final RegExpMatch? match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    return SemanticVersion(
      major: int.parse(match.group(1)!),
      minor: int.tryParse(match.group(2) ?? '') ?? 0,
      patch: int.tryParse(match.group(3) ?? '') ?? 0,
      preRelease: match.group(4) ?? '',
      build: match.group(5) ?? '',
    );
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // Una versión estable es mayor que su pre-release.
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;
    return preRelease.compareTo(other.preRelease);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease.isEmpty ? '' : '-$preRelease'}';

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.preRelease == preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);
}

/// Resultado de comparar la versión instalada contra la última publicada.
class VersionCheck {
  const VersionCheck({
    required this.current,
    required this.latest,
    required this.isUpdateAvailable,
  });

  final SemanticVersion current;
  final SemanticVersion latest;
  final bool isUpdateAvailable;
}
