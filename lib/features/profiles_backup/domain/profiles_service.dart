import 'dart:io';

import '../../../core/database/app_database.dart';
import '../../../core/services/backup_service.dart';

/// Perfiles de usuario (preferencias y colecciones separadas por perfil).
///
/// En Fase 1 los perfiles comparten la biblioteca de pistas (no se duplican
/// archivos); lo que cambia por perfil son las preferencias con `scope`.
/// La UI usa este servicio para no tocar Drift.
class ProfilesService {
  ProfilesService(AppDatabase db)
    : _profiles = db.profileDao,
      _backup = BackupService(db);

  final ProfileDao _profiles;

  final BackupService _backup;

  Stream<List<ProfileRow>> watchAll() => _profiles.watchAll();

  Future<List<ProfileRow>> all() => _profiles.getAll();

  Future<ProfileRow?> active() => _profiles.active();

  Future<int> create(String name) => _profiles.create(name.trim());

  Future<void> activate(int id) => _profiles.activate(id);

  Future<void> delete(int id) => _profiles.deleteProfile(id);

  Future<String> exportBackup({bool compress = true}) =>
      _backup.exportToFile(compress: compress);

  Future<BackupSummary> importBackup(File file, {bool merge = true}) =>
      _backup.importFromFile(file, merge: merge);

  Future<Map<String, dynamic>> preview() => _backup.buildBackup();
}

/// Perfil simple para mostrar en la UI.
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory ProfileSummary.fromRow(ProfileRow row) =>
      ProfileSummary(id: row.id, name: row.name, isActive: row.isActive);
}
