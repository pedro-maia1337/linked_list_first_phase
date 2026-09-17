import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

import 'package:flame/effects.dart';

import '../fx/contact_shadow.dart';
import '../fx/fx_config.dart';
import '../fx/game_curves.dart';
import '../physics/arena_wall.dart';
import '../physics/player_platform.dart';
import 'attack_controller.dart';
import 'dash_controller.dart';
import 'player_animations.dart';
import 'player_combat_config.dart';
import 'player_fx.dart';
import 'sword_hitbox.dart';

export 'attack_controller.dart';
export 'dash_controller.dart';
export 'player_animations.dart';
export 'player_combat_config.dart';
export '../physics/player_platform.dart';

/// Measured opaque (non-transparent) content height of the calibration
/// reference frame — `idle_east.png` frame 0 — at native scale: pixel-alpha
/// bounding-box scan, threshold alpha > 10, rows 108..199 -> 92px.
///
/// Módulo 15: the reference moved from walk frame 0 to idle frame 0. The
/// walk sheets were regenerated along with the new ones (the character now
/// occupies 87px of the 256px cell, not the 230px the Módulo 11 constant
/// recorded) and idle is the pose the player actually rests in now, so it
/// is the natural "grounded" reference. Every other sheet is fitted to it
/// through [PlayerSheetSpec.artScale]. `player_test` re-measures the PNG.
const double playerFrameOpaqueHeightNative = 92;

/// Target on-screen player height = 110px (section 2.3, unchanged).
/// scale = 110 / 92 = 1.1957.
const double playerDisplayScale = 110 / playerFrameOpaqueHeightNative;

/// Actual rendered opaque height at [playerDisplayScale] (≈ 110px) — used
/// by the debug height-ruler harness as the "1x" reference line length.
const double playerRenderedHeightPx =
    playerFrameOpaqueHeightNative * playerDisplayScale;

/// Transparent rows below the lowest opaque foot pixel, native. Every
/// delivered sheet shares the same foot baseline (row 199 of 256), so this
/// is one number for all of them; `player_test` checks each sheet.
const double playerFrameBottomPadNative = 56;

/// Shifts the idle art **down** by its scaled bottom padding so the visible
/// foot — not the frame's transparent edge — lands on local y = 0, where
/// the feet hitbox and the landing snap operate. Other sheets use the same
/// rule at their own scale (see `Player._applyVisualScale`).
///
/// Módulo 15 sign fix: with `Anchor.bottomCenter` the frame's bottom edge
/// sits at the visual's `position.y`, and the foot is `pad * scale` *above*
/// that edge. The Módulo 11 value was negative, which moved the art up and
/// left the foot `2 * pad * scale` above the platform — ~8px with the old
/// 9px padding (unnoticed), ~134px with the regenerated sheets' 56px.
const double playerVisualYOffset =
    playerFrameBottomPadNative * playerDisplayScale;

/// Not spec'd numerically in the design doc — a reasonable default.
const double playerMoveSpeed = 220;

/// Gravity and jump impulse (world px/s^2, px/s). Apex = v0^2/(2g) =
/// 580^2/2320 = 145px, time-to-apex 0.5s (Módulo 11 calibration,
/// unchanged).
const double playerGravity = 1160;
const double playerJumpVelocity = -580;

/// Módulo 15, Frente 3 — weight on the way down.
///
/// Gravity is multiplied by this once the player is falling (vy >= 0).
/// Rising is untouched, so the apex stays exactly 145px and the maximum
/// reachable platform height is unchanged; the fall is only ~9% quicker
/// (0.5s -> 0.456s for a same-height landing), which still clears the
/// 180px slot spacing with its +120px step (checked in `player_test`).
const double playerFallGravityMultiplier = 1.2;

/// Gravity for the current vertical velocity.
double playerGravityFor(double verticalVelocity) => verticalVelocity < 0
    ? playerGravity
    : playerGravity * playerFallGravityMultiplier;

/// Reserved extension points (Frente 3) — names only, no logic reads them
/// yet. Coyote time: seconds after leaving a ledge in which a jump still
/// counts as grounded. Jump buffer: seconds a press made just before
/// landing is remembered.
const double playerCoyoteTime = 0;
const double playerJumpBufferTime = 0;

/// Mudança 3 — double jump: the grounded jump plus one more in the air.
const int playerMaxJumps = 2;

