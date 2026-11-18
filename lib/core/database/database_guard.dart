import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../utils/logger.dart';

/// Resultado de la comprobación previa a abrir la base de datos.
enum DatabaseGuardOutcome {
  /// No existía archivo: Drift creará una base de datos nueva.
  fresh,

  /// El archivo existe y pasa `quick_check`; no hacía falta copia.
  intact,

  /// El archivo estaba en una versión anterior: se ha hecho `.bak`.
  backedUp,

  /// El archivo estaba corrupto: se ha aislado y se regenerará uno limpio.
  recovered,
}

/// Excepción lanzada por `beforeOpen` cuando SQLite detecta daños en el archivo.
///
/// `ServiceLocator` la intercepta para aislar el archivo y reintentar una vez.
class DatabaseCorruptionException implements Exception {
  const DatabaseCorruptionException(this.detail);

  final String detail;

  @override
  String toString() => 'Base de datos corrupta: $detail';
}

/// Blindaje anti-corrupción del archivo SQLite de Polaris Music.
///
/// Drift ejecuta `onCreate`/`onUpgrade` **antes** de `beforeOpen`, así que la
/// copia de seguridad no puede limitarse a `beforeOpen`: [prepare] se invoca
/// desde el bootstrap, antes de crear el `AppDatabase`, y [backupBeforeMigration]
/// se invoca además como primera instrucción de `onUpgrade`.
class DatabaseGuard {
  DatabaseGuard._();

  static const String _tag = 'DatabaseGuard';
  static const String databaseName = 'polaris_music';
  static const String fileName = '$databaseName.sqlite';
  static const String backupExtension = '.bak';

  /// Ruta que usa `driftDatabase(name: 'polaris_music')` en nativo.
  static Future<File> databaseFile() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    return File(p.join(documents.path, fileName));
  }

  /// Copia de seguridad junto al archivo original (`polaris_music.sqlite.bak`).
  static Future<File> backupFile() async {
    final File db = await databaseFile();
    return File('${db.path}$backupExtension');
  }

  /// Comprueba el archivo antes de que Drift lo abra.
  ///
  /// Nunca destruye un archivo sano: solo copia cuando la versión va a cambiar
  /// y, en caso de corrupción, lo renombra a `.corrupt-<timestamp>` antes de
  /// dejar que Drift regenere la base de datos.
  static Future<DatabaseGuardOutcome> prepare({
    required int targetSchemaVersion,
  }) async {
    final File db = await databaseFile();
    if (!db.existsSync()) {
      AppLog.i(_tag, 'No hay base de datos previa; se creará una nueva');
      return DatabaseGuardOutcome.fresh;
    }

    final String? corruption = _check(db);
    if (corruption != null) {
      await quarantine(db, reason: corruption);
      return DatabaseGuardOutcome.recovered;
    }

    final int currentVersion = _schemaVersion(db);
    if (currentVersion < targetSchemaVersion) {
      await copyToBackup(db);
      AppLog.i(
        _tag,
        'Copia previa a la migración v$currentVersion → v$targetSchemaVersion',
      );
      return DatabaseGuardOutcome.backedUp;
    }

    return DatabaseGuardOutcome.intact;
  }

  /// Copia defensiva dentro de `onUpgrade`, por si el arranque no pasó por
  /// [prepare] (por ejemplo, un `AppDatabase` creado directamente).
  static Future<void> backupBeforeMigration() async {
    try {
      final File db = await databaseFile();
      if (db.existsSync()) {
        await copyToBackup(db);
      }
    } catch (error, stack) {
      // Una copia fallida no debe impedir la migración: se registra y sigue.
      AppLog.w(
        _tag,
        'No se pudo crear la copia previa a la migración',
        error,
        stack,
      );
    }
  }

  /// Copia [db] a `polaris_music.sqlite.bak` de forma atómica.
  static Future<File> copyToBackup(File db) async {
    final File backup = await backupFile();
    await _copyWithSidecars(db, backup);
    return backup;
  }

  /// Aísla un archivo dañado y elimina los restos para que Drift pueda crear
  /// una base de datos limpia sin arrastrar un WAL corrupto.
  static Future<void> quarantine(
    File db, {
    String reason = 'desconocida',
  }) async {
    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final File damaged = File('${db.path}.corrupt-$stamp');
    try {
      await db.rename(damaged.path);
      AppLog.e(
        _tag,
        'Base de datos dañada ($reason) aislada en ${damaged.path}',
      );
    } catch (error, stack) {
      AppLog.e(_tag, 'No se pudo aislar la base de datos dañada', error, stack);
      // Como último recurso se borra: es preferible perder la biblioteca que
      // dejar la app inarrancable para siempre.
      await _safeDelete(db);
    }
    await _safeDelete(File('${db.path}-wal'));
    await _safeDelete(File('${db.path}-shm'));
    await _safeDelete(File('${db.path}-journal'));
  }

  /// `null` significa "archivo sano".
  static String? _check(File db) {
    Database? database;
    try {
      database = _openForPreflight(db);
      final ResultSet result = database.select('PRAGMA quick_check(1)');
      if (result.isEmpty) return 'quick_check sin resultado';
      final String status = '${result.first.columnAt(0)}';
      return status == 'ok' ? null : status;
    } catch (error) {
      return '$error';
    } finally {
      database?.close();
    }
  }

  static int _schemaVersion(File db) {
    Database? database;
    try {
      database = _openForPreflight(db);
      final ResultSet result = database.select('PRAGMA user_version');
      if (result.isEmpty) return 0;
      return result.first.columnAt(0) as int? ?? 0;
    } catch (_) {
      return 0;
    } finally {
      database?.close();
    }
  }

  /// Abre en lectura/escritura para que SQLite pueda recuperar un journal
  /// pendiente; si eso falla, prueba en solo lectura antes de declarar corrupción.
  static Database _openForPreflight(File db) {
    try {
      return sqlite3.open(db.path);
    } catch (_) {
      return sqlite3.open(db.path, mode: OpenMode.readOnly);
    }
  }

  static Future<void> _copyWithSidecars(File source, File target) async {
    final Directory parent = target.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    // En modo WAL una copia pura del archivo principal puede perder las últimas
    // transacciones. Un checkpoint TRUNCATE vuelca el WAL antes de copiar.
    await _checkpoint(source);
    await source.copy(target.path);

    // Tras el checkpoint los sidecars están vacíos; se copian de todos modos
    // por si el checkpoint no pudo completarse.
    for (final String suffix in <String>['-wal', '-shm']) {
      final File sidecar = File('${source.path}$suffix');
      if (sidecar.existsSync()) {
        await _safeCopy(sidecar, File('${target.path}$suffix'));
      }
    }
  }

  static Future<void> _checkpoint(File db) async {
    Database? database;
    try {
      database = sqlite3.open(db.path);
      database.select('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo hacer checkpoint antes de la copia',
        error,
        stack,
      );
    } finally {
      database?.close();
    }
  }

  static Future<void> _safeCopy(File source, File target) async {
    try {
      await source.copy(target.path);
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo copiar ${source.path}', error, stack);
    }
  }

  static Future<void> _safeDelete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo borrar ${file.path}', error, stack);
    }
  }
}
