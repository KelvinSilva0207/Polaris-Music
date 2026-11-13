import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../models/update_info.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';
import '../services/window_service.dart';

final Provider<SettingsService> settingsServiceProvider =
    Provider<SettingsService>((Ref ref) => sl<SettingsService>());

/// Preferencias reactivas: emite la caché actual y cada cambio.
final StreamProvider<Map<String, String>> settingsValuesProvider =
    StreamProvider<Map<String, String>>((Ref ref) {
      final SettingsService service = ref.watch(settingsServiceProvider);
      return service.changes;
    });

final Provider<bool> onboardingDoneProvider = Provider<bool>((Ref ref) {
  final AsyncValue<Map<String, String>> values = ref.watch(
    settingsValuesProvider,
  );
  return values.maybeWhen(
    data: (Map<String, String> map) =>
        map[AppConstants.keyOnboardingDone] == 'true',
    orElse: () => ref.watch(settingsServiceProvider).onboardingDone,
  );
});

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => sl<PermissionService>());

final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (Ref ref) => sl<UpdateService>(),
);

final Provider<WindowService> windowServiceProvider = Provider<WindowService>(
  (Ref ref) => sl<WindowService>(),
);

final Provider<TrayService> trayServiceProvider = Provider<TrayService>(
  (Ref ref) => sl<TrayService>(),
);

final FutureProvider<UpdateInfo?> latestUpdateProvider =
    FutureProvider<UpdateInfo?>((Ref ref) {
      return ref.watch(updateServiceProvider).checkForUpdates();
    });

final FutureProvider<String> currentVersionProvider = FutureProvider<String>((
  Ref ref,
) {
  return ref.watch(updateServiceProvider).currentVersion();
});
