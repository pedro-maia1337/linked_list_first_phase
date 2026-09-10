import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

import 'package:flame/effects.dart';

import '../boss/boss_combat.dart';
import '../fx/contact_shadow.dart';
import '../fx/fx_config.dart';
import '../fx/game_curves.dart';
import '../track/linear_track.dart';
import '../wagon/vagao.dart';

/// Player states (see docs/boss-vagoneiro-design.md, section 4.2). [walk]
/// (West/East) is the only animation wired to real horizontal movement.
/// [walkNorth]/[walkSouth] are loaded and testable in isolation (debug
/// harness) but no vertical-movement logic triggers them yet — reserved the
/// same way the boss reserves `observing`/`chainAttack`. `idle`/`hit`/
/// `pulled` remain reserved names for a future module.
enum PlayerState { walk, walkNorth, walkSouth, idle, hit, pulled }

enum _Facing { left, right }

/// The player's walk-frame visual.
///
/// A subclass purely so it can mix in [HasVisibility]: Mudança 3 needs to
/// hide the walk frames while the double-jump pose is on screen, and
/// `isVisible` is the one way to stop a component rendering without
/// detaching it (which would restart its animation ticker and drop its
/// paint configuration every time the player jumped).
class _PlayerVisual extends SpriteAnimationComponent with HasVisibility {
  _PlayerVisual({
    required super.animation,
    required super.size,
    required super.anchor,
    required super.scale,
    required super.position,
  });
}

/// The double-jump pose, for the same reason — see [_PlayerVisual].
class _DoubleJumpVisual extends SpriteComponent with HasVisibility {
  _DoubleJumpVisual({
    required super.sprite,
    required super.size,
    required super.anchor,
    required super.scale,
    required super.position,
  });
}

const String playerWalkWestAssetPath = 'player/spritesheets/West.png';
const String playerWalkEastAssetPath = 'player/spritesheets/East.png';
const String playerWalkNorthAssetPath = 'player/spritesheets/North.png';
const String playerWalkSouthAssetPath = 'player/spritesheets/South.png';

/// The generated double-jump pose (Mudança 3 / documento seção 3.1).
///
/// Unlike the four walk sheets this is a **single frame**, not a 256px
/// grid: one 432x772 pixel-art pose of the character mid-flip, with the
/// spin arcs drawn in. It is therefore loaded as a `Sprite` on its own
/// component rather than sliced into [playerFrameSize] cells — trying to
/// force it into the walk sheets' geometry is what would break the
/// calibration, not using it.
const String playerDoubleJumpAssetPath = 'player/spritesheets/jump-double.png';

/// Native canvas of [playerDoubleJumpAssetPath].
const double playerDoubleJumpFrameWidth = 432;
const double playerDoubleJumpFrameHeight = 772;

/// Measured opaque content height of that pose (pixel-alpha bounding-box
/// scan, threshold alpha > 10: bbox (30,30)-(402,742) inside the 432x772
/// canvas -> 712px tall, 372px wide).
///
/// The same measurement rule the walk frames use
/// ([playerFrameOpaqueHeightNative]), applied to a differently sized
/// canvas — which is the only reason this constant exists separately.
const double playerDoubleJumpOpaqueHeightNative = 712;

/// Transparent padding below the pose's lowest opaque pixel
/// (772 - 742 = 30 native px), the pose's equivalent of
/// [playerFrameBottomPadNative].
const double playerDoubleJumpBottomPadNative = 30;

/// Scale that renders the pose at the **same calibrated 110px** the walk
/// frames render at: 110 / 712 = 0.1545.
///
/// This is the section 2.3 rule applied to a new asset, not a change to
/// it: [playerDisplayScale] and the 110px target are untouched, and the
/// pose is fitted to them. Note the pose's raised arm inflates its
/// bounding box relative to a standing frame, so matching bbox height
/// makes the *character* read slightly smaller for the fraction of a
/// second it is on screen — a playtest-tunable trade, and the honest one,
/// since the alternative is inventing a per-pose fudge factor that no
/// measurement backs.
const double playerDoubleJumpDisplayScale =
    110 / playerDoubleJumpOpaqueHeightNative;

/// Shifts the pose up by its own scaled bottom padding, so its lowest
/// visible pixel lands on local y = 0 — the same point [playerVisualYOffset]
/// puts the walk frames' foot on.
const double playerDoubleJumpVisualYOffset =
    -(playerDoubleJumpBottomPadNative * playerDoubleJumpDisplayScale);

/// All 4 directional spritesheets share the same 256x256 frame size now —
/// the resolution mismatch between the old direita.png (128x128) and
/// esquerda.png (256x256) that used to require per-side frame sizes
/// (design doc section 8.2) no longer exists with West/East/North/South.
const double playerFrameSize = 256;

/// Measured opaque (non-transparent) content height of a player walk frame
/// at native scale (256px frame, no scale applied), i.e. the real
/// on-screen pixel height of the character art once you ignore the
/// frame's transparent padding. Measured directly from `East.png` frame 0
/// with a pixel-alpha bounding-box scan (threshold alpha > 10): bbox
/// (83,17)-(188,247) inside the 256x256 frame -> opaque height 230px
/// (frames 2/4 measured 232/230px, consistent — frame 0 used as the
/// reference "grounded" pose). A raw measurement fact independent of
/// [playerDisplayScale]; used below to derive that scale from a target
/// on-screen height.
const double playerFrameOpaqueHeightNative = 230;

/// Módulo 11 recalibration: target total on-screen player height (visual +
/// collider) = 110px (fixed value, not a ratio this time — see module task
/// item 1). scale = 110 / 230 = 0.4783.
const double playerDisplayScale = 110 / playerFrameOpaqueHeightNative;

