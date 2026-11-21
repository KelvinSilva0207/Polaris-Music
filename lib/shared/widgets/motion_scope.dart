import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/motion_provider.dart';
import '../../core/theme/motion_config.dart';

/// Aplica la configuración de movimiento a todo el árbol de la aplicación.
///
/// Se coloca en `MaterialApp.builder`, por encima del `Navigator`, para que
/// también afecte a diálogos y rutas. Respeta la preferencia del sistema
/// “reducir animaciones” sin sobrescribir la configuración guardada.
class MotionScope extends ConsumerStatefulWidget {
  const MotionScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MotionScope> createState() => _MotionScopeState();
}

class _MotionScopeState extends ConsumerState<MotionScope> {
  bool _systemDisable = false;
  VoidCallback? _previousAccessibilityCallback;

  @override
  void initState() {
    super.initState();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    _previousAccessibilityCallback = dispatcher.onAccessibilityFeaturesChanged;
    dispatcher.onAccessibilityFeaturesChanged = _onAccessibilityChanged;
    _systemDisable = dispatcher.accessibilityFeatures.disableAnimations;
  }

  void _onAccessibilityChanged() {
    // El callback previo pertenece a SemanticsBinding: sin invocarlo, el
    // sistema no actualiza MediaQuery ni la semántica al cambiar accesibilidad.
    _previousAccessibilityCallback?.call();
    if (!mounted) return;
    final bool disabled = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (disabled == _systemDisable) return;

    void apply() {
      if (!mounted) return;
      setState(() => _systemDisable = disabled);
    }

    // SemanticsBinding difiere este trabajo durante persistentCallbacks;
    // hacerlo aquí de forma inmediata provocaría `setState()` durante el build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.platformDispatcher.onAccessibilityFeaturesChanged =
        _previousAccessibilityCallback;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotionConfig stored = ref.watch(motionControllerProvider);
    final MotionConfig effective = _systemDisable
        ? stored.copyWith(
            transitions: false,
            ambient: false,
            gestures: false,
            island: false,
          )
        : stored;

    final MediaQueryData media = MediaQuery.of(context);
    final bool disableImplicit =
        media.disableAnimations || !effective.transitions;
    final bool ambientAllowed =
        effective.enabled(MotionCategory.ambient) &&
        // ignore: deprecated_member_use
        TickerMode.of(context) &&
        !media.disableAnimations;
    if (ref.read(ambientMotionGateProvider) != ambientAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(ambientMotionGateProvider.notifier).state = ambientAllowed;
      });
    }

    return ProviderScope(
      overrides: <Override>[motionConfigProvider.overrideWithValue(effective)],
      child: _MotionInherited(
        config: effective,
        child: MediaQuery(
          data: media.copyWith(disableAnimations: disableImplicit),
          child: widget.child,
        ),
      ),
    );
  }
}

class _MotionInherited extends InheritedWidget {
  const _MotionInherited({required this.config, required super.child});

  final MotionConfig config;

  static MotionConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionInherited>()?.config ??
      MotionConfig.defaults;

  @override
  bool updateShouldNotify(_MotionInherited oldWidget) =>
      oldWidget.config != config;
}

/// Configuración de movimiento vigente en este contexto.
extension MotionContext on BuildContext {
  MotionConfig get motion => _MotionInherited.of(this);
}

/// Comprobación única para animaciones que deben detenerse en pausa,
/// minimizado, pestaña oculta o cuando el sistema pide reducir movimiento.
extension MotionGate on BuildContext {
  bool motionAllowed(MotionCategory category) =>
      motion.enabled(category) &&
      // ignore: deprecated_member_use
      TickerMode.of(this) &&
      !MediaQuery.of(this).disableAnimations;

  bool ambientMotionAllowed({required bool playing}) =>
      playing && motionAllowed(MotionCategory.ambient);
}
