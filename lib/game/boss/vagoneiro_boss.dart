import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';

import '../fx/ambient_light.dart';
import '../track/linear_track.dart';
import '../wagon/vagao.dart';
import 'boss_combat.dart';

/// Boss animation states (see docs/boss-vagoneiro-design.md, section 4.1).
///
/// **Módulo 14:** the art behind these changed (the sombre humanoid was
/// replaced by the caricatured conductor sheet), and combat logic now
/// drives them for real, but the enum itself is untouched — same six
/// names, same meaning, same rows of the grid.
enum BossState { idle, observing, chainAttack, hit, exposed, recovering }

/// Path to the boss spritesheet.
///
/// **Módulo 14:** the file behind this path is the caricatured replacement
/// (design doc plano-jogo section 5: bosses are cartoon/Cuphead-flavoured,
/// in comic contrast with the serious world). It is **1800x1200, a grid of
/// 6 columns x 4 rows of 300x300 cells** — not the old 1536x1024/256px
/// grid. The delivered-asset map (Módulo 14, section 3.7) is the source of
/// truth for that geometry, and the row->state mapping of design doc
/// section 4.1 is preserved cell for cell, including the two empty cells
/// at the end of row 3.
///
/// Kept as one sheet sliced by grid position, deliberately: the delivered
/// art was renormalised so every frame sits at a consistent anchor point
/// *inside its own cell*, so splitting it into per-frame files would throw
/// that away and force a per-frame anchor offset table (section 3.7).
const String bossSpriteAssetPath = 'boss/sprite.png';
const double bossFrameSize = 300;
const int bossSheetColumns = 6;
const int bossSheetRows = 4;

/// Which way the character in `boss/sprite.png` is actually drawn.
///
/// **Módulo 15, Mudança 4.** Measured off the sheet during the playtest
/// pass rather than inherited from the design doc's prose: every cell of
/// the caricatured conductor faces screen-**right**. The doc's "perfil
/// voltado para a esquerda" describes the older, replaced art, and
/// Módulo 14 carried that sentence over to the new sheet without
/// re-checking it — which is the bug this constant closes.
///
/// Kept as a named constant instead of a bare `if (facing == 'right')` so
/// that the day the art *is* regenerated left-facing, the fix is this one
/// line and not a hunt for an inverted condition.
///
/// **Asymmetry check (required by Mudança 4), done on the art itself.**
/// The two asymmetric elements are the coiled chain, carried on the arm
/// nearest the viewer, and the round gold cap emblem, pinned to whichever
/// side of the cap faces the way he is looking. Mirroring carries both
/// across, which is precisely what turning around does to a real figure:
/// the chain stays on the near arm and the emblem stays on the leading
/// side of the cap. The emblem is a radially symmetric rosette — no text,
/// no numbering, no buckle or fastening that reads wrong reversed — so
/// nothing in the design carries handedness that a mirror would break.
/// **Verdict: the flip is visually correct; native left-facing
/// regeneration is not required.** Recorded here so the check is not
/// repeated from scratch every time someone reads the flip.
const String bossSheetNativeFacing = 'right';

/// Fileira 1 (index 0): `idle`, all 6 columns filled.
const int bossIdleRow = 0;
const int bossIdleFrameCount = 6;
const double bossIdleStepTime = 0.15;

/// Fileira 2 (index 1): columns 1-4 are `observing` (the boss sizing up
/// the track), columns 5-6 are the `chainAttack` wind-up. Reserved names in
/// Módulos 0-13; from Módulo 14 they are what the boss's slot selection
/// and the attack telegraphs actually play — `observing` while he picks a
/// node, `chainAttack` for the reach that executes it.
const int bossObservingRow = 1;
const int bossObservingFrameCount = 4;
const double bossObservingStepTime = 0.16;
const int bossChainAttackFrameOffset = 4;
const int bossChainAttackFrameCount = 2;
const double bossChainAttackStepTime = 0.18;

