import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/features/library/domain/scan_index.dart';

import 'support/fake_settings_service.dart';

void main() {
  group('Índice incremental de biblioteca', () {
    test('la huella distingue cambios de tamaño y de fecha', () {
      const FileSignature original = FileSignature(120, 1000);
      const FileSignature same = FileSignature(120, 1000);
      const FileSignature resized = FileSignature(121, 1000);
      const FileSignature touched = FileSignature(120, 1001);

      expect(original.encoded, '120@1000');
      expect(original, same);
      expect(original.hashCode, same.hashCode);
      expect(original == resized, isFalse);
      expect(original == touched, isFalse);
    });

    test('lee la firma de un archivo real y tolera rutas inaccesibles', () {
      final Directory temp = Directory.systemTemp.createTempSync(
        'polaris-scan-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final File file = File('${temp.path}/track.mp3')
        ..writeAsStringSync('contenido');
      final File missing = File('${temp.path}/absent.mp3');

      final FileSignature? signature = FileSignature.read(file.path);
      expect(signature, isNotNull);
      expect(signature!.size, greaterThan(0));
      expect(FileSignature.read(missing.path), isNull);
    });

    test('codifica, decodifica y poda rutas desaparecidas', () {
      const FileSignature a = FileSignature(10, 20);
      const FileSignature b = FileSignature(30, 40);
      ScanIndex index = ScanIndex(const <String, String>{});
      expect(index.isUnchanged('/a.mp3', a), isFalse);

      index = index.withSignature('/a.mp3', a).withSignature('/b.mp3', b);
      final ScanIndex restored = ScanIndex.decode(index.encode());
      expect(restored.length, 2);
      expect(restored.isUnchanged('/a.mp3', a), isTrue);
      expect(restored.isUnchanged('/a.mp3', b), isFalse);

      final ScanIndex pruned = restored.retainAll(<String>['/a.mp3']);
      expect(pruned.length, 1);
      expect(pruned.isUnchanged('/b.mp3', b), isFalse);
    });

    test('un índice corrupto se trata como vacío', () {
      expect(ScanIndex.decode('{no es json').length, 0);
      expect(ScanIndex.decode('["no", "mapa"]').length, 0);
      expect(ScanIndex.decode(null).length, 0);
    });

    test('persistencia y límites de la escala de carátulas', () async {
      final FakeSettingsService settings = FakeSettingsService();
      expect(settings.libraryArtworkScale, 1);

      await settings.setLibraryArtworkScale(1.25);
      expect(settings.libraryArtworkScale, 1.25);

      await settings.setLibraryArtworkScale(9);
      expect(settings.libraryArtworkScale, 1.75);

      await settings.setLibraryArtworkScale(0.1);
      expect(settings.libraryArtworkScale, 0.75);
    });

    test(
      'el índice se guarda en preferencias pero la escala se restablece',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        await settings.setScanIndex(<String, String>{'/a.mp3': '10@20'});
        await settings.setLibraryArtworkScale(1.5);

        expect(
          ScanIndex(settings.scanIndex)
              .isUnchanged('/a.mp3', const FileSignature(10, 20)),
          isTrue,
        );

        await settings.resetPreferences();

        expect(
          AppConstants.resettablePreferenceKeys,
          contains(AppConstants.keyLibraryArtworkScale),
        );
        expect(
          AppConstants.resettablePreferenceKeys,
          isNot(contains(AppConstants.keyScanIndex)),
        );
        expect(settings.scanIndex, containsPair('/a.mp3', '10@20'));
        expect(settings.libraryArtworkScale, 1);
      },
    );
  });
}
