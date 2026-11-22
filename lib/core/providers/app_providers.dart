import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../models/update_info.dart';
import '../services/app_updater_service.dart';
import '../services/audio_engine_service.dart';
import '../services/brightness_service.dart';
import '../services/global_hotkey_service.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';
import '../services/storage_paths_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';
import '../services/window_service.dart';

final Provider<SettingsService> settingsServiceProvider =
    Provider<SettingsService>((Ref ref) => sl<SettingsService>());

/// Motor de audio; se usa de forma puntual para consultar propiedades de mpv.
final Provider<AudioEngineService> audioEngineProvider =
    Provider<AudioEngineService>((Ref ref) => sl<AudioEngineService>());

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

final Provider<StoragePathsService> storagePathsServiceProvider =
    Provider<StoragePathsService>((Ref ref) => sl<StoragePathsService>());

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => sl<PermissionService>());

final Provider<BrightnessService> brightnessServiceProvider =
    Provider<BrightnessService>((Ref ref) => sl<BrightnessService>());

final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (Ref ref) => sl<UpdateService>(),
);

/// Proveedor concreto del updater (necesario para el diálogo y Android).
final Provider<AppUpdaterService> appUpdaterServiceProvider =
    Provider<AppUpdaterService>((Ref ref) => sl<AppUpdaterService>());

/// Desenlace del instalador del sistema: éxito, cancelación o error.
final StreamProvider<ApkInstallOutcome> apkInstallOutcomeProvider =
    StreamProvider<ApkInstallOutcome>((Ref ref) {
      return ref.watch(appUpdaterServiceProvider).installOutcomes;
    });

final Provider<WindowService> windowServiceProvider = Provider<WindowService>(
  (Ref ref) => sl<WindowService>(),
);

final Provider<TrayService> trayServiceProvider = Provider<TrayService>(
  (Ref ref) => sl<TrayService>(),
);

final Provider<GlobalHotkeyService> globalHotkeyServiceProvider =
    Provider<GlobalHotkeyService>((Ref ref) => sl<GlobalHotkeyService>());

/// Estado nativo de la ventana, observable por el shell.
final Provider<ValueNotifier<WindowUiState>> windowStateProvider =
    Provider<ValueNotifier<WindowUiState>>(
      (Ref ref) => ref.watch(windowServiceProvider).state,
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
