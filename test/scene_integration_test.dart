import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/game/fx/ambient_light.dart';
import 'package:linked_list_first_phase/game/fx/boss_rim_light.dart';
import 'package:linked_list_first_phase/game/fx/fx_config.dart';
import 'package:linked_list_first_phase/game/fx/glow_light.dart';
import 'package:linked_list_first_phase/game/vagoneiro_arena_game.dart';
import 'package:linked_list_first_phase/game/wagon/chain_anchor.dart';
import 'package:linked_list_first_phase/game/wagon/vagao.dart';

/// Módulo 13 — integração da cena.
///
/// Guards the things that are easy to break silently and impossible to see
/// in a unit test's output: that the regenerated wagon frames stay centred
/// on their slot, that the boss's rim light is a rim and not an outline,
/// that the lantern falloff actually discriminates between lit and unlit
/// stretches of track, and that both ends of the chain are closed off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Flame.images` is a process-global cache keyed by the *unprefixed*
  // path, and it caches failures as well as successes — one load at the
  // wrong prefix poisons that path for every later test in the isolate.
  // The game sets this itself in `onLoad`; the tests that read an image
  // directly need it set before they touch the cache.
  setUpAll(() => Flame.images.prefix = 'assets/');

  Future<VagoneiroArenaGame> bootGame() async {
    final game = VagoneiroArenaGame();
    game.onGameResize(Vector2(1672, 941));
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    await game.ready();
    game.update(0);
    return game;
  }

  /// Horizontal centre of a frame's opaque content, in native px, measured
  /// the same way the [VagaoFrame] offsets were: alpha > 10.
  Future<double> opaqueCentreX(String assetPath) async {
    final image = await Flame.images.load(assetPath);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    var minX = image.width, maxX = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (bytes[(y * image.width + x) * 4 + 3] > 10) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
    }
    return (minX + maxX) / 2;
  }

  test('every wagon frame registers onto the slot it is drawn at', () async {
    final frames = [
      vagaoIdleFrame,
      ...vagaoTremorFrames,
      ...vagaoFallingFrames,
    ];
    expect(frames.length, 15, reason: 'the regenerated set is 15 frames');

    final scale = vagaoDisplayWidth / vagaoNativeCanvasWidth;

    for (final frame in frames) {
      final image = await Flame.images.load(frame.assetPath);
      final measured = await opaqueCentreX(frame.assetPath);
      final canvasCentre = (image.width - 1) / 2;

      // The constant in the table must match what is actually in the file —
      // this is what catches an art re-export that silently shifts a frame.
      expect(
        frame.contentCentreOffsetX,
        closeTo(measured - canvasCentre, 1.0),
        reason: '${frame.assetPath}: registration constant is stale',
      );

      // And with the correction applied, the content lands on the wagon's
      // own origin (local x = 0) rather than up to 28 world px off it.
      final correctedLocalX =
          (measured - canvasCentre - frame.contentCentreOffsetX) * scale;
      expect(
        correctedLocalX.abs(),
        lessThan(1.0),
        reason: '${frame.assetPath}: content not centred after correction',
      );
    }
  });

  test('the idle wagon still renders at the calibrated ≈45px', () async {
    // Section 2.3 is a constraint on this module, not an output of it: the
    // art changed, the number did not.
    expect(
      vagaoOpaqueHeightNative * (vagaoDisplayWidth / vagaoNativeCanvasWidth),
      closeTo(45, 0.5),
    );
    // ...and the cart's rendered body must stay wider than the collider it
    // is supposed to be a platform for.
    const bodyWidthNative = 172.0;
    expect(
      bodyWidthNative * (vagaoDisplayWidth / vagaoNativeCanvasWidth),
      greaterThan(vagaoColliderWidth),
    );
  });

  test('the boss rim light is a rim, not an outline', () async {
    final key = bossRimLightDirection;
    // The key direction must point upwards — it is derived from lantern
    // anchors that sit above the boss.
    expect(key.y, lessThan(0));

    final offsets = BossRimLight.offsets;
    expect(offsets, isNotEmpty);

    var totalWeight = 0.0;
    var maxUp = 0.0;
    var maxLateral = 0.0;
    for (final (dx, dy, weight) in offsets) {
      // Nothing may light the underside: a redraw offset downwards is what
      // put a glowing band beneath the boots.
      expect(dy, lessThan(0), reason: 'a redraw is offset downwards');
      totalWeight += weight;
      maxUp = math.max(maxUp, -dy);
      maxLateral = math.max(maxLateral, dx.abs());
    }

    // Normalised, so the additive redraws sum to `bossRimLightOpacity` at
    // the brightest point instead of saturating to white.
    expect(totalWeight, closeTo(1.0, 1e-9));

    // The halo must reach substantially further up than sideways. This is
    // the actual "rim, not outline" property: the flanking redraws are
    // tapered by their cos² weight, so even the most lateral direction
    // barely displaces and therefore barely shows along the silhouette's
    // sides.
    expect(
      maxUp,
      greaterThan(2 * maxLateral),
      reason: 'the halo spreads sideways nearly as much as upwards',
    );

    // And the rim never gets thicker than its configured width.
    expect(maxUp, lessThanOrEqualTo(bossRimLightWidth + 1e-9));
  });

  test('lantern light reaches the track ends but not its dark middle',
      () async {
    final game = await bootGame();
    final anchors = [
      for (final group in game.arenaConfig.decorativeAnchors.values) ...group,
    ];

    double intensityAtSlot(int index) {
      final slot = game.track.slotAt(index);
      return lanternLightIntensityAt(
        Vector2(slot.x, slot.y + wagonLanternGlowYOffset),
        anchors,
      );
    }

    // Slot 7 sits ~61px from the lantern at (215, 730).
    expect(intensityAtSlot(7), greaterThan(0.5));
    // Slots 2-4 are the unlit middle of the track.
    for (final index in [2, 3, 4]) {
      expect(
        intensityAtSlot(index),
        0,
        reason: 'slot $index should stay dark',
      );
    }

    // A lit slot's wagon actually receives the glow component; an unlit
    // one receives nothing.
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    expect(
      game.track.slotAt(7).vagao!.children.whereType<GlowLight>().length,
      1,
    );
    expect(
      game.track.slotAt(3).vagao!.children.whereType<GlowLight>(),
      isEmpty,
    );
  });

  test('both ends of the chain are anchored to something fixed', () async {
    final game = await bootGame();

    final anchors = game.world.children.whereType<ChainAnchor>().toList();
    expect(anchors.length, 2, reason: 'one anchor per end of the track');

    final config = game.arenaConfig.chainConnections.endAnchors;
    expect(config.map((a) => a.id), containsAll(['boss_side', 'track_end']));

    // The boss-side anchor's chain tip must land *inside* the boss's
    // silhouette, so the chain reads as passing behind him instead of
    // floating beside him.
    final bossSide = config.firstWhere((a) => a.id == 'boss_side');
    final bossLeft = game.boss.position.x - game.boss.size.x / 2;
    final bossRight = game.boss.position.x + game.boss.size.x / 2;
    expect(bossSide.tip.x, greaterThan(bossLeft));
    expect(bossSide.tip.x, lessThan(bossRight));

    // The track-end anchor chains to the tail slot, and the tail slot is
    // still the tail — this module must not have touched the list.
    final trackEnd = config.firstWhere((a) => a.id == 'track_end');
    expect(trackEnd.chainToSlot, 7);
    expect(game.track.slotAt(7).next, isNull);
    expect(game.track.slotAt(0).prev, isNull);
  });

  test('the ambient tint is a low-opacity wash, not a repaint', () async {
    expect(ambientCoolTintOpacity, inInclusiveRange(0.05, 0.15));
    final filter = ambientCoolTintFilter();
    expect(filter, isNotNull);

    final game = await bootGame();
    // Applied to the boss and to every wagon's art, so nothing in the
    // wagon/chain/boss family is left on a different palette.
    expect(game.boss.paint.colorFilter, isNotNull);
    for (final slot in game.track.slots) {
      final visual = slot.vagao!.children
          .whereType<SpriteComponent>()
          .firstWhere((c) => c is! GlowLight && c.priority >= 0);
      expect(
        visual.paint.colorFilter,
        isNotNull,
        reason: 'wagon at slot ${slot.index} is untinted',
      );
    }
  });
}
