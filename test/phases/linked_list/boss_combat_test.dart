import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/shared/player/player.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/boss_combat.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/vagoneiro_boss.dart';
import 'package:linked_list_first_phase/phases/linked_list/fx/boss_dock.dart';
import 'package:linked_list_first_phase/shared/fx/contact_shadow.dart';
import 'package:linked_list_first_phase/shared/fx/game_curves.dart';
import 'package:linked_list_first_phase/phases/linked_list/vagoneiro_arena_game.dart';
import 'package:linked_list_first_phase/phases/linked_list/wagon/vagao.dart';
import 'package:linked_list_first_phase/phases/linked_list/fx/linked_list_fx_config.dart';

/// Módulo 14/15 — the boss's dock, the replacement art, and the fight.
///
/// Guards what is easy to break silently: the registration of the new
/// spritesheet (a re-export with a different cell size would otherwise
/// slice garbage), the rules of the phase bands and the punish window, the
/// invariants the design doc calls inviolable — above all that a `Vagao`
/// is never moved between slots — and, from Módulo 15, the two rules the
/// playtest pass added that a refactor could quietly undo: the roster is
/// exactly two primitives, and two holes are never adjacent.
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

  /// Settles spawn tweens and the async decorations that attach a frame or
  /// two late.
  Future<void> settle(VagoneiroArenaGame game, {int frames = 40}) async {
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }
  }

  /// Pumps the game for [seconds] of **wall-clock** time.
  ///
  /// The wagon's tremor telegraph is timed off `DateTime.now()` (Módulo
  /// 13, so a stalled frame cannot shorten it), so a sequence that has to
  /// reach `falling` cannot be settled by counting `update` calls — it
  /// needs the clock to actually advance.
  Future<void> settleRealTime(VagoneiroArenaGame game, double seconds) async {
    final deadline = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(deadline)) {
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
  }

  /// Opaque bounding box of a cell of a grid spritesheet, alpha > 10 — the
  /// same measurement the constants in `vagoneiro_boss.dart` record.
  Future<({int top, int bottom, int height})?> cellBounds(
    String assetPath,
    int row,
    int column,
    int cellSize,
  ) async {
    final image = await Flame.images.load(assetPath);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    var minY = cellSize, maxY = -1;
    for (var y = 0; y < cellSize; y++) {
      for (var x = 0; x < cellSize; x++) {
        final px = column * cellSize + x;
        final py = row * cellSize + y;
        if (bytes[(py * image.width + px) * 4 + 3] > 10) {
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxY < 0) {
      return null;
    }
    return (top: minY, bottom: maxY, height: maxY - minY + 1);
  }

  // ---------------------------------------------------------------------------
  // Frente 2 — the replacement art
  // ---------------------------------------------------------------------------

  group('boss spritesheet (Frente 2)', () {
    test('is the 6x4 grid of 300px cells the slicing map declares', () async {
      final image = await Flame.images.load(bossSpriteAssetPath);
      expect(image.width, bossSheetColumns * bossFrameSize);
      expect(image.height, bossSheetRows * bossFrameSize);
    });

    test('row 3 really has only 4 filled columns, as section 4.1 says',
        () async {
      for (var column = 0; column < bossHitFrameCount; column++) {
        expect(
          await cellBounds(
            bossSpriteAssetPath,
            bossHitRow,
            column,
            bossFrameSize.toInt(),
          ),
          isNotNull,
          reason: 'hit frame $column should have art',
        );
      }
      // Slicing these two would flash empty frames at the end of the loop —
      // which is exactly why `bossHitFrameCount` is 4 and not 6.
      for (final column in [4, 5]) {
        expect(
          await cellBounds(
            bossSpriteAssetPath,
            bossHitRow,
            column,
            bossFrameSize.toInt(),
          ),
          isNull,
          reason: 'cell (2,$column) must stay empty',
        );
      }
    });

    test('the calibration constants match the file, and still hit 176px',
        () async {
      var totalHeight = 0.0;
      var totalBottom = 0.0;
      for (var column = 0; column < bossIdleFrameCount; column++) {
        final bounds = await cellBounds(
          bossSpriteAssetPath,
          bossIdleRow,
          column,
          bossFrameSize.toInt(),
        );
        expect(bounds, isNotNull);
        totalHeight += bounds!.height;
        totalBottom += bounds.bottom;
      }

      // The recorded measurements must be what is actually in the file —
      // this is what catches an art re-export that silently resizes the
      // character inside its cell.
      expect(
        bossOpaqueHeightNative,
        closeTo(totalHeight / bossIdleFrameCount, 1.0),
      );
      expect(
        bossFrameBottomPadNative,
        closeTo((bossFrameSize - 1) - totalBottom / bossIdleFrameCount, 1.0),
      );

      // And design doc section 2.3 is a constraint on this module, not an
      // output of it: the art changed, the numbers did not.
      expect(bossOpaqueHeightNative * bossDisplayScale, closeTo(176, 0.5));
      expect(bossFrameSize * bossDisplayScale / 176, greaterThan(1));
    });

    test('every BossState maps to cells inside the grid', () async {
      final game = await bootGame();
      for (final state in BossState.values) {
        game.boss.playState(state);
        expect(
          game.boss.animation,
          isNotNull,
          reason: '$state produced no animation',
        );
        expect(game.boss.animation!.frames, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Frente 1 — the dock
  // ---------------------------------------------------------------------------

  group('boss dock (Frente 1)', () {
    test('the deck lands on the boss feet, with a contact shadow and no gap',
        () async {
      final game = await bootGame();

      final dock = game.world.children.whereType<BossDock>().single;
      // The prop is registered by its deck surface, and the deck surface is
      // the boss's *visible* foot line — not the frame's bottom edge, which
      // is 32.5 native px lower.
      expect(dock.deckTopY, closeTo(game.boss.visibleFootY, 0.5));
      expect(game.boss.visibleFootY, lessThan(game.boss.position.y));

      // Boss position/scale are untouched by any of this.
      expect(game.boss.position.x, game.arenaConfig.boss.x);
      expect(game.boss.position.y, game.arenaConfig.boss.y);

      // The shadow sits on that same line — no gap by construction.
      final shadow = game.world.children
          .whereType<ContactShadow>()
          .firstWhere((s) => s.priority == fxPriorityBossContactShadow);
      expect(shadow.position.y, closeTo(game.boss.visibleFootY, 0.001));
      expect(shadow.position.x, closeTo(game.boss.position.x, 0.001));

      // The dock paints behind the boss, the wagons and the chain anchors.
      expect(dock.priority, lessThan(fxPriorityChainAnchor));
      expect(shadow.priority, greaterThan(dock.priority));
      expect(shadow.priority, lessThan(game.boss.priority));
    });

    test('the dock carries the same cool wash as the wagons and chains',
        () async {
      final game = await bootGame();
      final dock = game.world.children.whereType<BossDock>().single;
      expect(dock.paint.colorFilter, isNotNull);
    });

    test('the deck is wide enough for the boss and clear of slot 0',
        () async {
      final game = await bootGame();
      final dock = game.world.children.whereType<BossDock>().single;

      // Wider than the boss's rendered idle silhouette (133 native px).
      expect(bossDockDeckWidth, greaterThan(133 * bossDisplayScale));

      final deckLeft = game.boss.position.x +
          bossDockDeckCentreOffsetX -
          bossDockDeckWidth / 2;
      // Slot 0's wagon art ends at x = 1440 + 119.1/2.
      final slot0Right = game.track.slotAt(0).x + vagaoDisplayWidth / 2;
      expect(deckLeft, greaterThan(slot0Right - 40));
      // And the whole prop stays inside the canvas. (Centre-anchored, so
      // this is the real box even though the sprite is mirrored.)
      expect(dock.position.x + dock.size.x / 2,
          lessThanOrEqualTo(game.arenaConfig.canvas.width));
    });
  });

  // ---------------------------------------------------------------------------
  // Frente 3 — HP, phases and the punish window
  // ---------------------------------------------------------------------------

  group('HP, phases and the exposed window', () {
    test('the phase bands are the ones the design doc writes', () {
      expect(phaseForHpFraction(1.0), BossPhase.fase1);
      expect(phaseForHpFraction(0.66), BossPhase.fase1);
      expect(phaseForHpFraction(0.659), BossPhase.fase2);
      expect(phaseForHpFraction(0.33), BossPhase.fase2);
      expect(phaseForHpFraction(0.329), BossPhase.fase3);
      expect(phaseForHpFraction(0), BossPhase.fase3);

      // And max HP is chosen so whole numbers of hits land in each band.
      expect(phaseForHpFraction(8 / bossMaxHp), BossPhase.fase1);
      expect(phaseForHpFraction(7 / bossMaxHp), BossPhase.fase2);
      expect(phaseForHpFraction(4 / bossMaxHp), BossPhase.fase2);
      expect(phaseForHpFraction(3 / bossMaxHp), BossPhase.fase3);
    });

    test('the boss is invulnerable outside the exposed window', () async {
      final game = await bootGame();
      final boss = game.boss;

      expect(boss.isExposed, isFalse);
      expect(boss.takeDamage(1), isFalse);
      expect(boss.hp, bossMaxHp);

      boss.enterExposed(1.5);
      expect(boss.isExposed, isTrue);
      expect(boss.takeDamage(1), isTrue);
      expect(boss.hp, bossMaxHp - 1);
    });

    test('a player attack only damages inside the window', () async {
      final game = await bootGame();
      await settle(game);

      expect(
        game.attackDirector.resolvePlayerAttack(),
        AttackOutcome.missInvulnerable,
      );
      expect(game.boss.hp, bossMaxHp);

      game.boss.enterExposed(1.5);
      expect(game.attackDirector.resolvePlayerAttack(), AttackOutcome.hit);
      expect(game.boss.hp, lessThan(bossMaxHp));
    });

    test('the exposed window closes on its own', () async {
      final game = await bootGame();
      game.boss.enterExposed(0.2);
      expect(game.boss.isExposed, isTrue);
      for (var i = 0; i < 30; i++) {
        game.boss.update(1 / 60);
      }
      expect(game.boss.isExposed, isFalse);
      expect(game.boss.takeDamage(1), isFalse);
    });

    test('crossing a threshold fires exactly one phase transition',
        () async {
      final game = await bootGame();
      final seen = <BossPhase>[];
      final boss = VagoneiroBoss(
        position: Vector2(1530, 760),
        facing: 'left',
        track: game.track,
        container: game.world,
        onPhaseChanged: seen.add,
      );
      await game.world.add(boss);
      await settle(game, frames: 5);

      // 12 -> 7 crosses 0.66; 7 -> 3 crosses 0.33.
      for (final target in [7, 3]) {
        while (boss.hp > target) {
          boss.enterExposed(1);
          boss.takeDamage(1);
        }
      }
      expect(seen, [BossPhase.fase2, BossPhase.fase3]);
    });
  });

  // ---------------------------------------------------------------------------
  // InserirNo — the inviolable rule
  // ---------------------------------------------------------------------------

  group('InserirNo', () {
    test('relabels slots without physically moving a single wagon',
        () async {
      final game = await bootGame();
      await settle(game);

      final positionsBefore = {
        for (final slot in game.track.slots)
          if (slot.vagao != null) slot.index: slot.vagao!.position.clone(),
      };
      expect(positionsBefore.length, 8, reason: 'the test track starts full');

      game.boss.insertAtHead();

      for (final slot in game.track.slots) {
        final vagao = slot.vagao;
        if (vagao == null) {
          continue;
        }
        // Design doc section 3.0, inviolable: a wagon is never repositioned.
        // Every wagon that is still on the track is at its own slot's fixed
        // coordinate, exactly as it was drawn.
        expect(
          vagao.position,
          Vector2(slot.x, slot.y),
          reason: 'wagon at slot ${slot.index} was moved',
        );
      }
    });

    test('a full track drops its end wagon instead of overflowing',
        () async {
      final game = await bootGame();
      await settle(game);

      final tailBefore = game.track.slots.last.vagao;
      expect(tailBefore, isNotNull);

      game.boss.insertAtHead();

      // The end-of-line wagon is out of the list immediately (so the
      // relabel can refill the slot in the same frame) and is falling.
      expect(tailBefore!.state, VagaoState.falling);
      expect(identical(game.track.slots.last.vagao, tailBefore), isFalse);
      // The list is still exactly as long as it was.
      expect(game.track.slots.length, 8);
      for (final slot in game.track.slots) {
        expect(slot.vagao, isNotNull, reason: 'slot ${slot.index} left empty');
      }
    });

    test('a gap in the middle shifts one index along', () async {
      final game = await bootGame();
      await settle(game);

      // Empty the whole track, then occupy only 0 and 1.
      for (final slot in game.track.slots) {
        game.boss.clearSlot(slot.index);
      }
      game.boss.occupySlot(0);
      game.boss.occupySlot(1);

      final moved = game.boss.insertAtHead();
      expect(moved, {0: 1, 1: 2});

      await settle(game, frames: 5);
      for (final index in [0, 1, 2]) {
        expect(game.track.slotAt(index).vagao, isNotNull);
      }
      for (final index in [3, 4, 5, 6, 7]) {
        expect(game.track.slotAt(index).vagao, isNull);
      }
    });

    test('the insertion point is always slot 0', () async {
      final game = await bootGame();
      await settle(game);

      // Mudança 1 (b): "sempre no slot 0". Módulo 14 could push from
      // either end (`origin: TrackEnd.tail`); that parameter went with
      // Lista Dupla. Occupying only the far end and pushing must still
      // shift *away* from slot 0, never towards it.
      for (final slot in game.track.slots) {
        game.boss.clearSlot(slot.index);
      }
      game.boss.occupySlot(6);

      final moved = game.boss.insertAtHead();
      expect(moved, {6: 7});
      expect(game.track.slotAt(0).vagao, isNotNull,
          reason: 'the new node belongs at slot 0');
      expect(game.track.slotAt(5).vagao, isNull);
    });
  });

  group('the operation HUD', () {
    test('the arena wires the boss operations into the ticker', () async {
      final game = await bootGame();
      await settle(game);

      game.boss.clearSlot(3);
      expect(game.combatHud.currentOperation, 'clearSlot(3)');

      game.boss.occupySlot(3);
      expect(game.combatHud.currentOperation, 'occupySlot(3)');

      game.boss.removerNo(3);
      expect(game.combatHud.currentOperation, contains('removerNo(slot[3])'));
    });

    test('InserirNo announces itself and every slot write it makes',
        () async {
      final game = await bootGame();
      await settle(game);

      // The ticker only ever holds the latest line, so the *sequence* is
      // checked at the source — which is also the contract the HUD relies
      // on: every mutation, not just the headline one, is announced.
      final operations = <String>[];
      final boss = VagoneiroBoss(
        position: Vector2(1530, 760),
        facing: 'left',
        track: game.track,
        container: game.world,
        onOperation: operations.add,
      );
      await game.world.add(boss);
      await settle(game, frames: 5);

      boss.insertAtHead();

      expect(operations.first, contains('pop()'));
      expect(operations, contains('insertAtHead(novoVagao)'));
      expect(operations.last, startsWith('occupySlot('));
    });
  });

  // ---------------------------------------------------------------------------
  // Player damage
  // ---------------------------------------------------------------------------

  group('player damage', () {
    test('a hit costs one HP and then buys immunity', () async {
      final game = await bootGame();
      await settle(game);

      expect(game.player.hp, playerMaxHp);
      expect(
        game.player.takeCombatDamage(1, reason: 'teste'),
        isTrue,
      );
      expect(game.player.hp, playerMaxHp - 1);

      // A second source noticing the same mistake in the same second
      // cannot charge for it again.
      expect(game.player.takeCombatDamage(1, reason: 'teste'), isFalse);
      expect(game.player.hp, playerMaxHp - 1);
    });

    test('running out of HP restarts the fight from any damage source',
        () async {
      final game = await bootGame();
      await settle(game);

      // Get the boss out of phase 1 first, so the restart has a phase to
      // roll back.
      game.boss.enterExposed(5);
      while (game.boss.phase == BossPhase.fase1) {
        game.boss.takeDamage(1);
      }
      await settle(game, frames: 10);

      // Park the player on a wagon first: the whole game is pumped between
      // hits (to let the invulnerability window expire), so a player left
      // in mid-air would fall past the death line and be charged extra
      // damage by the very system under test.
      final slot = game.track.slotAt(0);
      game.player.position.setValues(slot.x, slot.y - 60);
      await settle(game, frames: 20);

      for (var i = 0; i < playerMaxHp; i++) {
        game.player.takeCombatDamage(1, reason: 'teste');
        // Slightly more than `playerInvulnerabilityDuration` of game time.
        await settle(game, frames: 70);
      }

      expect(game.player.hp, playerMaxHp, reason: 'the fight restarted');
      expect(game.boss.hp, bossMaxHp);
      expect(game.boss.phase, BossPhase.fase1);
      expect(game.player.jumpsRemaining, playerMaxJumps);
    });

    test('RemoverNo under the player is combat damage, not just a fall',
        () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      // Put the player on a wagon and let the collision resolve.
      final slot = game.track.slotAt(0);
      game.player.position.setValues(slot.x, slot.y - 60);
      await settle(game, frames: 20);

      final hpBefore = game.player.hp;
      game.boss.removerNo(0);
      // 1.2s of telegraph on the wall clock, then `falling` flips isSolid
      // and the player's next update reports the lost support.
      await settleRealTime(game, 1.8);

      expect(
        game.player.hp,
        lessThan(hpBefore),
        reason: 'losing the floor to RemoverNo must cost a hit point',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Módulo 15 — the playtest correction pass
  // ---------------------------------------------------------------------------

  group('Mudança 1 — the roster is exactly two primitives', () {
    test('BossAttack has two values and nothing else', () {
      expect(
        BossAttack.values,
        [BossAttack.removerNo, BossAttack.inserirNo],
        reason: 'a third attack would have to be added here first',
      );
    });

    test('a long fight only ever runs those two', () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      for (var i = 0; i < 6; i++) {
        await game.attackDirector.runNextAttack();
      }

      expect(game.attackDirector.executed, isNotEmpty);
      expect(
        game.attackDirector.executed,
        everyElement(isIn(BossAttack.values)),
      );
    });

    test('phases differ in cadence only, never in capability', () {
      // Faster, and more of the same: the three cadences must be strictly
      // ordered by tempo, and must not introduce anything phase 1 lacks
      // beyond "how many" and "how fast".
      expect(cadenceFase2.interval, lessThan(cadenceFase1.interval));
      expect(cadenceFase3.interval, lessThan(cadenceFase2.interval));
      expect(cadenceFase2.telegraphMin, lessThan(cadenceFase1.telegraphMin));
      expect(cadenceFase3.telegraphMin, lessThan(cadenceFase2.telegraphMin));

      // Phase 1 is the 1.2-1.5s window the brief pins down, exactly.
      expect(cadenceFase1.telegraphMin, 1.2);
      expect(cadenceFase1.telegraphMax, 1.5);

      // Phase 2 is "~30% mais rápido".
      expect(cadenceFase2.interval / cadenceFase1.interval, closeTo(0.7, 1e-9));

      // What each phase permits, as the brief words it.
      expect(cadenceFase1.maxSimultaneousHoles, 1);
      expect(cadenceFase2.maxSimultaneousHoles, 2);
      expect(cadenceFase2.maxChainedInsertions, 2);
      expect(cadenceFase1.canChainRemoveThenInsert, isFalse);
      expect(cadenceFase2.canChainRemoveThenInsert, isFalse);
      expect(cadenceFase3.canChainRemoveThenInsert, isTrue);

      // And the telegraph never compresses to the point of being
      // unreadable, which is where "harder" would become "unfair".
      for (final cadence in [cadenceFase1, cadenceFase2, cadenceFase3]) {
        expect(cadence.telegraphMin, greaterThan(0.5));
      }
    });
  });

  group('Mudança 1 (a) — RemoverNo never opens adjacent holes', () {
    test('a slot beside an existing hole is not a candidate', () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      // With a full track every slot is fair game.
      expect(game.attackDirector.removableSlots().length, 8);

      // Punch one hole and both of its neighbours must drop out of the
      // selection — and the hole itself, which has nothing to remove.
      game.boss.clearSlot(4);
      expect(
        game.attackDirector.removableSlots(),
        isNot(anyElement(isIn([3, 4, 5]))),
      );
      expect(
        game.attackDirector.removableSlots(),
        containsAll([0, 1, 2, 6, 7]),
      );
    });

    test('a neighbour that is only *becoming* a hole also blocks it',
        () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      // This is the case a naive "is the slot empty?" check misses: slot 4
      // is still solid and still occupied, but it is trembling and will be
      // a hole in about a second — so removing 3 or 5 now would produce
      // the forbidden adjacent pair a moment later.
      game.boss.removerNo(4);
      await settle(game, frames: 5);
      expect(game.track.slotAt(4).vagao!.state, VagaoState.tremor);

      expect(
        game.attackDirector.removableSlots(),
        isNot(anyElement(isIn([3, 4, 5]))),
      );
    });

    test('the ends of the track are walls, not holes', () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      // Off-track indices must not count as gaps — otherwise slot 0 and
      // slot 7 could never be removed at all.
      expect(game.attackDirector.removableSlots(), contains(0));
      expect(game.attackDirector.removableSlots(), contains(7));
    });

    test('no sequence of real attacks can produce an adjacent pair',
        () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      // Drive the boss into phase 3 — the fastest cadence, two holes
      // allowed, and RemoverNo chained straight into InserirNo — and check
      // the invariant after every beat. This is the acceptance criterion
      // stated as a property, not as a single arrangement.
      while (game.boss.phase != BossPhase.fase3) {
        game.boss.enterExposed(1);
        game.boss.takeDamage(1);
      }
      expect(game.boss.phase, BossPhase.fase3);

      for (var beat = 0; beat < 6; beat++) {
        await game.attackDirector.runNextAttack();
        await settle(game, frames: 10);
        for (var i = 0; i < game.track.slots.length - 1; i++) {
          final a = game.track.slotAt(i).vagao;
          final b = game.track.slotAt(i + 1).vagao;
          expect(
            a == null && b == null,
            isFalse,
            reason: 'slots $i and ${i + 1} were both empty after beat $beat',
          );
        }
      }
    });
  });

  group('Mudança 3 — double jump', () {
    test('two presses spend both jumps and a landing gives them back',
        () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      final slot = game.track.slotAt(0);
      game.player.position.setValues(slot.x, slot.y - 60);
      await settle(game, frames: 30);
      expect(game.player.jumpsRemaining, playerMaxJumps);
      expect(playerMaxJumps, 2);

      // Press, release, press again — the release matters, since one held
      // key must not spend both jumps on consecutive frames.
      game.debugHoldJumpForTest(true);
      game.update(1 / 60);
      expect(game.player.jumpsRemaining, 1, reason: 'ground jump');

      // Held down: still one jump left.
      game.update(1 / 60);
      game.update(1 / 60);
      expect(
        game.player.jumpsRemaining,
        1,
        reason: 'holding the key must not spend the air jump',
      );

      game.debugHoldJumpForTest(false);
      game.update(1 / 60);
      game.debugHoldJumpForTest(true);
      game.update(1 / 60);
      expect(game.player.jumpsRemaining, 0, reason: 'air jump');

      // A third press in the air does nothing.
      game.debugHoldJumpForTest(false);
      game.update(1 / 60);
      game.debugHoldJumpForTest(true);
      game.update(1 / 60);
      expect(game.player.jumpsRemaining, 0);

      game.debugHoldJumpForTest(false);
      await settle(game, frames: 150);
      expect(
        game.player.jumpsRemaining,
        playerMaxJumps,
        reason: 'landing refills the jumps',
      );
    });

    test('the second jump adds real height over a single one', () {
      // The acceptance criterion is "can safely cross an isolated hole and
      // a sequence of two non-adjacent holes". What makes that true is
      // that the air jump is a full impulse, so the apex it adds is the
      // same ~145px the first one reaches — enough to re-clear a 180px gap
      // from mid-flight.
      final singleApex =
          (playerJumpVelocity * playerJumpVelocity) / (2 * playerGravity);
      final airImpulse = playerJumpVelocity * playerDoubleJumpVelocityFactor;
      final secondApex = (airImpulse * airImpulse) / (2 * playerGravity);

      expect(singleApex, closeTo(145, 0.5));
      expect(secondApex, closeTo(singleApex, 0.5));
    });
  });

  group('Mudança 2 — the shove reads as a shove', () {
    test('the tween is eased and inside the 0.35-0.5s window', () {
      expect(empurraoPlayerTweenDuration, greaterThanOrEqualTo(0.35));
      expect(empurraoPlayerTweenDuration, lessThanOrEqualTo(0.5));
      expect(GameCurves.impactOut, isNot(Curves.linear));
    });

    test('the landing squash is a 10-15% compression over 2-3 frames', () {
      final compression = 1 - empurraoLandSquashFactor;
      expect(compression, greaterThanOrEqualTo(0.10));
      expect(compression, lessThanOrEqualTo(0.15));

      final frames = empurraoLandSquashDuration * 60;
      expect(frames, greaterThanOrEqualTo(2));
      expect(frames, lessThanOrEqualTo(3));
    });

    test('the shove eases across time and springs back to the base scale',
        () async {
      final game = await bootGame();
      await settle(game, frames: 60);

      final slot = game.track.slotAt(0);
      game.player.position.setValues(slot.x, slot.y - 60);
      await settle(game, frames: 30);

      // Aim at the real standing surface of slot 3, the way InserirNo does
      // — a target in mid-air would just let gravity carry the player past
      // the death line and respawn them, which is not what is under test.
      final destination = game.track.slotAt(3);
      final target = Vector2(
        destination.x,
        destination.vagao!.platformHitbox.absoluteTopLeftPosition.y,
      );
      final startX = game.player.position.x;
      game.player.shoveToSlot(target);

      // Mid-tween: the player is on the way, not already there — an
      // instantaneous move would fail this.
      await settle(game, frames: 6);
      expect(game.player.isBeingMoved, isTrue);
      expect(game.player.position.x, isNot(closeTo(startX, 0.5)));
      expect(game.player.position.x, isNot(closeTo(target.x, 0.5)));

      // And it arrives, with the squash fully sprung back so the resting
      // size is bit-for-bit the calibrated one.
      await settle(game, frames: 120);
      expect(game.player.isBeingMoved, isFalse);
      expect(game.player.position.x, closeTo(target.x, 1));
      expect(
        game.player.debugVisualScaleForTest.y,
        closeTo(playerDisplayScale, 1e-6),
        reason: 'the squash must spring back to exactly the calibrated scale',
      );
    });
  });

  group('Mudança 4 — the boss faces the player', () {
    test('the sheet is drawn right-facing, so a left-facing boss is mirrored',
        () async {
      final game = await bootGame();
      await settle(game, frames: 10);

      expect(game.boss.facing, 'left');
      expect(bossSheetNativeFacing, 'right');
      // flipHorizontally() negates scale.x. Before the Módulo 15 fix this
      // was +1 and the boss spent the fight looking away from the track.
      expect(game.boss.scale.x, lessThan(0));
    });

    test('the flip is a render transform only — the calibration is intact',
        () async {
      final game = await bootGame();
      await settle(game, frames: 10);

      // Mirroring must not move the boss, resize him, or shift the body
      // collider off centre — that is what would make the flip a
      // regression rather than a fix.
      expect(game.boss.position.x, game.arenaConfig.boss.x);
      expect(game.boss.size.x, closeTo(bossFrameSize * bossDisplayScale, 1e-3));
      expect(game.boss.scale.x.abs(), 1.0);
      // Vector2 is Float32List-backed, so this is a float32 round-trip of
      // a double — compare at single-precision tolerance, not 1e-6.
      expect(
        game.boss.bodyHitbox.position.x,
        closeTo(game.boss.size.x / 2, 1e-3),
      );
    });

    test('the track really does run to the boss left', () async {
      final game = await bootGame();
      // The geometric fact the fix is about: every slot sits at a smaller
      // x than the boss, so "facing the player" means facing left.
      for (final slot in game.track.slots) {
        expect(slot.x, lessThan(game.boss.position.x));
      }
    });
  });

  group('Mudança 5 — one easing curve for combat/movement', () {
    test('the project curve is a real ease-out, evaluated consistently', () {
      expect(GameCurves.softOut, Curves.easeOutCubic);

      // The scalar helper and the Curve must be the same function — the
      // whole point of the file is that the tween path and the per-frame
      // lerp path cannot drift apart.
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(
          GameCurves.softOutAt(t),
          closeTo(GameCurves.softOut.transform(t), 1e-9),
        );
      }

      // Ease-*out*: most of the distance is covered early.
      expect(GameCurves.softOutAt(0.5), greaterThan(0.5));
      expect(GameCurves.softOutAt(0), 0);
      expect(GameCurves.softOutAt(1), 1);
      // And it clamps, so a lerp that overruns its interval cannot
      // overshoot the target.
      expect(GameCurves.softOutAt(1.4), 1);
      expect(GameCurves.softOutAt(-0.2), 0);
    });
  });
}
