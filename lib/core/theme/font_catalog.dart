import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Identificadores estables de las fuentes incluidas y de la del sistema.
const String fontIdPolarisSans = 'polarisSans';
const String fontIdPolarisDisplay = 'polarisDisplay';
const String fontIdSystem = 'system';
const String fontIdCustomPrefix = 'custom:';

/// Opción mostrada en el selector de fuentes.
@immutable
class FontOption {
  const FontOption({
    required this.id,
    required this.label,
    required this.family,
    this.description,
  });

  final String id;
  final String label;

  /// `null` significa «usa la fuente del sistema».
  final String? family;
  final String? description;
}

/// Fuentes distribuidas con la app. Todas bajo SIL Open Font License.
const List<FontOption> builtInFonts = <FontOption>[
  FontOption(
    id: fontIdPolarisSans,
    label: 'Polaris Sans',
    family: 'Polaris Sans',
    description: 'Geométrica y legible. Tipografía base de Polaris.',
  ),
  FontOption(
    id: fontIdPolarisDisplay,
    label: 'Polaris Display',
    family: 'Polaris Display',
    description: 'Cabeceras geométricas con personalidad propia.',
  ),
  FontOption(
    id: fontIdSystem,
    label: 'Del sistema',
    family: null,
    description: 'Respeta la tipografía nativa de Windows o Android.',
  ),
];

/// Fuente importada por el usuario y copiada dentro de los datos de la app.
@immutable
class ImportedFont {
  const ImportedFont({
    required this.id,
    required this.name,
    required this.fileName,
    required this.family,
  });

  final String id;
  final String name;
  final String fileName;
  final String family;

  String get configId => '$fontIdCustomPrefix$id';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'fileName': fileName,
    'family': family,
  };

  factory ImportedFont.fromJson(Map<String, Object?> json) => ImportedFont(
    id: json['id'] is String ? json['id']! as String : '',
    name: json['name'] is String ? json['name']! as String : 'Fuente',
    fileName: json['fileName'] is String ? json['fileName']! as String : '',
    family: json['family'] is String
        ? json['family']! as String
        : 'PolarisUser',
  );

  static List<ImportedFont> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <ImportedFont>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <ImportedFont>[];
      return decoded
          .whereType<Map>()
          .map(
            (Map entry) =>
                ImportedFont.fromJson(Map<String, Object?>.from(entry)),
          )
          .where(
            (ImportedFont font) =>
                font.id.isNotEmpty && font.fileName.isNotEmpty,
          )
          .toList(growable: false);
    } on FormatException {
      return const <ImportedFont>[];
    }
  }

  static String encode(List<ImportedFont> fonts) =>
      jsonEncode(fonts.map((ImportedFont f) => f.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportedFont &&
          other.id == id &&
          other.name == name &&
          other.fileName == fileName &&
          other.family == family;

  @override
  int get hashCode => Object.hash(id, name, fileName, family);
}

/// Registro en memoria de las familias importadas ya cargadas por el motor.
///
/// [FontService] lo mantiene al día; así los resolvedores de estilos compactos
/// pueden encontrar una fuente del usuario sin depender de un provider.
final Map<String, String> customFontFamilies = <String, String>{};

void registerCustomFontFamily(String id, String family) =>
    customFontFamilies[id] = family;

void unregisterCustomFontFamily(String id) => customFontFamilies.remove(id);

/// Resuelve el identificador guardado a un nombre de familia de Flutter.
///
/// `null` selecciona explícitamente la fuente del sistema. Si la fuente
/// importada ya no está disponible se cae a Polaris Sans, para que la interfaz
/// nunca quede sin tipografía.
String? resolveFontFamily(
  String fontId, [
  List<ImportedFont> imported = const [],
]) {
  if (fontId == fontIdSystem) return null;
  for (final FontOption option in builtInFonts) {
    if (option.id == fontId) return option.family;
  }
  if (fontId.startsWith(fontIdCustomPrefix)) {
    final String id = fontId.substring(fontIdCustomPrefix.length);
    for (final ImportedFont font in imported) {
      if (font.id == id) return font.family;
    }
    final String? registered = customFontFamilies[id];
    if (registered != null) return registered;
  }
  return builtInFonts.first.family;
}