/// Actual rendered opaque height at [playerDisplayScale] (230 * 0.4783 ≈
/// 110px) — used by the debug height-ruler harness as the "1x" reference
/// line length, so it always reflects whatever the player's current real
/// on-screen size is instead of a stale hardcoded number.
const double playerRenderedHeightPx =
    playerFrameOpaqueHeightNative * playerDisplayScale;

/// Distance (native, frame-0, alpha>10 scan) from the bottom edge of the
/// 256px frame down to the lowest opaque pixel of the character's foot —
/// i.e. how much transparent padding sits *below* the visible foot. This
/// is exactly what made the player look like it was floating above the
/// wagon: the frame's raw bottom edge (local y=0, the wrapper's anchor/
/// "ground" point) was never the same pixel as the visible foot, off by
/// this padding. See [playerVisualYOffset] for the fix.
const double playerFrameBottomPadNative = 9;

/// Shifts the visual sprite *up* by the scaled bottom padding
/// ([playerFrameBottomPadNative] * [playerDisplayScale]) so that the
/// lowest opaque (visible) pixel of the character — not the frame's raw
/// transparent edge — lands exactly on local y=0, the same point
/// [_feetHitbox] sits at and the same point [onCollision] snaps to the
/// wagon's platform top. Computed at the *new* scale, not reusing any
/// prior offset (module task item 1: "não reaproveite o offset antigo").
const double playerVisualYOffset =
    -(playerFrameBottomPadNative * playerDisplayScale);

const int playerWalkFrameCount = 8;
const double playerWalkStepTime = 0.1;

/// Not spec'd numerically in the design doc — a reasonable default.
const double playerMoveSpeed = 220;

/// Gravity and jump impulse (world px/s^2, px/s).
///
/// Módulo 11 recalibration: target jump apex ≈145px (module task item 4:
/// "1.3x a nova altura do player" -> 110 * 1.3 = 143, task text pins it at
/// 145 directly, used as-is). For constant gravity, apex height h =
/// v0^2/(2g) and time-to-apex t = v0/g. The previous pair (g=900,
/// v0=-450) gave apex = 450^2/(2*900) = 112.5px, t = 0.5s (flight time
/// 1.0s up+down). Scaling *both* g and v0 by the same factor k leaves
/// t = (k*v0)/(k*g) = v0/g unchanged (so horizontal reach at
/// [playerMoveSpeed] — already proven to clear the 180px slot spacing —
/// doesn't change either) while apex scales linearly by k:
///   k = 145 / 112.5 = 1.2889
///   g' = 900 * 1.2889 = 1160
///   v0' = -450 * 1.2889 = -580
/// Check: 580^2 / (2*1160) = 145.0 exactly, t = 580/1160 = 0.5s (same as
/// before) -> still comfortably clears the up-to-120px vertical zigzag
/// between slots (slots_config.json) with margin, and the unchanged 1.0s
/// total flight time still covers the 180px horizontal slot spacing at
/// [playerMoveSpeed] (220px/s -> 220px per jump), same as pre-recalibration.
const double playerGravity = 1160;
const double playerJumpVelocity = -580;

/// Mudança 3 — double jump.
///
/// How many jumps the player has between touching the ground and touching
/// it again: the grounded one plus one more in the air.
const int playerMaxJumps = 2;

/// Vertical impulse of the *second* jump, as a multiple of
/// [playerJumpVelocity].
///
/// 1.0 — "mesmo impulso vertical do primeiro", as the brief specifies,
/// kept as an explicit named multiplier precisely because the brief also
/// says it is "ajustável em playtest": tuning it is one number here, not
/// an edit to the physics.
///
/// Note what this buys, since it is the acceptance criterion: a second
/// jump taken at the apex of the first adds a full 145px apex and another
/// 0.5s of air time on top of whatever the first jump had left, which is
/// what turns "a sequence of two non-adjacent holes" (two 180px gaps with
/// one wagon between them) from a committed single leap into a recoverable
/// one.
const double playerDoubleJumpVelocityFactor = 1.0;

/// Fixed collision hitbox at the player's feet — deliberately small and
/// independent of the visual sprite's size, so collision behavior doesn't
/// change when the player turns around.
const double playerHitboxWidth = 50;
const double playerHitboxHeight = 10;

/// The player: horizontal movement (arrows/A-D) plus gravity and jump
/// (Space/W/ArrowUp). No dedicated jump animation — the current walk frame
/// is reused as a placeholder during the jump (design doc section 9.3). No
/// idle/hit animation this etapa (section 4.2).
///
/// Structured like [Vagao]: a plain (zero-size) [PositionComponent]
/// wrapper anchored at the feet, holding two *sibling* children — the
/// visual [SpriteAnimationComponent] (fixed 256x256, see [playerFrameSize])
/// and a fixed-size [RectangleHitbox]. If the hitbox were nested inside the
/// visual (or if this component itself carried both the sprite's size and
/// the hitbox), the hitbox's world position would shift if the visual's
/// size ever changed — keeping them as siblings of a zero-size parent is
/// what keeps the hitbox pinned exactly at the feet regardless of facing.
///
/// Landing is resolved by Flame's own collision engine
/// ([CollisionCallbacks] + [HasCollisionDetection] on the game) — this
/// class only positions its hitbox and reacts to the engine's
/// `onCollision`/`onCollisionEnd` callbacks; it does not reimplement AABB
/// overlap tests itself (design doc section 12.1).
class Player extends PositionComponent with CollisionCallbacks {
  final Set<LogicalKeyboardKey> Function() getPressedKeys;

