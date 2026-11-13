import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_config.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import 'app_shell.dart';

/// Raíz de Polaris Music.
class PolarisApp extends ConsumerWidget {
  const PolarisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeConfig config = ref.watch(themeConfigProvider);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromConfig(config),
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const _RootGate(),
    );
  }
}

/// Decide entre la introducción y la app completa.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool onboardingDone = ref.watch(onboardingDoneProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: onboardingDone
          ? const AppShell(key: ValueKey<String>('shell'))
          : const OnboardingScreen(key: ValueKey<String>('onboarding')),
    );
  }
}
