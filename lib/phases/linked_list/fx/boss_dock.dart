import 'dart:ui' show FilterQuality;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../boss/vagoneiro_boss.dart';
import 'ambient_light.dart';
import 'linked_list_fx_config.dart';

/// Módulo 14, Frente 1 — the piece of scenery the boss actually stands on.
///
/// ## Why it exists
///
/// Módulo 13 put the wagons and the chains into the scene (contact shadow,
/// shared cool wash, lantern bounce) but never gave the boss a surface of
/// his own: he was drawn straight onto the painted rock of the backdrop,
/// with no prop under him and no shadow, which is the same "sticker pasted
/// on the cave" reading Módulo 13 was written to remove. This is the
/// missing prop, treated exactly like the wagons: cool-tinted, with a
/// `contact-shadow.png` on its deck.
///
/// ## Positioning — by the deck's top surface, not by the canvas
///
/// The same principle `ChainAnchor` uses (place by the chain tip, not by
/// the plate): the only line in this art that has to line up with anything
/// is the deck's walking surface, measured at native row
/// [bossDockDeckTopNativeY]. It is put exactly on the boss's **visible**
/// foot line — [VagoneiroBoss.visibleFootY], i.e. the bottom of the real
/// opaque content of the current sheet, not the frame's transparent edge
/// (design doc section 2.3: "ancoragem do pé = base do bounding box de
/// conteúdo real do frame atual, não um offset fixo herdado de versões
/// antigas do asset").
///
/// That is what makes this a purely additive change. The boss's
/// `position`, `size`, [bossDisplayScale] and collider are all read and
/// never written: the dock moves to meet the boss, never the other way
/// round.
///
/// ## Scope
///
/// A [SpriteComponent] and nothing else — no hitbox, never consulted by
/// gameplay, and it neither reads nor writes slots, `next`/`prev` or the
/// linked list. The boss does not walk, so there is nothing here for
/// physics to do.
class BossDock extends SpriteComponent {
  BossDock._({
    required Vector2 position,
    required Vector2 size,
    required int priority,
  }) : super(
          position: position,
          size: size,
          priority: priority,
          // Centre-anchored deliberately: `flipHorizontallyAroundCenter`
          // only leaves `position` alone when the anchor is already the
          // centre (it compensates by shifting `transform.x` otherwise),
          // and this prop is mirrored. With the centre anchor,
          // `position.x ± size.x / 2` stays the component's real box after
          // the flip, which is what the registration below assumes and
          // what any bounds check can rely on.
          anchor: Anchor.center,
        ) {
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    // Módulo 13, item 2: the same 11% cool wash the wagons, the chains and
    // the boss himself carry. Without it this prop would arrive as the one
    // untinted thing in the frame — reintroducing, on the new asset, the
    // exact problem it is here to fix.
    applyAmbientCoolTint(this);
  }

  /// Loads the dock and places it so its deck surface lands under [boss].
  static Future<BossDock> under(
    VagoneiroBoss boss, {
    int priority = fxPriorityBossDock,
  }) async {
    final image = await Flame.images.load(bossDockAssetPath);

    final size = Vector2(
      image.width * bossDockRenderScale,
      image.height * bossDockRenderScale,
    );

    // Where the deck's centre has to land in world space.
    final deckCentreX = boss.position.x + bossDockDeckCentreOffsetX;

    // Horizontal registration. Unflipped, the deck centre sits
    // `bossDockDeckCentreNativeX - canvasWidth/2` to the right of the
    // canvas centre; mirroring the prop (see [bossDockFlipHorizontally])
    // reflects that offset about the same centre, so the sign flips.
    final deckCentreOffsetFromCanvasCentre =
        bossDockDeckCentreNativeX - bossDockCanvasWidth / 2;
    final effectiveOffsetNative = bossDockFlipHorizontally
        ? -deckCentreOffsetFromCanvasCentre
        : deckCentreOffsetFromCanvasCentre;

    final componentCentreX =
        deckCentreX - effectiveOffsetNative * bossDockRenderScale;

    // Vertical registration: the deck's top surface must land on the
    // boss's visible foot line, so the component's centre sits half its
    // own height below the canvas point that row maps to.
    final componentCentreY = boss.visibleFootY -
        bossDockDeckTopNativeY * bossDockRenderScale +
        size.y / 2;

    final dock = BossDock._(
      position: Vector2(componentCentreX, componentCentreY),
      size: size,
      priority: priority,
    );
    dock.sprite = Sprite(image);
    if (bossDockFlipHorizontally) {
      // Around the centre, not around the anchor: the registration above
      // is expressed in terms of the component's own box, so the box
      // itself must stay put.
      dock.flipHorizontallyAroundCenter();
    }
    return dock;
  }

  /// World y of the deck's walking surface — i.e. the line the boss's feet
  /// rest on and the line his contact shadow belongs on.
  double get deckTopY =>
      position.y - size.y / 2 + bossDockDeckTopNativeY * bossDockRenderScale;
}
