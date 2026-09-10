import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'ambient_light.dart';
import 'fx_config.dart';

/// Warm backlight/rim halo that makes the boss read as the scene's focal
/// point (Módulo 12, item 3).
///
/// ## How it works
///
/// Every frame it re-reads the boss's *current* animation frame
/// ([SpriteAnimationComponent.animationTicker]) and redraws that exact
/// silhouette a handful of times at small radial offsets, tinted
/// [bossRimLightColor] and blended additively. Because the boss's own
/// sprite is then drawn on top at priority 0 — this component lives in the
/// world at [fxPriorityBossBackdropFx] (-1) — only the few pixels of the
/// offset copies that stick out past the real silhouette survive, which is
/// exactly the rim.
///
/// Consequences that matter for this module's constraints:
///  * it reads the boss's `position`, `size`, `anchor` and `scale` and
///    never writes any of them — the calibrated 176px height
///    (`bossDisplayScale`) is the only scale involved;
///  * it reads the animation ticker but never sets `animation`, so the
///    boss's state machine (`idle`/`hit`/`exposed`/`recovering`) is
///    untouched and the rim automatically follows whichever state is
///    playing;
///  * it renders as a sibling, not a child, because Flame always draws a
///    component's children *after* its own `render()` — a child could only
///    ever be an overlay, never a backlight.
///
/// ## Módulo 13 fix — it was an outline, not a rim
///
/// The offsets used to be spread evenly around the whole compass, tapering
/// but never reaching zero, which traced a continuous warm stroke around
/// the entire silhouette. That is the "contorno dourado" this module was
/// asked to remove: a rim light is not a stroke, it only exists where the
/// key light actually grazes the form, and the side of a character turned
/// away from every light source has no rim at all.
///
/// Now the offsets are generated around [bossRimLightDirection] — taken
/// from the two lantern anchors nearest the boss in `slots_config.json`,
/// i.e. from the scene rather than from the artist's intuition — and
/// clipped to [bossRimLightArcHalfWidth] either side of it. Strength falls
/// off with the cosine of the angle from that direction, so the rim is
/// brightest where the light hits square on, fades along the flanks, and
/// stops dead outside the arc. The underside of the boss, facing the dark
/// backdrop, is left completely unlit.
///
/// The blend mode was already correct and is unchanged: [BlendMode.plus],
/// i.e. additive — the halo only ever adds light, never paints a colour
/// over the backdrop.
class BossRimLight extends Component {
  final SpriteAnimationComponent boss;

  /// Unit direction, offset distance and alpha weight for each redraw of
  /// the silhouette, built once from [bossRimLightDirection] and
  /// [bossRimLightArcHalfWidth].
  ///
  /// Samples are taken every 15° across the lit arc only, each carrying
  /// `cos²(angle from the key direction)` as its weight. That weight does
  /// double duty:
  ///  * it scales the redraw's **offset distance**, so a redraw pointing
  ///    along the flank barely displaces and therefore barely shows — the
  ///    rim tapers instead of running full-thickness around the outline;
  ///  * it scales the redraw's **alpha**, after the whole set is normalised
  ///    to sum to 1, so the additive copies add up to [bossRimLightOpacity]
  ///    at the brightest point rather than saturating to white.
  static final List<(double, double, double)> _offsets = _buildOffsets();

  /// The finished offset table, for the regression test that guards this
  /// from drifting back into an outline.
  @visibleForTesting
  static List<(double, double, double)> get offsets => _offsets;

  /// Each entry is `(dx, dy, weight)` where `(dx, dy)` is already scaled by
  /// the weight and by [bossRimLightWidth] — i.e. a ready-to-use pixel
  /// offset — and `weight` is the normalised alpha share.
  static List<(double, double, double)> _buildOffsets() {
    final key = bossRimLightDirection;
    final keyAngle = math.atan2(key.y, key.x);
    const step = math.pi / 12; // 15°
    final raw = <(double, double, double)>[];
    var total = 0.0;
    for (var delta = -bossRimLightArcHalfWidth;
        delta <= bossRimLightArcHalfWidth + 1e-9;
        delta += step) {
      final cosDelta = math.cos(delta);
      if (cosDelta <= 0) {
        continue;
      }
      final weight = cosDelta * cosDelta;
      final angle = keyAngle + delta;
      raw.add((math.cos(angle), math.sin(angle), weight));
      total += weight;
    }
    if (total == 0) {
      return const [];
    }
    return [
      for (final (dx, dy, weight) in raw)
        (
          dx * weight * bossRimLightWidth,
          dy * weight * bossRimLightWidth,
          weight / total,
        ),
    ];
  }

  final Paint _paint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false
    ..colorFilter = const ColorFilter.mode(
      bossRimLightColor,
      // `srcIn` keeps the frame's alpha (the silhouette) and replaces every
      // colour with the rim tone.
      BlendMode.srcIn,
    );

  double _elapsed = 0;
  double _pulse = 1;

  BossRimLight({required this.boss})
      : super(priority: fxPriorityBossBackdropFx);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _pulse = 1 +
        bossRimLightPulseAmplitude * math.sin(_elapsed * bossRimLightPulseSpeed);
  }

  @override
  void render(Canvas canvas) {
    final sprite = boss.animationTicker?.getSprite();
    if (sprite == null) {
      return;
    }

    // The boss's world-space draw rect, reconstructed from its own
    // position/size/anchor — read-only.
    final size = boss.size;
    final topLeft = Vector2(
      boss.position.x - boss.anchor.x * size.x,
      boss.position.y - boss.anchor.y * size.y,
    );

    canvas.save();
    // `VagoneiroBoss` calls `flipHorizontally()` when `facing != 'left'`,
    // which negates `scale.x` about the component's own origin (its
    // bottom-center position). Mirror the halo the same way so the rim
    // stays glued to the silhouette if that config value ever changes.
    if (boss.scale.x < 0) {
      canvas
        ..translate(boss.position.x, 0)
        ..scale(-1, 1)
        ..translate(-boss.position.x, 0);
    }

    for (final (dx, dy, weight) in _offsets) {
      final alpha = (bossRimLightOpacity * weight * _pulse).clamp(0.0, 1.0);
      _paint.color = Color.fromRGBO(0, 0, 0, alpha);
      sprite.render(
        canvas,
        position: Vector2(topLeft.x + dx, topLeft.y + dy),
        size: size,
        overridePaint: _paint,
      );
    }

    canvas.restore();
  }
}
