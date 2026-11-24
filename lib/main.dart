import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/services/app_mutex.dart';
import 'core/services/app_shutdown.dart';
import 'core/services/beta_crash_logger.dart';
import 'core/services/media_session_service.dart';
import 'core/services/tray_service.dart';
import 'core/services/window_service.dart';
import 'core/theme/theme_tokens.dart';
import 'core/utils/logger.dart';
import 'features/online_music/data/online_diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La caché de imágenes por defecto (1000 imágenes / 100 MiB) es excesiva para
  // una biblioteca con carátulas: cada pista visible decodifica una imagen y
  // el excedente se acumula hasta cerca de 100 MiB. Las miniaturas se decodifican
  // a 24–160 px, así que 500 entradas y 48 MiB bastan para cola + carátula
  // principal + vistas compactas sin disparar el working set en Windows.
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;

  await AppLog.initialize();

  // Diagnóstico Beta: un único par de handlers globales. BetaCrashLogger
  // encadena los callbacks previos y es el único que llama a AppLog.e, así no
  // se duplican líneas ni se presenta dos veces el mismo error.
  try {
    await BetaCrashLogger.initialize();
    BetaCrashLogger.install();
    // Los avisos de red/sincronización parcial de YouTube Music llegan al
    // registro Beta sin aumentar el contador de errores (no son crashes).
    OnlineDiagnostics.setReporter(BetaCrashLogger.logWarning);
  } catch (error, stack) {
    AppLog.w('Startup', 'No se pudo activar el diagnóstico Beta', error, stack);
  }

  try {
    await _start();
  } catch (error, stack) {
    AppLog.e('Startup', 'No se pudo iniciar Polaris Music', error, stack);
    runApp(_StartupFailureApp(error: error, logPath: AppLog.filePath));
  }
}

Future<void> _start() async {
  // El instalador usa AppMutex para cerrar también el proceso de la bandeja.
  if (!AppMutex.acquire()) {
    exit(0);
  }

  // media_kit necesita sus binarios nativos antes de crear ningún Player.
  MediaKit.ensureInitialized();

  await ServiceLocator.bootstrap();

  if (sl.isRegistered<TrayService>() && sl.isRegistered<WindowService>()) {
    final TrayService tray = sl<TrayService>();
    final WindowService window = sl<WindowService>();
    // Se conserva la suscripción para poder cancelarla: el closure captura
    // `window` y, sin referencia, no se puede liberar al reiniciar en debug.
    late final StreamSubscription<void> quitSubscription;
    quitSubscription = tray.quitRequests.listen((void _) async {
      AppLog.i('App', 'Salida solicitada desde la bandeja');
      await quitSubscription.cancel();
      await ServiceLocator.shutdown();
      await window.quit();
    });
  }

  // El botón X de la notificación de Android publica un evento desde el
  // handler de audio_service. Aquí, en el isolate de la interfaz, se ejecuta
  // el apagado completo. Solo así se pueden cerrar Drift, bandeja y motor
  // antes de terminar el proceso.
  if (sl.isRegistered<MediaSessionService>()) {
    final MediaSessionService mediaSession = sl<MediaSessionService>();
    bool handled = false;
    Future<void> handleQuit() async {
      if (handled) return;
      handled = true;
      AppLog.i('App', 'Salida solicitada desde la notificación multimedia');
      await AppShutdown.forMediaNotification();
    }

    mediaSession.quitRequests.listen((void _) => unawaited(handleQuit()));
    if (mediaSession.takePendingQuitRequest()) {
      unawaited(handleQuit());
    }
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
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: context.inkAlpha(0.70),
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
