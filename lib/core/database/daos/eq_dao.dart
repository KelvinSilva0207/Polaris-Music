part of '../app_database.dart';

@DriftAccessor(tables: [EqPresets])
class EqDao extends DatabaseAccessor<AppDatabase> with _$EqDaoMixin {
  EqDao(super.db);

  Stream<List<EqPresetRow>> watchAll() =>
      (select(eqPresets)..orderBy([
            (p) =>
                OrderingTerm(expression: p.isBuiltIn, mode: OrderingMode.desc),
            (p) => OrderingTerm(expression: p.name),
          ]))
          .watch();

  Future<List<EqPresetRow>> getAll() => select(eqPresets).get();

  Future<EqPresetRow?> byName(String name) =>
      (select(eqPresets)..where((p) => p.name.equals(name))).getSingleOrNull();

  Future<int> save({
    required String name,
    required List<double> bands,
    double preampDb = 0,
  }) => into(eqPresets).insertOnConflictUpdate(
    EqPresetsCompanion.insert(
      name: name,
      bandsJson: bands.join(','),
      preampDb: Value(preampDb),
    ),
  );

  Future<void> deletePreset(int id) => (delete(
    eqPresets,
  )..where((p) => p.id.equals(id) & p.isBuiltIn.equals(false))).go();
}