  /// `deathZone.y` from slots_config.json — never hardcoded (skill's
  /// data-driven rule). Crossing it fires [onPlayerDeath] (design doc
  /// section 10.1, gatilho 3: "sair dos limites verticais da arena").
  final double deathZoneY;

  /// Where [onPlayerDeath] resets the player to. This etapa's death
  /// handling is placeholder-only (section 10.2, item 4: "sem necessidade
  /// de arte dedicada") — log + reset, no respawn/game-over flow yet.
  final Vector2 respawnPosition;

  /// Optional extension hook (design doc section 10.2, item 3: "deixar esse
  /// callback como um ponto de extensão"). Invoked every time
  /// [onPlayerDeath] fires, in addition to the built-in log+reset.
  ///
  /// **Módulo 14** is what that extension point was reserved for: the
  /// arena hooks it to charge [quedaDamage], which is how a fall stops
  /// being cosmetic and starts counting as combat damage — without adding
  /// a second death path (design doc section 10.3).
  final void Function()? onDeath;

  /// The arena's slot geometry, read-only. Needed for two things and
  /// nothing else: knowing which slot the player is currently standing on
  /// (so an attack, a chain pull or a head-push can be resolved against an
  /// index), and computing the `prev` boundary while the list is still
  /// singly linked. This class never writes a slot, a `next`/`prev` or a
  /// `Slot.vagao`.
  final LinearTrack track;

  /// Fired when the wagon under the player stops being solid — i.e.
  /// `RemoverNo` actually pulled the floor out. Separate from [onDeath],
  /// which only fires much later, if and when the resulting fall crosses
  /// the death line.
  ///
  /// Mudança 1 (a) names this as the hook the removal must reuse, and it
  /// is: nothing about the damage path was rebuilt for Módulo 15.
  final void Function(Vagao lost)? onSupportLost;

  /// Fired whenever [takeCombatDamage] actually lands, with the reason to
  /// show, and once more with `hp == 0` when the player is defeated.
  final void Function(String reason, int hp)? onDamaged;

  /// Módulo 12 (polish visual) hook, fired *after* a landing has resolved,
  /// with the player's own foot position (this component's
  /// anchor-bottomCenter world position, i.e. the recalculated contact
  /// point) and the downward speed the landing happened at.
  ///
  /// Only fires for a landing with real vertical movement — see
  /// [playerLandingImpactThreshold]. Kept as a callback so this class stays
  /// free of any particle/asset knowledge: the game decides that a landing
  /// spawns `dust-poof.png` there. Nothing about the landing itself (the
  /// snap, `_isOnGround`, `_verticalVelocity`) depends on it.
  final void Function(Vector2 footPosition, double impactSpeed)? onLanded;

  late final _PlayerVisual _visual;

  /// The Mudança 3 double-jump pose. A separate component rather than
  /// another animation on [_visual], because it has its own canvas size,
  /// its own scale and its own foot offset (see
  /// [playerDoubleJumpDisplayScale]) — swapping it into [_visual], which
  /// is fixed at [playerFrameSize] and [playerDisplayScale], would stretch
  /// it to 256x256 and break the calibration it was measured against.
  ///
  /// Exactly one of the two is visible at any time; [_showDoubleJumpPose]
  /// is the only thing that decides which.
  late final _DoubleJumpVisual _doubleJumpVisual;

  late final SpriteAnimation _walkWestAnimation;
  late final SpriteAnimation _walkEastAnimation;
  late final SpriteAnimation _walkNorthAnimation;
  late final SpriteAnimation _walkSouthAnimation;
  late final RectangleHitbox _feetHitbox;

  _Facing _facing = _Facing.right;

  /// Vertical velocity only — horizontal movement is applied directly as a
  /// position delta, matching the pre-existing (Módulo 2) movement style.
  double _verticalVelocity = 0;
  bool _isOnGround = false;

  /// Mudança 3 — jumps left before the player has to touch the ground
  /// again. Reset to [playerMaxJumps] on every landing (and on every
  /// reset), decremented by each jump that actually leaves the ground.
  ///
  /// Kept as a *count* rather than a `hasDoubleJumped` flag so raising the
  /// maximum is a one-constant change, and so the invariant that matters
  /// ("you cannot jump more times than you have jumps") is readable
  /// straight off the field.
  int jumpsRemaining = playerMaxJumps;

  /// Edge detection for the jump key: a held key must not spend both jumps
  /// on consecutive frames. Without this the double jump is unusable — the
  /// first frame grounds-jumps, the second immediately air-jumps, and the
  /// player never gets the second one where they want it.
  bool _jumpKeyWasDown = false;

  /// The [Vagao] currently supporting the player, if any. Tracked
  /// separately from [_isOnGround] so a wagon that flips to `falling`
  /// while the player is standing on it (still geometrically overlapping,
  /// so `onCollisionEnd` hasn't fired) can still be detected and drop the
  /// player — see the per-frame check in [update] (design doc section
  /// 10.1, gatilho 1).
  Vagao? _supportingVagao;

  /// Guards [debugPlayWalkNorth]/[debugPlayWalkSouth] against overlapping
  /// triggers and against clobbering the real walk animation mid-preview —
  /// same re-entrancy pattern as [VagoneiroBoss]'s debug methods.
  bool _debugPreviewRunning = false;

  /// Módulo 12 squash-and-stretch state. `_squashPeak` is the vertical
  /// scale *multiplier* the deformation starts at (>1 = stretch, <1 =
  /// squash); it eases back to 1 over `_squashDuration`. All three are
  /// visual-only: they are applied to [_visual]'s `scale` on top of
  /// [playerDisplayScale] and are never read by movement, collision or
  /// the death check.
  double _squashPeak = 1;
  double _squashDuration = 0;
  double _squashElapsed = 0;

