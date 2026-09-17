import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flame/components.dart';

import '../../../shared/fx/combat_flash.dart';
import '../../../shared/hud/combat_hud.dart';
import '../../../shared/player/player.dart';
import '../track/linear_track.dart';
import '../track/slot.dart';
import '../wagon/vagao.dart';
import 'boss_combat.dart';
import 'vagoneiro_boss.dart';
import '../fx/linked_list_fx_config.dart';
import '../fx/slot_highlight.dart';

/// Módulo 15, Frente 3 — the fight itself, cut down to two primitives.
///
/// Owns *when* things happen; [VagoneiroBoss] owns *what* they do to the
/// list. The split matters: every list mutation here goes through
/// `boss.removerNo` / `boss.insertAtHead`, which are themselves written
/// purely in terms of `occupySlot` / `clearSlot`, so the design doc's
/// section 3.0 rule (a `Vagao` never moves between slots; only the boss
/// inserts and removes) is enforced by the fact that this class has no
/// other way to touch a slot.
///
/// **The roster is two attacks and the type system says so.** [BossAttack]
/// has exactly two values and [_execute] is an exhaustive switch over it,
/// so a third attack cannot be added here without the compiler asking for
/// it by name — which is the check Mudança 1 asks to hold permanently, not
/// just on the day it was written. Corrente Restritiva, Lista Dupla, Nó
/// Órfão and Ciclo Corrompido are gone: no telegraph, no pointer
/// corruption, no unlinked node, no `TrackEnd`, no reversibility flag.
///
/// The three phases differ only in [PhaseCadence] — how fast, how many
/// holes at once, what may be chained. Never in what an attack *does*.
class AttackDirector extends Component {
  final VagoneiroBoss boss;
  final LinearTrack track;
  final Player player;

  /// Where overlays are added — the game world, in the same coordinate
  /// space as the slots.
  final Component overlayParent;

  final CombatHud hud;

  /// Small screen shake, reusing the arena's existing camera director.
  /// Called on the frame the new wagon lands in slot 0 (Mudança 2).
  final void Function() shakeCamera;

  /// Spawns `dust-poof.png` at a world point. Supplied as a callback for
  /// the same reason [Player.onLanded] is: this class stays free of any
  /// asset knowledge, and the arena keeps owning the one place that
  /// decides what a puff of dust looks like (Mudança 2).
  final void Function(Vector2 position) spawnDust;

  AttackDirector({
    required this.boss,
    required this.track,
    required this.player,
    required this.overlayParent,
    required this.hud,
    required this.shakeCamera,
    required this.spawnDust,
  });

  final math.Random _random = math.Random();

  /// Seconds until the next attack fires.
  double _nextAttackIn = 2.5;

  /// True while an attack's telegraph/execution is running, so the
  /// scheduler cannot start a second one on top of it.
  bool _busy = false;

  /// The attack rotation position, so the fight alternates its two
  /// primitives instead of picking at random and repeating itself.
  int _rotation = 0;

  /// Set to true once the fight is over (either side).
  bool _finished = false;

  /// The last outcome resolved, kept for the debug harness and the tests.
  AttackOutcome? lastOutcome;

  /// The last sequence of primitives the boss actually ran, newest last.
  /// Exposed for the tests and the debug harness: it is the cheapest way
  /// to assert "the roster really is two attacks" against a live fight.
  final List<BossAttack> executed = [];