/// Fileira 3 (index 2): `hit`/`stunned`. Only 4 of the row's 6 columns have
/// art (design doc section 4.1, and re-verified on the replacement sheet:
/// cells (2,4) and (2,5) are fully transparent) — slicing all 6 would flash
/// empty frames at the end of the loop.
const int bossHitRow = 2;
const int bossHitFrameCount = 4;
const double bossHitStepTime = 0.12;

/// Fileira 4 (index 3): first 3 columns are `exposed`, last 3 are
/// `recovering` (design doc section 4.1).
const int bossExposedRecoveringRow = 3;
const int bossExposedFrameCount = 3;
const double bossExposedStepTime = 0.15;
const int bossRecoveringFrameCount = 3;
const double bossRecoveringStepTime = 0.15;

/// Native (unscaled) opaque content height of the boss's `idle` frames,
/// measured with a pixel-alpha bounding-box scan (threshold alpha > 10)
/// across all 6 columns of fileira 1 of `boss/sprite.png`.
///
/// **Re-measured in Módulo 14** against the replacement art (300px cells):
/// the six columns measure 233, 233, 241, 234, 236, 236 px, averaging
/// **235.5**. A raw measurement fact, independent of any target display
/// size — used below to derive [bossDisplayScale] from the *unchanged*
/// fixed target height.
const double bossOpaqueHeightNative = 235.5;

/// Transparent padding (native px) below the character's lowest opaque
/// pixel inside a 300px idle cell: the six idle columns bottom out at rows
/// 265, 265, 269, 266, 267, 267, averaging 266.5, so 299 - 266.5 = 32.5px
/// of empty cell sit under the boots.
///
/// This is the boss's equivalent of `playerFrameBottomPadNative`, and it
/// exists for the same reason (design doc section 2.3: the foot anchor is
/// the base of the frame's *real opaque content*, never the frame edge).
/// It is consumed by [visibleFootY] to tell the dock and the contact
/// shadow where the boss's feet actually are. Nothing writes `position`
/// with it: the boss's world position stays exactly the
/// `slots_config.json` value it always was.
const double bossFrameBottomPadNative = 32.5;

/// Display scale applied to the boss's rendered size (never to
/// [bossFrameSize], which stays the native cell size used to slice frames
/// from the spritesheet — this only decides how large the sliced frame is
/// drawn).
///
/// The target is the design doc section 2.3 value, unchanged and
/// non-negotiable: **176px** total height = 1.6x the player's 110px. Only
/// the native measurement feeding it moved, because the art did:
///   scale = 176 / 235.5 (bossOpaqueHeightNative) = 0.7473
/// Check: 235.5 * 0.7473 ≈ 176.0px, and 176 / 110 = 1.6x exactly. The
/// Módulo 11 value (176 / 232 on the old sheet) is recalculated from
/// scratch here rather than carried over — the same rule Módulo 11 itself
/// applied when the player art changed.
const double bossDisplayScale = 176 / bossOpaqueHeightNative;

/// Fixed logical hitbox representing the boss's solid body (design doc
/// section 11). Sized to the *core* of the character's art (excluding the
/// flared coat and the coiled chain on his arm), unchanged from Módulo 11
/// because the target height it is proportional to did not change.
///
/// This is a passive collider only: [Player]'s collision handling
/// special-cases [Vagao] platforms, so this hitbox does not push the
/// player back. Player attacks are resolved against *nodes* (see
/// `boss/attack_director.dart`), not against this box.
const double bossHitboxWidth = 78;
const double bossHitboxHeight = 156;

