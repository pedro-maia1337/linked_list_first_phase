import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/vagoneiro_boss.dart';
import 'package:linked_list_first_phase/shared/fx/contact_shadow.dart';
import 'package:linked_list_first_phase/shared/fx/glow_light.dart';
import 'package:linked_list_first_phase/shared/fx/sprite_burst.dart';
import 'package:linked_list_first_phase/shared/player/player.dart';
import 'package:linked_list_first_phase/phases/linked_list/vagoneiro_arena_game.dart';
import 'package:linked_list_first_phase/phases/linked_list/wagon/vagao.dart';

/// Módulo 12 verification for the juice that is driven by state transitions
/// rather than by a static frame: the wagon tremor/falling effects and the
/// player's landing squash + dust.
///
/// These also stand in as the regression guard the module asks for — every
/// test asserts, alongside the new effect, that the gameplay quantity it
/// sits next to did **not** move (the wagon's own position and platform
/// collider, the player's resting scale, `deathZone.y`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<VagoneiroArenaGame> bootGame() async {
    final game = VagoneiroArenaGame();
    game.onGameResize(Vector2(1672, 941));
    // See camera_and_parallax_test.dart for why these @internal calls are
    // the right way to boot a game headlessly.
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    await game.ready();
    game.update(0);
    return game;
  }

  /// Runs frames while also yielding to the event loop, so the real
  /// `Future.delayed` timers inside `Vagao.playVagaoFantasmaSequence` get a
  /// chance to fire. The wagon sequence is driven by wall-clock delays, not
  /// by `dt`, so a pure `update()` loop would never advance it.
  Future<void> pump(VagoneiroArenaGame game, double seconds) async {
    final steps = (seconds * 60).round();
    for (var i = 0; i < steps; i++) {
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// The wagon's art sprite: its only [SpriteComponent] child that is
  /// neither the contact shadow nor a Módulo 13 lantern pool.
  SpriteComponent visualOf(Vagao vagao) => vagao.children
      .whereType<SpriteComponent>()
      .firstWhere((c) => c is! ContactShadow && c is! GlowLight);

  test('every wagon and the player get a contact shadow', () async {
    final game = await bootGame();

    expect(
      game.player.children.whereType<ContactShadow>().length,
      1,
      reason: 'player should have exactly one contact shadow',
    );

    for (final slot in game.track.slots) {
      final vagao = slot.vagao;
      expect(vagao, isNotNull, reason: 'slot ${slot.index} should be occupied');
      expect(
        vagao!.children.whereType<ContactShadow>().length,
        1,
        reason: 'wagon at slot ${slot.index} should have one contact shadow',
      );
    }
  });

  test(
    'tremor emits sparks and jitters the sprite without moving the collider',
    () async {
      final game = await bootGame();
      final vagao = game.track.slotAt(3).vagao!;

      // Let the wagon's spawn `ScaleEffect` finish first. Its `onComplete`
      // assigns `state = idle` unconditionally, so a Vagao-Fantasma
      // triggered inside the 0.25s spawn window has its `tremor` silently
      // overwritten. That is pre-existing wagon-state-machine behaviour
      // (out of scope for this module) — the test just reproduces the real
      // situation, where a wagon has long finished spawning.
      await pump(game, 0.4);
      expect(vagao.state, VagaoState.idle);

      final wagonPositionBefore = vagao.position.clone();
      final colliderBefore =
          vagao.platformHitbox.absoluteTopLeftPosition.clone();

      game.boss.debugTriggerVagaoFantasma(3);
      await pump(game, 0.6);

      expect(vagao.state, VagaoState.tremor);

      // Effect side: sparks exist, and the art has been nudged off its
      // resting offset.
      final sparks = game.world.children
          .where((c) => c is SpriteBurst || c is SpriteLoop)
          .length;
      expect(sparks, greaterThan(0), reason: 'no spark-ember components');
      // Módulo 13: "at rest" is the current frame's registration offset,
      // not zero — the regenerated art is not centred in its own canvas.
      // What the jitter guarantees is displacement *from that offset*.
      expect(
        (visualOf(vagao).position - vagao.visualRestingOffset).length,
        greaterThan(0),
        reason: 'the wagon sprite should be jittering during tremor',
      );

      // Gameplay side: nothing that the player can land on has moved.
      expect(vagao.position, wagonPositionBefore);
      expect(vagao.platformHitbox.absoluteTopLeftPosition, colliderBefore);
      expect(vagao.isSolid, isTrue, reason: 'tremor is still a solid platform');
    },
  );

  test('entering falling shakes the camera and clears the jitter', () async {
    final game = await bootGame();
    final vagao = game.track.slotAt(3).vagao!;

    game.player.position.setValues(300, 400);
    await pump(game, 0.2);
    final restingCamera = game.camera.viewfinder.position.clone();

    game.boss.debugTriggerVagaoFantasma(3);
    // Past the ~1.2s tremor telegraph, into `falling`.
    var maxShake = 0.0;
    for (var i = 0; i < 110; i++) {
      game.player.position.setValues(300, 400);
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final d = (game.camera.viewfinder.position - restingCamera).length;
      if (d > maxShake) {
        maxShake = d;
      }
      if (vagao.state == VagaoState.falling) {
        break;
      }
    }

    expect(
      vagao.state,
      anyOf(VagaoState.falling, VagaoState.removed),
      reason: 'the wagon should have reached falling',
    );

    // The shake is fired on the transition, so give it a few frames.
    for (var i = 0; i < 10; i++) {
      game.player.position.setValues(300, 400);
      game.update(1 / 60);
      final d = (game.camera.viewfinder.position - restingCamera).length;
      if (d > maxShake) {
        maxShake = d;
      }
    }
    expect(maxShake, greaterThan(0.5), reason: 'no screen shake on falling');

    // Once tremor is over the sprite must be back on its exact resting
    // offset — the jitter is never a new position. Módulo 13: that resting
    // offset is the current frame's registration correction, so the check
    // is against `visualRestingOffset` rather than against zero.
    expect(visualOf(vagao).position, vagao.visualRestingOffset);
  });

  test('landing squashes the player, then returns to the exact base scale',
      () async {
    final game = await bootGame();

    final visual = game.player.children.whereType<SpriteAnimationComponent>()
        .first;
    final baseScale = Vector2.all(playerDisplayScale);
    // Módulo 15: the player boots in the air, so the sheet on screen is
    // jump_fall, drawn at its own art-scale-normalised size. The resting
    // (idle) scale is asserted at the end, once it has landed.
    expect(game.player.state, PlayerState.jumpFall);
    expect(
      visual.scale,
      Vector2.all(playerDisplayScale / playerJumpFallSheet.artScale),
    );

    // The player starts above slot 0 and falls onto it — run until it lands.
    var sawDeformation = false;
    for (var i = 0; i < 240; i++) {
      game.update(1 / 60);
      if ((visual.scale - baseScale).length > 0.005) {
        sawDeformation = true;
      }
    }
    expect(sawDeformation, isTrue, reason: 'no squash/stretch was ever applied');

    // And it always settles back exactly, never drifting the calibrated size.
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    // Compared against `baseScale`, not against the raw `double` constant:
    // `Vector2` is backed by a `Float32List`, so even an untouched
    // `Vector2.all(playerDisplayScale)` reads back as the float32 rounding
    // of it (0.47826087474823 vs 0.4782608695652174). Comparing vectors
    // keeps the assertion exact rather than papering over it with a
    // tolerance.
    expect(
      visual.scale,
      baseScale,
      reason: 'squash must return to exactly playerDisplayScale',
    );
  });

  test('Módulo 11 calibration constants are untouched', () async {
    final game = await bootGame();

    // 110px player, ≈45px wagon art, 176px boss, ≈145px jump apex —
    // recomputed here from the live constants rather than restated, so a
    // change to any of them fails this test.
    expect(playerRenderedHeightPx, closeTo(110, 0.01));
    expect(
      vagaoDisplayWidth / vagaoNativeCanvasWidth * vagaoOpaqueHeightNative,
      closeTo(45, 0.5),
    );
    expect(
      game.boss.size.y * (bossOpaqueHeightNative / bossFrameSize),
      closeTo(176, 0.5),
    );
    // apex = v0^2 / (2g)
    expect(
      (playerJumpVelocity * playerJumpVelocity) / (2 * playerGravity),
      closeTo(145, 0.5),
    );
    // Collider top surface still ≈38px above the wagon base.
    expect(vagaoColliderOffsetY - vagaoColliderHeight, closeTo(-38, 0.01));
    // deathZone still comes from the config, unmodified.
    expect(game.arenaConfig.deathZone.y, 900);
  });
}
