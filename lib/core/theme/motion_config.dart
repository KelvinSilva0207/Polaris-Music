import 'package:flutter/foundation.dart';

/// Perfiles listos para usar de Animaciones y Movimiento.
enum MotionProfile {
  fluid(
    'Fluido',
    'Transiciones amplias y ambiente continuo; la experiencia más expresiva.',
  ),
  balanced(
    'Equilibrado',
    'Movimiento cómodo con animaciones ambientales discretas.',
  ),
  minimal(
    'Mínimo',
    'Sin transiciones ni giros decorativos: máxima claridad y ahorro de GPU.',
  ),
  bajo(
    'Bajo',
    'Movimiento breve y funcional, sin ambiente continuo: máxima claridad.',
  ),
  medio(
    'Medio',
    'Equilibrio entre fluidez y sobriedad; animaciones cómodas y discretas.',
  ),
  alto('Alto', 'Transiciones amplias, pulses expresivos y ambiente continuo.'),
  custom('Personalizado', 'Velocidad y categorías ajustadas una a una.');

  const MotionProfile(this.label, this.description);

  final String label;
  final String description;
}

/// Categorías que pueden activarse o desactivarse por separado.
enum MotionCategory {
  transitions('Transiciones', 'Cambios de pantalla, paneles y listas'),
  ambient('Ambiente', 'Vinilo, ecualizador y brillos continuos'),
  gestures('Gestos', 'Inclinación de carátula y feedback táctil'),
  island('Isla dinámica', 'Despliegue y contracción de la isla');

  const MotionCategory(this.label, this.description);

  final String label;
  final String description;
}

/// Configuración persistente de movimiento.
///
/// `speed` es un multiplicador: valores mayores acortan las duraciones. Las
/// categorías desactivadas devuelven `Duration.zero`, por lo que los widgets
/// implicitan el cambio sin necesidad de reconstruir toda la app.
@immutable
class MotionConfig {
  const MotionConfig({
    this.profile = MotionProfile.balanced,
    this.speed = 1,
    this.transitions = true,
    this.ambient = true,
    this.gestures = true,
    this.island = true,
  });

  final MotionProfile profile;
  final double speed;
  final bool transitions;
  final bool ambient;
  final bool gestures;
  final bool island;

  static const MotionConfig fluid = MotionConfig(
    profile: MotionProfile.fluid,
    speed: 1.2,
  );
  static const MotionConfig balanced = MotionConfig(
    profile: MotionProfile.balanced,
    speed: 1,
  );
  static const MotionConfig minimal = MotionConfig(
    profile: MotionProfile.minimal,
    speed: 0.6,
    transitions: false,
    ambient: false,
    gestures: false,
    island: false,
  );

  /// Perfiles solicitados por la UI: Bajo / Medio / Alto.
  /// `minimal`, `balanced` y `fluid` se conservan por compatibilidad con JSON.
  static const MotionConfig bajo = MotionConfig(
    profile: MotionProfile.bajo,
    speed: 1.35,
    transitions: true,
    ambient: false,
    gestures: true,
    island: true,
  );
  static const MotionConfig medio = MotionConfig(
    profile: MotionProfile.medio,
    speed: 1,
    transitions: true,
    ambient: true,
    gestures: true,
    island: true,
  );
  static const MotionConfig alto = MotionConfig(
    profile: MotionProfile.alto,
    speed: 0.82,
    transitions: true,
    ambient: true,
    gestures: true,
    island: true,
  );
  static const MotionConfig defaults = medio;

  /// Perfiles seleccionables desde Personalización (excluye `custom`).
  static const List<MotionConfig> presets = <MotionConfig>[bajo, medio, alto];

  factory MotionConfig.fromProfile(MotionProfile profile) => switch (profile) {
    MotionProfile.fluid => fluid,
    MotionProfile.balanced => balanced,
    MotionProfile.minimal => minimal,
    MotionProfile.bajo => bajo,
    MotionProfile.medio => medio,
    MotionProfile.alto => alto,
    MotionProfile.custom => medio,
  };

  bool enabled(MotionCategory category) => switch (category) {
    MotionCategory.transitions => transitions,
    MotionCategory.ambient => ambient,
    MotionCategory.gestures => gestures,
    MotionCategory.island => island,
  };

  /// Duración ajustada al perfil. Las categorías apagadas duran cero.
  Duration duration(
    Duration base, {
    MotionCategory category = MotionCategory.transitions,
  }) {
    if (!enabled(category)) return Duration.zero;
    final double factor = 1 / speed.clamp(0.25, 2.0);
    final int microseconds = (base.inMicroseconds * factor).round();
    return Duration(microseconds: microseconds < 0 ? 0 : microseconds);
  }

  bool get anyAnimation => transitions || ambient || gestures || island;

  /// Amplitud recomendada para micro-animaciones decorativas.
  ///
  /// Las duraciones ya se derivan de [speed]; este valor modula recorridos,
  /// escalas, brillos y número de partículas. Nunca afecta a la precisión de
  /// arrastre de la línea de tiempo.
  double get intensity => switch (profile) {
    MotionProfile.alto || MotionProfile.fluid => 1,
    MotionProfile.medio || MotionProfile.balanced => 0.65,
    MotionProfile.bajo => 0.35,
    MotionProfile.minimal => 0,
    MotionProfile.custom => ((1.6 - speed) / 1.2).clamp(0.15, 1),
  };

  MotionConfig copyWith({
    MotionProfile? profile,
    double? speed,
    bool? transitions,
    bool? ambient,
    bool? gestures,
    bool? island,
  }) {
    final bool edited =
        speed != null ||
        transitions != null ||
        ambient != null ||
        gestures != null ||
        island != null;
    return MotionConfig(
      profile: profile ?? (edited ? MotionProfile.custom : this.profile),
      speed: speed ?? this.speed,
      transitions: transitions ?? this.transitions,
      ambient: ambient ?? this.ambient,
      gestures: gestures ?? this.gestures,
      island: island ?? this.island,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'profile': profile.name,
    'speed': speed,
    'transitions': transitions,
    'ambient': ambient,
    'gestures': gestures,
    'island': island,
  };

  factory MotionConfig.fromJson(Map<Object?, Object?> json) {
    final MotionProfile stored =
        _enumByName(MotionProfile.values, json['profile']) ??
        MotionProfile.custom;
    final MotionConfig base = stored == MotionProfile.custom
        ? defaults
        : MotionConfig.fromProfile(stored);
    final double speed = _number(json['speed'], base.speed).clamp(0.4, 1.6);
    return MotionConfig(
      profile: stored,
      speed: speed,
      transitions: _bool(json['transitions'], base.transitions),
      ambient: _bool(json['ambient'], base.ambient),
      gestures: _bool(json['gestures'], base.gestures),
      island: _bool(json['island'], base.island),
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? value) {
    if (value is! String) return null;
    for (final T item in values) {
      if (item.name == value) return item;
    }
    return null;
  }

  static double _number(Object? value, double fallback) =>
      value is num && value.isFinite ? value.toDouble() : fallback;

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is MotionConfig &&
      other.profile == profile &&
      other.speed == speed &&
      other.transitions == transitions &&
      other.ambient == ambient &&
      other.gestures == gestures &&
      other.island == island;

  @override
  int get hashCode =>
      Object.hash(profile, speed, transitions, ambient, gestures, island);
}

/// Acceso cómodo desde cualquier widget del árbol de la aplicación.
extension MotionConfigX on MotionConfig {
  /// Igual a [duration] pero con la categoría [MotionCategory.transitions].
  Duration get transitionDuration =>
      duration(const Duration(milliseconds: 300));
}
