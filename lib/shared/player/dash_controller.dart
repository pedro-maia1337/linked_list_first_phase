/// Módulo 15, Frente 2 — the dash, as plain state (no Flame), so its
/// distance, cooldown and cancellation can be tested without a game.
///
/// The controller only answers "how far does the player move this frame";
/// the [Player] applies that delta, suspends vertical input while
/// [isDashing], and calls [cancel] on a wall hit or on losing the floor.
library;

import 'dart:math' as math;

/// Calibrated player height (section 2.3) — mirrored here so this file stays
/// Flame-free; `player_test` pins it to `playerRenderedHeightPx`.
const double playerDashReferenceHeight = 110;

/// Fixed dash distance: 2.1x the player's height (brief: 2.0-2.2x).
const double playerDashDistance = 2.1 * playerDashReferenceHeight;

/// Nominal duration of a full, uncancelled dash.
const double playerDashDuration = 0.15;

/// Seconds after a dash *starts* before another may start. Time-based only —
/// no stamina/mana resource exists or should be introduced.
const double playerDashCooldown = 0.6;

/// Largest displacement a single frame may apply. Caps a long frame (a
/// hitch) so the dash cannot tunnel through a wall collider thinner than
/// twice this value (arena walls are 80px thick). The distance is tracked,
/// not the time, so capping a step only delays the dash — it never
/// shortens it.
const double playerDashMaxStep = 32;

/// Reserved extension point: i-frames during the dash. Deliberately off and
/// read by nothing yet — flipping it does nothing until the invulnerability
/// logic is written (see `Player.isDashInvulnerable`).
const bool playerDashGrantsInvulnerability = false;

enum DashCancelReason { wall, lostGround, interrupted }

class DashController {
  final double distance;
  final double duration;
  final double cooldown;

  DashController({
    this.distance = playerDashDistance,
    this.duration = playerDashDuration,
    this.cooldown = playerDashCooldown,
  });

  double get speed => distance / duration;

  bool _dashing = false;
  bool get isDashing => _dashing;

  /// -1 = west, 1 = east.
  int _direction = 1;
  int get direction => _direction;

  /// Whether the dash began on the ground (it is then cancelled by leaving
  /// the platform) or in the air (horizontal only, gravity suspended).
  bool _startedGrounded = false;
  bool get startedGrounded => _startedGrounded;

  double _travelled = 0;
  double get travelled => _travelled;

  double _cooldownRemaining = 0;
  double get cooldownRemaining => _cooldownRemaining;
  bool get isReady => !_dashing && _cooldownRemaining <= 0;

  DashCancelReason? lastCancelReason;

  /// Starts a dash towards [direction] (-1/1). Returns false when blocked by
  /// the cooldown or by a dash already running.
  bool tryStart({required int direction, required bool grounded}) {
    if (!isReady) {
      return false;
    }
    _dashing = true;
    _direction = direction < 0 ? -1 : 1;
    _startedGrounded = grounded;
    _travelled = 0;
    _cooldownRemaining = cooldown;
    lastCancelReason = null;
    return true;
  }

  /// Advances timers and returns this frame's horizontal displacement
  /// (signed, 0 when not dashing).
  double tick(double dt) {
    if (_cooldownRemaining > 0) {
      _cooldownRemaining = math.max(0, _cooldownRemaining - dt);
    }
    if (!_dashing) {
      return 0;
    }
    final step = math.min(
      math.min(speed * dt, playerDashMaxStep),
      distance - _travelled,
    );
    _travelled += step;
    if (_travelled >= distance) {
      _dashing = false;
    }
    return step * _direction;
  }

  void cancel(DashCancelReason reason) {
    if (!_dashing) {
      return;
    }
    _dashing = false;
    lastCancelReason = reason;
  }

  void reset() {
    _dashing = false;
    _travelled = 0;
    _cooldownRemaining = 0;
    lastCancelReason = null;
  }
}
