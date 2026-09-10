import 'dart:math' as math;

import 'package:flame/components.dart';

import '../track/linear_track.dart';
import '../wagon/vagao.dart';
import 'fx_config.dart';
import 'game_curves.dart';
import 'sprite_burst.dart';

/// World-y offset (relative to a wagon's ground point) at which the tremor
/// sparks are emitted: just above the platform collider's top surface
/// (-38px, `vagaoColliderOffsetY` + `vagaoColliderHeight`), so the embers
/// come off the wagon's roof line rather than out of thin air. Read as a
/// visual reference only — this module neither defines nor changes that
/// collider geometry.
const double _sparkEmitY = -46;

/// Vertical spread of the one-shot ember bursts around [_sparkEmitY].
const double _sparkSpreadY = 26;

/// Watches every wagon on the track and plays the Módulo 12 juice for its
/// state transitions, **without touching the wagon state machine itself**.
///
/// It is a pure observer: it polls `slot.vagao?.state` once per frame and
/// reacts to changes. `Vagao.playVagaoFantasmaSequence` (tremor -> falling
/// -> removed), `Vagao.isSolid`, the platform collider and the boss's
/// `occupySlot`/`clearSlot` are all left exactly as they were — which is
/// also why the effects survive any future change to *when* those
/// transitions fire.
///
/// What it produces:
///  * `tremor`: a looping `spark-ember` at the wagon's roof, a stream of
///    one-shot embers around it, and a small positional jitter of the
///    wagon's **sprite only** (`Vagao.applyVisualJitter`) — on top of, not
///    instead of, the existing `vagao-marcado.png` sprite swap;
///  * entering `falling`: one subtle screen shake via [onWagonEnteredFalling].
class WagonFxObserver extends Component {
  final LinearTrack track;

  /// Where the particle components are added (the game's world).
  final Component effectsParent;

  /// Invoked once, on the frame a wagon transitions into
  /// [VagaoState.falling].
  final void Function() onWagonEnteredFalling;

  final Map<int, _WagonFx> _bySlot = {};
  final math.Random _random = math.Random();

  WagonFxObserver({
    required this.track,
    required this.effectsParent,
    required this.onWagonEnteredFalling,
  });

  @override
  void update(double dt) {
    super.update(dt);

    for (final slot in track.slots) {
      final vagao = slot.vagao;
      final existing = _bySlot[slot.index];

      if (vagao == null || vagao.isRemoved) {
        existing?.dispose();
        _bySlot.remove(slot.index);
        continue;
      }

      // A cleared slot re-occupied in the same frame would otherwise keep
      // the previous wagon's effects — rebuild whenever the identity
      // changes, not just when the slot empties.
      if (existing == null || !identical(existing.vagao, vagao)) {
        existing?.dispose();
        _bySlot[slot.index] = _WagonFx(vagao)..update(dt, this);
        continue;
      }

      existing.update(dt, this);
    }
  }

  @override
  void onRemove() {
    for (final fx in _bySlot.values) {
      fx.dispose();
    }
    _bySlot.clear();
    super.onRemove();
  }

  double _randomSpread(double amplitude) =>
      (_random.nextDouble() * 2 - 1) * amplitude;
}

/// Per-wagon effect state: which state we last saw, the looping ember, and
/// the burst timer.
class _WagonFx {
  final Vagao vagao;

  VagaoState? _lastState;
  SpriteLoop? _emberLoop;
  double _burstTimer = 0;

  /// Mudança 5 — the tremor's eased jitter.
  ///
  /// This used to write a fresh random offset **every frame**, which is
  /// white noise, not a tremor: at 60fps the sprite teleported 60 times a
  /// second between unrelated points, and no amount of tuning the
  /// amplitude could make that read as a wagon shuddering. Now the jitter
  /// picks a target every [_retargetInterval] and *eases* towards it on
  /// [GameCurves.softOut] — the same curve the push and the landing squash
  /// use — so the motion has direction and settles instead of buzzing.
  ///
  /// The amplitude constant (`vagaoTremorJitterAmplitude`) is unchanged;
  /// only how the offset gets from one value to the next is.
  final Vector2 _jitterFrom = Vector2.zero();
  final Vector2 _jitterTo = Vector2.zero();
  double _jitterElapsed = 0;

