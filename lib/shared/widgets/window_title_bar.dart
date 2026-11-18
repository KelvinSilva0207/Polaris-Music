import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/legacy.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/window_service.dart';
import '../../core/theme/theme_tokens.dart';
import '../../features/dynamic_island/presentation/island_providers.dart';
import 'polaris_logo.dart';

/// Barra de título personalizada de Windows.
///
/// Añade el cuarto botón solicitado: además de minimizar, maximizar y cerrar,
/// permite enviar la app a la bandeja del sistema sin agruparla en la barra de
/// tareas. El área central arrastra la ventana y el doble clic maximiza.
class WindowTitleBar extends ConsumerWidget {
  const WindowTitleBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WindowService window = ref.watch(windowServiceProvider);
    final bool islandEnabled = ref.watch(
      dynamicIslandControllerProvider.select((s) => s.enabled),
    );
    final ValueNotifier<WindowUiState> notifier = ref.watch(
      windowStateProvider,
    );
    final PolarisTokens tokens = context.tokens;

    return ValueListenableBuilder<WindowUiState>(
      valueListenable: notifier,
      builder: (BuildContext context, WindowUiState state, Widget? _) {
        final bool isPhone = state.mode == WindowMode.phone;
        final double height = compact ? 34 : 38;

        final Widget bar = SizedBox(
          height: height,
          child: Row(
            children: <Widget>[
              SizedBox(width: compact ? 10 : 14),
              PolarisLogo(size: compact ? 18 : 20, glow: false),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: window.toggleMaximize,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isPhone
                          ? 'Polaris · Modo teléfono'
                          : (compact ? 'Polaris' : AppConstants.appName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
              ),
              if (!compact && !isPhone) ...<Widget>[
                _TitleBarButton(
                  tooltip: islandEnabled ? 'Minimizar a isla' : 'Minimizar',
                  icon: Icons.remove_rounded,
                  onTap: islandEnabled ? window.showIsland : window.minimize,
                ),
                _TitleBarButton(
                  tooltip: state.maximized ? 'Restaurar' : 'Maximizar',
                  icon: state.maximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
                  onTap: window.toggleMaximize,
                ),
              ],
              _TitleBarButton(
                tooltip: 'Ocultar en la bandeja',
                icon: Icons.expand_more_rounded,
                onTap: window.minimizeToTray,
              ),
              _TitleBarButton(
                tooltip: isPhone || compact
                    ? 'Abrir ventana principal'
                    : 'Cerrar',
                icon: isPhone || compact
                    ? Icons.open_in_full_rounded
                    : Icons.close_rounded,
                danger: !isPhone && !compact,
                onTap: isPhone || compact ? window.restoreNormal : window.close,
              ),
              const SizedBox(width: 4),
            ],
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            border: Border(
              bottom: BorderSide(
                color: tokens.panelBorder.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Platform.isWindows ? DragToMoveArea(child: bar) : bar,
        );
      },
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  const _TitleBarButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 34,
          child: Icon(
            icon,
            size: 17,
            color: danger
                ? const Color(0xFFFF8A80)
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}
