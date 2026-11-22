import 'package:drift/drift.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/core/services/settings_service.dart';

/// `SettingsService` en memoria para pruebas de persistencia.
///
/// No abre SQLite: el DAO solo existe para satisfacer el constructor y todos
/// los accesos usan el mapa local.
class FakeSettingsService extends SettingsService {
  FakeSettingsService()
    : super(AppDatabase.forTesting(_InertExecutor()).settingsDao);

  final Map<String, String> _values = <String, String>{};

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Ejecutor que nunca recibe consultas; solo aporta el dialecto a Drift.
class _InertExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => throw UnimplementedError();

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      throw UnimplementedError();

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      throw UnimplementedError();

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => throw UnimplementedError();
}
