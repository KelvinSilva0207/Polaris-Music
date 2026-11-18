import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/update_info.dart';
import '../services/app_updater_service.dart';
import 'app_providers.dart';

/// Estado del aviso silencioso de actualización al arrancar.
@immutable
class UpdatePromptState {
  const UpdatePromptState({
    this.info,
    this.checked = false,
    this.dismissed = false,
  });

  final UpdateInfo? info;
  final bool checked;
  final bool dismissed;

  bool get shouldShow =>
      checked && !dismissed && info?.isUpdateAvailable == true;

  UpdatePromptState copyWith({
    UpdateInfo? info,
    bool? checked,
    bool? dismissed,
  }) {
    return UpdatePromptState(
      info: info ?? this.info,
      checked: checked ?? this.checked,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Consulta GitHub 3 segundos después de crear el provider, sin bloquear el
/// arranque. El aviso se muestra una sola vez por sesión hasta que se descarte.
class UpdatePromptController extends StateNotifier<UpdatePromptState> {
  UpdatePromptController(this._service) : super(const UpdatePromptState()) {
    _timer = Timer(const Duration(seconds: 3), () => unawaited(check()));
  }

  final AppUpdaterService _service;
  Timer? _timer;
  bool _checking = false;

  Future<void> check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final UpdateInfo? info = await _service.checkForUpdates();
      if (!mounted) return;
      state = state.copyWith(
        info: info,
        checked: true,
        // Si ya no hay actualización, no volver a insistir en esta sesión.
        dismissed: info?.isUpdateAvailable == true ? false : true,
      );
    } finally {
      _checking = false;
    }
  }

  void dismiss() {
    if (mounted) state = state.copyWith(dismissed: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<UpdatePromptController, UpdatePromptState>
updatePromptProvider =
    StateNotifierProvider<UpdatePromptController, UpdatePromptState>((Ref ref) {
      return UpdatePromptController(ref.watch(appUpdaterServiceProvider));
    });
