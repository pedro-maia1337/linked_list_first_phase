import 'dart:ui' show Canvas;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show Color, FontWeight, TextStyle;

/// Plain-text HUD listing the current phase's debug shortcuts (the lines
/// are supplied by the phase — see `linkedListDebugLegend`) across
/// Módulos 0-6 (see docs/boss-vagoneiro-design.md, section 11 — critérios
/// de aceite), so the acceptance criteria can be validated manually
/// without touching code. No new gameplay logic — this component only
/// renders a static legend; the actual key handling stays in
/// [VagoneiroArenaGame.onKeyEvent] as before.
///
/// Added to `camera.viewport` (not `world`) so it stays pinned to the
/// screen regardless of world/camera position.
class DebugHelpOverlay extends PositionComponent {
  /// The legend, one entry per line — supplied by the phase, since each
  /// phase wires its own debug keys.
  final List<String> lines;

  late final TextPaint _textPaint;

  DebugHelpOverlay({required Vector2 position, required this.lines})
      : super(position: position, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    _textPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFF00FF66),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < lines.length; i++) {
      _textPaint.render(canvas, lines[i], Vector2(0, i * 20));
    }
  }
}
