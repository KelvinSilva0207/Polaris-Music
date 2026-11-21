import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/motion_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/providers/typography_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_config.dart';
import '../core/theme/font_catalog.dart';
import '../core/theme/typography_config.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../shared/widgets/directional_transitions.dart';
import '../shared/widgets/motion_scope.dart';
import 'app_shell.dart';

/// Raíz de Polaris Music.
class PolarisApp extends ConsumerStatefulWidget {
  const PolarisApp({super.key});

  @override
  ConsumerState<PolarisApp> createState() => _PolarisAppState();
}

class _PolarisAppState extends ConsumerState<PolarisApp> {
  @override
  void initState() {
    super.initState();
    // El marco nativo de Windows usa el fondo del preset activo desde el primer
    // frame, no un negro fijo distinto del `scaffoldBackgroundColor`.
    unawaited(
      ref
          .read(windowServiceProvider)
          .setWindowBackground(ref.read(themeConfigProvider).background),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeConfig config = ref.watch(flowingThemeConfigProvider);
    ref.listen<AppThemeConfig>(themeConfigProvider, (previous, next) {
      if (previous != null && previous.background == next.background) return;
      unawaited(
        ref.read(windowServiceProvider).setWindowBackground(next.background),
      );
    });
    final TypographyConfig typography = ref.watch(typographyProvider);
    final List<ImportedFont> imported = ref.watch(fontLibraryProvider);
    final String? family = resolveFontFamily(typography.familyId, imported);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromConfig(
        config,
        typography: ResolvedTypography(typography, family),
      ),
      themeAnimationDuration: ref
          .watch(motionConfigProvider)
          .duration(const Duration(milliseconds: 450)),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (BuildContext context, Widget? child) =>
          MotionScope(child: child ?? const SizedBox.shrink()),
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
    return DirectionalContentSwitcher(
      direction: onboardingDone ? 1 : 0,
      duration: context.motion.duration(const Duration(milliseconds: 300)),
      distance: 0.10,
      child: onboardingDone
          ? const AppShell(key: ValueKey<String>('shell'))
          : const OnboardingScreen(key: ValueKey<String>('onboarding')),
    );
  }
}
