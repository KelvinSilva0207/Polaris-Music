import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/features/online_music/data/audius_models.dart';
import 'package:polaris_music/features/online_music/domain/download_task.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

void main() {
  group('AudiusTrackDto', () {
    test('mapea título, artista, duración y carátula', () {
      final AudiusTrackDto dto = AudiusTrackDto.fromJson(<String, dynamic>{
        'id': 'abc123',
        'title': '  Luna de Neón ',
        'duration': 214,
        'genre': 'Electronic',
        'play_count': 1540,
        'permalink': '/kelvin/luna-de-neon',
        'user': <String, dynamic>{'name': 'Kelvin Silva'},
        'artwork': <String, dynamic>{
          '150x150': 'https://cdn.example/150.jpg',
          '480x480': 'https://cdn.example/480.jpg',
        },
      });

      expect(dto.id, 'abc123');
      expect(dto.title, 'Luna de Neón');
      expect(dto.artist, 'Kelvin Silva');
      expect(dto.durationMs, 214000);
      expect(dto.genre, 'Electronic');
      expect(dto.playCount, 1540);
      expect(dto.artworkUrl, 'https://cdn.example/480.jpg');
      expect(dto.isStreamable, isTrue);
    });

    test('tolera campos ausentes y marca pistas no transmisibles', () {
      final AudiusTrackDto dto = AudiusTrackDto.fromJson(<String, dynamic>{
        'id': 'x',
        'title': 'Demo',
        'is_streamable': false,
      });

      expect(dto.artist, 'Desconocido');
      expect(dto.durationMs, 0);
      expect(dto.artworkUrl, isNull);
      expect(dto.isStreamable, isFalse);
    });

    test('la entidad conserva el identificador con la fuente', () {
      final OnlineTrack track = AudiusTrackDto.fromJson(<String, dynamic>{
        'id': '42',
        'title': 'Pista',
        'duration': 60,
      }).toEntity();

      expect(track.externalId, 'audius:42');
      expect(track.sourceId, '42');
      expect(track.sourceLabel, 'Audius');
    });
  });

  group('Track online', () {
    test('el id efímero es negativo y estable', () {
      final int a = Track.ephemeralId('audius:abc');
      final int b = Track.ephemeralId('audius:abc');
      final int c = Track.ephemeralId('audius:def');

      expect(a, isNegative);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('Track.online marca origen streaming y URL como ruta', () {
      final OnlineTrack track = const OnlineTrack(
        externalId: 'audius:abc',
        sourceId: 'abc',
        title: 'Pista',
        artist: 'Artista',
        durationMs: 90000,
        artworkUrl: 'https://cdn.example/cover.jpg',
      );

      final Track playable = track.toTrack(
        streamUrl: 'https://cdn.example/audio.mp3',
        artworkPath: r'C:\cache\cover.jpg',
      );

      expect(playable.isOnline, isTrue);
      expect(playable.isPersisted, isFalse);
      expect(playable.isFavorite, isFalse);
      expect(playable.path, 'https://cdn.example/audio.mp3');
      expect(playable.artworkPath, r'C:\cache\cover.jpg');
      expect(playable.artworkUrl, 'https://cdn.example/cover.jpg');
      expect(playable.album, 'Audius');
      expect(playable.duration, const Duration(milliseconds: 90000));
    });

    test('fromRow distingue descargas de archivos locales', () {
      final TrackRow row = TrackRow(
        id: 7,
        path: r'C:\descargas\tema.mp3',
        title: 'Tema',
        artist: 'Artista',
        album: 'Audius',
        durationMs: 1000,
        fileSize: 10,
        source: 'download',
        externalId: 'audius:abc',
        isFavorite: false,
        playCount: 0,
        skipCount: 0,
        addedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final Track track = Track.fromRow(row);
      expect(track.isDownloaded, isTrue);
      expect(track.externalId, 'audius:abc');
      expect(track.isPersisted, isTrue);
    });
  });

  group('DownloadTask', () {
    const OnlineTrack track = OnlineTrack(
      externalId: 'audius:abc',
      sourceId: 'abc',
      title: 'Pista',
      artist: 'Artista',
      durationMs: 1000,
    );

    test('copyWith conserva la pista y actualiza el progreso', () {
      const DownloadTask queued = DownloadTask(track: track);
      final DownloadTask running = queued.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.42,
      );

      expect(running.track, track);
      expect(running.status, DownloadStatus.downloading);
      expect(running.progress, 0.42);
      expect(running.isActive, isTrue);
      expect(running.isCompleted, isFalse);
    });

    test('estados finales no se consideran activos', () {
      const DownloadTask failed = DownloadTask(
        track: track,
        status: DownloadStatus.failed,
      );
      expect(failed.isActive, isFalse);
      expect(failed.isFailed, isTrue);
    });
  });
}
