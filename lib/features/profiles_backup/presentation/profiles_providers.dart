import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/backup_service.dart';
import '../domain/profiles_service.dart';

final Provider<ProfilesService> profilesServiceProvider =
    Provider<ProfilesService>((Ref ref) => sl<ProfilesService>());

final StreamProvider<List<ProfileSummary>> profilesProvider =
    StreamProvider<List<ProfileSummary>>((Ref ref) {
      return ref
          .watch(profilesServiceProvider)
          .watchAll()
          .map(
            (List<ProfileRow> rows) =>
                rows.map(ProfileSummary.fromRow).toList(growable: false),
          );
    });

/// Acciones de respaldo usadas por Ajustes.
class BackupActions {
  BackupActions(this._service);

  final ProfilesService _service;

  Future<String> export({bool compress = true}) =>
      _service.exportBackup(compress: compress);

  Future<BackupSummary> import(File file, {bool merge = true}) =>
      _service.importBackup(file, merge: merge);
}

final Provider<BackupActions> backupActionsProvider = Provider<BackupActions>(
  (Ref ref) => BackupActions(sl<ProfilesService>()),
);
