import 'dart:math' as math;

import 'package:flame/components.dart';

import 'fx_config.dart';

/// Drives the camera (Módulo 12, item 5): eased horizontal follow, clamped
/// to the arena's own bounds, plus the transient screen shake item 4 asks
/// for.
///
/// Deliberately hand-rolled instead of `camera.follow(...)`: Flame's
/// `FollowBehavior` moves at a constant `maxSpeed` towards the target,
/// which reads as a mechanical drag rather than easing. This closes a fixed
/// *fraction* of the remaining distance per unit time —
/// `1 - e^(-k*dt)` — which is the frame-rate-independent form of
/// exponential smoothing, so the pan feels the same at 60 and at 144 fps.
///
/// It writes only `camera.viewfinder.position`. It never touches the
/// player, the wagons, the boss, any collider, or `deathZone.y`; the
/// player's own on-screen visibility is a consequence of the clamp bounds
/// (see [_clampedTarget]), not of any gameplay rule.
class CameraDirector extends Component {
  final CameraComponent camera;
  final PositionComponent target;

  /// Arena bounds the camera's *visible rect* is kept inside — the canvas
  /// from `slots_config.json`, which is also the horizontal extent the
  /// track (x 180..1440) and the boss (x 1530) live in. The parallax
  /// backdrop tiles infinitely, so the clamp is about keeping the framing
  /// honest, not about hiding an edge.
  final double worldWidth;
  final double worldHeight;

  final math.Random _random = math.Random();

  /// Eased, un-shaken camera position. Kept separate from
  /// `viewfinder.position` so a shake never feeds back into the easing.
  late Vector2 _eased;
  bool _initialised = false;

  double _shakeRemaining = 0;
  double _shakeDuration = 0;
  double _shakeAmplitude = 0;

  CameraDirector({
    required this.camera,
    required this.target,
    required this.worldWidth,
    required this.worldHeight,
  });

  /// Fires a decaying positional shake. Repeated triggers take the stronger
  /// of the two rather than stacking, so several wagons falling at once
  /// can't shove the camera off the arena.
  void shake({
    double amplitude = wagonFallShakeAmplitude,
    double duration = wagonFallShakeDuration,
  }) {
    if (amplitude <= _shakeAmplitude && _shakeRemaining > 0) {
      _shakeRemaining = math.max(_shakeRemaining, duration);
      return;
    }
    _shakeAmplitude = amplitude;
    _shakeDuration = duration;
    _shakeRemaining = duration;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final desired = _clampedTarget();

    if (!_initialised) {
      _eased = desired.clone();
      _initialised = true;
    } else {
      // Frame-rate independent exponential easing.
      final t = 1 - math.exp(-cameraFollowStiffness * dt);
      _eased += (desired - _eased) * t;
    }

    var offsetX = 0.0;
    var offsetY = 0.0;
    if (_shakeRemaining > 0) {
      _shakeRemaining = math.max(0, _shakeRemaining - dt);
      // Linear decay to zero, so the shake always settles exactly back on
      // the eased position.
      final decay = _shakeDuration <= 0 ? 0.0 : _shakeRemaining / _shakeDuration;
      final magnitude = _shakeAmplitude * decay;
      offsetX = (_random.nextDouble() * 2 - 1) * magnitude;
      offsetY = (_random.nextDouble() * 2 - 1) * magnitude;
      if (_shakeRemaining == 0) {
        _shakeAmplitude = 0;
      }
    }

    camera.viewfinder.position = Vector2(
      _eased.x + offsetX,
      _eased.y + offsetY,
    );
  }

  /// Where the camera would sit with no easing and no shake.
  ///
  /// Horizontal: centred on the player. Vertical: pinned as low as the
  /// bounds allow, which frames the track (slot y 660..780), the death line
  /// (y 900) and the jump apex (≈145px above a slot) without the camera
  /// bobbing every time the player jumps.
  Vector2 _clampedTarget() {
    final visible = camera.visibleWorldRect;
    final halfWidth = visible.width / 2;
    final halfHeight = visible.height / 2;

    return Vector2(
      _clampAxis(target.position.x, halfWidth, worldWidth),
      // Bottom-pinned rest position, then clamped by the same rule.
      _clampAxis(worldHeight - halfHeight, halfHeight, worldHeight),
    );
  }

  /// Keeps a `[centre - half, centre + half]` window inside `[0, extent]`.
  /// If the window is wider than the arena, the arena is centred instead —
  /// clamping would otherwise be unsatisfiable.
  static double _clampAxis(double centre, double half, double extent) {
    if (half * 2 >= extent) {
      return extent / 2;
    }
    return centre.clamp(half, extent - half);
  }
}