/// The boss "O Vagoneiro".
///
/// Two responsibilities, deliberately kept apart from the attack patterns
/// themselves (which live in `boss/attack_director.dart`):
///
///  * **the character** — standing at its fixed arena position, playing
///    whichever [BossState] the fight asks for;
///  * **the list operations** — [occupySlot] / [clearSlot] are still the
///    only way a wagon enters or leaves the track (design doc section 3.0),
///    and [insertAtHead] is expressed purely in terms of them, so the rule
///    that a `Vagao` never physically moves between slots holds by
///    construction.
class VagoneiroBoss extends SpriteAnimationComponent {
  /// `boss.facing` from slots_config.json — 'left' for this arena, and
  /// correctly so: the boss stands at the head end of the rail (x=1530,
  /// past slot 0 at x=1440) and the player arrives from the tail end, far
  /// to his left. He has to be looking at them.
  ///
  /// **Módulo 15, Mudança 4.** Módulo 11's comment here asserted that the
  /// delivered sheet was already drawn in left-facing profile, so
  /// `facing == 'left'` skipped the flip. Playtest showed the opposite:
  /// the replacement caricatured sheet is drawn facing *right*, and with
  /// the flip skipped the boss spent the whole fight looking away from the
  /// track. See [bossSheetNativeFacing] for the corrected convention — the
  /// art is not regenerated, only mirrored at render time.
  final String facing;

  final LinearTrack track;

  /// Component that hosts wagon components in world/game coordinate space
  /// (the same space slot.x/slot.y and this boss's own position are in).
  /// Passed explicitly instead of relying on `this.parent` so
  /// [occupySlot] can be called right after construction, before this
  /// component's own mount lifecycle finishes.
  final Component container;

  /// Fired whenever a list operation happens, with the operation written
  /// the way the player is meant to learn it (`occupySlot(0)`,
  /// `slot[7].next = null`, ...). Consumed by the HUD (Módulo 14
  /// acceptance criterion: "HUD de operação em execução").
  final void Function(String operation)? onOperation;

  /// Fired once per phase transition (Módulo 14, item 1).
  final void Function(BossPhase phase)? onPhaseChanged;

  /// Fired once, when [hp] reaches zero.
  final void Function()? onDefeated;

  /// Null until [onLoad] has decoded the sheet. Nullable rather than
  /// `late` because combat state can legitimately be driven before the
  /// component finishes loading — `occupySlot` is already called that way
  /// in this codebase — and a state change that arrives early must set the
  /// state and skip the repaint, not throw.
  SpriteSheet? _sheet;

  /// See [bossHitboxWidth]/[bossHitboxHeight].
  late final RectangleHitbox bodyHitbox;

  // --- Combat state ---------------------------------------------------------

  int hp = bossMaxHp;

  BossPhase _phase = BossPhase.fase1;
  BossPhase get phase => _phase;

  double get hpFraction => hp / bossMaxHp;

  bool get isDefeated => hp <= 0;

  /// Remaining seconds of the punish window. While positive the boss takes
  /// real damage; at zero he is invulnerable (Módulo 14, item 8).
  double _exposedRemaining = 0;
  bool get isExposed => _exposedRemaining > 0;
  double get exposedRemaining => _exposedRemaining;

  /// Current animation state. Written only by [_play].
  BossState _state = BossState.idle;
  BossState get state => _state;

  /// How long the current one-shot animation still has to run before the
  /// boss falls back to [BossState.idle]. Zero for looping states.
  ///
  /// This single timer is also what makes a superseded one-shot harmless:
  /// [_play] rewrites it on every transition, so a `hit` landing mid-
  /// `recovering` replaces the pending return-to-idle rather than racing
  /// it.
  double _oneShotRemaining = 0;

  VagoneiroBoss({
    required Vector2 position,
    required this.facing,
    required this.track,
    required this.container,
    this.onOperation,
    this.onPhaseChanged,
    this.onDefeated,
  }) : super(
          position: position,
          anchor: Anchor.bottomCenter,
          size: Vector2.all(bossFrameSize * bossDisplayScale),
        );

  /// World y of the boss's **visible** foot line — the bottom of the real
  /// opaque content of the current sheet, which is [bossFrameBottomPadNative]
  /// native px above the frame's own bottom edge.
  ///
  /// `position.y` is the arena's ground point from `slots_config.json` and
  /// stays exactly that; this is the derived line the dock and the contact
  /// shadow register against (design doc section 2.3). Nothing here moves
  /// the boss.
  double get visibleFootY =>
      position.y - bossFrameBottomPadNative * bossDisplayScale;

