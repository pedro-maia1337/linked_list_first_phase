import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';

import 'fx_config.dart';

/// Loads (once) and caches the particle spritesheets, so a burst spawned
/// every landing / every 0.19s of tremor never re-decodes the same image.
///
/// All three sheets are a single horizontal row of 6 frames; the frame size
/// is derived from the sheet's real pixel height and its known frame count,
/// never hardcoded twice.
class ParticleSheets {
  static const int frameCount = 6;

  static final Map<String, SpriteAnimation> _cache = {};

  static Future<SpriteAnimation> animation(
    String assetPath, {
    required double stepTime,
    required bool loop,
  }) async {
    final key = '$assetPath|$stepTime|$loop';
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final image = await Flame.images.load(assetPath);
    final frameHeight = image.height.toDouble();
    final frameWidth = image.width / frameCount;
    final sheet = SpriteSheet(
      image: image,
      srcSize: Vector2(frameWidth, frameHeight),
    );
    final animation = sheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
      loop: loop,
    );
    _cache[key] = animation;
    return animation;
  }
}

/// A one-shot particle animation that removes itself when the last frame
/// finishes (Módulo 12, item 4: the landing dust puff, and the individual
/// sparks thrown off a trembling wagon).
///
/// The three particle sheets are baseline-aligned — every frame's opaque
/// content bottoms out at the frame's lower edge — so [Anchor.bottomCenter]
/// puts the effect's contact point exactly on the world position it is
/// given, with no per-asset fudge offset.
class SpriteBurst extends SpriteAnimationComponent {
  SpriteBurst({
    required super.animation,
    required Vector2 position,
    required double width,
    required double aspectRatio,
    double opacity = 1,
    super.priority,
  }) : super(
          position: position,
          size: Vector2(width, width / aspectRatio),
          anchor: Anchor.bottomCenter,
          removeOnFinish: true,
        ) {
    paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    this.opacity = opacity;
  }

  /// Landing dust, anchored at the player's own foot point — the exact
  /// position `Player.position` holds (bottom-center anchor, art shifted
  /// by `playerVisualYOffset` so that point is the visible foot). Nothing
  /// here re-derives that anchor.
  static Future<SpriteBurst> dustPoof(Vector2 footPosition) async {
    final animation = await ParticleSheets.animation(
      fxDustPoofAssetPath,
      stepTime: dustPoofStepTime,
      loop: false,
    );
    return SpriteBurst(
      animation: animation,
      position: footPosition,
      width: dustPoofWidth,
      // 48x48 frames.
      aspectRatio: 1,
    );
  }
}

/// A continuously looping particle animation, used for the ember loop that
/// runs for as long as a wagon stays in `tremor`. Removed explicitly by
/// whoever started it, never on its own.
class SpriteLoop extends SpriteAnimationComponent {
  SpriteLoop({
    required super.animation,
    required Vector2 position,
    required double width,
    required double aspectRatio,
    double opacity = 1,
    super.priority,
  }) : super(
          position: position,
          size: Vector2(width, width / aspectRatio),
          anchor: Anchor.bottomCenter,
        ) {
    paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    this.opacity = opacity;
  }
}
