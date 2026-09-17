import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/boss_combat.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/vagoneiro_boss.dart';
import 'package:linked_list_first_phase/shared/physics/arena_wall.dart';
import 'package:linked_list_first_phase/shared/player/player.dart';
import 'package:linked_list_first_phase/shared/player/player_fx.dart';
import 'package:linked_list_first_phase/phases/linked_list/vagoneiro_arena_game.dart';
import 'package:linked_list_first_phase/phases/linked_list/wagon/vagao.dart';

/// Módulo 15 — upgrade do player (idle/dash/pulo granular/espada).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> pump(VagoneiroArenaGame game, int frames, {double dt = 1 / 60}) async {
    for (var i = 0; i < frames; i++) {
      game.update(dt);
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Boots, lets the player land on slot 0 and the spawn tweens finish.
  Future<VagoneiroArenaGame> bootGrounded() async {
    final game = await bootGame();
    await pump(game, 90);
    expect(game.player.isOnGround, isTrue);
    return game;
  }

  /// Per-cell opaque rows (alpha > 10), or null for an empty cell.
  Future<List<({int top, int bottom})?>> cellRows(
    String assetPath,
    int cells,
  ) async {
    final image = await Flame.images.load(assetPath);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final result = <({int top, int bottom})?>[];
    for (var c = 0; c < cells; c++) {
      var top = 1 << 30, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = c * 256; x < (c + 1) * 256; x++) {
          if (bytes[(y * image.width + x) * 4 + 3] > 10) {
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }
      result.add(bottom < 0 ? null : (top: top, bottom: bottom));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Frente 1 — assets and animation state
  // ---------------------------------------------------------------------------

  group('Frente 1 — spritesheets', () {
    final realStates = PlayerState.values
        .where((s) => playerSheetFor(s) != null)
        .toList();

    test('the eight real states and the reserved names', () {
      expect(realStates, [
        PlayerState.idle,
        PlayerState.walk,
        PlayerState.dash,
        PlayerState.jumpRise,
        PlayerState.jumpFall,
        PlayerState.doubleJump,
        PlayerState.attack1,
        PlayerState.attack2,
      ]);
      for (final reserved in [
        PlayerState.hit,
        PlayerState.damaged,
        PlayerState.pulled,
        PlayerState.attackAir,
        PlayerState.death,
      ]) {
        expect(playerSheetFor(reserved), isNull);
      }
      expect(playerWalkSheet.frameCount, 8);
      expect(playerIdleSheet.frameCount, 6);
      expect(playerDashSheet.frameCount, 6);
      expect(playerJumpRiseSheet.frameCount, 4);
      expect(playerJumpFallSheet.frameCount, 4);
      expect(playerDoubleJumpSheet.frameCount, 6);
      expect(playerAttack1Sheet.frameCount, 6);
      expect(playerAttack2Sheet.frameCount, 6);
    });

    test('every sheet is exactly frameCount x 256 by 256, every cell filled',
        () async {
      for (final state in realStates) {
        final spec = playerSheetFor(state)!;
        for (final facing in PlayerFacing.values) {
          final path = spec.assetPath(facing);
          final image = await Flame.images.load(path);
          expect(image.width, spec.frameCount * playerFrameSize, reason: path);
          expect(image.height, playerFrameSize, reason: path);
          final rows = await cellRows(path, spec.frameCount);
          expect(rows.every((r) => r != null), isTrue,
              reason: '$path has an empty cell');
        }
      }
    });

    test('every sheet shares the foot baseline the anchor is computed from',
        () async {
      final baseline = (playerFrameSize - 1 - playerFrameBottomPadNative).toInt();
      for (final state in realStates) {
        final spec = playerSheetFor(state)!;
        for (final facing in PlayerFacing.values) {
          final path = spec.assetPath(facing);
          final rows = await cellRows(path, spec.frameCount);
          final lowest =
              rows.map((r) => r!.bottom).reduce((a, b) => a > b ? a : b);
          // attack2's opening frame reaches 2px lower (the blade tip).
          expect(lowest, inInclusiveRange(baseline, baseline + 2),
              reason: path);
        }
      }
    });

    test('calibration constants re-measured from idle frame 0 -> 110px',
        () async {
      final rows = await cellRows(playerIdleSheet.assetPath(PlayerFacing.east), 1);
      final idle0 = rows.single!;
      expect(idle0.bottom - idle0.top + 1, playerFrameOpaqueHeightNative);
      expect(playerFrameSize - 1 - idle0.bottom, playerFrameBottomPadNative);
      expect(playerRenderedHeightPx, closeTo(110, 1e-9));
      expect(playerDashReferenceHeight, playerRenderedHeightPx);
      // Walk's art scale is the measured upright-height ratio.
      final walk0 = (await cellRows(
        playerWalkSheet.assetPath(PlayerFacing.east),
        1,
      ))
          .single!;
      expect(
        playerWalkSheet.artScale,
        closeTo((walk0.bottom - walk0.top + 1) / playerFrameOpaqueHeightNative,
            1e-9),
      );
    });

    test('effect sheets have the grids the code slices', () async {
      for (final facing in PlayerFacing.values) {
        final trail = await Flame.images.load(playerDashTrailAssetPath(facing));
        expect(trail.width, 64 * playerDashTrailFrameCount);
        expect(trail.height, 32);
        final arc = await Flame.images.load(playerSlashArcAssetPath(facing));
        expect(arc.width, playerSlashArcFrameSize * playerSlashArcColumns);
        expect(arc.height, playerSlashArcFrameSize * playerSlashArcRows);
      }
      final burst = await Flame.images.load(playerDoubleJumpBurstAssetPath);
      expect(burst.width, 96 * playerDoubleJumpBurstFrameCount);
      expect(burst.height, 96);
    });

    test('no north/south anywhere: no asset, no state, no code', () {
      final names = Directory('assets/shared/player')
          .listSync(recursive: true)
          .map((e) => e.path.toLowerCase());
      expect(names.where((n) => n.contains('north') || n.contains('south')),
          isEmpty);
      expect(
        PlayerState.values.map((s) => s.name.toLowerCase()).where(
              (n) => n.contains('north') || n.contains('south'),
            ),
        isEmpty,
      );
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final src = file.readAsStringSync().toLowerCase();
        expect(src.contains('north'), isFalse, reason: file.path);
        expect(src.contains('south'), isFalse, reason: file.path);
      }
    });
  });

  group('Frente 1 — idle replaces the frozen walk frame', () {
    test('the freeze code is gone from the player', () {
      final src = File('lib/shared/player/player.dart').readAsStringSync();
      expect(src.contains('paused = true'), isFalse);
      expect(src.contains('currentIndex = 0'), isFalse);
    });

    test('standing still plays the real idle cycle at the calibrated scale',
        () async {
      final game = await bootGrounded();
      final player = game.player;
      expect(player.state, PlayerState.idle);
      expect(player.debugVisualScaleForTest, Vector2.all(playerDisplayScale));
      expect(player.debugVisualYOffsetForTest,
          closeTo(playerVisualYOffset, 1e-4));

      final visual =
          player.children.whereType<SpriteAnimationComponent>().first;
      final ticker = visual.animationTicker!;
      expect(ticker.isPaused, isFalse);
      final seen = <int>{};
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
        seen.add(ticker.currentIndex);
      }
      expect(seen.length, greaterThan(1), reason: 'idle should animate');
    });

    test('walking switches to walk and keeps the facing', () async {
      final game = await bootGrounded();
      game.debugSetPressedKeysForTest({LogicalKeyboardKey.keyA});
      await pump(game, 3);
      expect(game.player.state, PlayerState.walk);
      expect(game.player.facing, PlayerFacing.west);
      // Walk is fitted to the same 110px through its art scale.
      expect(
        game.player.debugVisualScaleForTest.y,
        closeTo(playerDisplayScale / playerWalkSheet.artScale, 1e-3),
      );
      game.debugSetPressedKeysForTest({});
      await pump(game, 2);
      expect(game.player.state, PlayerState.idle);
      expect(game.player.facing, PlayerFacing.west);
    });
  });

  // ---------------------------------------------------------------------------
  // Frente 2 — dash
  // ---------------------------------------------------------------------------

  group('Frente 2 — dash', () {
    test('distance is 2.0-2.2x the player height and travelled exactly', () {
      expect(playerDashDistance / playerRenderedHeightPx,
          inInclusiveRange(2.0, 2.2));
      final dash = DashController();
      expect(dash.tryStart(direction: -1, grounded: false), isTrue);
      var moved = 0.0;
      // Includes a long hitch frame, which must be capped, not skipped.
      for (final dt in [1 / 60, 0.5, 1 / 60, 1 / 60, 1 / 60, 1 / 60, 1 / 60,
        1 / 60, 1 / 60, 1 / 60, 1 / 60]) {
        final step = dash.tick(dt);
        expect(step.abs(), lessThanOrEqualTo(playerDashMaxStep + 1e-9));
        moved += step;
      }
      expect(moved, closeTo(-playerDashDistance, 1e-9));
      expect(dash.isDashing, isFalse);
    });

    test('the cooldown blocks an early re-dash', () {
      final dash = DashController();
      expect(dash.tryStart(direction: 1, grounded: true), isTrue);
      expect(dash.tryStart(direction: 1, grounded: true), isFalse);
      var t = 0.0;
      while (dash.isDashing) {
        dash.tick(1 / 60);
        t += 1 / 60;
      }
      expect(dash.tryStart(direction: 1, grounded: true), isFalse,
          reason: 'dash finished but cooldown still running');
      while (t < playerDashCooldown - 1 / 60) {
        dash.tick(1 / 60);
        t += 1 / 60;
        expect(dash.isReady, isFalse);
      }
      dash.tick(1 / 30);
      expect(dash.tryStart(direction: 1, grounded: true), isTrue);
    });

    test('air dash covers the full distance, horizontally only, with a trail',
        () async {
      final game = await bootGrounded();
      final player = game.player;
      player.position.setValues(900, 300);
      // Teleporting off the wagon: the engine reports the separation on
      // the next collision pass.
      await pump(game, 2);
      expect(player.isOnGround, isFalse);
      final start = player.position.clone();

      // Vertical input during the dash is ignored.
      game.debugSetPressedKeysForTest(
          {LogicalKeyboardKey.keyC, LogicalKeyboardKey.space});
      await pump(game, 1);
      expect(player.dash.isDashing, isTrue);
      expect(player.state, PlayerState.dash);
      final jumpsBefore = player.jumpsRemaining;
      while (player.dash.isDashing) {
        await pump(game, 1);
        expect(player.position.y, start.y, reason: 'no vertical motion');
      }
      expect(player.jumpsRemaining, jumpsBefore);
      expect(player.position.x - start.x, closeTo(playerDashDistance, 1e-3));
      expect(
        game.world.children
            .whereType<PlayerFxSprite>()
            .where((c) => c.kind == PlayerFxKind.dashTrail),
        isNotEmpty,
      );

      // Cooldown: pressing again right away does nothing.
      game.debugSetPressedKeysForTest({});
      await pump(game, 1);
      game.debugSetPressedKeysForTest({LogicalKeyboardKey.keyC});
      await pump(game, 1);
      expect(player.dash.isDashing, isFalse);
    });

    test('a wall cancels the dash and stops the player at its face',
        () async {
      final game = await bootGrounded();
      final player = game.player;
      const wallLeft = 1000.0;
      await game.world.add(ArenaWall(left: wallLeft, top: 0, height: 941));
      await pump(game, 1);

      player.position.setValues(900, 300);
      await pump(game, 2);
      expect(player.isOnGround, isFalse);
      expect(player.requestDash(direction: 1), isTrue);
      await pump(game, 20);

      expect(player.dash.isDashing, isFalse);
      expect(player.dash.lastCancelReason, DashCancelReason.wall);
      expect(player.dash.travelled, lessThan(playerDashDistance));
      expect(player.position.x,
          lessThanOrEqualTo(wallLeft - playerHitboxWidth / 2 + 1e-3));
    });

    test('a grounded dash is cancelled by running off the platform',
        () async {
      final game = await bootGrounded();
      final player = game.player;
      expect(player.requestDash(direction: -1), isTrue);
      await pump(game, 20);
      expect(player.dash.lastCancelReason, DashCancelReason.lostGround);
      expect(player.dash.travelled, lessThan(playerDashDistance));
      expect(player.verticalVelocity, greaterThan(0), reason: 'now falling');
    });

    test('the i-frame hook is reserved and off', () async {
      expect(playerDashGrantsInvulnerability, isFalse);
      final game = await bootGrounded();
      game.player.position.setValues(900, 300);
      game.player.requestDash();
      expect(game.player.isDashInvulnerable, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Frente 3 — double jump
  // ---------------------------------------------------------------------------

  group('Frente 3 — jump', () {
    test('apex is still ~145px; the heavier fall keeps every slot reachable',
        () {
      const dt = 1 / 1000;
      double simulate(double targetDy, {required bool untilApex}) {
        var vy = playerJumpVelocity, y = 0.0, t = 0.0, minY = 0.0;
        while (true) {
          vy += playerGravityFor(vy) * dt;
          y += vy * dt;
          t += dt;
          if (y < minY) minY = y;
          if (untilApex && vy >= 0) return -minY;
          if (!untilApex && vy > 0 && y >= targetDy) return t;
        }
      }

      expect(simulate(0, untilApex: true), closeTo(145, 1));

      // Worst slot step in slots_config.json: +120px up across 180px.
      // Landing only needs the 50px feet box to overlap the 55px collider.
      final airTime = simulate(-120, untilApex: false);
      final reach = airTime * playerMoveSpeed;
      expect(reach, greaterThan(180 - (playerHitboxWidth + vagaoColliderWidth) / 2));
      expect(playerFallGravityMultiplier, greaterThan(1));
    });

    test('in-game apex of a single jump is ~145px', () async {
      final game = await bootGrounded();
      final startY = game.player.position.y;
      var minY = startY;
      game.debugHoldJumpForTest(true);
      for (var i = 0; i < 240; i++) {
        game.update(1 / 240);
        if (game.player.position.y < minY) minY = game.player.position.y;
        if (i == 0) game.debugHoldJumpForTest(false);
      }
      expect(startY - minY, closeTo(145, 2));
    });

    test('jumpRise -> jumpFall -> doubleJump -> jumpFall -> idle, with burst',
        () async {
      final game = await bootGrounded();
      final player = game.player;
      player.stateHistory.clear();

      game.debugHoldJumpForTest(true);
      await pump(game, 1);
      game.debugHoldJumpForTest(false);
      expect(player.state, PlayerState.jumpRise);

      while (player.verticalVelocity < 0) {
        await pump(game, 1);
        if (player.verticalVelocity < 0) {
          expect(player.state, PlayerState.jumpRise);
        }
      }
      expect(player.state, PlayerState.jumpFall);
      await pump(game, 1);

      game.debugHoldJumpForTest(true);
      await pump(game, 1);
      game.debugHoldJumpForTest(false);
      expect(player.state, PlayerState.doubleJump);
      // Components added mid-update are mounted on the next tick.
      await pump(game, 1);
      final burst = game.world.children
          .whereType<PlayerFxSprite>()
          .where((c) => c.kind == PlayerFxKind.doubleJumpBurst)
          .toList();
      expect(burst, hasLength(1));
      // Anchored on the feet at the moment of activation (two frames ago).
      expect((burst.single.position.x - player.position.x).abs(), lessThan(1));
      expect((burst.single.position.y - player.position.y).abs(), lessThan(25));

      for (var i = 0; i < 300 && !player.isOnGround; i++) {
        await pump(game, 1);
      }
      await pump(game, 2);
      expect(player.stateHistory, [
        PlayerState.jumpRise,
        PlayerState.jumpFall,
        PlayerState.doubleJump,
        PlayerState.jumpFall,
        PlayerState.idle,
      ]);
    });

    test('reversing mid-air turns and moves on the same frame', () async {
      final game = await bootGrounded();
      final player = game.player;

      // Jump while moving east.
      game.debugSetPressedKeysForTest(
          {LogicalKeyboardKey.keyD, LogicalKeyboardKey.space});
      await pump(game, 1);
      game.debugSetPressedKeysForTest({LogicalKeyboardKey.keyD});
      await pump(game, 5);
      expect(player.isOnGround, isFalse);
      expect(player.facing, PlayerFacing.east);
      expect(player.state, PlayerState.jumpRise);

      final visual =
          player.children.whereType<SpriteAnimationComponent>().first;
      final indexBefore = visual.animationTicker!.currentIndex;
      expect(indexBefore, greaterThan(0), reason: 'rise already under way');
      final xBefore = player.position.x;

      // Reverse while still airborne: one frame later the player has
      // already moved west *and* faces west, and the rise animation did
      // not restart.
      game.debugSetPressedKeysForTest({LogicalKeyboardKey.keyA});
      await pump(game, 1);
      expect(player.isOnGround, isFalse);
      expect(player.position.x, lessThan(xBefore));
      expect(player.facing, PlayerFacing.west);
      expect(player.state, PlayerState.jumpRise);
      expect(visual.animationTicker!.currentIndex,
          greaterThanOrEqualTo(indexBefore));
    });

    test('coyote time / input buffer are reserved names only', () {
      expect(playerCoyoteTime, 0);
      expect(playerJumpBufferTime, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Frente 4 — sword
  // ---------------------------------------------------------------------------

  group('Frente 4 — attack controller', () {
    Map<int, bool> liveByFrame(AttackController c) {
      final live = <int, bool>{};
      while (c.isAttacking) {
        live[c.frameIndex] = (live[c.frameIndex] ?? false) || c.isHitboxActive;
        c.tick(1 / 240);
      }
      return live;
    }

    test('hitbox is live only on the peak frames', () {
      final c = AttackController(comboWindow: 0.35);
      c.press(grounded: true);
      expect(c.swing, SwordSwing.first);
      final first = liveByFrame(c);
      expect(first.keys.toSet(), {0, 1, 2, 3, 4, 5});
      expect({for (final e in first.entries) if (e.value) e.key}, {2, 3});

      c.press(grounded: true);
      expect(c.swing, SwordSwing.second);
      final second = liveByFrame(c);
      expect({for (final e in second.entries) if (e.value) e.key}, {3});
      expect(playerAttackReach / playerRenderedHeightPx, closeTo(1.4, 1e-9));
    });

    test('golpe 2 chains only inside the window; outside it resets', () {
      final c = AttackController(comboWindow: 0.35);
      c.press(grounded: true);
      while (c.isAttacking) {
        c.tick(1 / 60);
      }
      c.tick(0.2);
      c.press(grounded: true);
      expect(c.swing, SwordSwing.second, reason: 'inside the window');
      while (c.isAttacking) {
        c.tick(1 / 60);
      }
      c.press(grounded: true);
      expect(c.swing, SwordSwing.first, reason: 'after golpe 2 -> golpe 1');
      while (c.isAttacking) {
        c.tick(1 / 60);
      }
      c.tick(0.4);
      c.press(grounded: true);
      expect(c.swing, SwordSwing.first, reason: 'window expired');
    });

    test('a press during golpe 1 recovery queues golpe 2; earlier is ignored',
        () {
      final c = AttackController();
      c.press(grounded: true);
      expect(c.press(grounded: true), isFalse, reason: 'wind-up frame');
      while (c.frameIndex < 2) {
        c.tick(1 / 120);
      }
      expect(c.press(grounded: true), isTrue);
      while (c.swing == SwordSwing.first) {
        c.tick(1 / 120);
      }
      expect(c.swing, SwordSwing.second);
    });

    test('attacking in the air is ignored (attack_air reserved)', () {
      final c = AttackController();
      expect(c.press(grounded: false), isFalse);
      expect(c.isAttacking, isFalse);
    });
  });

  group('Frente 4 — sword vs boss', () {
    /// Stands the player on slot 0 facing the boss.
    Future<VagoneiroArenaGame> bootFacingBoss() async {
      final game = await bootGrounded();
      expect(game.player.facing, PlayerFacing.east);
      expect(game.boss.position.x - game.player.position.x,
          lessThan(playerAttackReach));
      return game;
    }

    /// Plays one full swing, recording on which attack frames the hitbox
    /// was live and when the boss lost HP.
    Future<({Set<int> liveFrames, Set<int> damageFrames})> swing(
      VagoneiroArenaGame game,
    ) async {
      final player = game.player;
      final live = <int>{};
      final damage = <int>{};
      var hp = game.boss.hp;
      while (player.attack.isAttacking) {
        // The hitbox is set for the frame the update just advanced to, and
        // the engine resolves contacts right after — so both are sampled
        // against the post-update frame index.
        await pump(game, 1, dt: 1 / 120);
        if (!player.attack.isAttacking) break;
        final frame = player.attack.frameIndex;
        if (player.swordHitbox.isLive) live.add(frame);
        if (game.boss.hp != hp) {
          damage.add(frame);
          hp = game.boss.hp;
        }
      }
      return (liveFrames: live, damageFrames: damage);
    }

    test('J (a held key, not a debug shortcut) swings and hits an exposed boss',
        () async {
      final game = await bootFacingBoss();
      game.boss.enterExposed(5);
      final hpBefore = game.boss.hp;

      // The key event itself does no damage any more.
      final result = game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyJ,
          logicalKey: LogicalKeyboardKey.keyJ,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyJ},
      );
      expect(result, KeyEventResult.handled);
      expect(game.boss.hp, hpBefore);

      await pump(game, 1, dt: 1 / 120);
      game.debugSetPressedKeysForTest({});
      expect(game.player.state, PlayerState.attack1);

      final r = await swing(game);
      expect(r.liveFrames, {2, 3});
      expect(r.damageFrames.length, 1, reason: 'one hit per swing');
      expect(r.damageFrames.single, inInclusiveRange(2, 3));
      expect(game.boss.hp, hpBefore - playerAttackDamage);
      expect(game.attackDirector.lastOutcome, AttackOutcome.hit);
      expect(game.boss.state, BossState.hit);
    });

    test('the slash arc appears over the blade during the peak', () async {
      final game = await bootFacingBoss();
      game.player.requestAttack();
      var sawArc = false;
      while (game.player.attack.isAttacking) {
        await pump(game, 1, dt: 1 / 120);
        final arcs = game.player.children
            .whereType<PlayerFxSprite>()
            .where((c) => c.kind == PlayerFxKind.slashArc);
        if (arcs.isNotEmpty) {
          sawArc = true;
          expect(game.player.attack.frameIndex, greaterThanOrEqualTo(2));
          expect(arcs.single.position.x, greaterThan(0), reason: 'in front');
        }
      }
      expect(sawArc, isTrue);
    });

    test('the combo lands golpe 2 on frame 4 only', () async {
      final game = await bootFacingBoss();
      game.boss.enterExposed(5);
      game.player.requestAttack();
      await swing(game);
      expect(game.player.attack.comboWindowOpen, isTrue);
      game.player.requestAttack();
      expect(game.player.attack.swing, SwordSwing.second);
      await pump(game, 1, dt: 1 / 120);
      expect(game.player.state, PlayerState.attack2);
      final r = await swing(game);
      expect(r.liveFrames, {3});
      expect(r.damageFrames, {3});
      expect(game.boss.hp, bossMaxHp - 2);
    });

    test('outside the exposed window the swing connects but deals nothing',
        () async {
      final game = await bootFacingBoss();
      expect(game.boss.isExposed, isFalse);
      game.player.requestAttack();
      await swing(game);
      expect(game.boss.hp, bossMaxHp);
      expect(game.attackDirector.lastOutcome, AttackOutcome.missInvulnerable);
    });

    test('facing away from the boss never reaches it', () async {
      final game = await bootFacingBoss();
      game.boss.enterExposed(5);
      game.debugSetPressedKeysForTest({LogicalKeyboardKey.keyA});
      await pump(game, 1);
      game.debugSetPressedKeysForTest({});
      await pump(game, 1);
      expect(game.player.facing, PlayerFacing.west);
      game.player.requestAttack();
      await swing(game);
      expect(game.boss.hp, bossMaxHp);
      expect(game.attackDirector.lastOutcome, isNull);
    });

    test('no attack in the air', () async {
      final game = await bootGrounded();
      game.player.position.setValues(900, 300);
      await pump(game, 2);
      expect(game.player.requestAttack(), isFalse);
      expect(game.player.attack.isAttacking, isFalse);
    });
  });

  group('no regression in the old debug keys', () {
    KeyEventResult press(VagoneiroArenaGame game, LogicalKeyboardKey key,
            PhysicalKeyboardKey physical) =>
        game.onKeyEvent(
          KeyDownEvent(
            physicalKey: physical,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
          {key},
        );

    test('H, X, P and K behave as before', () async {
      final game = await bootGrounded();

      press(game, LogicalKeyboardKey.keyH, PhysicalKeyboardKey.keyH);
      expect(game.boss.state, BossState.hit);

      press(game, LogicalKeyboardKey.keyX, PhysicalKeyboardKey.keyX);
      expect(game.boss.isExposed, isTrue);

      final hp = game.boss.hp;
      press(game, LogicalKeyboardKey.keyP, PhysicalKeyboardKey.keyP);
      expect(game.boss.hp, hp - 3);

      await pump(game, 200);
      final executedBefore = game.attackDirector.executed.length;
      press(game, LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK);
      await pump(game, 5);
      expect(game.attackDirector.executed.length, greaterThan(executedBefore));
    });
  });
}
