/// A generic combat feedback ring, shared by every phase.
///
/// Split from the Módulo 14/15 `combat_fx.dart`; the linked_list phase's
/// slot telegraph lives in `phases/linked_list/fx/slot_highlight.dart`.
library;

import 'dart:ui';

import 'package:flame/components.dart';

import 'fx_config.dart';

/// A one-shot expanding ring: the "clang vazio" of a miss, or the spark of
/// a hit that landed. Which one it is, is only the colour and the size —
/// the *reason* is decided by the combat resolver and shown in the HUD.
class CombatFlash extends PositionComponent {
  final Color color;
  final double diameter;
  final double duration;

  double _elapsed = 0;

  CombatFlash({
    required Vector2 position,
    required this.color,
    required this.diameter,
    required this.duration,
    super.priority = fxPriorityCombatOverlay,
  }) : super(
          position: position,
          size: Vector2.all(diameter),
          anchor: Anchor.center,
        );

  factory CombatFlash.miss(Vector2 position) => CombatFlash(
        position: position,
        color: combatMissFlashColor,
        diameter: combatMissFlashDiameter,
        duration: combatMissFlashDuration,
      );

  factory CombatFlash.hit(Vector2 position) => CombatFlash(
        position: position,
        color: combatHitFlashColor,
        diameter: combatHitFlashDiameter,
        duration: combatHitFlashDuration,
      );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / duration).clamp(0.0, 1.0);
    final radius = diameter / 2 * (0.35 + 0.65 * progress);
    canvas.drawCircle(
      Offset(diameter / 2, diameter / 2),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * (1 - progress) + 1
        ..color = color.withValues(alpha: 1 - progress),
    );
  }
}