/// Vertical impulse of the *second* jump, as a multiple of
/// [playerJumpVelocity] ("mesmo impulso vertical do primeiro").
const double playerDoubleJumpVelocityFactor = 1.0;

/// Fixed collision hitbox at the player's feet — deliberately small and
/// independent of the visual sprite's size.
const double playerHitboxWidth = 50;
const double playerHitboxHeight = 10;

/// Input bindings (Módulo 15). The dash has its own button rather than a
/// direction double-tap: C sits under the left hand next to A/D/W, and a
/// double-tap would make every quick left-right correction a dash.
final Set<LogicalKeyboardKey> playerDashKeys = {LogicalKeyboardKey.keyC};
final Set<LogicalKeyboardKey> playerAttackKeys = {LogicalKeyboardKey.keyJ};

/// Seconds between trail puffs while dashing.
const double playerDashTrailInterval = 0.03;

/// The player: horizontal movement (arrows/A-D), jump + double jump
/// (Space/W/ArrowUp), dash (C) and a two-hit sword combo (J).
///
/// Structured like a phase platform (e.g. the linked_list `Vagao`): a plain (zero-size) [PositionComponent]
/// wrapper anchored at the feet, holding *sibling* children — the visual
/// [SpriteAnimationComponent], a fixed-size feet [RectangleHitbox], the
/// contact shadow and the [SwordHitbox]. The feet hitbox never depends on
/// which animation is showing.
///
/// Landing is resolved by Flame's own collision engine; this class only
/// reacts to `onCollision`/`onCollisionEnd`.
class Player extends PositionComponent with CollisionCallbacks {
  final Set<LogicalKeyboardKey> Function() getPressedKeys;

  /// `deathZone.y` from slots_config.json. Crossing it fires
  /// [onPlayerDeath].
  final double deathZoneY;

  /// Where [onPlayerDeath] resets the player to.
  final Vector2 respawnPosition;

  /// Extension hook invoked every time [onPlayerDeath] fires; the phase
  /// decides what a fall costs (linked_list charges `quedaDamage`).
  final void Function()? onDeath;

  /// Maps a platform the player just landed on to its logical index in the
  /// phase's structure (a slot of the linked list, say), or `null` when the
  /// platform is not part of it. Supplied by the phase; read-only.
  final int? Function(PlayerPlatform platform)? platformIndexOf;

  /// Fired when the platform under the player stops being solid.
  final void Function(PlayerPlatform lost)? onSupportLost;

  /// Fired whenever [takeCombatDamage] actually lands.
  final void Function(String reason, int hp)? onDamaged;

  /// Fired after a landing with real vertical movement, with the foot
  /// position and the impact speed.
  final void Function(Vector2 footPosition, double impactSpeed)? onLanded;

  /// Fired once per swing per target the sword's live hitbox touches. The
  /// arena decides what a contact means (a boss contact is resolved by
  /// `AttackDirector.resolvePlayerAttack`, i.e. `boss.takeDamage`).
  final void Function(PositionComponent target)? onSwordContact;

  late final SpriteAnimationComponent _visual;
  late final RectangleHitbox _feetHitbox;
  late final SwordHitbox _swordHitbox;
  late final PlayerFx _fx;

  final Map<(PlayerState, PlayerFacing), SpriteAnimation> _animations = {};

  PlayerFacing _facing = PlayerFacing.east;
  PlayerFacing get facing => _facing;

  PlayerState _state = PlayerState.idle;
  PlayerState get state => _state;

  /// Every state change, newest last — read by tests to check transition
  /// order. Bounded so a long session cannot grow it without limit.
  final List<PlayerState> stateHistory = [];

  final DashController dash = DashController();
  final AttackController attack = AttackController();

  /// Vertical velocity only — horizontal movement is applied directly as a
  /// position delta.
  double _verticalVelocity = 0;
  double get verticalVelocity => _verticalVelocity;
  bool _isOnGround = false;
  bool get isOnGround => _isOnGround;

  /// Jumps left before the player has to touch the ground again.
  int jumpsRemaining = playerMaxJumps;

  /// Edge detection for the held-key inputs.
  bool _jumpKeyWasDown = false;
  bool _dashKeyWasDown = false;
  bool _attackKeyWasDown = false;

  /// Seconds left of the double-jump flip animation.
  double _doubleJumpRemaining = 0;

  double _dashTrailTimer = 0;

  /// The platform currently supporting the player, if any.
  PlayerPlatform? _supportingPlatform;