  late final ContactShadow _contactShadow;

  Player({
    required Vector2 position,
    required this.getPressedKeys,
    required this.deathZoneY,
    required this.respawnPosition,
    required this.track,
    this.onDeath,
    this.onLanded,
    this.onSupportLost,
    this.onDamaged,
  }) : super(position: position, anchor: Anchor.bottomCenter);

  // ---------------------------------------------------------------------------
  // Módulo 14 — combat state
  // ---------------------------------------------------------------------------

  int hp = playerMaxHp;

  bool get isDefeated => hp <= 0;

  /// Seconds of post-hit immunity still to run. While positive,
  /// [takeCombatDamage] is a no-op — one mistake cannot be charged twice
  /// by two systems noticing it in the same second (the phantom wagon
  /// dropping the player *and* the fall that follows, for instance).
  double _invulnerableRemaining = 0;
  bool get isInvulnerable => _invulnerableRemaining > 0;

  /// Seconds of stagger still to run: a brief loss of control plus a
  /// shove. Available to combat and exercised by the debug harness.
  double _staggerRemaining = 0;
  bool get isStaggered => _staggerRemaining > 0;

  /// Index of the slot the player last landed on. Kept as the player's
  /// "logical position in the list": it is what `RemoverNo` aims at and
  /// what the `InserirNo` relabel moves them along by.
  int _currentSlotIndex = 0;
  int get currentSlotIndex => _currentSlotIndex;

  /// True while a scripted tween owns the player's position (a chain pull,
  /// or following a relabel). Gravity and input are suspended for its
  /// duration so the two cannot fight over `position`.
  bool _tweenActive = false;
  bool get isBeingMoved => _tweenActive;

  double _damageFlashElapsed = 0;

  @override
  Future<void> onLoad() async {
    final westImage = await Flame.images.load(playerWalkWestAssetPath);
    final eastImage = await Flame.images.load(playerWalkEastAssetPath);
    final northImage = await Flame.images.load(playerWalkNorthAssetPath);
    final southImage = await Flame.images.load(playerWalkSouthAssetPath);

    final frameSize = Vector2.all(playerFrameSize);

    final westSheet = SpriteSheet(image: westImage, srcSize: frameSize);
    final eastSheet = SpriteSheet(image: eastImage, srcSize: frameSize);
    final northSheet = SpriteSheet(image: northImage, srcSize: frameSize);
    final southSheet = SpriteSheet(image: southImage, srcSize: frameSize);

    _walkWestAnimation = westSheet.createAnimation(
      row: 0,
      stepTime: playerWalkStepTime,
      to: playerWalkFrameCount,
    );
    _walkEastAnimation = eastSheet.createAnimation(
      row: 0,
      stepTime: playerWalkStepTime,
      to: playerWalkFrameCount,
    );
    _walkNorthAnimation = northSheet.createAnimation(
      row: 0,
      stepTime: playerWalkStepTime,
      to: playerWalkFrameCount,
    );
    _walkSouthAnimation = southSheet.createAnimation(
      row: 0,
      stepTime: playerWalkStepTime,
      to: playerWalkFrameCount,
    );

    _visual = _PlayerVisual(
      animation: _walkEastAnimation,
      size: frameSize.clone(),
      anchor: Anchor.bottomCenter,
      scale: Vector2.all(playerDisplayScale),
      // See [playerVisualYOffset]: cancels out the frame's transparent
      // bottom padding so the visible foot — not the raw frame edge —
      // sits exactly at local y=0 (where [_feetHitbox] and the
      // onCollision landing-snap both operate).
      position: Vector2(0, playerVisualYOffset),
    );
    await add(_visual);

    // Mudança 3: the double-jump pose, hidden until a second jump fires.
    // Same foot-anchoring discipline as [_visual] — bottomCenter anchor
    // plus its own scaled bottom-padding offset — so the two line up on
    // local y = 0 and swapping between them never shifts the character.
    _doubleJumpVisual = _DoubleJumpVisual(
      sprite: Sprite(await Flame.images.load(playerDoubleJumpAssetPath)),
      size: Vector2(
        playerDoubleJumpFrameWidth,
        playerDoubleJumpFrameHeight,
      ),
      anchor: Anchor.bottomCenter,
      scale: Vector2.all(playerDoubleJumpDisplayScale),
      position: Vector2(0, playerDoubleJumpVisualYOffset),
    )..isVisible = false;
    await add(_doubleJumpVisual);

    _feetHitbox = RectangleHitbox(
      size: Vector2(playerHitboxWidth, playerHitboxHeight),
      anchor: Anchor.bottomCenter,
      position: Vector2.zero(),
      collisionType: CollisionType.active,
    );
    await add(_feetHitbox);

    // Módulo 12 (polish visual): contact shadow centred on local y = 0 —
    // the same point [_feetHitbox] sits at and the same point
    // [playerVisualYOffset] was computed to put the visible foot on, so
    // there is no gap between the character's base and its shadow by
    // construction. `priority: -1` keeps it under the character art.
    _contactShadow = await ContactShadow.load(
      width: playerContactShadowWidth,
      baseOpacity: playerContactShadowOpacity,
    );
    await add(_contactShadow);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _tickCombatTimers(dt);

    // A scripted move (a chain pull, or following a head-push relabel)
    // owns `position` for its duration: input and gravity are suspended so
    // the two cannot fight over the same field mid-tween.
    if (_tweenActive) {
      _updateContactShadow();
      return;
    }

    final keys = getPressedKeys();
    var movingLeft = keys.contains(LogicalKeyboardKey.arrowLeft) ||
        keys.contains(LogicalKeyboardKey.keyA);
    var movingRight = keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD);
    var jumpPressed = keys.contains(LogicalKeyboardKey.space) ||
        keys.contains(LogicalKeyboardKey.arrowUp) ||
        keys.contains(LogicalKeyboardKey.keyW);

