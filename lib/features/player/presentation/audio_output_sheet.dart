import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_output_selection_service.dart';
import '../../../core/theme/theme_tokens.dart';
import 'audio_output_providers.dart';

/// Hoja propia para elegir la salida sin modificar Ajustes (otro agente está
/// trabajando en esa pantalla). Se abre desde las acciones rápidas del
/// reproductor.
class AudioOutputSheet extends ConsumerStatefulWidget {
  const AudioOutputSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const AudioOutputSheet(),
  );

  @override
  ConsumerState<AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends ConsumerState<AudioOutputSheet> {
  bool _busy = false;

  Future<void> _select(
    AudioOutputSelectionService service,
    AudioOutputChoice choice,
  ) async {
    setState(() => _busy = true);
    await service.select(choice);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AudioOutputSelectionService service = ref.watch(
      audioOutputSelectionProvider,
    );
    final AudioOutputSelectionState state = service.state;
    final Color accent = context.tokens.accent;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.speaker_outlined, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Salida de audio',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Salida actual: ${state.selected.label}',
                style: TextStyle(color: context.inkAlpha(0.62), fontSize: 12),
              ),
              if (state.message != null) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    state.message!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (!state.platformSupportsSelection)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'En esta plataforma solo se puede usar la salida automática. '
                    'La cola y la posición no se modifican.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              RadioGroup<AudioOutputChoice>(
                groupValue: state.selected,
                onChanged: (AudioOutputChoice? value) {
                  if (_busy || !state.platformSupportsSelection) return;
                  if (value != null) unawaited(_select(service, value));
                },
                child: Column(
                  children: <Widget>[
                    for (final AudioOutputChoice choice in state.choices)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<AudioOutputChoice>(value: choice),
                        title: Text(choice.label),
                        subtitle: Text(
                          choice.isAuto
                              ? 'mpv elige el dispositivo del sistema'
                              : choice.systemKey ?? choice.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.inkAlpha(0.52),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 18),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.multiOutputSupported,
                onChanged: null,
                title: const Text('Salida dual / múltiple'),
                subtitle: Text(
                  state.multiOutputMessage,
                  style: TextStyle(fontSize: 11, color: context.inkAlpha(0.60)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