  @override
  Future<void> onLoad() async {
    final image = await Flame.images.load(bossSpriteAssetPath);
    _sheet = SpriteSheet(
      image: image,
      srcSize: Vector2.all(bossFrameSize),
    );

    // Módulo 13, item 2: the shared cool wash that puts the boss on the
    // same palette as the cave he stands in. Set on this component's own
    // `paint`, so it applies to every frame of every state without the
    // animation/state machine knowing about it, and without touching
    // `position`, `size` or `bossDisplayScale`.
    applyAmbientCoolTint(this);

    // Replays whatever state combat already put the boss in, rather than
    // forcing `idle` over it (see [_play]'s not-loaded-yet branch).
    _play(_state);

    // Módulo 15, Mudança 4: mirror only when the requested facing differs
    // from what the sheet is actually drawn as. With
    // [bossSheetNativeFacing] == 'right' and `facing` == 'left' (this
    // arena's config), that is exactly one flip — the boss now faces the
    // track and the player instead of the wall behind him.
    //
    // `flipHorizontally()` negates `scale.x`, which is a *render*
    // transform: `position`, `size`, [bossDisplayScale] and [bodyHitbox]
    // (added below, symmetric about the frame's centre line) are all
    // untouched, so the section 2.3 calibration survives the fix intact.
    if (facing != bossSheetNativeFacing) {
      flipHorizontally();
    }

    // Anchored on the **visible** foot line rather than on the frame's
    // bottom edge, for the same reason the dock and the shadow are: with
    // the replacement art there are 32.5 native px of empty cell under the
    // boots, and a collider registered to the frame edge would hang that
    // far below the character. Size and shape are unchanged from Módulo 11.
    bodyHitbox = RectangleHitbox(
      size: Vector2(bossHitboxWidth, bossHitboxHeight),
      anchor: Anchor.bottomCenter,
      position: Vector2(
        size.x / 2,
        size.y - bossFrameBottomPadNative * bossDisplayScale,
      ),
      // Static, never moves — excluded from active-active broad-phase
      // pairing, same reasoning as Vagao.platformHitbox.
      collisionType: CollisionType.passive,
    );
    await add(bodyHitbox);
  }

  // ---------------------------------------------------------------------------
  // Animation
  // ---------------------------------------------------------------------------

  /// Slices [count] frames starting at column [from] of [row].
  SpriteAnimation? _animation(
    int row,
    int from,
    int count,
    double stepTime, {
    bool loop = true,
  }) =>
      _sheet?.createAnimation(
        row: row,
        stepTime: stepTime,
        from: from,
        to: from + count,
        loop: loop,
      );

  /// Switches the boss to [state]. Looping states (`idle`, `observing`,
  /// `chainAttack`, `exposed`) stay until something else changes them;
  /// one-shot states (`hit`, `recovering`) return to `idle` on their own.
  void _play(BossState state) {
    _state = state;

    if (_sheet == null) {
      // Not loaded yet: record the state (and the one-shot durations the
      // update loop reads) without touching `animation`. `onLoad` plays
      // whatever state is current once the sheet exists.
      _oneShotRemaining = switch (state) {
        BossState.hit => bossHitFrameCount * bossHitStepTime,
        BossState.recovering =>
          bossRecoveringFrameCount * bossRecoveringStepTime,
        _ => 0,
      };
      return;
    }

    switch (state) {
      case BossState.idle:
        animation = _animation(
          bossIdleRow,
          0,
          bossIdleFrameCount,
          bossIdleStepTime,
        );
        _oneShotRemaining = 0;
      case BossState.observing:
        animation = _animation(
          bossObservingRow,
          0,
          bossObservingFrameCount,
          bossObservingStepTime,
        );
        _oneShotRemaining = 0;
      case BossState.chainAttack:
        animation = _animation(
          bossObservingRow,
          bossChainAttackFrameOffset,
          bossChainAttackFrameCount,
          bossChainAttackStepTime,
        );
        _oneShotRemaining = 0;
      case BossState.hit:
        animation = _animation(
          bossHitRow,
          0,
          bossHitFrameCount,
          bossHitStepTime,
          loop: false,
        );
        _oneShotRemaining = bossHitFrameCount * bossHitStepTime;
      case BossState.exposed:
        animation = _animation(
          bossExposedRecoveringRow,
          0,
          bossExposedFrameCount,
          bossExposedStepTime,
        );
        _oneShotRemaining = 0;
      case BossState.recovering:
        animation = _animation(
          bossExposedRecoveringRow,
          bossExposedFrameCount,
          bossRecoveringFrameCount,
          bossRecoveringStepTime,
          loop: false,
        );
        _oneShotRemaining = bossRecoveringFrameCount * bossRecoveringStepTime;
    }
  }

