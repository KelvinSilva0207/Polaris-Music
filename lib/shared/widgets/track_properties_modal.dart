import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart'
    show AudioMetadata, Picture, readMetadata;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/models/track.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/metadata_text.dart';

/// Diálogo "Propiedades" de una pista.
///
/// Se abre desde el menú contextual (clic derecho en escritorio u opciones en
/// Android). Reúne información del archivo, calidad de audio real (leída del
/// contenedor), metadatos ID3/Vorbis/MP4 y estadísticas de uso de Drift.
///
/// La lectura de metadatos se hace en un isolate aparte para no congelar la
/// interfaz, incluso con carátulas integradas grandes.
class TrackPropertiesModal {
  const TrackPropertiesModal._();

  static Future<void> show({
    required BuildContext context,
    required Track track,
    required Color accent,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.62),
      builder: (BuildContext dialogContext) =>
          _TrackPropertiesDialog(track: track, accent: accent),
    );
  }
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return 'No disponible';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit <= 1 ? 0 : 2)} ${units[unit]}';
}

/// Metadatos leídos del archivo, o `null` si no existe o no se pueden leer.
Future<AudioMetadata?> _readMetadataSafely(String path) async {
  if (path.isEmpty) return null;
  final File file = File(path);
  if (!file.existsSync()) return null;
  try {
    return await Isolate.run(() => readMetadata(File(path), getImage: true));
  } catch (_) {
    // Archivos dañados o formatos sin parser: la UI cae a los datos de Drift.
    return null;
  }
}

class _TrackPropertiesDialog extends StatefulWidget {
  const _TrackPropertiesDialog({required this.track, required this.accent});

  final Track track;
  final Color accent;

  @override
  State<_TrackPropertiesDialog> createState() => _TrackPropertiesDialogState();
}

class _TrackPropertiesDialogState extends State<_TrackPropertiesDialog> {
  late final Future<AudioMetadata?> _metadata;
  int _fileSize = 0;

