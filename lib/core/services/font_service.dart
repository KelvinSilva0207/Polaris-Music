import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../constants/app_paths.dart';
import '../theme/font_catalog.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

/// Registro de fuentes del usuario.
///
/// Cada fuente importada se **copia** al directorio de datos de la app y se
/// registra en el motor con un nombre de familia propio. El archivo original
/// no se vuelve a necesitar: en cada arranque se recargan las copias internas.
class FontService {
  FontService(this._settings);

  final SettingsService _settings;
  final Map<String, String> _families = <String, String>{};
  List<ImportedFont> _fonts = const <ImportedFont>[];

  List<ImportedFont> get fonts => List<ImportedFont>.unmodifiable(_fonts);

  String? familyForId(String id) => _families[id];

  /// Recupera las copias internas. Una copia ausente o corrupta se descarta
  /// sin impedir que el resto de fuentes (y la app) arranquen.
  Future<void> restore() async {
    final List<ImportedFont> stored = ImportedFont.decode(
      _settings.getString(AppConstants.keyImportedFonts),
    );
    final Directory dir = await AppPaths.fonts();
    final List<ImportedFont> available = <ImportedFont>[];

    for (final ImportedFont font in stored) {
      final File file = File(p.join(dir.path, font.fileName));
      if (!await file.exists()) {
        AppLog.w('Fuentes', 'Falta la copia interna de ${font.name}');
        continue;
      }
      try {
        await _register(font, await file.readAsBytes());
        available.add(font);
      } catch (error) {
        AppLog.w('Fuentes', 'No se pudo cargar ${font.name}: $error');
      }
    }

    _fonts = available;
    _persist();
  }

  /// Importa un `.ttf`/`.otf`: valida el formato, guarda una copia interna y
  /// registra la familia en el motor antes de persistir la elección.
  Future<ImportedFont> importFont(String sourcePath) async {
    final String extension = p.extension(sourcePath).toLowerCase();
    if (extension != '.ttf' && extension != '.otf') {
      throw const FormatException('Solo se admiten archivos .ttf y .otf');
    }

    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('El archivo de fuente ya no existe');
    }
    final Uint8List bytes = await source.readAsBytes();
    if (!_looksLikeFont(bytes)) {
      throw const FormatException(
        'El archivo no es una fuente OpenType/TrueType',
      );
    }

    final String id = 'font_${DateTime.now().microsecondsSinceEpoch}';
    final String fileName = '$id$extension';
    final Directory dir = await AppPaths.fonts();
    final File copy = File(p.join(dir.path, fileName));
    await copy.writeAsBytes(bytes, flush: true);

    final ImportedFont font = ImportedFont(
      id: id,
      name: p.basenameWithoutExtension(sourcePath),
      fileName: fileName,
      family: 'PolarisUser_$id',
    );

    try {
      await _register(font, bytes);
    } catch (error) {
      await copy.delete();
      rethrow;
    }

    _fonts = <ImportedFont>[..._fonts, font];
    _persist();
    return font;
  }

  /// Elimina la copia interna y deja de registrar la familia.
  Future<void> removeFont(String id) async {
    final ImportedFont? font = _fontById(id);
    if (font == null) return;

    final Directory dir = await AppPaths.fonts();
    final File file = File(p.join(dir.path, font.fileName));
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException catch (error) {
        AppLog.w('Fuentes', 'No se pudo borrar ${font.fileName}: $error');
      }
    }

    _families.remove(id);
    unregisterCustomFontFamily(id);
    _fonts = _fonts
        .where((ImportedFont f) => f.id != id)
        .toList(growable: false);
    _persist();
  }

  ImportedFont? _fontById(String id) {
    for (final ImportedFont font in _fonts) {
      if (font.id == id) return font;
    }
    return null;
  }

  Future<void> _register(ImportedFont font, Uint8List bytes) async {
    final FontLoader loader = FontLoader(font.family);
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _families[font.id] = font.family;
    registerCustomFontFamily(font.id, font.family);
  }

  void _persist() {
    _settings.setString(
      AppConstants.keyImportedFonts,
      ImportedFont.encode(_fonts),
    );
  }

  /// Cabeceras TTF/OTF admitidas (incluye colecciones `ttcf`).
  static bool _looksLikeFont(Uint8List bytes) {
    if (bytes.length < 12) return false;
    if (bytes[0] == 0x00 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00) {
      return true;
    }
    if (bytes[0] == 0x74 &&
        bytes[1] == 0x72 &&
        bytes[2] == 0x75 &&
        bytes[3] == 0x65) {
      return true; // 'true'
    }
    if (bytes[0] == 0x4f &&
        bytes[1] == 0x54 &&
        bytes[2] == 0x54 &&
        bytes[3] == 0x4f) {
      return true; // 'OTTO'
    }
    if (bytes[0] == 0x74 &&
        bytes[1] == 0x74 &&
        bytes[2] == 0x63 &&
        bytes[3] == 0x66) {
      return true; // 'ttcf'
    }
    return false;
  }
}
