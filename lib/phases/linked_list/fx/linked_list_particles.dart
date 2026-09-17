/// The linked_list phase's particle bursts (wagon sparks, boss smoke),
/// built on the shared [SpriteBurst] / [SpriteLoop] / [ParticleSheets].
library;

import 'package:flame/components.dart';

import '../../../shared/fx/sprite_burst.dart';
import 'linked_list_fx_config.dart';

/// A single ember thrown off a trembling wagon.
Future<SpriteBurst> sparkEmberBurst(Vector2 position) async {
  final animation = await ParticleSheets.animation(
    fxSparkEmberAssetPath,
    stepTime: sparkEmberStepTime,
    loop: false,
  );
  return SpriteBurst(
    animation: animation,
    position: position,
    width: sparkEmberWidth,
    // 32x32 frames.
    aspectRatio: 1,
  );
}

/// A single wisp of smoke drifting off the boss.
Future<SpriteBurst> smokeWispBurst(
  Vector2 position, {
  double opacity = bossSmokeOpacity,
  int? priority,
}) async {
  final animation = await ParticleSheets.animation(
    fxSmokeWispAssetPath,
    // Slow: the wisp should last most of the interval between spawns.
    stepTime: bossSmokeInterval / ParticleSheets.frameCount,
    loop: false,
  );
  return SpriteBurst(
    animation: animation,
    position: position,
    // 48x64 frames — sized from the target height so the wisp reads at a
    // fixed scale against the boss's calibrated 176px.
    width: bossSmokeHeight * 48 / 64,
    aspectRatio: 48 / 64,
    opacity: opacity,
    priority: priority,
  );
}

Future<SpriteLoop> sparkEmberLoop(Vector2 position) async {
  final animation = await ParticleSheets.animation(
    fxSparkEmberAssetPath,
    stepTime: sparkEmberStepTime,
    loop: true,
  );
  return SpriteLoop(
    animation: animation,
    position: position,
    width: sparkEmberWidth,
    aspectRatio: 1,
  );
}
