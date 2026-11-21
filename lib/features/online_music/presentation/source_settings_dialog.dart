import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/theme_tokens.dart';
import '../domain/music_source.dart';
import '../domain/online_source_settings.dart';
import 'online_music_providers.dart';
import 'source_status_ui.dart';

/// Abre la configuración de fuentes online desde la pantalla de exploración.
Future<void> showSourcesDialog(
  BuildContext context, {
  MusicSourceId? initial,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext context) => SourceSettingsDialog(initial: initial),
);

/// Diálogo de credenciales y estados de cada proveedor.
///
/// Los tokens se guardan en la base de datos local de la app y se envían solo
/// al dominio de su proveedor. No se distribuye ningún `client_secret`.
class SourceSettingsDialog extends ConsumerStatefulWidget {
  const SourceSettingsDialog({super.key, this.initial});

  final MusicSourceId? initial;

  @override
  ConsumerState<SourceSettingsDialog> createState() =>
      _SourceSettingsDialogState();
}

class _SourceSettingsDialogState extends ConsumerState<SourceSettingsDialog> {
  late final TextEditingController _soundCloudToken;
  late final TextEditingController _spotifyToken;
  late final TextEditingController _spotifyMarket;
  late final TextEditingController _tidalToken;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SettingsService settings = ref.read(settingsServiceProvider);
    _soundCloudToken = TextEditingController(
      text: settings.getString(OnlineSourceSettings.soundCloudToken) ?? '',
    );
    _spotifyToken = TextEditingController(
      text: settings.getString(OnlineSourceSettings.spotifyToken) ?? '',
    );
    _spotifyMarket = TextEditingController(
      text: settings.stringOr(
        OnlineSourceSettings.spotifyMarket,
        OnlineSourceSettings.defaultSpotifyMarket,
      ),
    );
    _tidalToken = TextEditingController(
      text: settings.getString(OnlineSourceSettings.tidalToken) ?? '',
    );
    unawaited(ref.read(onlineSearchProvider.notifier).checkSources());
  }

  @override
  void dispose() {
    _soundCloudToken.dispose();
    _spotifyToken.dispose();
    _spotifyMarket.dispose();
    _tidalToken.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final OnlineSearchController controller = ref.read(
      onlineSearchProvider.notifier,
    );
    try {
      await controller.configureSource(
        MusicSourceId.soundcloud,
        _soundCloudToken.text,
      );
      await controller.configureSource(
        MusicSourceId.spotify,
        _spotifyToken.text,
        market: _spotifyMarket.text,
      );
      await controller.configureSource(MusicSourceId.tidal, _tidalToken.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuentes actualizadas.'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OnlineSearchState state = ref.watch(onlineSearchProvider);
    final List<MusicSourceProvider> providers = ref
        .watch(musicSourceCatalogProvider)
        .providers;
    final MusicSourceId? initial = widget.initial;

    return AlertDialog(
      title: const Text('Fuentes online'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Audius y YouTube Music funcionan sin cuenta ni tokens. '
                'SoundCloud, Spotify y Tidal necesitan un token OAuth de tu '
                'propia app; se guarda solo en este dispositivo. Spotify y '
                'Tidal solo aportan metadatos: el audio se busca en fuentes '
                'abiertas y se etiqueta su origen real.',
                style: TextStyle(fontSize: 12, color: context.inkAlpha(0.60)),
              ),
              const SizedBox(height: 16),
              for (final MusicSourceProvider provider in providers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SourceCard(
                    provider: provider,
                    status:
                        state.sourceStatuses[provider.id] ?? provider.status,
                    highlight: initial == provider.id,
                    child: switch (provider.id) {
                      MusicSourceId.audius => Text(
                        'Catálogo abierto. Reproducción y descarga disponibles '
                        'sin credenciales.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.inkAlpha(0.54),
                        ),
                      ),
                      MusicSourceId.soundcloud => TextField(
                        controller: _soundCloudToken,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Token OAuth de SoundCloud',
                          hintText: 'OAuth access token',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      MusicSourceId.spotify => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _spotifyToken,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Token OAuth de Spotify',
                              hintText: 'Bearer access token',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _spotifyMarket,
                            decoration: const InputDecoration(
                              labelText: 'Mercado (ISO 3166)',
                              hintText: 'US',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLength: 2,
                          ),
                          Text(
                            'Solo metadatos. El audio se busca en fuentes '
                            'abiertas y se etiqueta como '
                            '“Spotify → YouTube Music”.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.inkAlpha(0.38),
                            ),
                          ),
                        ],
                      ),
                      MusicSourceId.tidal => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _tidalToken,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Token OAuth de Tidal',
                              hintText: 'OAuth access token',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Solo metadatos: Tidal no ofrece audio abierto. '
                            'Las pistas se buscan en fuentes anónimas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.inkAlpha(0.38),
                            ),
                          ),
                        ],
                      ),
                      MusicSourceId.youtube => Text(
                        'Búsqueda y reproducción anónimas vía InnerTube: '
                        'encuentra y escucha música sin iniciar sesión en '
                        'Google. No necesita tokens.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.inkAlpha(0.54),
                        ),
                      ),
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar y comprobar'),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.provider,
    required this.status,
    required this.highlight,
    required this.child,
  });

  final MusicSourceProvider provider;
  final MusicSourceStatus status;
  final bool highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color color = SourceStatusUi.color(status, context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.08)
            : context.inkAlpha(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.5)
              : context.inkAlpha(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                provider.id.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                SourceStatusUi.shortLabel(status),
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
          if (status.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              status.detail,
              style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
