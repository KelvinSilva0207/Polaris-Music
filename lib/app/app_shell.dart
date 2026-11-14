import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../features/dynamic_island/presentation/dynamic_island_overlay.dart';
import '../features/equalizer/presentation/equalizer_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/library_providers.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/player/presentation/mini_player_bar.dart';
import '../features/player/presentation/now_playing_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/stats_sync/presentation/stats_screen.dart';

/// Estructura principal: navegación adaptable, mini reproductor e isla.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const int _playerTab = 2;

  int _index = 0;

  late final List<Widget> _screens = <Widget>[
    HomeScreen(onNavigate: _goTo),
    const LibraryScreen(),
    const NowPlayingScreen(),
    const EqualizerScreen(),
    const StatsScreen(),
    SettingsScreen(onNavigate: _goTo),
  ];

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Inicio', Icons.home_outlined, Icons.home_rounded),
    _NavItem(
      'Biblioteca',
      Icons.library_music_outlined,
      Icons.library_music_rounded,
    ),
    _NavItem(
      'Reproductor',
      Icons.play_circle_outline_rounded,
      Icons.play_circle_rounded,
    ),
    _NavItem('Ecualizador', Icons.graphic_eq_rounded, Icons.graphic_eq_rounded),
    _NavItem('Estadísticas', Icons.insights_outlined, Icons.insights_rounded),
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

  @override
  Widget build(BuildContext context) {
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool rail = constraints.maxWidth >= 760;
        return rail ? _buildRail(constraints.maxWidth) : _buildBottomBar();
      },
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[content, const DynamicIslandOverlay()],
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
                Icon(
                  Icons.public_rounded,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (extended) ...<Widget>[
                  const SizedBox(height: 6),
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

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