  /// Squash-and-stretch state (visual only).
  double _squashPeak = 1;
  double _squashDuration = 0;
  double _squashElapsed = 0;

  late final ContactShadow _contactShadow;

  Player({
    required Vector2 position,
    required this.getPressedKeys,
    required this.deathZoneY,
    required this.respawnPosition,
    this.platformIndexOf,
    this.onDeath,
    this.onLanded,
    this.onSupportLost,
    this.onDamaged,
    this.onSwordContact,
  }) : super(position: position, anchor: Anchor.bottomCenter);

  // ---------------------------------------------------------------------------
  // Módulo 14 — combat state
  // ---------------------------------------------------------------------------

  int hp = playerMaxHp;

  bool get isDefeated => hp <= 0;

  double _invulnerableRemaining = 0;
  bool get isInvulnerable => _invulnerableRemaining > 0;

  /// Reserved (Frente 2): dash i-frames. Always false while
  /// [playerDashGrantsInvulnerability] is off, and nothing consults it yet.
  bool get isDashInvulnerable =>
      playerDashGrantsInvulnerability && dash.isDashing;

  double _staggerRemaining = 0;
  bool get isStaggered => _staggerRemaining > 0;

  int _currentSlotIndex = 0;
  int get currentSlotIndex => _currentSlotIndex;

  bool _tweenActive = false;
  bool get isBeingMoved => _tweenActive;

  double _damageFlashElapsed = 0;