    // Módulo 14: a stagger is a brief loss of control, not a freeze —
    // gravity below still runs, only input is ignored.
    if (isStaggered) {
      movingLeft = false;
      movingRight = false;
      jumpPressed = false;
    }

    if (movingLeft && !movingRight) {
      position.x -= playerMoveSpeed * dt;
      // Facing/animation only switches while grounded (see _applyFacing's
      // doc) and never during a [_debugPreviewRunning] preview, so a
      // North/South preview triggered mid-walk isn't stomped by real
      // movement input.
      if (_isOnGround && !_debugPreviewRunning) {
        _applyFacing(_Facing.left);
      }
    } else if (movingRight && !movingLeft) {
      position.x += playerMoveSpeed * dt;
      // Módulo 15, Mudança 1: the `prev`-direction wall is gone with Lista
      // Dupla, which is what used to lift it in phase 2. It could not stay
      // behind on its own — with the roster reduced, the boss's only
      // punish window opens at **slot 0**, the end of the rail he stands
      // at, and a player who may never walk back towards `prev` could
      // never reach it after the first InserirNo shoved them away. The
      // restriction and the mechanic that relieved it were one feature;
      // removing half of it would have made the fight unwinnable.
      if (_isOnGround && !_debugPreviewRunning) {
        _applyFacing(_Facing.right);
      }
    }

    // Mudança 3 — one jump per *press*, up to [jumpsRemaining] of them
    // between landings. The edge (`pressed now, not pressed last frame`)
    // is what makes the second jump a decision instead of an accident of
    // holding the key.
    final jumpJustPressed = jumpPressed && !_jumpKeyWasDown;
    _jumpKeyWasDown = jumpPressed;

    if (jumpJustPressed && jumpsRemaining > 0) {
      final isAirJump = !_isOnGround;
      _verticalVelocity = isAirJump
          ? playerJumpVelocity * playerDoubleJumpVelocityFactor
          : playerJumpVelocity;
      _isOnGround = false;
      _supportingVagao = null;
      jumpsRemaining--;

      // Módulo 12 (juice): stretch on take-off. Gated on real vertical
      // motion having just started — the same "no movement, no animation"
      // rule the Módulo 11 fix applies to the walk cycle horizontally, so
      // a jump key held against a ceiling-less standstill can't produce a
      // deformation without the player actually leaving the ground. The
      // physics above is untouched: this reads `_verticalVelocity`, never
      // writes it.
      if (_verticalVelocity != 0) {
        _startSquash(playerJumpStretchFactor, playerJumpStretchDuration);
      }
      if (isAirJump) {
        _showDoubleJumpPose(true);
      }
    }

    // Freeze/resume the walk animation based on actual horizontal movement
    // (design doc section 4.2: no idle asset exists this etapa, so "idle"
    // is just the walk animation held still, not a new animation/state).
    // `SpriteAnimationComponent`'s own `update()` advances its ticker
    // unconditionally by elapsed time regardless of player velocity (see
    // Flame's `SpriteAnimationTicker.update()`) — nothing here ever gated
    // that on movement before, which is why the walk cycle kept looping
    // while standing still. `movingLeft ^ movingRight` mirrors exactly the
    // condition the two branches above use to apply a position delta
    // (true only when exactly one direction is held), deliberately not
    // gated on [_isOnGround] — horizontal movement (and thus the walk
    // animation) works the same in the air, so standing still at a jump's
    // apex with no horizontal input freezes it too.
    if (!_debugPreviewRunning) {
      final isWalking = movingLeft ^ movingRight;
      final ticker = _visual.animationTicker;
      if (ticker != null) {
        if (isWalking) {
          ticker.paused = false;
        } else if (!ticker.isPaused) {
          // Freeze on frame 0 (module task item 2), not wherever mid-
          // stride the cycle happened to stop. Resuming afterwards then
          // naturally restarts from frame 0 (task item 3's "opção mais
          // natural" — chosen over resuming mid-stride, since frame 0 is
          // already where it's frozen).
          ticker.currentIndex = 0;
          ticker.paused = true;
        }
      }
    }

    // If the wagon supporting the player stopped being solid (it entered
    // `falling` — design doc section 9.2/10.1, gatilho 1) since the last
    // frame, drop the player even though the hitboxes are still
    // geometrically overlapping (so `onCollisionEnd` hasn't fired yet).
    if (_isOnGround && _supportingVagao != null && !_supportingVagao!.isSolid) {
      final lost = _supportingVagao!;
      _isOnGround = false;
      _supportingVagao = null;
      // Losing the floor to `RemoverNo` is combat damage, not just a
      // platforming inconvenience. The wagon's own
      // `tremor -> falling` sequence is untouched — this is the arena
      // being told the support went away, at the exact frame `isSolid`
      // flipped.
      onSupportLost?.call(lost);
    }

    _verticalVelocity += playerGravity * dt;
    position.y += _verticalVelocity * dt;

    if (position.y > deathZoneY) {
      onPlayerDeath();
    }

