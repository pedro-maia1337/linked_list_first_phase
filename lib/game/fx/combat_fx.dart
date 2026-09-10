/// Módulo 14/15 — the drawn half of the fight.
///
/// Everything in this file is decoration over the existing linear track:
/// no component here has a hitbox, reads or writes a `Slot`, or takes part
/// in collision.
///
/// **Módulo 15, Mudança 1** removed three quarters of it. `ChainTelegraph`
/// (Corrente Restritiva), `CycleArc` and `CycleMarker` (Ciclo Corrompido)
/// are gone along with the attacks that drew them; what is left is the
/// two pieces the surviving roster needs — [SlotHighlight], now the
/// telegraph for *both* primitives, and [CombatFlash].
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'fx_config.dart';

/// A pulsing ring over one slot, for [remaining] seconds.
///
/// Módulo 15: this is the telegraph for **both** surviving primitives —
/// the boss's wind-up before `RemoverNo` takes a node out, and before
/// `InserirNo` shoves a new one in at slot 0. Only [color] distinguishes
/// them (see `removerNoTelegraphColor` / `inserirNoTelegraphColor`), which
/// is deliberate: one telegraph vocabulary is easier to read mid-fight
/// than two unrelated overlays, and it is the reason the roster reduction
/// left the drawn half *smaller* rather than merely different.
///
/// Removes itself when [remaining] runs out.
class SlotHighlight extends PositionComponent {
  double remaining;
  final Color color;
  final double diameter;

  double _pulse = 0;

  SlotHighlight({
    required Vector2 position,
    required this.remaining,
    this.color = removerNoTelegraphColor,
    this.diameter = slotTelegraphDiameter,
    super.priority = fxPriorityCombatOverlay,
  }) : super(
          position: position,
          size: Vector2.all(diameter),
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 7;
    remaining -= dt;
    if (remaining <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final radius = diameter / 2;
    final centre = Offset(radius, radius);
    final alpha = 0.45 + 0.35 * (0.5 + 0.5 * math.sin(_pulse));
    canvas
      ..drawCircle(
        centre,
        radius * (0.9 + 0.06 * math.sin(_pulse)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color.withValues(alpha: alpha),
      )
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.18)
          ..blendMode = BlendMode.plus,
      );
  }
}

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
