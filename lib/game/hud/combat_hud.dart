import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart' show FontWeight, TextStyle;

import '../boss/boss_combat.dart';

/// Módulo 14 — the fight's read-outs, pinned to the screen.
///
/// Three things the acceptance criteria ask for, in one component:
///  * the boss's HP and current phase, so the 100-66 / 65-33 / 32-0 bands
///    are visible rather than implied;
///  * the player's HP, so "the boss now deals real damage" is legible;
///  * the **"operação em execução"** ticker — the list operation the fight
///    is running right now, written the way the player is meant to learn
///    it (`occupySlot(3)`, `insertAtHead(novoVagao)`,
///    `slot[7].next = null`). This is the teaching half of the HUD: every
///    attack is a data-structure operation, and the HUD is where that is
///    said out loud.
///
/// Plus the transient caption used for lines like "Sem `next`, sem
/// removido." — the message a primitive puts up when it lands.
///
/// It is a pure view: every value comes from a supplier callback, so the
/// HUD reads the fight and never drives it.
class CombatHud extends PositionComponent {
  final int Function() bossHp;
  final BossPhase Function() bossPhase;
  final bool Function() bossExposed;
  final int Function() playerHp;

  /// Fade time of a caption, in and out, around its own hold time.
  static const double captionFade = 0.35;

  late final TextPaint _labelPaint;
  late final TextPaint _opPaint;
  late final TextPaint _captionPaint;

  Vector2 _screen = Vector2(1280, 720);

  String _operation = '';
  double _operationAge = 0;

  String _caption = '';
  double _captionRemaining = 0;
  double _captionTotal = 0;

  /// What the ticker and the caption are currently showing. Exposed so the
  /// tests can assert that a list operation actually reached the HUD,
  /// rather than trusting that the wiring is still connected.
  @visibleForTesting
  String get currentOperation => _operation;

  /// The most recent caption text, whether or not it has faded out yet.
  /// Kept separate from "is a caption on screen right now" (which is what
  /// [captionVisible] answers) so a test can assert *which* line was shown
  /// without having to catch it inside its 1.5s window.
  @visibleForTesting
  String get lastCaption => _caption;

  @visibleForTesting
  bool get captionVisible => _captionRemaining > 0;

  CombatHud({
    required this.bossHp,
    required this.bossPhase,
    required this.bossExposed,
    required this.playerHp,
  }) : super(position: Vector2.zero(), anchor: Anchor.topLeft);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _screen = size.clone();
  }

  @override
  Future<void> onLoad() async {
    _labelPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFF3E7D3),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
    _opPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFF9BE8FF),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
    _captionPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFFFD24A),
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Shows [operation] in the ticker. Called by the boss for every real
  /// `occupySlot`/`clearSlot`/pointer write, so the HUD cannot drift out of
  /// sync with what the list actually did.
  void showOperation(String operation) {
    _operation = operation;
    _operationAge = 0;
  }

  /// Shows a transient caption (Módulo 14, section 4.1 ①: the "Sem `next`,
  /// sem acesso." line, "fade in/out 1.5s").
  void showCaption(String text, {double duration = 1.5}) {
    _caption = text;
    _captionRemaining = duration;
    _captionTotal = duration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _operationAge += dt;
    if (_captionRemaining > 0) {
      _captionRemaining = math.max(0, _captionRemaining - dt);
    }
  }

  @override
  void render(Canvas canvas) {
    _renderBossBar(canvas);
    _renderPlayerHp(canvas);
    _renderOperation(canvas);
    _renderCaption(canvas);
  }

  void _renderBossBar(Canvas canvas) {
    const barWidth = 420.0;
    const barHeight = 16.0;
    final left = (_screen.x - barWidth) / 2;
    const top = 22.0;

    final fraction = (bossHp() / bossMaxHp).clamp(0.0, 1.0);

    canvas
      ..drawRect(
        Rect.fromLTWH(left - 2, top - 2, barWidth + 4, barHeight + 4),
        Paint()..color = const Color(0xCC120E1A),
      )
      ..drawRect(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        Paint()..color = const Color(0xFF2A2233),
      )
      ..drawRect(
        Rect.fromLTWH(left, top, barWidth * fraction, barHeight),
        Paint()
          ..color = bossExposed()
              ? const Color(0xFFFFD24A)
              : const Color(0xFFC0392B),
      );

    // The two phase thresholds, drawn on the bar itself so the bands the
    // design doc specifies are something the player can see coming.
    for (final threshold in [bossPhase1LowerBound, bossPhase2LowerBound]) {
      final x = left + barWidth * threshold;
      canvas.drawRect(
        Rect.fromLTWH(x - 1, top, 2, barHeight),
        Paint()..color = const Color(0xFF120E1A),
      );
    }

    final status = bossExposed() ? '  ·  EXPOSTO' : '  ·  invulnerável';
    _labelPaint.render(
      canvas,
      'O VAGONEIRO   ${bossHp()}/$bossMaxHp   ${bossPhase().label}$status',
      Vector2(left, top + barHeight + 6),
    );
  }

  void _renderPlayerHp(Canvas canvas) {
    const pipWidth = 22.0;
    const pipHeight = 12.0;
    const gap = 5.0;
    final totalWidth = playerMaxHp * pipWidth + (playerMaxHp - 1) * gap;
    final left = _screen.x - totalWidth - 24;
    const top = 24.0;

    for (var i = 0; i < playerMaxHp; i++) {
      final x = left + i * (pipWidth + gap);
      canvas.drawRect(
        Rect.fromLTWH(x, top, pipWidth, pipHeight),
        Paint()
          ..color = i < playerHp()
              ? const Color(0xFF00FF66)
              : const Color(0xFF3A2A38),
      );
    }
    _labelPaint.render(
      canvas,
      'MAQUINISTA',
      Vector2(left, top + pipHeight + 6),
    );
  }

  void _renderOperation(Canvas canvas) {
    if (_operation.isEmpty) {
      return;
    }
    // Fades out after a few seconds so a stale operation does not read as
    // the current one.
    final alpha = (1 - (_operationAge - 2.5) / 1.5).clamp(0.0, 1.0);
    if (alpha <= 0) {
      return;
    }
    TextPaint(
      style: _opPaint.style.copyWith(
        color: _opPaint.style.color!.withValues(alpha: alpha),
      ),
    ).render(
      canvas,
      '> $_operation',
      Vector2(_screen.x / 2, 70),
      anchor: Anchor.topCenter,
    );
  }

  void _renderCaption(Canvas canvas) {
    if (_captionRemaining <= 0) {
      return;
    }
    final elapsed = _captionTotal - _captionRemaining;
    final alpha = math
        .min(elapsed / captionFade, _captionRemaining / captionFade)
        .clamp(0.0, 1.0);

    TextPaint(
      style: _captionPaint.style.copyWith(
        color: _captionPaint.style.color!.withValues(alpha: alpha),
      ),
    ).render(
      canvas,
      _caption,
      Vector2(_screen.x / 2, _screen.y * 0.30),
      anchor: Anchor.topCenter,
    );
  }
}
