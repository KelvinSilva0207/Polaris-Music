import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../domain/dynamic_island_controller.dart';

final StateNotifierProvider<DynamicIslandController, DynamicIslandState>
dynamicIslandControllerProvider =
    StateNotifierProvider<DynamicIslandController, DynamicIslandState>((
      Ref ref,
    ) {
      final DynamicIslandController controller = DynamicIslandController(
        settings: sl(),
        engine: sl(),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
