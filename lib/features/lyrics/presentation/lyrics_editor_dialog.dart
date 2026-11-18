import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../player/presentation/player_providers.dart';
import 'lyrics_providers.dart';

/// Creador/sincronizador de letras: pega el texto, marca el instante actual y
/// guarda o exporta un `.lrc` propio.
class LyricsEditorDialog extends ConsumerStatefulWidget {
  const LyricsEditorDialog({
    super.key,
    required this.track,
    required this.initial,
  });

  final Track track;
  final LrcDocument initial;

  @override
  ConsumerState<LyricsEditorDialog> createState() => _LyricsEditorDialogState();
}

class _LyricsEditorDialogState extends ConsumerState<LyricsEditorDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial.lines.isEmpty
        ? '[ti:${widget.track.title}]\n[ar:${widget.track.artist}]\n'
        : widget.initial.toLrc(),
  );
  final TextEditingController _line = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _line.dispose();
    super.dispose();
  }

  LrcDocument _document() => LrcDocument.parse(_text.text);

  /// Inserta la línea escrita con la posición real del reproductor.
  void _markCurrent() {
    final String text = _line.text.trim();
    if (text.isEmpty) return;
    final Duration position = ref
        .read(playerControllerProvider)
        .playback
        .position;
    final String fragment = '[${LrcDocument.formatTimestamp(position)}]$text\n';
    final String current = _text.text;
    final int cursor = _text.selection.baseOffset;
    final int at = cursor < 0 || cursor > current.length
        ? current.length
        : cursor;
    _text.value = TextEditingValue(
      text: current.substring(0, at) + fragment + current.substring(at),
      selection: TextSelection.collapsed(offset: at + fragment.length),
    );
    _line.clear();
  }

  Future<void> _save() async {
    await ref.read(lyricsServiceProvider).saveLyrics(widget.track, _document());
    ref.invalidate(lyricsForTrackProvider(widget.track));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _export() async {
    try {
      final Uri? result = await FilePicker.saveFile(
        dialogTitle: 'Exportar letra sincronizada',
        fileName: '${FileUtils.sanitizeFileName(widget.track.title)}.lrc',
        bytes: Uint8List.fromList(utf8.encode(_document().toLrc())),
        mimeType: 'text/plain',
      );
      if (result != null && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editor de letras'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Pega aquí la letra o escribe una línea y pulsa «Marcar tiempo '
              'actual» en el instante exacto. Puedes repetirlo línea por línea.',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'LRC',
                hintText: '[00:12.34] Texto de la línea',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _line,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _markCurrent(),
                    decoration: const InputDecoration(
                      labelText: 'Nueva línea',
                      hintText: 'Escribe la siguiente frase',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _line.text.trim().isEmpty ? null : _markCurrent,
                  icon: const Icon(Icons.access_time_rounded, size: 18),
                  label: const Text('Marcar tiempo actual'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Exportar .lrc'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
