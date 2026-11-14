import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/services/tray_service.dart';
import 'core/services/window_service.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLog.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLog.e(
      'Flutter',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.e('Platform', error, error, stack);
    return true;
  };

  try {
    await _start();
  } catch (error, stack) {
    AppLog.e('Startup', 'No se pudo iniciar Polaris Music', error, stack);
    runApp(_StartupFailureApp(error: error, logPath: AppLog.filePath));
  }
}

Future<void> _start() async {
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
  AppLog.i('App', 'Interfaz iniciada');
}

/// Pantalla de emergencia si los servicios fallan antes de `runApp`.
///
/// Evita la ventana muda: muestra el error y dónde está el registro completo.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.error, this.logPath});

  final Object error;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    final String detail = error.toString();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0710),
      ),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Color(0xFFFF8A80),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No se pudo iniciar ${AppConstants.appName}',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cierra la app y vuelve a abrirla. Si el problema continúa, '
                    'envía el archivo de registro para revisarlo.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SelectableText(
                    detail,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      color: Color(0xFFFFCCBC),
                    ),
                  ),
                  if (logPath != null) ...<Widget>[
                    const SizedBox(height: 20),
                    const Text(
                      'Registro:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      logPath!,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
