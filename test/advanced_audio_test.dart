import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/services/backup_service.dart';
import 'package:polaris_music/core/services/system_audio_service.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';

void main() {
  group('Repetidor A-B', () {
    test('el fragmento solo está activo con A, B y B posterior a A', () {
      const PlayerUiState empty = PlayerUiState();
      expect(empty.loopActive, isFalse);

      final PlayerUiState onlyA = empty.copyWith(
        loopA: const Duration(seconds: 5),
      );
      expect(onlyA.loopActive, isFalse);

      final PlayerUiState badB = onlyA.copyWith(
        loopB: const Duration(seconds: 2),
      );
      expect(badB.loopActive, isFalse);

      final PlayerUiState valid = onlyA.copyWith(
        loopB: const Duration(seconds: 20),
      );
      expect(valid.loopActive, isTrue);
    });

    test('copyWith permite limpiar marcas con null', () {
      final PlayerUiState marked = const PlayerUiState().copyWith(
        loopA: const Duration(seconds: 3),
        loopB: const Duration(seconds: 9),
      );
      expect(marked.loopActive, isTrue);

      final PlayerUiState cleared = marked.copyWith(loopA: null, loopB: null);
      expect(cleared.loopA, isNull);
      expect(cleared.loopB, isNull);
      expect(cleared.loopActive, isFalse);
    });
  });

  group('Avisos y buffering', () {
    test('el aviso se puede fijar y limpiar con null', () {
      const PlayerUiState base = PlayerUiState();
      expect(base.notice, isNull);

      final PlayerUiState shown = base.copyWith(
        notice: 'Archivo no disponible',
      );
      expect(shown.notice, 'Archivo no disponible');

      final PlayerUiState hidden = shown.copyWith(notice: null);
      expect(hidden.notice, isNull);
    });

    test('copyWith limpia buffering y error tras un fallo', () {
      const PlaybackSnapshot stuck = PlaybackSnapshot(
        buffering: true,
        playing: true,
        error: 'sin archivo',
      );
      final PlaybackSnapshot clean = stuck.copyWith(
        buffering: false,
        playing: false,
        error: null,
      );
      expect(clean.buffering, isFalse);
      expect(clean.playing, isFalse);
      expect(clean.error, isNull);
    });
  });

  group('Perfiles por dispositivo', () {
    test('la identidad de la salida depende de la clave estable', () {
      const AudioOutputDevice speakers = AudioOutputDevice(
        key: 'windows:endpoint-1',
        name: 'Altavoces',
        platform: 'windows',
      );
      const AudioOutputDevice renamed = AudioOutputDevice(
        key: 'windows:endpoint-1',
        name: 'Altavoces USB',
        platform: 'windows',
      );
      const AudioOutputDevice headphones = AudioOutputDevice(
        key: 'windows:endpoint-2',
        name: 'Auriculares',
        platform: 'windows',
      );

      expect(speakers, renamed);
      expect(speakers == headphones, isFalse);
    });
  });

  group('Resumen de respaldo', () {
    test('total suma todas las secciones y expone los avisos', () {
      const BackupSummary summary = BackupSummary(
        settings: 2,
        eqPresets: 3,
        playlists: 1,
        favorites: 4,
        lyrics: 5,
        plugins: 1,
        profiles: 2,
        themes: 3,
        warnings: <String>['No se pudo restaurar keyThemeConfig'],
      );

      expect(summary.total, 21);
      expect(summary.warnings, hasLength(1));
    });
  });
}
