import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/update_info.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/update_prompt_provider.dart';
import '../core/services/window_service.dart';
import '../core/theme/compact_style_config.dart';
import '../core/theme/compact_theme_scope.dart';
import '../core/theme/theme_tokens.dart';
import '../features/dynamic_island/presentation/dynamic_island_overlay.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/online_music/presentation/online_music_screen.dart';
import '../features/phone/presentation/phone_mode_shell.dart';
import '../features/player/domain/player_controller.dart';
import '../features/player/presentation/mini_player_bar.dart';
import '../features/player/presentation/now_playing_screen.dart';
import '../features/player/presentation/player_providers.dart';
import '../features/player/presentation/tray_mini_player.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/update_dialog.dart';
import '../shared/widgets/directional_transitions.dart';
import '../shared/widgets/liquid_nav_bar.dart';
import '../shared/widgets/motion_scope.dart';
import '../shared/widgets/window_title_bar.dart';
import 'app_navigation.dart';

/// Estructura principal: barra flotante de cuatro secciones, mini reproductor
/// persistente y adaptación a los modos de ventana de escritorio.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  /// Orden visual de los modos. `cycleMode()` no sigue el orden del enum.
  static const List<WindowMode> _modeOrder = <WindowMode>[
    WindowMode.normal,
    WindowMode.mini,
    WindowMode.phone,
    WindowMode.island,
  ];

  late final List<Widget> _screens;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = <Widget>[
      const KeyedSubtree(
        key: ValueKey<String>('section-player'),
        child: CompactThemeScope(
          surface: CompactSurface.player,
          child: NowPlayingScreen(),
        ),
      ),
      const KeyedSubtree(
        key: ValueKey<String>('section-library'),
        child: LibraryScreen(),
      ),
      const KeyedSubtree(
        key: ValueKey<String>('section-online'),
        child: OnlineMusicScreen(),
      ),
      KeyedSubtree(
        key: const ValueKey<String>('section-settings'),
        child: SettingsScreen(onNavigate: _goToSection),
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      // Reanuda la última canción, posición exacta, cola y playlist activa.
      unawaited(ref.read(playerControllerProvider.notifier).restoreSession());
      _maybeScanOnStartup();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final bool hidden =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    // Solo conmuta la UI; media_kit sigue reproduciendo en segundo plano.
    ref.read(windowServiceProvider).setBackgrounded(hidden);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _maybeScanOnStartup() async {
    if (!mounted) return;
    final bool scanOnStartup = ref.read(settingsServiceProvider).scanOnStartup;
    if (!scanOnStartup) return;
    try {
      final bool hasFolders =
          (await ref.read(libraryRepositoryProvider).watchFolders().first)
              .isNotEmpty;
      if (!hasFolders || !mounted) return;
      if (ref.read(scanControllerProvider).running) return;
      await ref.read(scanControllerProvider.notifier).scan();
    } catch (_) {
      // Un fallo del escáner nunca debe bloquear la interfaz.
    }
  }

  void _goToSection(AppSection section) {
    ref.read(appSectionProvider.notifier).state = section;
  }

  void _togglePlayback() {
    ref.read(playerControllerProvider.notifier).togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    // Avisos del reproductor (archivo no disponible, error de apertura...) como
    // SnackBar en la ventana principal. En modo isla/mini no hay Scaffold.
    ref.listen<String?>(
      playerControllerProvider.select((PlayerUiState s) => s.notice),
      (String? previous, String? next) {
        if (next == null || next == previous) return;
        if (ref.read(windowStateProvider).value.mode != WindowMode.normal) {
          return;
        }
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              // Fondo rojo oscuro y texto blanco: el aviso se lee igual con
              // temas claros, oscuros o dinámicos, sin volcar URLs firmadas.
              backgroundColor: const Color(0xFF8E1B24),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              content: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: context.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      next,
                      style: TextStyle(
                        color: context.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      },
    );

    final bool showUpdate = ref.watch(
      updatePromptProvider.select((UpdatePromptState s) => s.shouldShow),
    );
    if (showUpdate && !_updateDialogShown) {
      _updateDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        final UpdateInfo? info = ref.read(updatePromptProvider).info;
        if (info != null) unawaited(UpdateDialog.show(context, info));
      });
    }

    final ValueNotifier<WindowUiState> notifier = ref.watch(
      windowStateProvider,
    );
    return ValueListenableBuilder<WindowUiState>(
      valueListenable: notifier,
      builder: (BuildContext context, WindowUiState state, Widget? _) {
        final WindowService window = ref.read(windowServiceProvider);
        final Widget content;
        switch (state.mode) {
          case WindowMode.mini:
            content = CompactThemeScope(
              surface: CompactSurface.mini,
              child: TrayMiniPlayer(
                onOpen: window.restoreNormal,
                onHide: window.minimizeToTray,
              ),
            );
            break;
          case WindowMode.phone:
            content = const CompactThemeScope(
              surface: CompactSurface.phone,
              child: PhoneModeShell(),
            );
            break;
          case WindowMode.island:
            content = CompactThemeScope(
              surface: CompactSurface.island,
              child: IslandWindow(
                onRestore: window.restoreNormal,
                onHide: window.hide,
                onCapsuleGeometryChanged: window.setIslandCapsule,
              ),
            );
            break;
          case WindowMode.normal:
            content = _buildNormal();
            break;
        }
        // En segundo plano se cortan todos los ticks (vinilo, pulse de gestos,
        // indicadores...). mpv sigue reproduciendo; solo para la animación que
        // nadie está viendo. El TickerMode va dentro del contenido para que no
        // congele la propia transición de entrada/salida.
        return DirectionalContentSwitcher(
          direction: _modeOrder.indexOf(state.mode),
          duration: context.motion.duration(const Duration(milliseconds: 340)),
          distance: 0.08,
          child: KeyedSubtree(
            key: ValueKey<String>('mode-${state.mode.name}'),
            child: TickerMode(enabled: !state.backgrounded, child: content),
          ),
        );
      },
    );
  }

  Widget _buildNormal() {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is! KeyDownEvent ||
              event.logicalKey != LogicalKeyboardKey.space) {
            return KeyEventResult.ignored;
          }
          // Nunca robamos la barra espaciadora mientras se escribe.
          final BuildContext? focused =
              FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              focused.findAncestorWidgetOfExactType<EditableText>() != null) {
            return KeyEventResult.ignored;
          }
          _togglePlayback();
          return KeyEventResult.handled;
        },
        child: Builder(
          builder: (BuildContext context) {
            final bool android = Platform.isAndroid;
            // La barra va abajo en todas las plataformas: reservamos su altura
            // para que el mini-reproductor quede justo encima. En Android se
            // añade además el área del sistema (gestos/navegación).
            final double navClearance = android
                ? MediaQuery.viewPaddingOf(context).bottom + 84
                : 84;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SafeArea(
                  top: android,
                  bottom: false,
                  left: false,
                  right: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navClearance),
                    child: Column(
                      children: <Widget>[
                        if (Platform.isWindows) const WindowTitleBar(),
                        Expanded(
                          child: Consumer(
                            builder: (BuildContext context, WidgetRef ref, Widget? _) {
                              final AppSection section = ref.watch(
                                appSectionProvider,
                              );
                              return Column(
                                children: <Widget>[
                                  Expanded(
                                    child: Padding(
                                      // La barra va abajo en todas las
                                      // plataformas; el hueco se reserva
                                      // con `navClearance`.
                                      padding: EdgeInsets.zero,
                                      // Mantiene las cuatro secciones
                                      // montadas (como el IndexedStack) pero
                                      // desliza/desvanece según la dirección
                                      // del cambio de índice. Cada hijo lleva
                                      // su propio TickerMode para detener el
                                      // vinilo y los pulsos de la pestaña
                                      // oculta sin congelar la transición.
                                      child: DirectionalSectionStack(
                                        index: section.index,
                                        duration: context.motion.duration(
                                          const Duration(milliseconds: 340),
                                        ),
                                        distance: 0.10,
                                        children: _screens,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: context.motion.duration(
                                      const Duration(milliseconds: 320),
                                    ),
                                    switchInCurve: Curves.easeOutBack,
                                    switchOutCurve: Curves.easeInCubic,
                                    // El mini que sale es un panel decorado;
                                    // pintarlo durante la transición deja
                                    // un rectángulo justo encima de la barra.
                                    layoutBuilder:
                                        (
                                          Widget? currentChild,
                                          List<Widget> previousChildren,
                                        ) => Stack(
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            Offstage(
                                              offstage: true,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: previousChildren,
                                              ),
                                            ),
                                            ?currentChild,
                                          ],
                                        ),
                                    transitionBuilder:
                                        (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.4),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                    child: section != AppSection.player
                                        ? SizedBox(
                                            key: const ValueKey<String>('mini'),
                                            child: CompactThemeScope(
                                              surface: CompactSurface.mini,
                                              child: MiniPlayerBar(
                                                onOpen: () => _goToSection(
                                                  AppSection.player,
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(
                                            key: ValueKey<String>('no-mini'),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const _FloatingNavBar(),
                if (Platform.isWindows) const _SidePeekTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Barra flotante de las cuatro secciones principales.
///
/// Abajo en todas las plataformas, igual que en el teléfono. En Android se
/// respeta el SafeArea inferior; en escritorio se limita el ancho para que no
/// se estire en ventanas grandes y siga pareciendo una barra flotante.
class _FloatingNavBar extends ConsumerWidget {
  const _FloatingNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSection selected = ref.watch(appSectionProvider);
    void changeSection(AppSection section) =>
        ref.read(appSectionProvider.notifier).state = section;

    return SafeArea(
      top: false,
      bottom: Platform.isAndroid,
      left: false,
      right: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = Platform.isAndroid
                ? double.infinity
                : math.min<double>(
                    620,
                    math.max<double>(280, constraints.maxWidth - 40),
                  );
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                width: width,
                child: LiquidNavBar(
                  selected: selected,
                  onChanged: changeSection,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pestaña sutil del borde derecho para ocultar/mostrar la ventana (AIMP).
class _SidePeekTab extends ConsumerStatefulWidget {
  const _SidePeekTab();

  @override
  ConsumerState<_SidePeekTab> createState() => _SidePeekTabState();
}

class _SidePeekTabState extends ConsumerState<_SidePeekTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final WindowService window = ref.watch(windowServiceProvider);
    if (!window.isSupported) return const SizedBox.shrink();
    final ValueNotifier<WindowUiState> notifier = ref.watch(
      windowStateProvider,
    );
    final PolarisTokens tokens = context.tokens;

    return ValueListenableBuilder<WindowUiState>(
      valueListenable: notifier,
      builder: (BuildContext context, WindowUiState state, Widget? _) {
        final bool hidden = state.sideHidden;
        return Align(
          alignment: Alignment.centerRight,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              setState(() => _hovered = true);
              if (hidden) unawaited(window.setSideHidden(false));
            },
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => unawaited(window.toggleSideHidden()),
              child: AnimatedContainer(
                duration: context.motion.duration(
                  const Duration(milliseconds: 220),
                ),
                curve: Curves.easeOutCubic,
                width: _hovered ? 20 : 12,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(10),
                  ),
                  color: tokens.surface.withValues(
                    alpha: _hovered || hidden ? 0.92 : 0.42,
                  ),
                  border: Border(
                    left: BorderSide(
                      color: tokens.accent.withValues(
                        alpha: _hovered || hidden ? 0.75 : 0.30,
                      ),
                    ),
                  ),
                ),
                child: Icon(
                  hidden
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  size: 15,
                  color: tokens.accent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
