import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';

/// Progreso del escaneo de la biblioteca.
class ScanProgress {
  const ScanProgress({
    required this.processed,
    required this.total,
    this.currentFile = '',
  });

  final int processed;
  final int total;
  final String currentFile;

  double get fraction => total == 0 ? 0 : processed / total;
}

/// Resumen del último escaneo.
class ScanSummary {
  const ScanSummary({
    this.filesFound = 0,
    this.inserted = 0,
    this.updated = 0,
    this.removed = 0,
    this.failed = 0,
    this.duration = Duration.zero,
  });

  final int filesFound;
  final int inserted;
  final int updated;
  final int removed;
  final int failed;
  final Duration duration;

  int get totalProcessed => inserted + updated;

  @override
  String toString() =>
      'ScanSummary(encontrados: $filesFound, '
      'nuevos: $inserted, actualizados: $updated, eliminados: $removed, '
      'errores: $failed)';
}

/// Metadata serializable extraída en un isolate de fondo.
class _ScannedFile {
  const _ScannedFile({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    required this.year,
    required this.trackNumber,
    required this.discNumber,
    required this.durationMs,
    required this.bitrate,
    required this.sampleRate,
    required this.format,
    required this.size,
    this.artworkBytes,
    this.artworkExtension,
    this.lyrics,
    this.lyricsSynced = false,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int durationMs;
  final int? bitrate;
  final int? sampleRate;
  final String format;
  final int size;
  final Uint8List? artworkBytes;
  final String? artworkExtension;
  final String? lyrics;
  final bool lyricsSynced;
}

/// Escanea carpetas en isolates y persiste en Drift.
///
/// - La metadata se lee con `audio_metadata_reader` en lotes dentro de
///   `Isolate.run`, así la UI no se congela con bibliotecas grandes.
/// - El upsert conserva favoritos, playCount y fechas de alta.
/// - Las carátulas se cachean en `AppPaths.artwork()` con un hash estable de
///   la ruta (no se duplica la imagen en la base de datos).
class LibraryScanner {
  LibraryScanner(AppDatabase db)
    : _folders = db.folderDao,
      _tracks = db.trackDao,
      _lyrics = db.lyricsDao;

  static const String _tag = 'Scanner';
  static const int _batchSize = 48;

  final FolderDao _folders;
  final TrackDao _tracks;
  final LyricsDao _lyrics;

  final StreamController<ScanProgress> _progress =
      StreamController<ScanProgress>.broadcast();
  bool _running = false;

  Stream<ScanProgress> get progress => _progress.stream;
  bool get isRunning => _running;

  Future<ScanSummary> scanAll({bool removeMissing = true}) async {
    if (_running) {
      throw StateError('Ya hay un escaneo en curso.');
    }
    _running = true;
    final Stopwatch watch = Stopwatch()..start();
    int inserted = 0;
    int updated = 0;
    int failed = 0;

    try {
      final List<ScanFolderRow> folders = await _folders.getAll();
      final Set<String> found = <String>{};

      for (final ScanFolderRow folder in folders) {
        final List<String> files = await FileUtils.listAudioFiles(
          folder.path,
          recursive: folder.recursive,
        );
        found.addAll(files);
      }

      final Set<String> knownPaths = (await _tracks.allPaths()).toSet();
      final List<String> pending = found
          .where((String path) => !knownPaths.contains(path))
          .toList();
      // Releer los existentes solo si el archivo cambió de tamaño/fecha es
      // costoso; en Fase 1 se reindexan todos para refrescar metadatos.
      final List<String> all = found.toList(growable: false);

      int processed = 0;
      for (int start = 0; start < all.length; start += _batchSize) {
        final int end = (start + _batchSize) > all.length
            ? all.length
            : start + _batchSize;
        final List<String> batch = all.sublist(start, end);
        final List<_ScannedFile?> parsed = await Isolate.run(
          () => _scanBatch(batch),
        );

        for (final _ScannedFile? file in parsed) {
          if (file == null) {
            failed++;
            continue;
          }
          try {
            final bool isNew = pending.contains(file.path);
            final String? artworkPath = await _cacheArtwork(file);
            final int id = await _tracks.upsertScanned(
              TracksCompanion.insert(
                path: file.path,
                title: file.title,
                artist: Value(file.artist),
                album: Value(file.album),
                albumArtist: Value(
                  file.albumArtist.isEmpty ? null : file.albumArtist,
                ),
                genre: Value(file.genre.isEmpty ? null : file.genre),
                year: Value(file.year),
                trackNumber: Value(file.trackNumber),
                discNumber: Value(file.discNumber),
                durationMs: Value(file.durationMs),
                bitrate: Value(file.bitrate),
                sampleRate: Value(file.sampleRate),
                format: Value(file.format),
                fileSize: Value(file.size),
                artworkPath: Value(artworkPath),
              ),
            );

            if (file.lyrics != null && file.lyrics!.trim().isNotEmpty) {
              await _lyrics.save(
                id,
                file.lyrics!,
                synced: file.lyricsSynced,
                source: 'embedded',
              );
            }

            if (isNew) {
              inserted++;
            } else {
              updated++;
            }
          } catch (error, stack) {
            failed++;
            AppLog.w(_tag, 'No se pudo indexar ${file.path}', error, stack);
          }
        }

        processed += batch.length;
        if (!_progress.isClosed) {
          _progress.add(
            ScanProgress(
              processed: processed,
              total: all.length,
              currentFile: batch.isEmpty ? '' : batch.last,
            ),
          );
        }
      }

      int removed = 0;
      if (removeMissing && found.isNotEmpty) {
        final int before = await _tracks.count();
        await _tracks.deleteMissingPaths(found);
        final int after = await _tracks.count();
        removed = before - after;
      }

      for (final ScanFolderRow folder in folders) {
        await _folders.markScanned(folder.id);
      }

      watch.stop();
      final ScanSummary summary = ScanSummary(
        filesFound: all.length,
        inserted: inserted,
        updated: updated,
        removed: removed,
        failed: failed,
        duration: watch.elapsed,
      );
      AppLog.i(_tag, '$summary en ${watch.elapsed.inSeconds}s');
      return summary;
    } finally {
      _running = false;
    }
  }

  Future<String?> _cacheArtwork(_ScannedFile file) async {
    final Uint8List? bytes = file.artworkBytes;
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final Directory dir = await AppPaths.artwork();
      final String ext = file.artworkExtension ?? 'jpg';
      final String name = '${FileUtils.fnv1a(file.path)}.$ext';
      final File target = File(p.join(dir.path, name));
      if (!await target.exists()) {
        await target.writeAsBytes(bytes, flush: true);
      }
      return target.path;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo guardar la carátula', error, stack);
      return null;
    }
  }

  Future<void> dispose() async {
    await _progress.close();
  }
}

/// Lee un lote de archivos. Vive en el isolate de fondo.
List<_ScannedFile?> _scanBatch(List<String> paths) {
  final List<_ScannedFile?> result = <_ScannedFile?>[];
  for (final String path in paths) {
    result.add(_parseFile(path));
  }
  return result;
}

_ScannedFile? _parseFile(String path) {
  final File file = File(path);
  try {
    final AudioMetadata metadata = readMetadata(file, getImage: true);
    final String fallbackTitle = p.basenameWithoutExtension(path);
    final String title = (metadata.title ?? '').trim();
    final String artist = (metadata.artist ?? '').trim();
    final String album = (metadata.album ?? '').trim();
    final String albumArtist = (metadata.albumArtist ?? '').trim();
    final String genre = metadata.genres.isEmpty
        ? ''
        : metadata.genres.first.trim();

    final Picture? picture = metadata.pictures.isEmpty
        ? null
        : metadata.pictures.first;
    final String? extension = picture == null
        ? null
        : _extensionForMime(picture.mimetype);

    return _ScannedFile(
      path: path,
      title: title.isEmpty ? fallbackTitle : title,
      artist: artist.isEmpty ? 'Desconocido' : artist,
      album: album.isEmpty ? 'Desconocido' : album,
      albumArtist: albumArtist,
      genre: genre,
      year: metadata.year?.year == 0 ? null : metadata.year?.year,
      trackNumber: metadata.trackNumber,
      discNumber: metadata.discNumber,
      durationMs: metadata.duration?.inMilliseconds ?? 0,
      bitrate: metadata.bitrate,
      sampleRate: metadata.sampleRate,
      format: FileUtils.extensionOf(path).toUpperCase(),
      size: file.lengthSync(),
      artworkBytes: picture?.bytes,
      artworkExtension: extension,
      lyrics: metadata.lyrics,
      lyricsSynced: (metadata.lyrics ?? '').contains('['),
    );
  } catch (_) {
    // Formatos sin parser o archivos corruptos: se omiten sin abortar el lote.
    return null;
  }
}

String _extensionForMime(String mime) {
  final String normalized = mime.toLowerCase();
  if (normalized.contains('png')) return 'png';
  if (normalized.contains('webp')) return 'webp';
  if (normalized.contains('gif')) return 'gif';
  if (normalized.contains('bmp')) return 'bmp';
  return 'jpg';
}