  /// Public, non-debug entry point used by the attack director to show what
  /// the boss is doing. Never interrupts the punish window: while the boss
  /// is `exposed` he stays exposed, because that window is a *combat* state
  /// and letting an attack animation cut it short would silently shorten
  /// the player's opportunity.
  void playState(BossState state) {
    if (isExposed && state != BossState.hit) {
      return;
    }
    _play(state);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_exposedRemaining > 0) {
      _exposedRemaining = math.max(0, _exposedRemaining - dt);
      if (_exposedRemaining == 0 && !isDefeated) {
        _play(BossState.recovering);
      }
      return;
    }

    if (_oneShotRemaining > 0) {
      _oneShotRemaining = math.max(0, _oneShotRemaining - dt);
      if (_oneShotRemaining == 0) {
        _play(BossState.idle);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Combat
  // ---------------------------------------------------------------------------

  /// Opens the punish window for [duration] seconds (Módulo 14, item 8:
  /// telegraph -> execução -> punição). Extends, never shortens, a window
  /// already open.
  void enterExposed(double duration) {
    if (isDefeated) {
      return;
    }
    _exposedRemaining = math.max(_exposedRemaining, duration);
    if (_state != BossState.exposed) {
      _play(BossState.exposed);
    }
    _log('exposed for ${duration.toStringAsFixed(1)}s — vulnerável');
  }

  /// Applies [amount] of damage **only** if the punish window is open
  /// (Módulo 14, item 8). Returns whether it landed, so the caller can
  /// pick the right feedback without re-deriving the rule.
  bool takeDamage(int amount) {
    if (isDefeated || !isExposed) {
      return false;
    }

    hp = math.max(0, hp - amount);
    onOperation?.call('boss.hp -= $amount  ->  $hp/$bossMaxHp');
    _log('takeDamage($amount) -> hp $hp/$bossMaxHp');

    if (hp == 0) {
      _exposedRemaining = 0;
      _play(BossState.hit);
      _log('derrotado');
      onDefeated?.call();
      return true;
    }

    // Stagger: the window stays open a beat longer, so a player who reads
    // the opening can chain a couple of hits inside it.
    _exposedRemaining = math.max(_exposedRemaining, bossExposedAfterHit);
    _play(BossState.hit);
    _oneShotRemaining = 0; // the exposed timer owns the return to idle.

    _updatePhase();
    return true;
  }

  void _updatePhase() {
    final next = phaseForHpFraction(hpFraction);
    if (next == _phase) {
      return;
    }
    _phase = next;
    _log('fase -> ${next.label}');
    onPhaseChanged?.call(next);
  }

  /// Resets the fight to its opening state. Used by the arena when the
  /// player runs out of hit points, and by the debug harness.
  void resetCombat() {
    hp = bossMaxHp;
    _phase = BossPhase.fase1;
    _exposedRemaining = 0;
    _play(BossState.idle);
  }

  // ---------------------------------------------------------------------------
  // Debug playback (unchanged entry points — design doc section 4.1)
  // ---------------------------------------------------------------------------

  /// Isolated playback of `hit`/`stunned` (fileira 3): plays the 4-frame
  /// animation once, then returns to `idle` on its own.
  ///
  /// Kept as the same public method Módulos 0-13 wired the `H` key to, and
  /// still safe to call from the debug harness — but it is now the *same*
  /// code path real combat uses (see [takeDamage]), so the harness shows
  /// exactly what a hit looks like in play.
  Future<void> debugPlayHit() async {
    _log('debugPlayHit() -> playing hit/stunned');
    _play(BossState.hit);
  }

  /// Isolated playback of `exposed` -> `recovering` -> `idle` (fileira 4).
  /// Same entry point as before; it now opens a real punish window, so the
  /// `X` key is also the manual way to test that a player attack lands only
  /// inside it.
  Future<void> debugPlayExposed() async {
    _log('debugPlayExposed() -> opening the punish window');
    enterExposed(bossExposedAfterInsercao);
  }

  // ---------------------------------------------------------------------------
  // List operations (design doc section 3.0 — the only way a wagon appears
  // or disappears)
  // ---------------------------------------------------------------------------

  /// Occupies [index] with a new wagon at that slot's fixed position,
  /// playing the `spawning` -> `idle` transition (section 3.1). No-op with
  /// a log if the slot is already occupied.
  void occupySlot(int index, {VagaoState estadoInicial = VagaoState.idle}) {
    final slot = track.slotAt(index);
    if (slot.vagao != null) {
      _log('occupySlot($index) ignored: slot already occupied');
      return;
    }

    final vagao = Vagao(position: Vector2(slot.x, slot.y));
    slot.vagao = vagao;
    container.add(vagao);

    onOperation?.call('occupySlot($index)');
    _log(
      'occupySlot($index, estadoInicial: $estadoInicial) -> '
      'wagon spawning at (${slot.x}, ${slot.y})',
    );
  }

  /// Removes whatever wagon occupies [index].
  void clearSlot(int index) {
    final slot = track.slotAt(index);
    final vagao = slot.vagao;
    if (vagao == null) {
      _log('clearSlot($index) ignored: slot already empty');
      return;
    }

    vagao.removeFromParent();
    slot.vagao = null;

    onOperation?.call('clearSlot($index)');
    _log('clearSlot($index) -> wagon removed');
  }

  /// Debug trigger for [removerNo], kept as the exact public name and
  /// signature Módulos 0-13 wired the `Ctrl+0-7` keys to. It is a thin
  /// alias of the production path the attack director calls, so the debug
  /// key exercises real combat rather than a parallel implementation.
  ///
  /// It deliberately does **not** consult the non-adjacency rule: the
  /// whole point of a debug key is to be able to set up the arrangement
  /// you want to look at, including one the boss would never choose. The
  /// rule lives where the boss picks a slot
  /// (`AttackDirector.removableSlots`), not in the primitive.
  void debugTriggerVagaoFantasma(int index) => removerNo(index);

  /// **RemoverNo** — the first of the two primitives the boss has left
  /// after Módulo 15 (Mudança 1 (a)).
  ///
  /// Plays the pre-existing `tremor -> falling` sequence (wagons/states)
  /// on whatever wagon occupies [index], then clears the slot via the
  /// normal [clearSlot] path once the fall finishes, leaving
  /// `slot[index].vagao == null`. No-op with a log if the slot is empty.
  ///
  /// The wagon state machine is untouched, and so is the damage path: a
  /// player standing here when the wagon flips out of `isSolid` is caught
  /// by `Player.onSupportLost` — the existing fall hook — and no new
  /// hitbox is introduced (Mudança 1 (a)).
  void removerNo(int index) {
    final slot = track.slotAt(index);
    final vagao = slot.vagao;
    if (vagao == null) {
      _log('removerNo($index) ignored: slot is empty');
      return;
    }

    onOperation?.call('removerNo(slot[$index]) -> tremor -> falling');
    _log('removerNo($index) -> tremor started');
    vagao.playVagaoFantasmaSequence(() {
      _log('removerNo($index) -> falling finished, clearing slot');
      clearSlot(index);
    });
  }

  /// Detaches the wagon at [index] from the list **immediately** and lets
  /// its own `falling` animation play out in the world before it removes
  /// itself.
  ///
  /// This is what "cair do fim da linha" needs (Mudança 1 (b)) and it is
  /// deliberately different from [removerNo]: there, the slot stays
  /// occupied for the whole tremor telegraph plus the fall, because the
  /// point *is* the telegraph. Here the slot has to be
  /// logically free *now* so the relabel that follows can fill it in the
  /// same frame — the fall is only the visual receipt of a pop that has
  /// already happened.
  void dropOffEndOfLine(int index) {
    final slot = track.slotAt(index);
    final vagao = slot.vagao;
    if (vagao == null) {
      return;
    }

    slot.vagao = null;
    onOperation?.call('pop() em slot[$index] — fim da linha');
    _log('dropOffEndOfLine($index) -> detached, playing fall');

    vagao.playFall(() => vagao.removeFromParent());
  }

  /// **InserirNo** — the second and last primitive (Mudança 1 (b)).
  ///
  /// Always inserts at **slot 0**, the end of the rail the boss stands at.
  /// Módulo 14's `origin: TrackEnd.tail` variant went with Lista Dupla:
  /// there is one insertion point now, and the parameter that used to
  /// choose between two is gone rather than defaulted, so no caller can
  /// resurrect the other direction by accident.
  ///
  /// The design's original wording ("empurra todos para trás") assumes
  /// wagons sliding along a rail, which the fixed-slot model forbids
  /// (design doc section 3.0). What actually happens is a **relabel**: the
  /// logical contents of `slot[0..N-2]` become the contents of
  /// `slot[1..N-1]`, expressed entirely through [occupySlot]/[clearSlot].
  /// No `Vagao` component is ever repositioned — the only thing that
  /// physically moves is the player, and only if they were standing on
  /// affected content (handled by the caller, see
  /// `AttackDirector.inserirNo`).
  ///
  /// If the last slot (the far end, opposite the boss) was occupied, its
  /// content has nowhere to be relabelled to, so it drops off the end of
  /// the line via [dropOffEndOfLine] instead of overflowing the track.
  ///
  /// Returns the index -> index map of where each slot's content ended up,
  /// so the caller can move the player to match without re-deriving the
  /// shift.
  Map<int, int> insertAtHead({
    void Function(int index)? onEndOfLineDropped,
  }) {
    final slots = track.slots;
    final count = slots.length;

    const insertIndex = 0;
    final endIndex = count - 1;

    // A wagon already mid-fall is logically gone; it must not be counted as
    // content to shift.
    bool occupied(int index) {
      final vagao = slots[index].vagao;
      return vagao != null && vagao.isSolid;
    }

    final wasOccupied = [for (var i = 0; i < count; i++) occupied(i)];

    // "Cai do fim da linha": the content at the far end has nowhere to be
    // relabelled to, so it falls instead of overflowing the track.
    if (wasOccupied[endIndex]) {
      dropOffEndOfLine(endIndex);
      onEndOfLineDropped?.call(endIndex);
    }

    // Target occupancy after the relabel: everything one index further
    // along, plus the freshly inserted node at slot 0.
    final willBeOccupied = List<bool>.filled(count, false);
    final movedTo = <int, int>{};
    for (var i = 0; i < count; i++) {
      final destination = i + 1;
      if (destination >= count) {
        continue; // that's the one that just fell.
      }
      if (wasOccupied[i]) {
        willBeOccupied[destination] = true;
        movedTo[i] = destination;
      }
    }
    willBeOccupied[insertIndex] = true;

    onOperation?.call('insertAtHead(novoVagao)');

    // Apply only the differences. The contents are homogeneous, so a slot
    // that was occupied and stays occupied needs no churn — tearing every
    // wagon down and rebuilding it would restart eight spawn tweens and
    // eight chain segments to produce an identical frame. The *logical*
    // relabel is still complete: it is `willBeOccupied` that is being
    // realised, and `movedTo` is what the player follows.
    for (var i = 0; i < count; i++) {
      final isOccupied = occupied(i);
      if (willBeOccupied[i] && !isOccupied) {
        occupySlot(i);
      } else if (!willBeOccupied[i] && isOccupied) {
        clearSlot(i);
      }
    }

    return movedTo;
  }

  void _log(String message) {
    developer.log(message, name: 'VagoneiroBoss');
    // ignore: avoid_print
    print('[VagoneiroBoss] $message');
  }
}
