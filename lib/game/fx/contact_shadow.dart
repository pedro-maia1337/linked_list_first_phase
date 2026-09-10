import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'fx_config.dart';

/// A soft contact shadow drawn from `effects/contact-shadow.png` (Módulo
/// 12, item 2).
///
/// `contact-shadow.png` is a 96x32 frame holding a dark ellipse centred in
/// the frame, so with [Anchor.center] at the owner's local `(0, 0)` the
/// ellipse straddles the owner's own ground point: its upper half is drawn
/// over whatever the entity is standing on, its lower half just below.
/// That is what produces "sem gap visual entre a base do personagem/vagão e
/// a sombra" — there is no offset to get wrong, because the shadow's centre
/// *is* the contact point.
///
/// This relies on both owners already anchoring at their real ground point:
///  * [Player] is `Anchor.bottomCenter` at the recalculated foot position
///    (`playerVisualYOffset` shifts the *art* so the lowest opaque pixel
///    sits at local y = 0 — the same y this shadow centres on);
///  * [Vagao] is `Anchor.bottomCenter` at its slot's ground coordinate.
///
/// Neither anchoring is modified by this module; the shadow simply reuses
/// it.
///
/// Always added with a negative `priority` so it renders before its
/// owner's own visual child — Flame draws a component's own `render()`
/// first and then its children in priority order, so a shadow that is a
/// *sibling* of the sprite (not a child of it) and sorts first ends up
/// underneath the art without being affected by the art's scale, spawn
/// tween or squash-and-stretch.
class ContactShadow extends SpriteComponent {
  ContactShadow({
    required double width,
    required double baseOpacity,
    double yOffset = 0,
    super.priority = -1,
  }) : super(
          // Native frame is 96x32 — keep that aspect ratio so the ellipse
          // never distorts.
          size: Vector2(width, width * 32 / 96),
          // Normally zero: the owner's anchor already *is* the contact
          // point. A non-zero [yOffset] is for an owner whose art has
          // transparent padding below its anchor (see
          // `vagaoContactShadowYOffset`), so the shadow lands on the
          // *visible* base instead of on the padding.
          position: Vector2(0, yOffset),
          anchor: Anchor.center,
        ) {
    paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    opacity = baseOpacity;
  }

  static Future<ContactShadow> load({
    required double width,
    required double baseOpacity,
    double yOffset = 0,
    int priority = -1,
  }) async {
    final shadow = ContactShadow(
      width: width,
      baseOpacity: baseOpacity,
      yOffset: yOffset,
      priority: priority,
    );
    shadow.sprite = Sprite(await Flame.images.load(fxContactShadowAssetPath));
    return shadow;
  }
}
