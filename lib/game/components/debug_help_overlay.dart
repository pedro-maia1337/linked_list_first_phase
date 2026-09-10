import 'dart:ui' show Canvas;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart' show Color, FontWeight, TextStyle;

/// Plain-text HUD listing every debug shortcut already wired up across
/// Módulos 0-6 (see docs/boss-vagoneiro-design.md, section 11 — critérios
/// de aceite), so the acceptance criteria can be validated manually
/// without touching code. No new gameplay logic — this component only
/// renders a static legend; the actual key handling stays in
/// [VagoneiroArenaGame.onKeyEvent] as before.
///
/// Added to `camera.viewport` (not `world`) so it stays pinned to the
/// screen regardless of world/camera position.
class DebugHelpOverlay extends PositionComponent {
  static const List<String> _lines = [
    'DEBUG — Vagoneiro (Módulos 0-15)',
    'J          atacar (só fere o boss na janela exposed)',
    'K          forçar o próximo ataque (RemoverNo / InserirNo)',
    'P          -3 HP no boss (pular para a próxima fase)',
    '0-7        occupySlot(index)',
    'Shift+0-7  clearSlot(index)',
    'Ctrl+0-7   RemoverNo (tremor -> falling -> clearSlot)',
    'H          boss.debugPlayHit()',
    'X          boss.debugPlayExposed()',
    'N          player.debugPlayWalkNorth() (preview only)',
    'S          player.debugPlayWalkSouth() (preview only)',
    'R          reset player position (onPlayerDeath)',
    'Espaço/W/↑ pular (2x — double jump, Mudança 3)',
    'M          toggle slot/boss position markers',
    'L          toggle fixed-height reference rulers (player/vagão/boss)',
  ];

  late final TextPaint _textPaint;

  DebugHelpOverlay({required Vector2 position})
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
    for (var i = 0; i < _lines.length; i++) {
      _textPaint.render(canvas, _lines[i], Vector2(0, i * 20));
    }
  }
}
