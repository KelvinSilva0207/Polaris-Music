import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/beta_crash_logger.dart';

/// Tests aislados: siempre se inyecta un directorio temporal, nunca se toca
/// la carpeta real de registros del usuario.
void main() {
  late Directory dir;

  setUp(() async {
    BetaCrashLogger.resetForTesting();
    dir = await Directory.systemTemp.createTemp('polaris-beta-logger-');
    await BetaCrashLogger.initialize(directory: dir.path);
  });

  tearDown(() async {
    await BetaCrashLogger.flush();
    BetaCrashLogger.resetForTesting();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('usa el directorio inyectado y arranca sin archivos ni errores', () {
    expect(BetaCrashLogger.logDirectory, dir.path);
    expect(BetaCrashLogger.loggedErrors, 0);
    expect(BetaCrashLogger.logFiles(), isEmpty);
  });

  test(
    'cuenta errores y deduplica el mismo error en la ventana corta',
    () async {
      final StackTrace stack = StackTrace.current;
      BetaCrashLogger.recordPlatformError(StateError('rojo'), stack);
      BetaCrashLogger.recordPlatformError(StateError('rojo'), stack);
      expect(BetaCrashLogger.loggedErrors, 1);

      BetaCrashLogger.recordPlatformError(StateError('azul'), stack);
      expect(BetaCrashLogger.loggedErrors, 2);
      await BetaCrashLogger.flush();
      expect(BetaCrashLogger.logFiles(), hasLength(1));
    },
  );

  test('logWarning escribe avisos sin contarlos como errores', () async {
    BetaCrashLogger.logWarning(
      'YouTubeMusic',
      'sincronización parcial',
      error: StateError('red'),
    );
    await BetaCrashLogger.flush();

    expect(BetaCrashLogger.loggedErrors, 0);
    final String content = await File(
      '${dir.path}${Platform.pathSeparator}beta_crash.log',
    ).readAsString();
    expect(content, contains('[W][YouTubeMusic] sincronización parcial'));
    expect(content, contains('error: Bad state: red'));
  });

  test('logError cuenta errores reportados explícitamente', () async {
    BetaCrashLogger.logError('Sync', 'fallo al subir', error: StateError('x'));
    BetaCrashLogger.logError('Sync', 'fallo al subir', error: StateError('x'));
    await BetaCrashLogger.flush();
    expect(BetaCrashLogger.loggedErrors, 1);
  });

  test('la bandera desactiva la escritura Beta', () async {
    BetaCrashLogger.isBetaLoggingEnabled = false;
    BetaCrashLogger.logWarning('Red', 'aviso ignorado');
    BetaCrashLogger.recordPlatformError(
      StateError('ignorado'),
      StackTrace.current,
    );
    await BetaCrashLogger.flush();
    expect(BetaCrashLogger.loggedErrors, 0);
    expect(BetaCrashLogger.logFiles(), isEmpty);
  });

  test('rota como máximo 5 archivos y no supera ~2 MB en total', () async {
    final String chunk = 'x' * 4000;
    for (int i = 0; i < 600; i++) {
      BetaCrashLogger.enqueueForTesting('[$i] $chunk');
    }
    await BetaCrashLogger.flush();

    final List<File> files = BetaCrashLogger.logFiles();
    expect(files, hasLength(BetaCrashLogger.maxFiles));
    expect(
      BetaCrashLogger.logBytes(),
      lessThanOrEqualTo(BetaCrashLogger.maxTotalBytes),
    );
    expect(files.map((File f) => f.path).toSet(), hasLength(5));
  });

  test('limpiar borra los archivos y reinicia el contador', () async {
    BetaCrashLogger.recordPlatformError(
      StateError('fallo'),
      StackTrace.current,
    );
    await BetaCrashLogger.flush();
    expect(BetaCrashLogger.logFiles(), isNotEmpty);

    final int removed = await BetaCrashLogger.clearLogs();

    expect(removed, greaterThan(0));
    expect(BetaCrashLogger.logFiles(), isEmpty);
    expect(BetaCrashLogger.loggedErrors, 0);
  });

  test('exporta un ZIP legible con los logs y el diagnóstico', () async {
    BetaCrashLogger.logWarning('Red', 'reintento');
    await BetaCrashLogger.flush();

    final String path = await BetaCrashLogger.exportLogs(
      diagnostics: 'Versión: 9.9.9',
    );
    final Archive archive = ZipDecoder().decodeBytes(
      await File(path).readAsBytes(),
    );
    final List<String> names = archive.files
        .map((ArchiveFile f) => f.name)
        .toList();

    expect(names, contains('beta_crash.log'));
    expect(names, contains('diagnostico.txt'));
    expect(
      utf8.decode(
        archive.files
                .firstWhere((ArchiveFile f) => f.name == 'diagnostico.txt')
                .content
            as List<int>,
      ),
      contains('Versión: 9.9.9'),
    );
  });
}
