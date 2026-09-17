/// Módulo 15 — the project's single easing vocabulary.
///
/// Mudança 5 of the playtest pass: before this file every system that
/// moved a transform picked its own timing (the head-push tween eased,
/// the wagon tremor teleported to a fresh random offset every frame, the
/// squash rolled its own inline `1 - (1-t)^3`). The result read as rigid
/// even where a curve *was* applied, because no two systems agreed on the
/// shape of "settling into place".
///
/// So: one curve, [GameCurves.softOut], used by every transform tween that
/// belongs to combat or movement — the InserirNo push, the landing/jump
/// squash, the wagon tremor. Nothing here changes *what* the game does;
/// it only fixes how a change of position or scale is distributed over
/// time.
library;

import 'package:flutter/animation.dart' show Curve, Curves;

/// The project's easing curves.
///
/// Deliberately a tiny, closed set: two entries, both ease-*out* shapes,
/// because everything they drive is a reaction settling (a shove landing,
/// feet hitting a roof, a wagon shuddering to rest) rather than an action
/// starting. A system that wants a different feel should be asking
/// whether it is really the same kind of motion, not adding a third
/// constant here.
abstract final class GameCurves {
  /// The default for every combat/movement transform tween: fast at the
  /// start, decelerating into the target with no overshoot.
  static const Curve softOut = Curves.easeOutCubic;

  /// The same shape with a small overshoot, for the one moment that
  /// benefits from reading as an *impact* rather than an arrival: the
  /// player being shoved onto their new slot by InserirNo.
  static const Curve impactOut = Curves.easeOutBack;

  /// [softOut] evaluated by hand, for the systems that interpolate
  /// manually (per-frame lerps) instead of driving a Flame `Effect`.
  ///
  /// Keeping the scalar version here — rather than letting each of those
  /// inline its own cubic — is the whole point of this file: the two
  /// paths cannot drift apart.
  static double softOutAt(double t) => softOut.transform(t.clamp(0.0, 1.0));
}
