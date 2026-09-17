/// Módulo 14/15 — the telegraph ring over a slot (linked_list phase).
///
/// Decoration over the existing linear track: no hitbox, never reads or
/// writes a `Slot`, takes no part in collision.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../../shared/fx/fx_config.dart';
import 'linked_list_fx_config.dart';

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
