import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// Módulo 15 — a solid vertical wall for the player.
///
/// The arena had no walls at all; the dash needs one to be cancellable by a
/// wall hit, so the arena now closes its two horizontal edges with these.
/// Nothing else collides with them: wagons and the boss never move, and the
/// player resolves the push-out itself (`Player._resolveWall`).
///
/// Keep [thickness] above twice `playerDashMaxStep` so a dash frame can
/// never skip across it.
class ArenaWall extends PositionComponent {
  late final RectangleHitbox hitbox;

  ArenaWall({
    required double left,
    required double top,
    required double height,
    double thickness = 80,
  }) : super(
          position: Vector2(left, top),
          size: Vector2(thickness, height),
        );

  @override
  Future<void> onLoad() async {
    hitbox = RectangleHitbox(
      size: size.clone(),
      collisionType: CollisionType.passive,
    );
    await add(hitbox);
  }
}