    // Módulo 12 (polish visual). Both run *after* the physics above and
    // read only its results — no branch below can change `position`,
    // `_verticalVelocity`, `_isOnGround` or `_supportingVagao`.
    _updateSquashAndStretch(dt);
    _updateContactShadow();
  }

  /// Starts a squash/stretch: [peak] is the vertical scale multiplier the
  /// deformation begins at, easing back to 1 over [duration] seconds.
  void _startSquash(double peak, double duration) {
    _squashPeak = peak;
    _squashDuration = duration;
    _squashElapsed = 0;
  }

  /// Eases the current deformation out and writes it to [_visual]'s scale.
  ///
  /// The vertical multiplier runs from [_squashPeak] back to 1 on an
  /// ease-out-cubic; the horizontal multiplier is its reciprocal, so the
  /// silhouette's area stays constant (a stretched player gets narrower, a
  /// squashed one wider) — the classic 2D squash-and-stretch relationship.
  ///
  /// Crucially, this only ever multiplies [playerDisplayScale] (the
  /// calibrated 110px height) and always returns to exactly
  /// `Vector2.all(playerDisplayScale)` when the deformation finishes, so
  /// the resting size is bit-for-bit the Módulo 11 value. [_visual]'s
  /// `Anchor.bottomCenter` means the deformation grows/shrinks away from
  /// the feet, leaving the foot anchor (and therefore
  /// [playerVisualYOffset]'s correction) exactly where it was.
  void _updateSquashAndStretch(double dt) {
    if (_squashDuration <= 0) {
      return;
    }

    _squashElapsed += dt;
    final progress = (_squashElapsed / _squashDuration).clamp(0.0, 1.0);

    if (progress >= 1) {
      _squashDuration = 0;
      _squashPeak = 1;
      _visual.scale = Vector2.all(playerDisplayScale);
      return;
    }

    // Mudança 5: the project curve, not a hand-inlined cubic. This used to
    // be `1 - (1-t)^3` written out here — numerically the same shape, but
    // invisible to anyone retuning the game's feel, which is exactly the
    // "cada sistema com seu timing solto" the standardisation is for.
    final eased = GameCurves.softOutAt(progress);
    final scaleY = _squashPeak + (1 - _squashPeak) * eased;
    _visual.scale = Vector2(
      playerDisplayScale / scaleY,
      playerDisplayScale * scaleY,
    );
  }

  /// Fades the contact shadow while the player is airborne, so it reads as
  /// a shadow cast on the platform rather than as a decal glued to the
  /// feet. Never moves it — the shadow's position is the contact point.
  void _updateContactShadow() {
    _contactShadow.opacity = _isOnGround
        ? playerContactShadowOpacity
        : playerContactShadowAirborneOpacity;
  }

  /// Fires when the player dies from a platforming error (design doc
  /// section 10): standing on a wagon that turned `falling`, falling into
  /// the hole left by a `removed` wagon (both handled indirectly — either
  /// case leaves the player with no support, so gravity carries them past
  /// [deathZoneY]), or leaving the arena's vertical bounds directly.
  ///
  /// This etapa's handling is a placeholder (section 10.2, item 4): log +
  /// reset to [respawnPosition], no real respawn/game-over flow yet. Kept
  /// separate from any future `CombatDamage` death path (section 10.3).
  void onPlayerDeath() {
    developer.log(
      'Player died (fell past deathZone.y=$deathZoneY at y=${position.y})',
      name: 'Player',
    );

    onDeath?.call();

    _resetToRespawn();
  }

  /// The positional half of a reset, without the damage hook — shared by
  /// [onPlayerDeath] and [resetCombat] so restarting the fight does not
  /// charge the player the fall damage they are being reset *from*.
  void _resetToRespawn() {
    position.setFrom(respawnPosition);
    _verticalVelocity = 0;
    _isOnGround = false;
    _supportingVagao = null;
    jumpsRemaining = playerMaxJumps;
    _jumpKeyWasDown = false;
    if (isLoaded) {
      _showDoubleJumpPose(false);
    }
  }

  /// Fired by Flame's collision engine while the player's hitbox overlaps
  /// another one. Only reacts to a [Vagao]'s platform hitbox, and only
  /// resolves as a landing when the wagon is solid (section 9.2) and the
  /// player is moving downward (never snaps the player up mid-jump).
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // Flame's ShapeHitbox.onCollision forwards to the *parent entity*,
    // passing the other hitbox's parent entity as `other` — not the raw
    // hitboxes themselves (see flame's shape_hitbox.dart). So `other` here
    // is the Vagao itself.
    if (other is! Vagao) {
      return;
    }
    if (!other.isSolid || _verticalVelocity < 0) {
      return;
    }

    // TEMPORARY DEBUG (Módulo 11 recalibration): logs the vertical gap
    // between the player's own foot point (position.y — now that
    // [playerVisualYOffset] is applied, this is the true visible foot,
    // not just the frame edge) and the wagon's platform surface, measured
    // *before* the snap below overwrites it. Flame only fires onCollision
    // once the hitboxes already overlap, so a small negative value (a few
    // px of penetration on this frame) is expected and fine; a large gap
    // would mean the two colliders are miscalibrated relative to each
    // other. Remove once the "floating over the wagon" fix is confirmed.
    final preSnapGapPx =
        position.y - other.platformHitbox.absoluteTopLeftPosition.y;
    developer.log(
      'DEBUG contact gap (player foot vs wagon top, pre-snap) = '
      '${preSnapGapPx.toStringAsFixed(2)}px',
      name: 'Player',
    );
    // ignore: avoid_print
    print(
      '[Player] DEBUG contact gap (pre-snap) = '
      '${preSnapGapPx.toStringAsFixed(2)}px',
    );

    // Módulo 12 (juice): the impact speed has to be read *before* the snap
    // below zeroes it. Reading only — the landing resolution itself is
    // unchanged.
    final impactSpeed = _verticalVelocity;

    // Snap the player's feet (this component's own anchor-bottomCenter
    // position) exactly onto the platform's top edge, from the engine's
    // own computed world-space geometry — no hand-rolled overlap math.
    position.y = other.platformHitbox.absoluteTopLeftPosition.y;
    _verticalVelocity = 0;
    _isOnGround = true;
    _supportingVagao = other;

    // Mudança 3: touching the ground is what refills the jumps — the one
    // rule the double jump has. Note what is deliberately *not* here:
    // walking off a ledge does not spend the ground jump, so a player who
    // steps into a hole RemoverNo just opened still has both jumps to
    // climb out with. With holes that kill, the forgiving reading is the
    // right one, and it costs nothing elsewhere.
    jumpsRemaining = playerMaxJumps;
    _showDoubleJumpPose(false);

    // Módulo 14: remember where in the *list* the player is. Only linked
    // wagons count. Every wagon on this track is linked now that the Nó
    // Órfão is gone, but the guard stays: it is the invariant ("only a
    // node in the list is a position in the list"), not a special case
    // for one deleted component.
    if (other.linked) {
      for (final slot in track.slots) {
        if (identical(slot.vagao, other)) {
          _currentSlotIndex = slot.index;
          break;
        }
      }
    }

    _onLandingFx(impactSpeed);
  }

  /// Módulo 12 (juice): squash + dust on touchdown.
  ///
  /// Gated on [playerLandingImpactThreshold] so a contact with no real
  /// vertical movement behind it (the engine re-firing `onCollision` while
  /// the player simply stands on a wagon, at `_verticalVelocity` ≈ the
  /// single frame of gravity accumulated since the last snap) produces
  /// neither effect — the vertical counterpart of the Módulo 11 rule that
  /// a standing player doesn't play a walk cycle.
  ///
  /// The squash depth scales with how hard the landing was, capped at the
  /// full [playerLandSquashFactor] for a fall at jump speed.
  void _onLandingFx(double impactSpeed) {
    if (impactSpeed < playerLandingImpactThreshold) {
      return;
    }

    final intensity =
        (impactSpeed / playerJumpVelocity.abs()).clamp(0.35, 1.0);
    _startSquash(
      1 - (1 - playerLandSquashFactor) * intensity,
      playerLandSquashDuration,
    );

    // `position` is the foot contact point the snap above just resolved —
    // exactly the anchor the Módulo 11 scale pass recalculated.
    onLanded?.call(position.clone(), impactSpeed);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Vagao) {
      _isOnGround = false;
      if (identical(_supportingVagao, other)) {
        _supportingVagao = null;
      }
    }
  }

  /// Switches the visual's animation on a real horizontal-direction change.
  /// `_visual.size` no longer needs adjusting here — all 4 directions share
  /// [playerFrameSize] now. Never touches [_feetHitbox] — see class doc.
  void _applyFacing(_Facing facing) {
    if (facing == _facing) {
      return;
    }
    _facing = facing;
    _visual.animation =
        facing == _Facing.left ? _walkWestAnimation : _walkEastAnimation;
    _syncDoubleJumpFacing();
  }

  /// The double-jump pose is drawn facing right (the same direction
  /// `East.png` is), so it needs mirroring when the player is heading
  /// left. `scale.x` is negated rather than reassigned so the calibrated
  /// [playerDoubleJumpDisplayScale] magnitude survives every flip.
  void _syncDoubleJumpFacing() {
    final magnitude = playerDoubleJumpDisplayScale;
    _doubleJumpVisual.scale.x =
        _facing == _Facing.left ? -magnitude : magnitude;
  }

  /// Swaps between the walk frames and the double-jump pose. Exactly one
  /// is ever visible, and neither is ever moved — they share local y = 0
  /// as their foot line, so the swap is a pure change of what is drawn.
  void _showDoubleJumpPose(bool show) {
    _doubleJumpVisual.isVisible = show;
    _visual.isVisible = !show;
    if (show) {
      _syncDoubleJumpFacing();
    }
  }

  // ---------------------------------------------------------------------------
  // Módulo 14 — combat
  // ---------------------------------------------------------------------------

  void _tickCombatTimers(double dt) {
    if (_invulnerableRemaining > 0) {
      _invulnerableRemaining = math.max(0, _invulnerableRemaining - dt);
      _damageFlashElapsed += dt;
      // A plain on/off blink on the visual child only — it never touches
      // `position`, the collider or `_isOnGround`, so being hit changes
      // how the player looks and nothing about how they move.
      final blinkOn =
          (_damageFlashElapsed / playerDamageFlashPeriod).floor().isEven;
      _visual.opacity = blinkOn ? 0.35 : 1;
      if (_invulnerableRemaining == 0) {
        _visual.opacity = 1;
        _damageFlashElapsed = 0;
      }
    }

    if (_staggerRemaining > 0) {
      _staggerRemaining = math.max(0, _staggerRemaining - dt);
    }
  }

  /// Applies [amount] of combat damage unless the player is still inside
  /// the post-hit immunity window. Returns whether it landed.
  bool takeCombatDamage(int amount, {required String reason}) {
    if (isInvulnerable || isDefeated) {
      return false;
    }

    hp = math.max(0, hp - amount);
    _invulnerableRemaining = playerInvulnerabilityDuration;
    _damageFlashElapsed = 0;
    developer.log('took $amount damage ($reason) -> hp $hp', name: 'Player');
    onDamaged?.call(reason, hp);
    return true;
  }

  /// A brief, non-damaging loss of control plus a small shove.
  ///
  /// Módulo 15: the attack that spent this (the Ciclo Corrompido's
  /// wrong-node penalty) is gone, so nothing in combat calls it today. It
  /// is kept as a player capability rather than deleted because it is the
  /// only non-damaging punish the player has, and the debug harness
  /// exercises it.
  void stagger({double direction = 1}) {
    _staggerRemaining = playerStaggerDuration;
    position.x += playerStaggerPushback * direction;
    _startSquash(playerLandSquashFactor, playerStaggerDuration);
  }

  /// Carries the player to [target] over [duration], then hands control
  /// back — the movement half of `InserirNo` (Mudança 1 (b) / Mudança 2).
  ///
  /// The wagons must never move (design doc section 3.0), so when the boss
  /// relabels the list it is the **player** who visibly slides to stay
  /// with the content they were standing on. Deliberately a tween and not
  /// a physics impulse: this is choreography, and it has to land exactly
  /// on the slot it is aimed at.
  ///
  /// **Mudança 2 — why this stopped reading as a hard cut.** The Módulo 14
  /// version was a 0.28s `easeOutCubic` move and nothing else, which the
  /// playtest read as an instant teleport with a blur. Four things were
  /// added, and every one of them is visual:
  ///
  ///  1. [GameCurves.impactOut] over [empurraoPlayerTweenDuration] (0.42s)
  ///     — the small overshoot at the end is what makes it read as being
  ///     *shoved* into place rather than arriving there;
  ///  2. a ~13% vertical squash on the frame they settle
  ///     ([empurraoLandSquashFactor]), springing back over 2-3 frames
  ///     through the existing squash system — the same deformation a jump
  ///     landing uses, not a second one;
  ///  3. a puff of dust at the landing point, via [onSettled];
  ///  4. (fired by the caller, on the other end of the push) a screen
  ///     shake as the new wagon enters slot 0.
  ///
  /// None of it touches `position`'s destination, `_currentSlotIndex`, the
  /// collider or the calibrated scales: the player ends the tween on
  /// exactly the pixel the un-eased version ended on.
  ///
  /// [onSettled] is called with the foot position once the tween finishes.
  void shoveToSlot(
    Vector2 target, {
    double duration = empurraoPlayerTweenDuration,
    void Function(Vector2 footPosition)? onSettled,
  }) {
    if (_tweenActive) {
      return;
    }
    _tweenActive = true;
    _verticalVelocity = 0;
    add(
      MoveToEffect(
        target,
        EffectController(duration: duration, curve: GameCurves.impactOut),
        onComplete: () {
          _tweenActive = false;
          // Land cleanly: the tween put the feet on the slot's platform
          // surface, so the next frame's collision resolves normally
          // instead of the player starting the frame falling.
          _isOnGround = false;
          _supportingVagao = null;
          _startSquash(
            empurraoLandSquashFactor,
            empurraoLandSquashDuration,
          );
          onSettled?.call(position.clone());
        },
      ),
    );
  }

  /// Test hook: the visual child's current scale, which the squash system
  /// writes and must always return to exactly `Vector2.all(
  /// playerDisplayScale)`. Read-only, and read only by tests — the
  /// alternative is exposing [_visual] itself, which would let a caller
  /// move it.
  Vector2 get debugVisualScaleForTest => _visual.scale.clone();

  /// Plays the player's attack swing. There is no dedicated attack asset
  /// (same situation as `idle`, design doc section 4.2), so the swing is
  /// sold with the existing squash-and-stretch — the *resolution* of the
  /// attack is the arena's job, not this class's.
  void playAttackSwing() {
    _startSquash(playerJumpStretchFactor, playerLandSquashDuration);
  }

  /// Full reset for a restarted fight.
  void resetCombat() {
    hp = playerMaxHp;
    _invulnerableRemaining = 0;
    _staggerRemaining = 0;
    _currentSlotIndex = 0;
    _visual.opacity = 1;
    _resetToRespawn();
  }

  /// Debug-only, isolated playback of `walkNorth` (design doc section 4.2 /
  /// module task item 4): plays the 8-frame North animation once, then
  /// returns to whichever real walk animation was active. No vertical-
  /// movement logic decides when this fires — this is purely a visual
  /// preview hook for the debug harness, same pattern as
  /// [VagoneiroBoss.debugPlayHit].
  Future<void> debugPlayWalkNorth() =>
      _debugPreviewDirection(_walkNorthAnimation, 'walkNorth');

  /// Debug-only, isolated playback of `walkSouth` — see [debugPlayWalkNorth].
  Future<void> debugPlayWalkSouth() =>
      _debugPreviewDirection(_walkSouthAnimation, 'walkSouth');

  Future<void> _debugPreviewDirection(
    SpriteAnimation animation,
    String label,
  ) async {
    if (_debugPreviewRunning) {
      developer.log(
        'debugPlayWalk$label ignored: another preview is running',
        name: 'Player',
      );
      return;
    }
    _debugPreviewRunning = true;
    developer.log('debugPlayWalk$label() -> previewing', name: 'Player');

    final restoreAnimation =
        _facing == _Facing.left ? _walkWestAnimation : _walkEastAnimation;
    _visual.animation = animation;
    await Future<void>.delayed(
      Duration(
        milliseconds: (playerWalkFrameCount * playerWalkStepTime * 1000)
            .round(),
      ),
    );

    _visual.animation = restoreAnimation;
    developer.log('debugPlayWalk$label() -> back to real facing', name: 'Player');
    _debugPreviewRunning = false;
  }
}
