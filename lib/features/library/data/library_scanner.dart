import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/debug/memory_probe.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/metadata_text.dart';

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

/// Argumentos enviados al isolate: **solo** datos planos y enviables.
///
/// Nunca debe contener `AppDatabase`, `DatabaseConnection`, `LibraryScanner`,
/// `Future` ni closures: el VM serializa este objeto para cruzar el límite.
class _ScanBatchArgs {
  const _ScanBatchArgs(this.paths, this.artworkDir, this.needsImage);

  final List<String> paths;
  final String artworkDir;
  final List<bool> needsImage;
}

/// Metadata serializable extraída en un isolate de fondo.
///
/// Todos sus campos son primitivos (`String`/`int`/`bool`) o `null`: es el DTO
/// que cruza el puente del isolate. No guarda bytes de carátulas.
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
    this.artworkPath,
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

  /// Ruta ya escrita en disco por el isolate (nunca bytes en memoria).
  final String? artworkPath;
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
    : _db = db,
      _folders = db.folderDao,
      _tracks = db.trackDao,
      _lyrics = db.lyricsDao;

  static const String _tag = 'Scanner';
  // Lote pequeño: el isolate lee y guarda las carátulas antes de devolver la
  // metadata. 48 archivos podían retener decenas de MB de golpe; con 12 el
  // pico baja mucho y el escaneo sigue siendo rápido.
  static const int _batchSize = 12;

  final AppDatabase _db;
  final FolderDao _folders;
  final TrackDao _tracks;
  final LyricsDao _lyrics;

  final StreamController<ScanProgress> _progress =
      StreamController<ScanProgress>.broadcast();
  bool _running = false;

  Stream<ScanProgress> get progress => _progress.stream;
  bool get isRunning => _running;

  /// Escanea explícitamente un conjunto de rutas sin tocar el resto de la
  /// biblioteca. Es el modo usado por el importador de Metrolist: añade/binda
  /// archivos pero nunca elimina pistas de otras carpetas.
  Future<ScanSummary> scanPaths(Iterable<String> paths) async {
    _ensureNotRunning();
    _running = true;
    try {
      final List<String> found = <String>[];
      for (final String path in paths) {
        found.addAll(await FileUtils.listAudioFiles(path, recursive: true));
      }
      final Set<String> unique = found.toSet();
      if (unique.isEmpty) return const ScanSummary();
      final Set<String> knownPaths = (await _tracks.allPaths()).toSet();
      return await _index(
        unique,
        unique.difference(knownPaths),
        removeMissing: false,
      );
    } finally {
      _running = false;
    }
  }

  void _ensureNotRunning() {
    if (_running) throw StateError('Ya hay un escaneo en curso.');
  }

  Future<ScanSummary> scanAll({bool removeMissing = true}) async {
    _ensureNotRunning();
    _running = true;
    try {
      final List<ScanFolderRow> folders = await _folders.getAll();
      final Set<String> found = <String>{};
      for (final ScanFolderRow folder in folders) {
        found.addAll(
          await FileUtils.listAudioFiles(
            folder.path,
            recursive: folder.recursive,
          ),
        );
      }
      final Set<String> knownPaths = (await _tracks.allPaths()).toSet();
      final Set<String> pending = found.difference(knownPaths);
      final ScanSummary summary = await _index(
        found,
        pending,
        removeMissing: removeMissing,
      );
      for (final ScanFolderRow folder in folders) {
        await _folders.markScanned(folder.id);
      }
      return summary;
    } finally {
      _running = false;
    }
  }

  Future<ScanSummary> _index(
    Set<String> found,
    Set<String> pending, {
    required bool removeMissing,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    int inserted = 0;
    int updated = 0;
    int failed = 0;
    int removed = 0;

    try {
      // Solo los archivos nuevos necesitan leer la carátula incrustada.
      // Releer imágenes de varios MB en cada escaneo era el mayor pico de
      // memoria: el `Uint8List` cruzaba el isolate y vivía hasta el upsert.
      final List<String> all = <String>[
        ...pending,
        ...found.where((String path) => !pending.contains(path)),
      ];
      final String artworkDir = (await AppPaths.artwork()).path;
      // Solo nombres: no se abren ni decodifican imágenes. Permite recuperar
      // la ruta de las pistas ya indexadas sin repetir la lectura incrustada.
      final Map<String, String> cachedArtwork = _readCachedArtwork(artworkDir);

      MemoryProbe.mark('scan:start');
      int processed = 0;

      // Todas las escrituras en una sola transacción: Drift publica el cambio
      // de `tracks` al confirmar, en vez de reemitir la biblioteca completa
      // (dos `List<Track>`) por cada archivo upsertado.
      await _db.transaction(() async {
        for (int start = 0; start < all.length; start += _batchSize) {
          final int end = (start + _batchSize) > all.length
              ? all.length
              : start + _batchSize;
          final List<String> batch = all.sublist(start, end);
          final List<bool> needsImage = <bool>[
            for (final String path in batch) pending.contains(path),
          ];
          // El isolate guarda la carátula en disco y devuelve solo la ruta:
          // ningún byte de imagen cruza al isolate principal. El helper es de
          // nivel superior para no capturar `this` ni la transacción de Drift.
          final List<_ScannedFile?> parsed = await _readBatchInIsolate(
            batch,
            artworkDir,
            needsImage,
          );

          for (final _ScannedFile? file in parsed) {
            if (file == null) {
              failed++;
              continue;
            }
            try {
              final bool isNew = pending.contains(file.path);
              // Si el isolate no leyó la carátula (pista ya indexada), se
              // reutiliza la copia en disco. `Value.absent()` evita borrar la
              // ruta existente cuando no hay ninguna copia cacheada.
              final String? cachedName =
                  cachedArtwork[FileUtils.fnv1a(file.path)];
              final String? artworkPath =
                  file.artworkPath ??
                  (cachedName == null ? null : p.join(artworkDir, cachedName));
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
                  artworkPath: artworkPath == null
                      ? const Value<String?>.absent()
                      : Value<String?>(artworkPath),
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
          if (processed % (_batchSize * 10) == 0) {
            MemoryProbe.mark('scan:batch:$processed');
          }
        }

        if (removeMissing && found.isNotEmpty) {
          final int before = await _tracks.count();
          await _tracks.deleteMissingPaths(found);
          final int after = await _tracks.count();
          removed = before - after;
        }
      });
      MemoryProbe.mark('scan:end');

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
      watch.stop();
    }
  }

  /// Recupera rutas de carátula que un escaneo anterior dejó a NULL.
  ///
  /// Solo consulta nombres del caché en disco: no abre ni decodifica imágenes,
  /// por lo que no aumenta el pico de RAM. Se ejecuta una vez al arrancar,
  /// aunque el escaneo automático esté desactivado.
  Future<int> restoreArtworkPaths() async {
    final String artworkDir = (await AppPaths.artwork()).path;
    final Map<String, String> cached = _readCachedArtwork(artworkDir);
    if (cached.isEmpty) return 0;

    final List<TrackRow> rows = await _tracks.allRows();
    int restored = 0;
    for (final TrackRow row in rows) {
      final String? current = row.artworkPath;
      if (current != null && current.isNotEmpty && File(current).existsSync()) {
        continue;
      }
      final String? name = cached[FileUtils.fnv1a(row.path)];
      if (name == null) continue;
      await _tracks.setArtworkPath(row.id, p.join(artworkDir, name));
      restored++;
    }
    if (restored > 0) {
      AppLog.i(_tag, 'Carátulas recuperadas del caché en disco: $restored');
    }
    return restored;
  }

  Future<void> dispose() async {
    await _progress.close();
  }
}

/// Punto de entrada del isolate. Vive en el ámbito superior (no es método de
/// instancia ni está anidado en el callback de Drift), por lo que su closure no
/// puede capturar `this`, la conexión de base de datos ni un `_Future`.
Future<List<_ScannedFile?>> _readBatchInIsolate(
  List<String> paths,
  String artworkDir,
  List<bool> needsImage,
) {
  final _ScanBatchArgs args = _ScanBatchArgs(paths, artworkDir, needsImage);
  return Isolate.run<List<_ScannedFile?>>(() => _scanBatch(args));
}

/// Lee un lote de archivos y guarda sus carátulas en disco, dentro del isolate.
///
/// Devuelve solo rutas: los `Uint8List` de portadas nunca cruzan el puente y
/// mueren con el isolate al terminar el lote.
Future<List<_ScannedFile?>> _scanBatch(_ScanBatchArgs args) async {
  final Directory artworkDir = Directory(args.artworkDir);
  if (!artworkDir.existsSync()) {
    artworkDir.createSync(recursive: true);
  }
  final List<_ScannedFile?> result = <_ScannedFile?>[];
  for (int i = 0; i < args.paths.length; i++) {
    result.add(await _parseFile(args.paths[i], artworkDir, args.needsImage[i]));
  }
  return result;
}

Future<_ScannedFile?> _parseFile(
  String path,
  Directory artworkDir,
  bool needArtwork,
) async {
  final File file = File(path);
  try {
    final AudioMetadata metadata = readMetadata(file, getImage: needArtwork);
    final String fallbackTitle = p.basenameWithoutExtension(path);
    final String rawArtist = (metadata.artist ?? '').trim();
    final String rawAlbum = (metadata.album ?? '').trim();
    final String title = MetadataText.clean(metadata.title, fallbackTitle);
    // Vacío mantiene el "Desconocido" de siempre; corrupto usa el archivo.
    final String artist = rawArtist.isEmpty
        ? 'Desconocido'
        : MetadataText.clean(rawArtist, fallbackTitle);
    final String album = rawAlbum.isEmpty
        ? 'Desconocido'
        : MetadataText.clean(rawAlbum, fallbackTitle);
    final String albumArtist = MetadataText.clean(metadata.albumArtist, '');
    final String genre = metadata.genres.isEmpty
        ? ''
        : MetadataText.clean(metadata.genres.first, '');

    final Picture? picture = needArtwork && metadata.pictures.isNotEmpty
        ? metadata.pictures.first
        : null;
    final String? artworkPath = picture == null
        ? null
        : await _writeArtwork(
            path,
            picture.bytes,
            picture.mimetype,
            artworkDir,
          );

    return _ScannedFile(
      path: path,
      title: title,
      artist: artist,
      album: album,
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
      artworkPath: artworkPath,
      lyrics: metadata.lyrics,
      lyricsSynced: (metadata.lyrics ?? '').contains('['),
    );
  } catch (_) {
    // Formatos sin parser o archivos corruptos: se omiten sin abortar el lote.
    return null;
  }
}

/// Índice de las carátulas ya guardadas en disco, por hash de la ruta.
///
/// Solo lee nombres de archivo: el objetivo es conservar las rutas de las
/// pistas existentes sin volver a extraer ni decodificar imágenes (el pico de
/// RAM que se quiso evitar). Si no hay copia, se deja el valor ausente para
/// que Drift no sobrescriba la ruta ya persistida.
Map<String, String> _readCachedArtwork(String artworkDir) {
  final Directory dir = Directory(artworkDir);
  final Map<String, String> byHash = <String, String>{};
  if (!dir.existsSync()) return byHash;
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final String name = p.basename(entity.path);
    byHash[p.basenameWithoutExtension(name)] = name;
  }
  return byHash;
}

/// Guarda la carátula ya redimensionada (máx. 600 px) y devuelve su ruta.
///
/// Se conserva el archivo original si la versión redimensionada ocupa más;
/// así el caché en disco nunca crece respecto a la carátula incrustada.
Future<String?> _writeArtwork(
  String path,
  Uint8List bytes,
  String mime,
  Directory artworkDir,
) async {
  if (bytes.isEmpty) return null;
  Uint8List output = bytes;
  String ext = _extensionForMime(mime);

  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 600,
    );
    ui.Image? decoded;
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      decoded = frame.image;
      final ByteData? data = await decoded.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data != null) {
        final Uint8List resized = data.buffer.asUint8List();
        if (resized.length < bytes.length) {
          output = resized;
          ext = 'png';
        }
      }
    } finally {
      decoded?.dispose();
      codec.dispose();
    }
  } catch (_) {
    // Códec no disponible para ese formato: se guarda el original tal cual.
  }

  try {
    final String name = '${FileUtils.fnv1a(path)}.$ext';
    final File target = File(p.join(artworkDir.path, name));
    if (!target.existsSync()) {
      await target.writeAsBytes(output, flush: true);
    }
    return target.path;
  } catch (_) {
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
