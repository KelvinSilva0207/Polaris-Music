import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart'
    show CommonMetadataSetters, Picture, PictureType, updateMetadata;
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/models/track.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import 'library_repository.dart';

/// Valores del formulario de edición de etiquetas.
class MetadataEditValues {
  const MetadataEditValues({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
  });

  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
}

/// Datos que cruzan el límite del isolate al escribir el archivo de audio.
class MetadataWriteRequest {
  const MetadataWriteRequest({
    required this.path,
    required this.values,
    this.artworkPath,
  });

  final String path;
  final MetadataEditValues values;
  final String? artworkPath;
}

/// Escribe etiquetas en el archivo original y actualiza la base de datos.
///
/// La lectura/escritura de sobres de audio se hace en un isolate porque los
/// writers reconstruyen el bloque de metadatos y pueden tardar en archivos
/// grandes. Si el contenedor no tiene writer (por ejemplo OGG), se conserva la
/// edición local y se avisa por log.
class MetadataEditorService {
  MetadataEditorService(this._repository);

  static const String _tag = 'MetadataEditor';

  final LibraryRepository _repository;

  /// Devuelve la ruta de la carátula cacheada, si se eligió una nueva.
  Future<String?> save(
    Track track,
    MetadataEditValues values, {
    Uint8List? artworkBytes,
    String? artworkExtension,
  }) async {
    if (track.id <= 0 || track.path.isEmpty) return null;

    String? artworkPath;
    if (artworkBytes != null && artworkBytes.isNotEmpty) {
      artworkPath = await _cacheArtwork(
        track.path,
        artworkBytes,
        artworkExtension,
      );
    }

    final MetadataWriteRequest request = MetadataWriteRequest(
      path: track.path,
      values: values,
      artworkPath: artworkPath,
    );
    try {
      await Isolate.run<void>(() => writeAudioTags(request));
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudieron escribir las etiquetas del archivo; '
        'se guarda solo la base de datos',
        error,
        stack,
      );
    }

    await _repository.updateMetadata(
      track,
      title: values.title,
      artist: values.artist,
      album: values.album,
      albumArtist: values.albumArtist,
      genre: values.genre,
      year: values.year,
      trackNumber: values.trackNumber,
      discNumber: values.discNumber,
      artworkPath: artworkPath,
    );
    return artworkPath;
  }

  /// Guarda la carátula elegida junto al resto de cachés de la aplicación.
  ///
  /// El nombre se deriva de la ruta del audio para que una edición posterior
  /// sobrescriba la misma imagen en vez de acumular copias.
  Future<String?> _cacheArtwork(
    String audioPath,
    Uint8List bytes,
    String? extension,
  ) async {
    try {
      final Directory dir = await AppPaths.artwork();
      final String ext = _normalizeExtension(extension);
      final String name = '${FileUtils.fnv1a(audioPath)}.$ext';
      final File target = File(p.join(dir.path, name));
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo guardar la carátula elegida', error, stack);
      return null;
    }
  }

  static String _normalizeExtension(String? extension) {
    final String value = (extension ?? 'jpg')
        .replaceFirst('.', '')
        .toLowerCase();
    switch (value) {
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
        return value;
      default:
        return 'jpg';
    }
  }
}

/// Aplica los cambios al contenedor de audio. Se ejecuta en un isolate.
void writeAudioTags(MetadataWriteRequest request) {
  final File file = File(request.path);
  if (!file.existsSync()) {
    throw FileSystemException('No existe el archivo de audio', file.path);
  }

  Uint8List? artworkBytes;
  String mimeType = 'image/jpeg';
  final String? artworkPath = request.artworkPath;
  if (artworkPath != null) {
    final File artworkFile = File(artworkPath);
    if (artworkFile.existsSync()) {
      artworkBytes = artworkFile.readAsBytesSync();
      mimeType = _mimeForPath(artworkPath);
    }
  }

  final MetadataEditValues values = request.values;
  final String genre = values.genre.trim();
  final int? year = values.year;

  // `updateMetadata` conserva los campos que no se tocan, a diferencia de
  // `replaceMetadata`, que reconstruye el bloque completo.
  updateMetadata(file, (tag) {
    tag.setTitle(values.title.trim());
    tag.setArtist(values.artist.trim());
    tag.setAlbum(values.album.trim());
    tag.setGenres(genre.isEmpty ? const <String>[] : <String>[genre]);
    tag.setYear(year == null ? null : DateTime(year));
    tag.setTrackNumber(values.trackNumber);
    tag.setCD(values.discNumber, null);
    if (artworkBytes != null) {
      tag.setPictures(<Picture>[
        Picture(artworkBytes, mimeType, PictureType.illustration),
      ]);
    }
  });
}

String _mimeForPath(String path) {
  final String extension = p
      .extension(path)
      .replaceFirst('.', '')
      .toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    _ => 'image/jpeg',
  };
}
