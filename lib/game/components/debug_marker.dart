import 'dart:ui';

import 'package:flame/components.dart';

/// Small filled-circle marker for visually validating a world coordinate
/// against slots_config.json (isolates "position is wrong" from
/// "scale/collider is wrong" — see docs/boss-vagoneiro-design.md, section
/// 9, and skill/flutter_flame_gamedev_skill.md config validation rules).
class DebugMarker extends PositionComponent {
  final Color color;
  final double radius;

  DebugMarker({
    required Vector2 position,
    required this.color,
    this.radius = 6,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
