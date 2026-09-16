import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'player_animations.dart';

/// Módulo 15, Frente 4 — the sword's damage area.
///
/// Not the player's collider: a separate child entity with its own
/// [RectangleHitbox], `inactive` except on the peak frames of a swing, so
/// Flame's collision engine only ever reports contacts that happen while
/// the blade is actually out. The rectangle spans from the player's centre
/// to [reach] in the facing direction, [hitboxHeight] up from the feet.
///
/// Each target is reported at most once per swing ([setLive]'s `swingId`),
/// so a hitbox that stays live for two frames cannot hit twice.
class SwordHitbox extends PositionComponent with CollisionCallbacks {
  final double reach;
  final double hitboxHeight;
  final void Function(PositionComponent target) onContact;

  late final RectangleHitbox hitbox;

  bool _live = false;
  bool get isLive => _live;

  int _swingId = -1;
  final Set<PositionComponent> _hitThisSwing = {};

  SwordHitbox({
    required this.reach,
    required double height,
    required this.onContact,
  }) : hitboxHeight = height;

  @override
  Future<void> onLoad() async {
    hitbox = RectangleHitbox(
      size: Vector2(reach, hitboxHeight),
      anchor: Anchor.bottomLeft,
      collisionType: CollisionType.inactive,
    );
    await add(hitbox);
  }

  /// Called every frame by the player with the attack controller's state.
  void setLive({
    required bool live,
    required int swingId,
    required PlayerFacing facing,
  }) {
    if (!isLoaded) {
      return;
    }
    if (swingId != _swingId) {
      _swingId = swingId;
      _hitThisSwing.clear();
    }
    hitbox.anchor =
        facing == PlayerFacing.west ? Anchor.bottomRight : Anchor.bottomLeft;
    if (live == _live) {
      return;
    }
    _live = live;
    hitbox.collisionType =
        live ? CollisionType.active : CollisionType.inactive;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (!_live || other == parent || !_hitThisSwing.add(other)) {
      return;
    }
    onContact(other);
  }
}
