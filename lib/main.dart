import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/di/service_locator.dart';
import 'core/services/tray_service.dart';
import 'core/services/window_service.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit necesita sus binarios nativos antes de crear ningún Player.
  MediaKit.ensureInitialized();

  await ServiceLocator.bootstrap();

  if (sl.isRegistered<TrayService>() && sl.isRegistered<WindowService>()) {
    final TrayService tray = sl<TrayService>();
    final WindowService window = sl<WindowService>();
    tray.quitRequests.listen((void _) async {
      AppLog.i('App', 'Salida solicitada desde la bandeja');
      await ServiceLocator.shutdown();
      await window.quit();
    });
  }

  runApp(const ProviderScope(child: PolarisApp()));
}