  @override
  void initState() {
    super.initState();
    _metadata = _readMetadataSafely(widget.track.path);
    _fileSize = widget.track.fileSize;
    if (_fileSize <= 0 && widget.track.path.isNotEmpty) {
      final File file = File(widget.track.path);
      if (file.existsSync()) _fileSize = file.lengthSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Size screen = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: (screen.height * 0.86).clamp(360.0, 700.0),
        ),
        child: DecoratedBox(
          decoration: _panelDecoration(tokens, widget.accent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: FutureBuilder<AudioMetadata?>(
                  future: _metadata,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<AudioMetadata?> snapshot,
                      ) {
                        final AudioMetadata? metadata = snapshot.data;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _Header(
                                track: widget.track,
                                accent: widget.accent,
                                metadata: metadata,
                                onClose: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(height: 18),
                              _Section(
                                title: 'Información del archivo',
                                icon: Icons.folder_open_rounded,
                                accent: widget.accent,
                                children: <Widget>[
                                  _PropertyRow(
                                    label: 'Nombre',
                                    value: widget.track.path.isEmpty
                                        ? '${widget.track.title}.${widget.track.format.toLowerCase()}'
                                        : p.basename(widget.track.path),
                                    icon: Icons.description_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Ruta',
                                    value: widget.track.path.isEmpty
                                        ? 'Streaming: no hay archivo local'
                                        : widget.track.path,
                                    icon: Icons.route_rounded,
                                    copyable: widget.track.path.isNotEmpty,
                                  ),
                                  _PropertyRow(
                                    label: 'Tamaño',
                                    value: formatFileSize(_fileSize),
                                    icon: Icons.storage_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Formato',
                                    value: _formatLabel(widget.track),
                                    icon: Icons.audiotrack_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Duración',
                                    value: Formatters.duration(
                                      metadata?.duration ??
                                          widget.track.duration,
                                    ),
                                    icon: Icons.access_time_rounded,
                                  ),
                                ],
                              ),
                              _Section(
                                title: 'Calidad de audio',
                                icon: Icons.graphic_eq_rounded,
                                accent: widget.accent,
                                children: <Widget>[
                                  _PropertyRow(
                                    label: 'Bitrate',
                                    value: _bitrateLabel(metadata),
                                    icon: Icons.speed_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Muestreo',
                                    value: _sampleRateLabel(metadata),
                                    icon: Icons.tune_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Profundidad',
                                    value: _bitDepthLabel(metadata),
                                    icon: Icons.layers_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Canales',
                                    value: 'Estéreo (estimado)',
                                    icon: Icons.surround_sound_rounded,
                                  ),
                                ],
                              ),
                              _Section(
                                title: 'Metadatos',
                                icon: Icons.music_note_rounded,
                                accent: widget.accent,
                                children: <Widget>[
                                  _PropertyRow(
                                    label: 'Título',
                                    value: _firstNonEmpty(<String?>[
                                      metadata == null
                                          ? null
                                          : MetadataText.repair(
                                              metadata.title ?? '',
                                            ),
                                      widget.track.title,
                                    ]),
                                    icon: Icons.title_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Artista',
                                    value: _firstNonEmpty(<String?>[
                                      metadata == null
                                          ? null
                                          : MetadataText.repair(
                                              metadata.artist ?? '',
                                            ),
                                      widget.track.artist,
                                    ]),
                                    icon: Icons.person_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Álbum',
                                    value: _firstNonEmpty(<String?>[
                                      metadata == null
                                          ? null
                                          : MetadataText.repair(
                                              metadata.album ?? '',
                                            ),
                                      widget.track.album,
                                    ]),
                                    icon: Icons.album_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Género',
                                    value: _genreLabel(metadata),
                                    icon: Icons.category_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Año',
                                    value: _yearLabel(metadata),
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                  _ArtworkRow(
                                    accent: widget.accent,
                                    trackArtwork: widget.track.artworkPath,
                                    picture: _firstPicture(metadata),
                                    onOpen: _openArtwork,
                                  ),
                                ],
                              ),
                              _Section(
                                title: 'Estadísticas de uso',
                                icon: Icons.analytics_rounded,
                                accent: widget.accent,
                                children: <Widget>[
                                  _PropertyRow(
                                    label: 'Reproducciones',
                                    value: '${widget.track.playCount}',
                                    icon: Icons.play_circle_outline_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Última vez',
                                    value: _lastPlayedLabel(),
                                    icon: Icons.schedule_rounded,
                                  ),
                                  _PropertyRow(
                                    label: 'Favorita',
                                    value: widget.track.isFavorite
                                        ? 'Sí'
                                        : 'No',
                                    icon: widget.track.isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                ],
                              ),
                              if (widget.track.isOnline)
                                _Section(
                                  title: 'Fuente',
                                  icon: Icons.cloud_queue_rounded,
                                  accent: widget.accent,
                                  children: <Widget>[
                                    _PropertyRow(
                                      label: 'Origen',
                                      value:
                                          widget.track.sourceLabel ??
                                          'Streaming online',
                                      icon: Icons.cloud_rounded,
                                    ),
                                    if (widget.track.externalId != null)
                                      _PropertyRow(
                                        label: 'ID externo',
                                        value: widget.track.externalId!,
                                        icon: Icons.tag_rounded,
                                        copyable: true,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Presentación de datos
  // ---------------------------------------------------------------------------

  String _formatLabel(Track track) {
    final String extension = track.path.isEmpty
        ? track.format
        : p.extension(track.path).replaceFirst('.', '');
    final String value = extension.isEmpty ? track.format : extension;
    return value.toUpperCase();
  }

  String _bitrateLabel(AudioMetadata? metadata) {
    final int bitrate = metadata?.bitrate ?? widget.track.bitrate ?? 0;
    if (bitrate <= 0) return 'No disponible';
    // Algunos contenedores informan bits por segundo en vez de kbps.
    final double kbps = bitrate > 10000 ? bitrate / 1000 : bitrate.toDouble();
    return '${kbps.toStringAsFixed(kbps >= 100 ? 0 : 1)} kbps';
  }

  String _sampleRateLabel(AudioMetadata? metadata) {
    final int rate = metadata?.sampleRate ?? widget.track.sampleRate ?? 0;
    if (rate <= 0) return 'No disponible';
    if (rate >= 1000) {
      final double khz = rate / 1000;
      return '${khz.toStringAsFixed(1)} kHz';
    }
    return '$rate Hz';
  }

  String _bitDepthLabel(AudioMetadata? metadata) {
    final int bitrate = metadata?.bitrate ?? widget.track.bitrate ?? 0;
    final int rate = metadata?.sampleRate ?? widget.track.sampleRate ?? 0;
    final String format = _formatLabel(widget.track);
    const Set<String> lossless = <String>{'FLAC', 'WAV', 'AIFF', 'APE'};
    if (!lossless.contains(format)) {
      return 'No aplica (formato comprimido)';
    }
    if (bitrate <= 0 || rate <= 0) return 'No disponible';
    final double kbps = bitrate > 10000 ? bitrate / 1000 : bitrate.toDouble();
    final int estimate = (kbps * 1000 / (rate * 2)).round();
    final int snapped = <int>[8, 16, 24, 32].reduce(
      (int a, int b) => (a - estimate).abs() <= (b - estimate).abs() ? a : b,
    );
    return '≈ $snapped-bit';
  }

  String _genreLabel(AudioMetadata? metadata) {
    final String genres = metadata == null
        ? ''
        : metadata.genres
              .map((String g) => MetadataText.repair(g))
              .where((String g) => g.trim().isNotEmpty)
              .join(', ');
    return _firstNonEmpty(<String?>[genres, widget.track.genre]);
  }

  String _yearLabel(AudioMetadata? metadata) {
    final int? fromFile = metadata?.year?.year;
    final int? year = (fromFile != null && fromFile > 0)
        ? fromFile
        : widget.track.year;
    return year == null ? 'No disponible' : '$year';
  }

  String _lastPlayedLabel() {
    final DateTime? value = widget.track.lastPlayedAt;
    if (value == null) return 'Nunca';
    return '${Formatters.date(value)} · ${Formatters.relativeDate(value)}';
  }

  Picture? _firstPicture(AudioMetadata? metadata) {
    if (metadata == null || metadata.pictures.isEmpty) return null;
    return metadata.pictures.first;
  }

  void _openArtwork(Picture? picture) {
    final String? localPath = widget.track.artworkPath;
    final bool hasLocal = localPath != null && File(localPath).existsSync();
    if (picture == null && !hasLocal) return;

    final int decodeSize = (496 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 600);
    showDialog<void>(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.8),
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: context.tokens.panelOverlay.withValues(alpha: 0.92),
              border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: picture != null
                          ? Image.memory(
                              picture.bytes,
                              fit: BoxFit.contain,
                              cacheWidth: decodeSize,
                              cacheHeight: decodeSize,
                            )
                          : Image.file(
                              File(localPath!),
                              fit: BoxFit.contain,
                              cacheWidth: decodeSize,
                              cacheHeight: decodeSize,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) => const SizedBox(
                                    width: 280,
                                    height: 280,
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      size: 64,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return 'No disponible';
}

BoxDecoration _panelDecoration(PolarisTokens tokens, Color accent) {
  final double radius = tokens.panelRadius + 8;
  if (tokens.isGlass) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 48,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: tokens.shadowColor.withValues(alpha: 0.5),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ],
    );
  }
  if (tokens.isNeumorphic) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: tokens.surface,
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: tokens.neumorphicLight.withValues(alpha: 0.9),
          blurRadius: 18,
          offset: const Offset(-6, -6),
        ),
        BoxShadow(
          color: tokens.neumorphicDark.withValues(alpha: 0.7),
          blurRadius: 26,
          offset: const Offset(8, 10),
        ),
      ],
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: tokens.surface.withValues(alpha: 0.98),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: tokens.shadowColor.withValues(alpha: 0.45),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.track,
    required this.accent,
    required this.metadata,
    required this.onClose,
  });

  final Track track;
  final Color accent;
  final AudioMetadata? metadata;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Picture? picture = metadata != null && metadata!.pictures.isNotEmpty
        ? metadata!.pictures.first
        : null;
    final String? artworkPath = track.artworkPath;
    final bool hasFileArtwork =
        artworkPath != null && File(artworkPath).existsSync();
    final int thumbSize = (62 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(24, 160);

    final Widget artwork = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 62,
        height: 62,
        child: picture != null
            ? Image.memory(
                picture.bytes,
                fit: BoxFit.cover,
                cacheWidth: thumbSize,
                cacheHeight: thumbSize,
              )
            : hasFileArtwork
            ? Image.file(
                File(artworkPath),
                fit: BoxFit.cover,
                cacheWidth: thumbSize,
                cacheHeight: thumbSize,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) => _artworkFallback(context),
              )
            : _artworkFallback(context),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: artwork,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Propiedades de la canción',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${track.artist} · ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.inkAlpha(0.60)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _artworkFallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.45),
            accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Icon(Icons.music_note_rounded, color: context.ink, size: 28),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: accent.withValues(alpha: 0.9)),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: context.inkAlpha(0.55),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.label,
    required this.value,
    required this.icon,
    this.copyable = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: context.inkAlpha(0.32)),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: context.inkAlpha(0.52),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
            ),
          ),
          if (copyable)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copiado al portapapeles'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: accent.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtworkRow extends StatelessWidget {
  const _ArtworkRow({
    required this.accent,
    required this.trackArtwork,
    required this.picture,
    required this.onOpen,
  });

  final Color accent;
  final String? trackArtwork;
  final Picture? picture;
  final void Function(Picture? picture) onOpen;

  @override
  Widget build(BuildContext context) {
    final bool hasLocal =
        trackArtwork != null && File(trackArtwork!).existsSync();
    final bool available = picture != null || hasLocal;
    final String detail = picture != null
        ? '${picture!.mimetype.toUpperCase()} · ${formatFileSize(picture!.bytes.length)}'
        : (hasLocal ? 'Imagen local' : 'Sin carátula integrada');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.image_rounded, size: 14, color: context.inkAlpha(0.32)),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(
              'Carátula',
              style: TextStyle(fontSize: 11.5, color: context.inkAlpha(0.52)),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.ink,
              ),
            ),
          ),
          if (available)
            TextButton.icon(
              onPressed: () => onOpen(picture),
              icon: Icon(Icons.zoom_in_rounded, size: 15, color: accent),
              label: Text(
                'Inspeccionar',
                style: TextStyle(fontSize: 11.5, color: accent),
              ),
            ),
        ],
      ),
    );
  }
}
