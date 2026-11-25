import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/media_session_service.dart';

void main() {
  test('la notificación de Android ofrece el botón X de cierre total', () {
    final List<MediaControl> controls = buildAndroidMediaControls(
      playing: true,
    );

    expect(controls, hasLength(4));
    expect(controls.last.action, MediaAction.custom);
    expect(controls.last.androidIcon, 'drawable/ic_close');
    expect(controls.last.label, 'Cerrar');
    expect(controls.last.customAction?.name, PolarisAudioHandler.quitAction);
  });

  test('el botón X convive con los controles esenciales', () {
    final List<MediaControl> playing = buildAndroidMediaControls(playing: true);
    final List<MediaControl> paused = buildAndroidMediaControls(playing: false);

    expect(playing[0], MediaControl.skipToPrevious);
    expect(playing[1], MediaControl.pause);
    expect(playing[2], MediaControl.skipToNext);
    expect(paused[1], MediaControl.play);
    expect(playing.last.customAction?.name, 'quit');
    expect(PolarisAudioHandler.quitEvent, 'polaris.quit');
  });

  test('la X aparece en la notificación plegada', () {
    final List<MediaControl> controls = buildAndroidMediaControls(
      playing: true,
    );

    // Android solo muestra tres acciones compactas y audio_service lo valida
    // con un assert: superar el límite tumbaría la notificación completa.
    expect(androidCompactActionIndices.length, lessThanOrEqualTo(3));
    expect(androidCompactActionIndices, contains(androidQuitControlIndex));
    expect(
      controls[androidQuitControlIndex].customAction?.name,
      PolarisAudioHandler.quitAction,
    );
    expect(
      androidCompactActionIndices.map((int index) => controls[index]).toList(),
      <MediaControl>[
        MediaControl.skipToPrevious,
        MediaControl.pause,
        controls.last,
      ],
    );
    expect(
      () => PlaybackState(
        controls: controls,
        androidCompactActionIndices: androidCompactActionIndices,
      ),
      returnsNormally,
    );
  });

  test('el icono X sobrevive a R8', () {
    final File icon = File('android/app/src/main/res/drawable/ic_close.xml');
    final File keep = File('android/app/src/main/res/raw/keep.xml');

    expect(icon.existsSync(), isTrue);
    expect(icon.readAsStringSync(), contains('M19,6.41L17.59,5'));
    expect(keep.existsSync(), isTrue);
    expect(keep.readAsStringSync(), contains('@drawable/*'));
  });
}