  PhaseCadence get cadence => cadenceFor(boss.phase);

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished || _busy || boss.isDefeated || player.isDefeated) {
      return;
    }

    // The boss does not start a new attack while he is still being
    // punished for the last one — the exposed window is the player's turn.
    if (boss.isExposed) {
      _nextAttackIn = cadence.interval;
      return;
    }

    _nextAttackIn -= dt;
    if (_nextAttackIn > 0) {
      return;
    }
    _nextAttackIn = cadence.interval;
    runNextAttack();
  }

  /// Runs the next beat of the fight for the current phase.
  ///
  /// A "beat" is one primitive, or — from phase 2 — a short chain of them.
  /// A chain is still only ever made of the same two primitives, played
  /// closer together: [PhaseCadence.chainGap] apart instead of a full
  /// [PhaseCadence.interval]. That is the whole of the phase progression
  /// (Mudança 1: "só de cadência e combinação").
  Future<void> runNextAttack() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final phaseCadence = cadence;
      final opener = _nextInRotation();

      await _execute(opener);

      // Phase 2: insertions may come twice in a row.
      if (opener == BossAttack.inserirNo) {
        for (var i = 1; i < phaseCadence.maxChainedInsertions; i++) {
          if (_finished || boss.isDefeated || player.isDefeated) {
            return;
          }
          await _wait(phaseCadence.chainGap);
          await _execute(BossAttack.inserirNo);
        }
        return;
      }

      // Phase 3: a removal may be followed immediately by an insertion —
      // the hole opens and the rail shifts under the player before they
      // have finished reading the first half.
      if (opener == BossAttack.removerNo &&
          phaseCadence.canChainRemoveThenInsert) {
        if (_finished || boss.isDefeated || player.isDefeated) {
          return;
        }
        await _wait(phaseCadence.chainGap);
        await _execute(BossAttack.inserirNo);
      }
    } finally {
      _busy = false;
    }
  }

  /// Alternates the two primitives. Deliberately a rotation and not a coin
  /// flip: with only two attacks left, random selection would visibly
  /// stutter (three removals in a row reads as the fight having stalled).
  BossAttack _nextInRotation() {
    final attack = BossAttack.values[_rotation % BossAttack.values.length];
    _rotation++;
    // A removal with nothing legal to remove would be a dead beat; swap to
    // the insertion rather than skipping the turn entirely.
    if (attack == BossAttack.removerNo && removableSlots().isEmpty) {
      return BossAttack.inserirNo;
    }
    return attack;
  }

  /// The exhaustive dispatch. Adding a third [BossAttack] breaks the build
  /// here — by design.
  Future<void> _execute(BossAttack attack) async {
    executed.add(attack);
    switch (attack) {
      case BossAttack.removerNo:
        await removerNo();
      case BossAttack.inserirNo:
        await inserirNo();
    }
  }

  /// A telegraph length inside this phase's window, re-rolled per attack so
  /// the wind-up is readable but never metronomic.
  double _telegraphDuration() {
    final c = cadence;
    return c.telegraphMin +
        _random.nextDouble() * (c.telegraphMax - c.telegraphMin);
  }

  // ---------------------------------------------------------------------------
  // Phase transitions
  // ---------------------------------------------------------------------------

  /// Wired to `boss.onPhaseChanged`.
  ///
  /// Módulo 15: this used to be where phase 2 unlocked reversibility, gold
  /// chains and the orphan node. It unlocks nothing now — a phase change
  /// is a change of tempo, announced and otherwise inert, which is exactly
  /// what Mudança 1 asks the progression to be.
  void onPhaseChanged(BossPhase phase) {
    final c = cadenceFor(phase);
    hud.showCaption(phase.label, duration: 2.0);
    hud.showOperation(
      'cadência: telegraph ${c.telegraphMin.toStringAsFixed(2)}'
      '-${c.telegraphMax.toStringAsFixed(2)}s · '
      'intervalo ${c.interval.toStringAsFixed(2)}s · '
      'até ${c.maxSimultaneousHoles} buraco(s)',
    );
    _log(
      'fase -> ${phase.name}: mesmas duas primitivas, '
      'intervalo ${c.interval.toStringAsFixed(2)}s',
    );
  }

  // ---------------------------------------------------------------------------
  // (a) RemoverNo — Mudança 1 (a)
  // ---------------------------------------------------------------------------

  /// Every slot the boss is **allowed** to remove right now.
  ///
  /// This is the single place the non-adjacency rule lives, and it is
  /// applied at the moment of selection rather than checked afterwards, so
  /// there is no window in which an illegal pair exists (Mudança 1 (a):
  /// "nunca pode haver dois buracos adjacentes ao mesmo tempo, sob nenhuma
  /// circunstância, em nenhuma fase").
  ///
  /// A slot is a candidate when:
  ///  * it holds a wagon that is currently `idle` — a wagon still
  ///    `spawning`, already trembling or already falling is not a node the
  ///    boss can decide to remove; and
  ///  * **neither** immediate neighbour (`i-1`, `i+1`) is already a hole
  ///    or on its way to becoming one. [_isHoleOrBecomingOne] treats
  ///    `tremor`, `falling`, `removed` and "empty" as the same thing on
  ///    purpose: by the time this removal's own tremor finishes, a
  ///    neighbour that is trembling *now* will be a hole, so allowing it
  ///    would produce the forbidden adjacent pair a second later. Checking
  ///    only for present emptiness is the bug that lets two holes open
  ///    side by side.
  ///
  /// The phase's [PhaseCadence.maxSimultaneousHoles] is applied on top by
  /// [removerNo] — it caps *how many*, while this caps *where*.
  List<int> removableSlots() {
    final candidates = <int>[];
    for (final slot in track.slots) {
      final vagao = slot.vagao;
      if (vagao == null || vagao.state != VagaoState.idle) {
        continue;
      }
      if (_isHoleOrBecomingOne(slot.index - 1) ||
          _isHoleOrBecomingOne(slot.index + 1)) {
        continue;
      }
      candidates.add(slot.index);
    }
    return candidates;
  }

  /// Whether [index] is, or is about to become, a gap in the rail.
  ///
  /// Out-of-range indices are **not** holes: the ends of the track are
  /// walls, not missing nodes, and treating them as gaps would forbid the
  /// boss from ever removing slot 0 or slot N-1.
  bool _isHoleOrBecomingOne(int index) {
    if (index < 0 || index >= track.slots.length) {
      return false;
    }
    final vagao = track.slotAt(index).vagao;
    if (vagao == null) {
      return true;
    }
    return vagao.state == VagaoState.tremor ||
        vagao.state == VagaoState.falling ||
        vagao.state == VagaoState.removed;
  }

  /// How many holes (present or imminent) the rail already has.
  int get openHoleCount => [
        for (var i = 0; i < track.slots.length; i++)
          if (_isHoleOrBecomingOne(i)) i,
      ].length;

  /// **RemoverNo.** Picks a legal occupied slot, plays the existing
  /// `tremor -> falling` sequence on it, and leaves `slot[i].vagao = null`.
  ///
  /// The damage path is the pre-existing one and nothing else: if the
  /// player is standing on the wagon when it enters `falling`,
  /// `Player.update` notices `isSolid` flip, drops them and fires
  /// `onSupportLost`, which the arena charges as [removerNoDamage]. No new
  /// hitbox, no new state (Mudança 1 (a)).
  Future<void> removerNo() async {
    if (openHoleCount >= cadence.maxSimultaneousHoles) {
      // The rail already has as many gaps as this phase allows. Not a
      // skipped turn — the scheduler will come back on the next beat.
      _log('removerNo abortado: $openHoleCount buraco(s) já abertos');
      return;
    }

    final candidates = removableSlots();
    if (candidates.isEmpty) {
      _log('removerNo abortado: nenhum slot elegível (regra de adjacência)');
      return;
    }

    // Prefer the slot the player is standing on: an attack that threatens
    // nothing is not a telegraph, it is scenery.
    final target = candidates.contains(player.currentSlotIndex)
        ? player.currentSlotIndex
        : candidates[_random.nextInt(candidates.length)];

    boss.playState(BossState.observing);
    hud.showOperation('mirando slot[$target] — removerNo');

    // Rolled once and held: `SlotHighlight.remaining` counts itself down
    // from the frame it mounts, so reading it back after the `await` would
    // wait for slightly less than the telegraph the player was shown.
    final telegraph = _telegraphDuration();
    await overlayParent.add(
      SlotHighlight(
        position: Vector2(
          track.slotAt(target).x,
          track.slotAt(target).y - slotTelegraphHeightAboveGround,
        ),
        remaining: telegraph,
        color: removerNoTelegraphColor,
      ),
    );
    await _wait(telegraph);

    // Re-check: the telegraph is long enough for the arrangement to have
    // changed under it (a chained insertion in phase 3 relabels every
    // slot). The rule is about the state at the moment of removal, so it
    // is verified again here rather than trusted from before the wait.
    if (!removableSlots().contains(target)) {
      _log('removerNo($target) cancelado: deixou de ser elegível');
      boss.playState(BossState.idle);
      return;
    }

    boss.playState(BossState.chainAttack);
    hud.showCaption('Nó removido.', duration: 1.2);
    boss.removerNo(target);

    // The wagon owns the rest of the timing (tremor + fall); the director
    // only needs to stay out of the way while it plays.
    await _wait(vagaoTremorDuration);
    boss.playState(BossState.idle);
  }

  // ---------------------------------------------------------------------------
  // (b) InserirNo — Mudança 1 (b) + Mudança 2
  // ---------------------------------------------------------------------------

  /// **InserirNo.** Inserts a new node at slot 0 — always slot 0, the end
  /// of the rail the boss stands at — and relabels the logical contents of
  /// `slot[0..N-2]` into `slot[1..N-1]`.
  ///
  /// No `Vagao` component is repositioned (design doc section 3.0). The
  /// only thing that physically moves is the **player**, tweened to the
  /// new position of the content they were standing on. That is also what
  /// sells the push — the shove is felt, not simulated — and Mudança 2 is
  /// entirely about making that tween read as a shove instead of a cut.
  Future<void> inserirNo() async {
    boss.playState(BossState.observing);
    hud.showOperation('apito — empurrão vindo do slot[0]');

    // See removerNo: the duration is held rather than read back off the
    // component, which starts counting down as soon as it mounts.
    final telegraph = _telegraphDuration();
    await overlayParent.add(
      SlotHighlight(
        position: Vector2(
          track.slotAt(0).x,
          track.slotAt(0).y - slotTelegraphHeightAboveGround,
        ),
        remaining: telegraph,
        color: inserirNoTelegraphColor,
      ),
    );
    await _wait(telegraph);

    boss.playState(BossState.chainAttack);

    final endIndex = track.slots.length - 1;
    final playerIndexBefore = player.currentSlotIndex;
    final playerWasOnEnd = playerIndexBefore == endIndex &&
        (track.slotAt(endIndex).vagao?.isSolid ?? false);

    final movedTo = boss.insertAtHead();

    // Mudança 2: the impact frame. The new wagon arrives in slot 0 — shake
    // the screen and kick up dust at its base on the same frame the
    // relabel lands, so the push has a physical origin rather than just a
    // consequence.
    shakeCamera();
    spawnDust(Vector2(track.slotAt(0).x, track.slotAt(0).y));

    if (playerWasOnEnd) {
      // Their node is the one that fell off the end of the line.
      hud.showCaption('Fim da linha.');
      player.takeCombatDamage(inserirNoDamage, reason: 'InserirNo');
    } else {
      final destination = movedTo[playerIndexBefore];
      if (destination != null) {
        final slot = track.slotAt(destination);
        hud.showOperation(
          'conteúdo de slot[$playerIndexBefore] agora em slot[$destination]',
        );
        // Only the player moves — the wagons stayed exactly where they
        // were drawn (section 3.0). Mudança 2: eased, with a landing
        // squash and a puff of dust where they touch down.
        player.shoveToSlot(
          Vector2(slot.x, _standingYFor(slot)),
          onSettled: spawnDust,
        );
      }
    }

    // Punish window: the boss overreached to shove the line, and is open
    // on the freshly inserted node for 1.5s.
    boss.enterExposed(bossExposedAfterInsercao);
  }

  // ---------------------------------------------------------------------------
  // Player attacks
  // ---------------------------------------------------------------------------

  /// Resolves one player attack: the boss takes damage **only** inside his
  /// exposed window, and is invulnerable outside it.
  ///
  /// Módulo 15: called when the sword's live hitbox touches the boss (see
  /// `Player.onSwordContact`), no longer straight from the `J` key. The
  /// swing animation belongs to the player's `AttackController`.
  ///
  /// With the orphan node and the cycle window gone, this is the whole
  /// rule set — the two special cases that used to sit in front of it went
  /// with the attacks that created them.
  AttackOutcome resolvePlayerAttack() {
    if (boss.isExposed) {
      boss.takeDamage(playerAttackDamage);
      _spawnFlash(
        CombatFlash.hit(Vector2(boss.position.x, boss.visibleFootY - 80)),
      );
      shakeCamera();
      return lastOutcome = AttackOutcome.hit;
    }

    _spawnFlash(CombatFlash.miss(player.position));
    hud.showOperation('miss: boss invulnerável fora da janela exposed');
    return lastOutcome = AttackOutcome.missInvulnerable;
  }

  /// Where the player's feet belong when standing on [slot]: the top
  /// surface of that slot's wagon, not the slot's ground point.
  ///
  /// Read from the wagon's own `platformHitbox` when there is one — the
  /// same geometry `Player.onCollision` snaps to — so a tween lands the
  /// player exactly where a jump would have, instead of sinking them into
  /// the cart by the collider's height. Falls back to the calibrated
  /// offset when the slot is empty (the push can aim at a slot whose
  /// wagon is still spawning).
  double _standingYFor(Slot slot) {
    final vagao = slot.vagao;
    if (vagao != null && vagao.isLoaded) {
      return vagao.platformHitbox.absoluteTopLeftPosition.y;
    }
    return slot.y + vagaoColliderOffsetY - vagaoColliderHeight;
  }

  void _spawnFlash(CombatFlash flash) {
    overlayParent.add(flash);
  }

  /// Ends the fight (either side won) so the scheduler stops.
  void finish() {
    _finished = true;
    _busy = false;
  }

  /// Restarts the rotation for a fresh fight.
  void restart() {
    _finished = false;
    _busy = false;
    _rotation = 0;
    _nextAttackIn = 2.5;
    executed.clear();
    lastOutcome = null;
  }

  Future<void> _wait(double seconds) =>
      Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

  void _log(String message) {
    developer.log(message, name: 'AttackDirector');
    // ignore: avoid_print
    print('[AttackDirector] $message');
  }
}
