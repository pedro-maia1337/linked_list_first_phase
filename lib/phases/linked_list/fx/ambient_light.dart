/// Módulo 13, item 2 — making the wagons and the boss share the scene's
/// light instead of sitting on top of it.
///
/// Two complementary halves, both purely decorative:
///
///  * [ambientCoolTintFilter] — a single low-opacity wash in the backdrop's
///    dominant cool tone, applied to every wagon sprite and to the boss.
///    This is the "conversa de paleta" half: it does not simulate a light,
///    it just stops the characters from being the only fully neutral thing
///    on screen.
///  * [WagonLanternLightObserver] — an additive warm pool on the roof of wagons
///    that are actually near a lantern anchor. This is the directional
///    half, and it is deliberately uneven: wagons in the dark stretches of
///    the track receive nothing.
///
/// Neither touches physics, colliders, slot positions, the wagon/boss state
/// machines, nor the section 2.3 scale calibration.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/arena_config.dart';
import '../track/linear_track.dart';
import '../wagon/vagao.dart';
import '../../../shared/fx/glow_light.dart';
import 'linked_list_fx_config.dart';


/// The shared cool wash described above.
///
/// `srcATop` composites [ambientCoolTintColor] over the sprite's own pixels
/// but clipped to their alpha, so a sprite's transparent padding stays
/// transparent and no silhouette is thickened. Applying it to a
/// [SpriteComponent]'s `paint` survives sprite swaps (`paint` is a property
/// of the component, not of the `Sprite`), which is what lets a single call
/// in `Vagao.onLoad` cover all fifteen state frames.
ColorFilter ambientCoolTintFilter() => ColorFilter.mode(
      ambientCoolTintColor.withValues(alpha: ambientCoolTintOpacity),
      BlendMode.srcATop,
    );

/// Applies [ambientCoolTintFilter] to [component] without discarding
/// whatever else its `paint` was already configured with (filter quality,
/// anti-aliasing, blend mode).
void applyAmbientCoolTint(HasPaint component) {
  component.paint.colorFilter = ambientCoolTintFilter();
}

/// The tint the arena's decorative chain links wear.
///
/// Módulo 15, Mudança 1: this used to take a `golden` flag and swap the
/// wash for a gold `modulate` when the list became doubly linked. Lista
/// Dupla is gone, so the alternative it selected between is gone with it
/// and the chains simply wear the shared cool wash, like every other piece
/// of the wagon/chain art family.
void applyChainTint(HasPaint component) {
  component.paint.colorFilter = ambientCoolTintFilter();
}

/// Strength of the warm lantern pool a wagon at [wagonRoof] should receive,
/// in `0..1`, given every lantern anchor in the arena config.
///
/// Linear falloff to zero at [wagonLanternGlowRadius] from the nearest
/// anchor — the *nearest*, not a sum, so two lamps flanking one wagon do
/// not blow it out.
double lanternLightIntensityAt(
  Vector2 wagonRoof,
  Iterable<DecorativeAnchor> anchors,
) {
  var best = 0.0;
  for (final anchor in anchors) {
    final distance = (Vector2(anchor.x, anchor.y) - wagonRoof).length;
    final intensity = 1 - distance / wagonLanternGlowRadius;
    if (intensity > best) {
      best = intensity;
    }
  }
  return best.clamp(0.0, 1.0);
}

/// Attaches a warm [GlowLight] to the roof of every wagon that stands near
/// a lantern, and keeps doing so as wagons are spawned and cleared.
///
/// Written as an observer of the track — the same shape as
/// `WagonFxObserver` — for the same reason: a wagon is created by
/// `boss.occupySlot`, which knows nothing about backdrop lighting, and
/// teaching it would put scenery data inside the state machine. Instead
/// this polls `slot.vagao` once per frame and decorates whatever it finds.
///
/// The glow is added as a *child* of the [Vagao], so it inherits the
/// wagon's position and disappears with it, and — because Flame always
/// draws a component's children after its own render — it lands on top of
/// the wagon art, which is what "glow no topo dos vagões" needs. It is not
/// a child of the wagon's scaled visual, so the spawn `ScaleEffect` and the
/// tremor jitter never touch it.
///
/// Per-slot intensity is computed once in [onLoad] from the slot's fixed
/// coordinate: slots never move, so there is nothing to recompute.
class WagonLanternLightObserver extends Component {
  final LinearTrack track;

  /// Every `decorativeAnchors` group from `slots_config.json`, flattened —
  /// a future group added there lights the wagons without a code change,
  /// exactly as it already lights the backdrop.
  final List<DecorativeAnchor> lanternAnchors;

  /// Slot index -> lantern intensity in `0..1`; slots too far from every
  /// lantern are absent rather than present with a zero.
  final Map<int, double> _intensityBySlot = {};

  /// The wagon each slot's glow is currently attached to, so a slot that is
  /// cleared and re-occupied gets a fresh glow instead of the observer
  /// believing it already did the work.
  final Map<int, Vagao> _litWagons = {};

  WagonLanternLightObserver({
    required this.track,
    required this.lanternAnchors,
  });

  @override
  Future<void> onLoad() async {
    for (final slot in track.slots) {
      final intensity = lanternLightIntensityAt(
        Vector2(slot.x, slot.y + wagonLanternGlowYOffset),
        lanternAnchors,
      );
      if (intensity > 0) {
        _intensityBySlot[slot.index] = intensity;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (final slot in track.slots) {
      final intensity = _intensityBySlot[slot.index];
      if (intensity == null) {
        continue;
      }

      final vagao = slot.vagao;
      if (vagao == null || vagao.isRemoved) {
        _litWagons.remove(slot.index);
        continue;
      }
      if (identical(_litWagons[slot.index], vagao)) {
        continue;
      }
      // A wagon whose `onLoad` has not finished has no children yet and
      // would drop the glow on the floor; it will be picked up next frame.
      if (!vagao.isLoaded) {
        continue;
      }

      _litWagons[slot.index] = vagao;
      _attachGlow(vagao, intensity, slot.index);
    }
  }

  Future<void> _attachGlow(Vagao vagao, double intensity, int slotIndex) async {
    final glow = await GlowLight.load(
      position: Vector2(0, wagonLanternGlowYOffset),
      diameter: wagonLanternGlowDiameter,
      baseOpacity: wagonLanternGlowMaxOpacity * intensity,
      pulseOpacityAmplitude: wagonLanternGlowFlickerAmplitude * intensity,
      pulseSpeed: lanternGlowFlickerSpeed,
      // Same staggering the backdrop lantern pools use, so a lit wagon
      // flickers with its own rhythm rather than in lockstep with them.
      phase: slotIndex * 1.31,
    );
    if (vagao.isRemoved) {
      return;
    }
    await vagao.add(glow);
  }
}

/// Unit direction of the boss's key light, from [bossRimLightDirX] /
/// [bossRimLightDirY]. Normalised here rather than trusting the constants
/// to already be unit length.
({double x, double y}) get bossRimLightDirection {
  final length = math.sqrt(
    bossRimLightDirX * bossRimLightDirX + bossRimLightDirY * bossRimLightDirY,
  );
  return (x: bossRimLightDirX / length, y: bossRimLightDirY / length);
}
