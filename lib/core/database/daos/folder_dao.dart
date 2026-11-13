part of '../app_database.dart';

@DriftAccessor(tables: [ScanFolders])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Stream<List<ScanFolderRow>> watchAll() => (select(
    scanFolders,
  )..orderBy([(f) => OrderingTerm(expression: f.addedAt)])).watch();

  Future<List<ScanFolderRow>> getAll() => select(scanFolders).get();

  Future<int> add(String path, {bool recursive = true}) async {
    await into(scanFolders).insert(
      ScanFoldersCompanion.insert(path: path, recursive: Value(recursive)),
      mode: InsertMode.insertOrIgnore,
    );
    final ScanFolderRow row = await (select(
      scanFolders,
    )..where((f) => f.path.equals(path))).getSingle();
    return row.id;
  }

  Future<void> remove(int id) =>
      (delete(scanFolders)..where((f) => f.id.equals(id))).go();

  Future<void> markScanned(int id) =>
      (update(scanFolders)..where((f) => f.id.equals(id))).write(
        ScanFoldersCompanion(lastScanAt: Value(DateTime.now())),
      );
}