  /// How long one jitter step takes. ~5 retargets over the ~1.2s tremor's
  /// first half — fast enough to read as a shudder, slow enough that each
  /// step is a movement rather than a jump.
  static const double _retargetInterval = 0.09;

  _WagonFx(this.vagao);

  void update(double dt, WagonFxObserver observer) {
    final state = vagao.state;
    if (state != _lastState) {
      _onStateChanged(_lastState, state, observer);
      _lastState = state;
    }

    if (state == VagaoState.tremor) {
      _updateTremor(dt, observer);
    }
  }

  void _onStateChanged(
    VagaoState? from,
    VagaoState to,
    WagonFxObserver observer,
  ) {
    if (from == VagaoState.tremor && to != VagaoState.tremor) {
      _stopTremor();
    }

    if (to == VagaoState.tremor) {
      _startTremor(observer);
    } else if (to == VagaoState.falling) {
      // Módulo 12, item 4: "screen shake sutil quando um vagão entra em
      // falling". Fired once, on the transition — not per frame of the
      // falling animation.
      observer.onWagonEnteredFalling();
    }
  }

  Future<void> _startTremor(WagonFxObserver observer) async {
    _burstTimer = 0;
    final loop = await SpriteLoop.sparkEmber(
      Vector2(vagao.position.x, vagao.position.y + _sparkEmitY),
    );
    // The wagon may have left `tremor` (or been removed entirely) while the
    // spritesheet was loading.
    if (_lastState != VagaoState.tremor || vagao.isRemoved) {
      return;
    }
    _emberLoop = loop;
    await observer.effectsParent.add(loop);
  }

  void _stopTremor() {
    _emberLoop?.removeFromParent();
    _emberLoop = null;
    _jitterFrom.setZero();
    _jitterTo.setZero();
    _jitterElapsed = 0;
    // Always put the sprite back exactly where it belongs — the jitter is
    // a temporary visual offset, never a new resting position.
    vagao.applyVisualJitter(Vector2.zero());
  }

  void _updateTremor(double dt, WagonFxObserver observer) {
    _jitterElapsed += dt;
    if (_jitterElapsed >= _retargetInterval) {
      _jitterElapsed -= _retargetInterval;
      _jitterFrom.setFrom(_jitterTo);
      _jitterTo.setValues(
        observer._randomSpread(vagaoTremorJitterAmplitude),
        observer._randomSpread(vagaoTremorJitterAmplitude),
      );
    }
    final t = GameCurves.softOutAt(_jitterElapsed / _retargetInterval);
    vagao.applyVisualJitter(
      Vector2(
        _jitterFrom.x + (_jitterTo.x - _jitterFrom.x) * t,
        _jitterFrom.y + (_jitterTo.y - _jitterFrom.y) * t,
      ),
    );

    _burstTimer -= dt;
    if (_burstTimer > 0) {
      return;
    }
    _burstTimer = sparkEmberBurstInterval;
    _spawnEmber(observer);
  }

  Future<void> _spawnEmber(WagonFxObserver observer) async {
    final position = Vector2(
      vagao.position.x + observer._randomSpread(sparkEmberSpreadX),
      vagao.position.y + _sparkEmitY + observer._randomSpread(_sparkSpreadY),
    );
    final burst = await SpriteBurst.sparkEmber(position);
    if (_lastState != VagaoState.tremor || vagao.isRemoved) {
      return;
    }
    await observer.effectsParent.add(burst);
  }

  void dispose() {
    _stopTremor();
  }
}
