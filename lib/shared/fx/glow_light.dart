import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'fx_config.dart';

/// An additively-blended light pool built from `effects/glow-warm-soft.png`
/// (Módulo 12, item 2).
///
/// Used twice with different tuning:
///  * over every `decorativeAnchors` lantern anchor from
///    `slots_config.json` — large, dim, barely flickering;
///  * over the boss's eyes — small, hotter [tint], clearly pulsing in both
///    opacity and scale.
///
/// Purely decorative: it has no hitbox, is never consulted by gameplay, and
/// its position is either read straight from the config or expressed in the
/// boss's own local space (so it inherits the boss's already-calibrated
/// 176px scale instead of introducing a second source of truth).
class GlowLight extends SpriteComponent {
  /// Opacity at the middle of the pulse.
  final double baseOpacity;

  /// Peak deviation from [baseOpacity] and from scale 1.0.
  final double pulseOpacityAmplitude;
  final double pulseScaleAmplitude;

  /// Radians per second of the pulse's sine.
  final double pulseSpeed;

  /// Starting phase, so several glows sharing the same speed don't beat in
  /// lockstep.
  final double phase;

  double _elapsed = 0;

  GlowLight({
    required Vector2 position,
    required double diameter,
    required this.baseOpacity,
    this.pulseOpacityAmplitude = 0,
    this.pulseScaleAmplitude = 0,
    this.pulseSpeed = 0,
    this.phase = 0,
    Color? tint,
    super.priority,
  }) : super(
          position: position,
          size: Vector2.all(diameter),
          anchor: Anchor.center,
        ) {
    paint = Paint()
      // Additive: the glow only ever *adds* light to whatever is behind it,
      // which is what makes it read as emitted light rather than a decal.
      ..blendMode = BlendMode.plus
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    if (tint != null) {
      // `modulate` multiplies the sprite by the tint, pushing the stock
      // amber towards a hotter, more saturated ember without needing a
      // second art asset.
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    opacity = baseOpacity;
  }

  /// Builds a glow from the shared image cache.
  static Future<GlowLight> load({
    required Vector2 position,
    required double diameter,
    required double baseOpacity,
    double pulseOpacityAmplitude = 0,
    double pulseScaleAmplitude = 0,
    double pulseSpeed = 0,
    double phase = 0,
    Color? tint,
    int? priority,
  }) async {
    final glow = GlowLight(
      position: position,
      diameter: diameter,
      baseOpacity: baseOpacity,
      pulseOpacityAmplitude: pulseOpacityAmplitude,
      pulseScaleAmplitude: pulseScaleAmplitude,
      pulseSpeed: pulseSpeed,
      phase: phase,
      tint: tint,
      priority: priority,
    );
    glow.sprite = Sprite(await Flame.images.load(fxGlowWarmSoftAssetPath));
    return glow;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (pulseSpeed <= 0 ||
        (pulseOpacityAmplitude == 0 && pulseScaleAmplitude == 0)) {
      return;
    }
    _elapsed += dt;
    final wave = math.sin(_elapsed * pulseSpeed + phase);
    if (pulseOpacityAmplitude != 0) {
      opacity =
          (baseOpacity + pulseOpacityAmplitude * wave).clamp(0.0, 1.0);
    }
    if (pulseScaleAmplitude != 0) {
      scale = Vector2.all(1 + pulseScaleAmplitude * wave);
    }
  }
}
