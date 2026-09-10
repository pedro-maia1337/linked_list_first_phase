import 'dart:ui' show FilterQuality;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../fx/ambient_light.dart';
import '../fx/fx_config.dart';

/// The two mirrored wall-fitting assets (Módulo 13, tarefa 6): a bolted
/// plate embedded in the rock with a few chain links trailing out of it.
const String chainAnchorLeftAssetPath =
    'wagons/spritesheets/sprite_anchor_left.png';
const String chainAnchorRightAssetPath =
    'wagons/spritesheets/sprite_anchor_right.png';

/// Which way an anchor faces: [left] has its plate on the left with the
/// chain running out to the right, [right] is the mirror image.
enum ChainAnchorSide {
  left(chainAnchorLeftAssetPath, chainAnchorTipXLeft),
  right(chainAnchorRightAssetPath, chainAnchorTipXRight);

  /// Art file for this side.
  final String assetPath;

  /// X of the art's **free chain end**, in native px — see
  /// [chainAnchorTipXLeft] / [chainAnchorTipXRight].
  final double tipXNative;

  const ChainAnchorSide(this.assetPath, this.tipXNative);

  static ChainAnchorSide fromConfig(String value) =>
      value == 'right' ? ChainAnchorSide.right : ChainAnchorSide.left;
}

/// A purely decorative chain anchor bolted into the cave wall, closing off
/// one end of the track (Módulo 13, tarefa 6).
///
/// ## Why it exists
///
/// The track's chain decoration ran wagon-to-wagon and boss-to-wagon only,
/// so the wagons at the two ends of the visible track had a chain leaving
/// on one side and nothing on the other — they read as hanging from thin
/// air at the extremities. This is the fixed point that chain now ends at.
///
/// ## Positioning
///
/// Placed by its **chain tip**, not by its plate or its canvas: the tip is
/// the end that has to meet whatever the anchor is terminating, and it is
/// the only point whose world position is actually specified anywhere.
/// [ChainAnchor.at] converts a world tip position into the top-left the
/// sprite has to be drawn at, using the measured native tip coordinates and
/// [chainAnchorRenderScale].
///
/// ## Scope
///
/// It is a [SpriteComponent] and nothing else: no hitbox, no state, never
/// consulted by gameplay. It does not touch slots, `next`/`prev`, or the
/// linked list — the wagon it sits beside does not know it exists.
class ChainAnchor extends SpriteComponent {
  ChainAnchor._({
    required Vector2 position,
    required Vector2 size,
    required int priority,
  }) : super(position: position, size: size, priority: priority) {
    paint
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    // Módulo 13, item 2: the same cool wash the wagons and the boss get.
    // Skipping it here would make the newly added scenery the one
    // untinted thing in the frame — exactly the "colado sobre o fundo"
    // problem this module is fixing.
    applyAmbientCoolTint(this);
  }

  /// Loads the [side] anchor and positions it so its free chain end lands
  /// exactly on [tip] (world/canvas coordinates).
  static Future<ChainAnchor> at({
    required Vector2 tip,
    required ChainAnchorSide side,
    int priority = fxPriorityChainAnchor,
  }) async {
    final image = await Flame.images.load(side.assetPath);
    final size = Vector2(
      image.width * chainAnchorRenderScale,
      image.height * chainAnchorRenderScale,
    );
    final anchor = ChainAnchor._(
      // Default anchor is topLeft, so subtracting the scaled native tip
      // offset from the desired world tip gives the draw origin directly.
      position: Vector2(
        tip.x - side.tipXNative * chainAnchorRenderScale,
        tip.y - chainAnchorTipY * chainAnchorRenderScale,
      ),
      size: size,
      priority: priority,
    );
    anchor.sprite = Sprite(image);
    return anchor;
  }
}
