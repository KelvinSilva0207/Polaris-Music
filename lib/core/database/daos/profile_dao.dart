part of '../app_database.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Stream<List<ProfileRow>> watchAll() => (select(
    profiles,
  )..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).watch();

  Future<List<ProfileRow>> getAll() => select(profiles).get();

  Future<ProfileRow?> active() => (select(
    profiles,
  )..where((p) => p.isActive.equals(true))).getSingleOrNull();

  Future<int> create(String name) => into(profiles).insert(
    ProfilesCompanion.insert(name: name),
    mode: InsertMode.insertOrIgnore,
  );

  /// Activa un perfil y desactiva el resto de forma atómica.
  Future<void> activate(int id) => transaction(() async {
    await update(profiles)
        .write(const ProfilesCompanion(isActive: Value(false)));
    await (update(profiles)..where((p) => p.id.equals(id))).write(
      const ProfilesCompanion(isActive: Value(true)),
    );
  });

  Future<void> deleteProfile(int id) => transaction(() async {
    final int total = (await select(profiles).get()).length;
    if (total <= 1) {
      throw StateError('Debe existir al menos un perfil.');
    }
    final ProfileRow? row = await (select(
      profiles,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    await (delete(profiles)..where((p) => p.id.equals(id))).go();
    if (row != null && row.isActive) {
      final List<ProfileRow> rest = await select(profiles).get();
      if (rest.isNotEmpty) {
        await (update(profiles)..where((p) => p.id.equals(rest.first.id)))
            .write(const ProfilesCompanion(isActive: Value(true)));
      }
    }
  });
}
