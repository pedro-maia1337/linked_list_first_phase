import 'package:flame/game.dart';

import 'phase_definition.dart';

/// The game a phase runs. Every phase's game extends this, so the app (and,
/// later, the hub) can start any phase and ask it the same questions
/// without knowing which structure it teaches.
///
/// Today each phase is its own [FlameGame]; the shared pieces (player, HUD,
/// fx, debug) are components the phase adds to itself.
abstract class PhaseGame extends FlameGame {
  /// The declaration this game was created from.
  PhaseDefinition get definition;

  /// Where the player (re)spawns, in world coordinates. Valid once the game
  /// has loaded.
  Vector2 get spawnPoint;

  /// The phase's victory condition — for a boss phase, the boss is defeated.
  bool get isCompleted;
}
