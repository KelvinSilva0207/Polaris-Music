import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/services/window_service.dart';
import '../core/theme/theme_tokens.dart';
import '../features/dynamic_island/presentation/dynamic_island_overlay.dart';
import '../features/equalizer/presentation/equalizer_screen.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/online_music/presentation/online_music_screen.dart';
import '../features/phone/presentation/phone_mode_shell.dart';
import '../features/player/presentation/mini_player_bar.dart';
import '../features/player/presentation/now_playing_screen.dart';
import '../features/player/presentation/player_providers.dart';
import '../features/player/presentation/tray_mini_player.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/polaris_logo.dart';
import '../shared/widgets/window_title_bar.dart';

/// Estructura principal: navegación adaptable, mini reproductor e isla.
///
/// La app arranca en el reproductor (índice 2) y adapta su composición al modo
/// de ventana: normal, mini de bandeja o teléfono acoplado.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const int _playerTab = 2;

  int _index = _playerTab;

  late final List<Widget> _screens = <Widget>[
    const LibraryScreen(),
    const OnlineMusicScreen(),
    const NowPlayingScreen(),
    const EqualizerScreen(),
    SettingsScreen(onNavigate: _goTo),
  ];

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      'Biblioteca',
      Icons.library_music_outlined,
      Icons.library_music_rounded,
    ),
    _NavItem('Online', Icons.cloud_outlined, Icons.cloud_rounded),
    _NavItem(
      'Reproductor',
      Icons.play_circle_outline_rounded,
      Icons.play_circle_rounded,
    ),
    _NavItem('Ecualizador', Icons.graphic_eq_rounded, Icons.graphic_eq_rounded),
    _NavItem('Ajustes', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _maybeScanOnStartup();
    });
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
      // Un fallo de escaneo no debe impedir usar la app.
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= _items.length || index == _index) return;
    setState(() => _index = index);
  }

  void _togglePlayback() {
    ref.read(playerControllerProvider.notifier).togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<WindowUiState> notifier = ref.watch(
      windowStateProvider,
    );

    return ValueListenableBuilder<WindowUiState>(
      valueListenable: notifier,
      builder: (BuildContext context, WindowUiState state, Widget? _) {
        switch (state.mode) {
          case WindowMode.mini:
            return TrayMiniPlayer(
              onOpen: ref.read(windowServiceProvider).restoreNormal,
              onHide: ref.read(windowServiceProvider).minimizeToTray,
            );
          case WindowMode.phone:
            return const PhoneModeShell();
          case WindowMode.normal:
            return _buildNormal(state);
        }
      },
    );
  }

  Widget _buildNormal(WindowUiState state) {
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool rail = constraints.maxWidth >= 760;
        return rail ? _buildRail(constraints.maxWidth) : _buildBottomBar();
      },
    );

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
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              children: <Widget>[
                if (Platform.isWindows) const WindowTitleBar(),
                Expanded(child: content),
              ],
            ),
            if (!state.sideHidden) const DynamicIslandOverlay(),
            if (Platform.isWindows) const _SidePeekTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(double width) {
    final bool extended = width >= 1080;
    return Row(
      children: <Widget>[
        NavigationRail(
          extended: extended,
          minExtendedWidth: 210,
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          labelType: extended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: <Widget>[
                const PolarisLogo(size: 34, glow: true),
                if (extended) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text(
                    'Polaris',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          destinations: _items
              .map(
                (_NavItem item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
              )
              .toList(growable: false),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                child: IndexedStack(index: _index, children: _screens),
              ),
              if (_index != _playerTab)
                MiniPlayerBar(onOpen: () => _goTo(_playerTab)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Column(
      children: <Widget>[
        Expanded(
          child: IndexedStack(index: _index, children: _screens),
        ),
        if (_index != _playerTab)
          MiniPlayerBar(onOpen: () => _goTo(_playerTab)),
        NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: _items
              .map(
                (_NavItem item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
              )
              .toList(growable: false),
        ),
      ],
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
            onEnter: (PointerEnterEvent _) {
              setState(() => _hovered = true);
              if (hidden) window.setSideHidden(false);
            },
            onExit: (PointerExitEvent _) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => window.toggleSideHidden(),
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

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