  @override
  Future<void> onLoad() async {
    final frameSize = Vector2.all(playerFrameSize);
    for (final state in PlayerState.values) {
      final spec = playerSheetFor(state);
      if (spec == null) {
        continue;
      }
      for (final facing in PlayerFacing.values) {
        final sheet = SpriteSheet(
          image: await Flame.images.load(spec.assetPath(facing)),
          srcSize: frameSize,
        );
        _animations[(state, facing)] = sheet.createAnimation(
          row: 0,
          stepTime: spec.stepTime,
          to: spec.frameCount,
          loop: spec.loop,
        );
      }
    }

    _visual = SpriteAnimationComponent(
      animation: _animations[(_state, _facing)],
      size: frameSize.clone(),
      anchor: Anchor.bottomCenter,
      scale: Vector2.all(playerDisplayScale),
      position: Vector2(0, playerVisualYOffset),
    );
    await add(_visual);

    _feetHitbox = RectangleHitbox(
      size: Vector2(playerHitboxWidth, playerHitboxHeight),
      anchor: Anchor.bottomCenter,
      position: Vector2.zero(),
      collisionType: CollisionType.active,
    );
    await add(_feetHitbox);

    _contactShadow = await ContactShadow.load(
      width: playerContactShadowWidth,
      baseOpacity: playerContactShadowOpacity,
    );
    await add(_contactShadow);

    _swordHitbox = SwordHitbox(
      reach: playerAttackReach,
      height: playerAttackHitboxHeight,
      onContact: (target) => onSwordContact?.call(target),
    );
    await add(_swordHitbox);

    _fx = await PlayerFx.load();

    attack.onSwingStarted = _onSwingStarted;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _tickCombatTimers(dt);

    // A scripted move owns `position` for its duration.
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
    var dashPressed = keys.any(playerDashKeys.contains);
    var attackPressed = keys.any(playerAttackKeys.contains);

    // Módulo 14: a stagger is a brief loss of control, not a freeze.
    if (isStaggered) {
      movingLeft = false;
      movingRight = false;
      jumpPressed = false;
      dashPressed = false;
      attackPressed = false;
      dash.cancel(DashCancelReason.interrupted);
    }

    final jumpJustPressed = jumpPressed && !_jumpKeyWasDown;
    final dashJustPressed = dashPressed && !_dashKeyWasDown;
    final attackJustPressed = attackPressed && !_attackKeyWasDown;
    _jumpKeyWasDown = jumpPressed;
    _dashKeyWasDown = dashPressed;
    _attackKeyWasDown = attackPressed;

    final horizontalInput = movingLeft == movingRight ? 0 : (movingLeft ? -1 : 1);

    if (attackJustPressed) {
      requestAttack();
    }
    if (dashJustPressed) {
      requestDash(direction: horizontalInput == 0 ? null : horizontalInput);
    }

    // Losing the floor ends a grounded swing (attacks are ground-only).
    if (attack.isAttacking && !_isOnGround) {
      attack.cancel();
    }
    attack.tick(dt);
    _swordHitbox.setLive(
      live: attack.isHitboxActive,
      swingId: attack.swingId,
      facing: _facing,
    );

    final dashing = dash.isDashing;
    final attacking = attack.isAttacking;
    // Sampled before the tick below, so the frame that finishes an air dash
    // still holds the player's height instead of applying gravity.
    final airDash = dashing && !dash.startedGrounded;

    if (!dashing && !attacking) {
      if (horizontalInput != 0) {
        position.x += playerMoveSpeed * dt * horizontalInput;
        // Facing follows the input in the air too. It used to switch only
        // while grounded, so a mid-jump reversal moved the player the new
        // way while the art kept facing the old one until landing — which
        // read as the reversal lagging.
        _setFacing(horizontalInput < 0 ? PlayerFacing.west : PlayerFacing.east);
      }

      // One jump per *press*, up to [jumpsRemaining] between landings.
      if (jumpJustPressed && jumpsRemaining > 0) {
        _jump();
      }
    }

    // Dash movement. Horizontal only; a grounded dash ends the moment the
    // floor does, an air dash holds the player's height.
    if (dashing) {
      if (dash.startedGrounded && !_isOnGround) {
        dash.cancel(DashCancelReason.lostGround);
      } else {
        position.x += dash.tick(dt);
        _emitDashTrail(dt);
      }
    } else {
      dash.tick(dt);
    }

    if (_doubleJumpRemaining > 0) {
      _doubleJumpRemaining = math.max(0, _doubleJumpRemaining - dt);
    }

    // If the wagon supporting the player stopped being solid, drop the
    // player even though the hitboxes still overlap.
    if (_isOnGround && _supportingPlatform != null && !_supportingPlatform!.isSolid) {
      final lost = _supportingPlatform!;
      _isOnGround = false;
      _supportingPlatform = null;
      onSupportLost?.call(lost);
    }

    if (airDash) {
      _verticalVelocity = 0;
    } else {
      _verticalVelocity += playerGravityFor(_verticalVelocity) * dt;
      position.y += _verticalVelocity * dt;
    }

    if (position.y > deathZoneY) {
      onPlayerDeath();
    }

    _setState(_resolveState(isWalking: horizontalInput != 0));

    _updateSquashAndStretch(dt);
    _updateContactShadow();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _jump() {
    final isAirJump = !_isOnGround;
    _verticalVelocity = isAirJump
        ? playerJumpVelocity * playerDoubleJumpVelocityFactor
        : playerJumpVelocity;
    _isOnGround = false;
    _supportingPlatform = null;
    jumpsRemaining--;

    _startSquash(playerJumpStretchFactor, playerJumpStretchDuration);
    if (isAirJump) {
      _doubleJumpRemaining = playerDoubleJumpSheet.duration;
      // Anchored at the feet at the instant of activation — a world
      // sibling, so it stays where the jump happened.
      parent?.add(_fx.doubleJumpBurst(position.clone()));
    }
  }

  /// Starts a dash towards [direction] (-1/1), or the facing direction.
  /// Returns whether it started. Ignored mid-swing and while a scripted
  /// move owns the player.
  bool requestDash({int? direction}) {
    if (_tweenActive || attack.isAttacking || isStaggered) {
      return false;
    }
    final dir = direction ?? (_facing == PlayerFacing.west ? -1 : 1);
    if (!dash.tryStart(direction: dir, grounded: _isOnGround)) {
      return false;
    }
    _setFacing(dir < 0 ? PlayerFacing.west : PlayerFacing.east);
    _doubleJumpRemaining = 0;
    _dashTrailTimer = 0;
    if (!_isOnGround) {
      _verticalVelocity = 0;
    }
    return true;
  }

  /// One press of the attack key. Ground-only; ignored mid-dash.
  bool requestAttack() {
    if (_tweenActive || dash.isDashing || isStaggered) {
      return false;
    }
    return attack.press(grounded: _isOnGround);
  }

  void _onSwingStarted(SwordSwing swing) {
    final row = swing == SwordSwing.first ? 0 : 1;
    final activeFrames = AttackController.activeFramesOf(swing);
    final sheet = AttackController.sheetOf(swing);
    final dir = _facing == PlayerFacing.west ? -1.0 : 1.0;
    // Over the blade: half-way along the reach, with the arc's *drawn*
    // content (not its cell) centred on the blade height.
    final arc = _fx.slashArc(
      _facing,
      row,
      Vector2(
        dir * playerAttackReach * 0.5,
        PlayerFx.slashArcBladeY[row] - PlayerFx.slashArcContentOffsetY[row],
      ),
    );
    // Hidden until the first live frame, then plays across the peak.
    final swingId = attack.swingId;
    add(
      TimerComponent(
        period: activeFrames.first * sheet.stepTime,
        removeOnFinish: true,
        onTick: () {
          if (attack.isAttacking && attack.swingId == swingId) {
            add(arc);
          }
        },
      ),
    );
  }

  void _emitDashTrail(double dt) {
    _dashTrailTimer -= dt;
    if (_dashTrailTimer > 0) {
      return;
    }
    _dashTrailTimer = playerDashTrailInterval;
    final behind = dash.direction * -30.0;
    parent?.add(
      _fx.dashTrail(_facing, position + Vector2(behind, -45)),
    );
  }

  // ---------------------------------------------------------------------------
  // Animation state
  // ---------------------------------------------------------------------------

  PlayerState _resolveState({required bool isWalking}) {
    final swing = attack.swing;
    if (swing != null) {
      return swing == SwordSwing.first
          ? PlayerState.attack1
          : PlayerState.attack2;
    }
    if (dash.isDashing) {
      return PlayerState.dash;
    }
    if (!_isOnGround) {
      if (_doubleJumpRemaining > 0) {
        return PlayerState.doubleJump;
      }
      return _verticalVelocity < 0 ? PlayerState.jumpRise : PlayerState.jumpFall;
    }
    return isWalking ? PlayerState.walk : PlayerState.idle;
  }

  void _setState(PlayerState next) {
    if (next == _state) {
      return;
    }
    _state = next;
    stateHistory.add(next);
    if (stateHistory.length > 64) {
      stateHistory.removeAt(0);
    }
    _refreshAnimation();
  }

  void _setFacing(PlayerFacing facing) {
    if (facing == _facing) {
      return;
    }
    _facing = facing;
    _refreshAnimation(keepProgress: true);
  }

  /// Swaps the visual to the current (state, facing) animation.
  ///
  /// [keepProgress] is for facing-only swaps: west/east sheets share frame
  /// timing, so the new ticker resumes where the old one was — turning in
  /// mid-air must not restart the rise or the flip.
  void _refreshAnimation({bool keepProgress = false}) {
    if (!isLoaded) {
      return;
    }
    final previous = _visual.animationTicker;
    _visual.animation = _animations[(_state, _facing)];
    final next = _visual.animationTicker;
    if (keepProgress && previous != null && next != null) {
      next
        ..currentIndex = previous.currentIndex
        ..clock = previous.clock
        ..elapsed = previous.elapsed;
    }
    _applyVisualScale();
  }

  double get _baseScale =>
      playerDisplayScale / (playerSheetFor(_state)?.artScale ?? 1);

  /// Writes the current sheet's calibrated scale (times the squash
  /// multiplier) and keeps the visible foot on local y = 0 at that scale.
  void _applyVisualScale([double scaleY = 1]) {
    final base = _baseScale;
    if (scaleY == 1) {
      _visual.scale = Vector2.all(base);
    } else {
      _visual.scale = Vector2(base / scaleY, base * scaleY);
    }
    _visual.position.y = playerFrameBottomPadNative * _visual.scale.y;
  }

  /// Starts a squash/stretch: [peak] is the vertical scale multiplier the
  /// deformation begins at, easing back to 1 over [duration] seconds.
  void _startSquash(double peak, double duration) {
    _squashPeak = peak;
    _squashDuration = duration;
    _squashElapsed = 0;
  }

  /// Eases the current deformation out. Only ever multiplies the sheet's
  /// calibrated scale, and returns to it exactly when finished.
  void _updateSquashAndStretch(double dt) {
    if (_squashDuration <= 0) {
      return;
    }

    _squashElapsed += dt;
    final progress = (_squashElapsed / _squashDuration).clamp(0.0, 1.0);

    if (progress >= 1) {
      _squashDuration = 0;
      _squashPeak = 1;
      _applyVisualScale();
      return;
    }

    final eased = GameCurves.softOutAt(progress);
    _applyVisualScale(_squashPeak + (1 - _squashPeak) * eased);
  }

  void _updateContactShadow() {
    _contactShadow.opacity = _isOnGround
        ? playerContactShadowOpacity
        : playerContactShadowAirborneOpacity;
  }

  // ---------------------------------------------------------------------------
  // Death / reset
  // ---------------------------------------------------------------------------

  /// Fires when the player falls past [deathZoneY]: log, hook, reset.
  void onPlayerDeath() {
    developer.log(
      'Player died (fell past deathZone.y=$deathZoneY at y=${position.y})',
      name: 'Player',
    );

    onDeath?.call();

    _resetToRespawn();
  }

  void _resetToRespawn() {
    position.setFrom(respawnPosition);
    _verticalVelocity = 0;
    _isOnGround = false;
    _supportingPlatform = null;
    jumpsRemaining = playerMaxJumps;
    _jumpKeyWasDown = false;
    _doubleJumpRemaining = 0;
    dash.reset();
    attack.cancel();
  }

  // ---------------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------------

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is ArenaWall) {
      _resolveWall(other);
      return;
    }

