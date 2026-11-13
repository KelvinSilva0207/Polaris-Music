part of '../app_database.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key, {String scope = 'global'}) async {
    final SettingRow? row =
        await (select(settings)
              ..where((s) => s.key.equals(key) & s.scope.equals(scope)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value, {String scope = 'global'}) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
          scope: Value(scope),
          key: key,
          value: value,
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<Map<String, String>> all({String scope = 'global'}) async {
    final List<SettingRow> rows = await (select(
      settings,
    )..where((s) => s.scope.equals(scope))).get();
    return <String, String>{
      for (final SettingRow row in rows) row.key: row.value,
    };
  }

  Future<void> remove(String key, {String scope = 'global'}) => (delete(
    settings,
  )..where((s) => s.key.equals(key) & s.scope.equals(scope))).go();

  Future<void> clear({String? scope}) async {
    if (scope == null) {
      await delete(settings).go();
    } else {
      await (delete(settings)..where((s) => s.scope.equals(scope))).go();
    }
  }
}
