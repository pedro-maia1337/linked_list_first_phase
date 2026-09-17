/// Módulo 15, Frente 4 — the sword combo, as plain state (no Flame).
///
/// Separate from movement physics: it owns only *which* swing is playing,
/// which frame of it, whether the hitbox is live, and the combo window. The
/// [Player] turns that into an animation, a hitbox and a slash effect; the
/// damage itself is resolved by `AttackDirector.resolvePlayerAttack`, the
/// same `boss.takeDamage()` path every other damage source uses.
library;

import 'player_animations.dart';

/// Frames (0-based) where the blade is at full extension and the hitbox is
/// live. The brief numbers them 1-based: attack1 frames 3-4, attack2
/// frame 4.
const Set<int> playerAttack1ActiveFrames = {2, 3};
const Set<int> playerAttack2ActiveFrames = {3};

/// Horizontal reach of the hitbox, measured from the player's centre to the
/// tip of the swing: 1.4x the calibrated 110px height.
const double playerAttackReach = 1.4 * 110;

/// Vertical extent of the hitbox, from the feet up.
const double playerAttackHitboxHeight = 90;

/// How long after golpe 1 ends a new press still chains into golpe 2. A
/// press during golpe 1's recovery frames (after its peak) is also kept and
/// chains the moment golpe 1 ends.
const double playerAttackComboWindow = 0.35;

enum SwordSwing { first, second }

class AttackController {
  final double comboWindow;

  AttackController({this.comboWindow = playerAttackComboWindow});

  SwordSwing? _swing;
  SwordSwing? get swing => _swing;
  bool get isAttacking => _swing != null;

  double _elapsed = 0;

  /// Seconds left in which a press chains into golpe 2.
  double _comboRemaining = 0;
  bool get comboWindowOpen => _comboRemaining > 0;

  bool _comboQueued = false;

  /// Bumped every time a swing starts, so the hitbox can remember which
  /// swing already dealt its damage (one hit per swing).
  int _swingId = 0;
  int get swingId => _swingId;

  /// Fired whenever a swing starts (the player swaps the animation there).
  void Function(SwordSwing swing)? onSwingStarted;

  /// Fired when the last swing ends with nothing queued.
  void Function()? onFinished;

  static PlayerSheetSpec sheetOf(SwordSwing swing) =>
      swing == SwordSwing.first ? playerAttack1Sheet : playerAttack2Sheet;

  static Set<int> activeFramesOf(SwordSwing swing) =>
      swing == SwordSwing.first
          ? playerAttack1ActiveFrames
          : playerAttack2ActiveFrames;

  int get frameIndex {
    final swing = _swing;
    if (swing == null) {
      return -1;
    }
    final sheet = sheetOf(swing);
    return (_elapsed / sheet.stepTime).floor().clamp(0, sheet.frameCount - 1);
  }

  /// True only on the peak frames of the current swing.
  bool get isHitboxActive {
    final swing = _swing;
    return swing != null && activeFramesOf(swing).contains(frameIndex);
  }

  /// Handles one press of the attack key. [grounded] = false is ignored
  /// (attack_air is reserved). Returns whether the press did anything.
  bool press({required bool grounded}) {
    if (!grounded) {
      return false;
    }
    final swing = _swing;
    if (swing == null) {
      _start(comboWindowOpen ? SwordSwing.second : SwordSwing.first);
      return true;
    }
    // Mid-swing: only golpe 1's recovery (past its first live frame) can
    // queue the follow-up. Golpe 2 is the finisher and ignores presses.
    if (swing == SwordSwing.first &&
        frameIndex >= playerAttack1ActiveFrames.first) {
      _comboQueued = true;
      return true;
    }
    return false;
  }

  void tick(double dt) {
    if (_comboRemaining > 0) {
      _comboRemaining -= dt;
      if (_comboRemaining < 0) {
        _comboRemaining = 0;
      }
    }
    final swing = _swing;
    if (swing == null) {
      return;
    }
    _elapsed += dt;
    if (_elapsed < sheetOf(swing).duration) {
      return;
    }

    _swing = null;
    if (swing == SwordSwing.first) {
      if (_comboQueued) {
        _start(SwordSwing.second);
        return;
      }
      _comboRemaining = comboWindow;
    } else {
      _comboRemaining = 0;
    }
    onFinished?.call();
  }

  /// Aborts the current swing (floor lost, scripted move) and closes the
  /// combo window.
  void cancel() {
    _swing = null;
    _comboQueued = false;
    _comboRemaining = 0;
    _elapsed = 0;
  }

  void _start(SwordSwing swing) {
    _swing = swing;
    _elapsed = 0;
    _comboQueued = false;
    _comboRemaining = 0;
    _swingId++;
    onSwingStarted?.call(swing);
  }
}