    // `other` is the hitbox's parent entity — the platform itself.
    if (other is! PlayerPlatform) {
      return;
    }
    final platform = other as PlayerPlatform;
    if (!platform.isSolid || _verticalVelocity < 0) {
      return;
    }

    // Read before the snap zeroes it.
    final impactSpeed = _verticalVelocity;

    position.y = platform.platformTopY;
    _verticalVelocity = 0;
    _isOnGround = true;
    _supportingPlatform = platform;

    // Touching the ground refills the jumps and ends the flip.
    jumpsRemaining = playerMaxJumps;
    _doubleJumpRemaining = 0;

    final index = platformIndexOf?.call(platform);
    if (index != null) {
      _currentSlotIndex = index;
    }

    _onLandingFx(impactSpeed);
  }

  /// Pushes the feet hitbox out of [wall] horizontally and ends any dash.
  void _resolveWall(ArenaWall wall) {
    final rect = wall.hitbox.toAbsoluteRect();
    final half = playerHitboxWidth / 2;
    if (position.x < rect.center.dx) {
      position.x = math.min(position.x, rect.left - half);
    } else {
      position.x = math.max(position.x, rect.right + half);
    }
    dash.cancel(DashCancelReason.wall);
  }

  /// Squash + dust on touchdown, gated on a real vertical impact.
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

    onLanded?.call(position.clone(), impactSpeed);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is PlayerPlatform) {
      _isOnGround = false;
      if (identical(_supportingPlatform, other)) {
        _supportingPlatform = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Módulo 14 — combat
  // ---------------------------------------------------------------------------

  void _tickCombatTimers(double dt) {
    if (_invulnerableRemaining > 0) {
      _invulnerableRemaining = math.max(0, _invulnerableRemaining - dt);
      _damageFlashElapsed += dt;
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
  void stagger({double direction = 1}) {
    _staggerRemaining = playerStaggerDuration;
    position.x += playerStaggerPushback * direction;
    _startSquash(playerLandSquashFactor, playerStaggerDuration);
  }

  /// Carries the player to [target] over [duration], then hands control
  /// back — the movement half of `InserirNo`. Visual easing only; the
  /// destination is exact. [onSettled] receives the foot position.
  void shoveToSlot(
    Vector2 target, {
    double duration = playerShoveTweenDuration,
    void Function(Vector2 footPosition)? onSettled,
  }) {
    if (_tweenActive) {
      return;
    }
    _tweenActive = true;
    _verticalVelocity = 0;
    dash.cancel(DashCancelReason.interrupted);
    attack.cancel();
    add(
      MoveToEffect(
        target,
        EffectController(duration: duration, curve: GameCurves.impactOut),
        onComplete: () {
          _tweenActive = false;
          _isOnGround = false;
          _supportingPlatform = null;
          _startSquash(
            playerShoveLandSquashFactor,
            playerShoveLandSquashDuration,
          );
          onSettled?.call(position.clone());
        },
      ),
    );
  }

  /// Test hook: the visual child's current scale. Read-only.
  Vector2 get debugVisualScaleForTest => _visual.scale.clone();

  /// Test hook: the visual child's current foot offset. Read-only.
  double get debugVisualYOffsetForTest => _visual.position.y;

  /// Test hook: the sword hitbox, for asserting when it is live.
  SwordHitbox get swordHitbox => _swordHitbox;

  /// Full reset for a restarted fight.
  void resetCombat() {
    hp = playerMaxHp;
    _invulnerableRemaining = 0;
    _staggerRemaining = 0;
    _currentSlotIndex = 0;
    _visual.opacity = 1;
    _resetToRespawn();
  }
}
