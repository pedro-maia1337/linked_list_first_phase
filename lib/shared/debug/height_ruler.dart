import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// Fixed-height reference ruler for visually validating entity scale
/// (see docs/boss-vagoneiro-design.md section 2.1: the intended scale
/// harmony between player/wagon/boss). Draws a vertical line of a single
/// *fixed* [heightPx] world-pixel length next to a moving ground anchor
/// (the entity's own bottom-center world position), with tick marks at
/// both ends and a label. Because all rulers created for a given debug
/// session share the same [heightPx] (the player's own measured reference
/// height — see [VagoneiroArenaGame._toggleHeightRulers]), holding them up
/// next to the player, a wagon and the boss at once turns the abstract
/// scale ratios from section 2.1 into a single, directly comparable
/// vertical line: the boss's art should clearly overshoot it, the wagon's
/// should clearly fall short of it.
///
/// Purely a debug/QA aid — toggled by the `L` key in
/// [VagoneiroArenaGame], no gameplay effect, doesn't touch any other
/// entity's state.
class HeightRuler extends PositionComponent {
  final Vector2 Function() groundAnchor;
  final double heightPx;
  final Color color;
  final String label;

  /// Horizontal distance (world px) from the entity's ground anchor to
  /// where the ruler is drawn, so it doesn't overlap the entity's own art.
  final double xOffset;

  late final TextPaint _textPaint;

  HeightRuler({
    required this.groundAnchor,
    required this.heightPx,
    required this.color,
    required this.label,
    this.xOffset = 50,
  }) : super(anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    _textPaint = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Re-reads the anchor every frame so the ruler tracks a moving entity
    // (the player) as well as static ones (a wagon, the boss).
    final ground = groundAnchor();
    position = Vector2(ground.x + xOffset, ground.y);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    canvas.drawLine(Offset.zero, Offset(0, -heightPx), paint);
    canvas.drawLine(const Offset(-6, 0), const Offset(6, 0), paint);
    canvas.drawLine(Offset(-6, -heightPx), Offset(6, -heightPx), paint);
    _textPaint.render(
      canvas,
      '$label (${heightPx.round()}px)',
      Vector2(9, -heightPx - 14),
    );
  }
}
