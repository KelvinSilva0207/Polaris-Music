import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/update_info.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/update_prompt_provider.dart';
import '../core/services/window_service.dart';
import '../core/theme/theme_tokens.dart';
import '../features/dynamic_island/presentation/dynamic_island_overlay.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/online_music/presentation/online_music_screen.dart';
import '../features/phone/presentation/phone_mode_shell.dart';
import '../features/player/presentation/mini_player_bar.dart';
import '../features/player/presentation/now_playing_screen.dart';
import '../features/player/presentation/player_providers.dart';
import '../features/player/presentation/tray_mini_player.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/update_dialog.dart';
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
  late final List<Widget> _screens;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = <Widget>[
      const NowPlayingScreen(),
      const LibraryScreen(),
      const OnlineMusicScreen(),
      SettingsScreen(onNavigate: _goToSection),
    ];
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
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
        switch (state.mode) {
          case WindowMode.mini:
            return TrayMiniPlayer(
              onOpen: window.restoreNormal,
              onHide: window.minimizeToTray,
            );
          case WindowMode.phone:
            return const PhoneModeShell();
          case WindowMode.island:
            return IslandWindow(onRestore: window.restoreNormal);
          case WindowMode.normal:
            return _buildNormal();
        }
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
        child: Column(
          children: <Widget>[
            if (Platform.isWindows) const WindowTitleBar(),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Consumer(
                    builder: (BuildContext context, WidgetRef ref, Widget? _) {
                      final AppSection section = ref.watch(appSectionProvider);
                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 66),
                              child: IndexedStack(
                                index: section.index,
                                children: _screens,
                              ),
                            ),
                          ),
                          if (section != AppSection.player)
                            MiniPlayerBar(
                              onOpen: () => _goToSection(AppSection.player),
                            ),
                        ],
                      );
                    },
                  ),
                  const _FloatingNavBar(),
                  if (Platform.isWindows) const _SidePeekTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior flotante y minimalista con las cuatro secciones principales.
class _FloatingNavBar extends ConsumerWidget {
  const _FloatingNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSection selected = ref.watch(appSectionProvider);
    final PolarisTokens tokens = context.tokens;
    final bool compact = MediaQuery.sizeOf(context).width < 620;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: tokens
              .panelDecoration(radius: 20, glow: tokens.accent)
              .copyWith(color: tokens.panelOverlay.withValues(alpha: 0.94)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: AppSection.values
                .map(
                  (AppSection section) => _NavButton(
                    section: section,
                    selected: section == selected,
                    compact: compact,
                    accent: tokens.accent,
                    onTap: () =>
                        ref.read(appSectionProvider.notifier).state = section,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.section,
    required this.selected,
    required this.compact,
    required this.accent,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final bool compact;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.35))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? section.activeIcon : section.icon,
                  size: 18,
                  color: selected ? accent : Colors.white60,
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                duration: const Duration(milliseconds: 220),
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
