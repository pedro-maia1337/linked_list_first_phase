import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/game/fx/fx_config.dart';
import 'package:linked_list_first_phase/game/vagoneiro_arena_game.dart';

/// Módulo 12 verification harness for the two behaviours that can't be
/// checked by eye in a single screenshot: the camera's easing/clamping and
/// the parallax layers reacting to the *camera* rather than to the player.
///
/// Everything here only reads the game — it never asserts on, or exercises,
/// gameplay rules (physics, collision, death, wagon/boss state machines).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds and mounts the real game at a fixed 1672x941 surface.
  ///
  /// `load()` + `mount()` + `ready()` is Flame's own headless boot sequence
  /// (the same one `FlameGame.ready()`'s doc describes): without the
  /// `mount()`, components added during `onLoad` are never attached to the
  /// tree and anything holding an `EffectTarget` — such as the wagon's
  /// spawn `ScaleEffect` — throws on its first update.
  Future<VagoneiroArenaGame> bootGame() async {
    final game = VagoneiroArenaGame();
    game.onGameResize(Vector2(1672, 941));
    // `load`/`mount` are `@internal` to Flame because production code never
    // calls them directly (GameWidget does). A headless test *is* the
    // GameWidget here, so calling them is the intended way to boot a game
    // without a widget tree.
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    await game.ready();
    game.update(0);
    return game;
  }

  /// Height the pinned player is held at — comfortably above
  /// `deathZone.y` (900).
  const pinY = 400.0;

  /// Advances the simulation while holding the player at [pinX].
  ///
  /// Both axes have to be pinned. An unpinned player parked at an arbitrary
  /// x has no wagon under it, falls past `deathZone.y` and is respawned by
  /// the real (untouched) death path back to x=1440 — and because the
  /// world (and therefore the player) updates before `CameraDirector` does
  /// within a single tick, the camera would read that respawned x on every
  /// death frame and quietly corrupt the measurement. Re-applying the whole
  /// position before every tick keeps the camera's input constant without
  /// changing any gameplay code.
  void advance(VagoneiroArenaGame game, double seconds, {double? pinX}) {
    final steps = (seconds * 60).round();
    for (var i = 0; i < steps; i++) {
      if (pinX != null) {
        game.player.position.setValues(pinX, pinY);
      }
      game.update(1 / 60);
    }
  }

  test('camera eases towards the player instead of snapping', () async {
    final game = await bootGame();

    // Park the camera at the left end of its travel, then ask for the right.
    advance(game, 3, pinX: 0);
    final settledLeft = game.camera.viewfinder.position.x;

    final right = game.arenaConfig.canvas.width;
    advance(game, 1 / 60, pinX: right);
    final afterOneFrame = game.camera.viewfinder.position.x;
    advance(game, 3, pinX: right);
    final settledRight = game.camera.viewfinder.position.x;

    expect(
      settledRight,
      greaterThan(settledLeft),
      reason: 'camera should follow the player horizontally',
    );
    // Easing, not snapping: one frame covers only a small slice of the gap.
    final gap = settledRight - settledLeft;
    expect(
      afterOneFrame - settledLeft,
      lessThan(gap * 0.25),
      reason: 'a single frame must not close most of the distance',
    );
    expect(
      afterOneFrame,
      greaterThan(settledLeft),
      reason: 'but it must move some of the way',
    );
  });

  test('camera keeps its visible rect inside the arena bounds', () async {
    final game = await bootGame();
    final canvas = game.arenaConfig.canvas;

    for (final x in <double>[-5000, 0, 400, 900, 1440, 1672, 9000]) {
      advance(game, 3, pinX: x);
      final visible = game.camera.visibleWorldRect;
      expect(
        visible.left,
        greaterThanOrEqualTo(-0.01),
        reason: 'visible rect ran off the left of the arena at player x=$x',
      );
      expect(
        visible.right,
        lessThanOrEqualTo(canvas.width + 0.01),
        reason: 'visible rect ran off the right of the arena at player x=$x',
      );
      expect(visible.top, greaterThanOrEqualTo(-0.01));
      expect(visible.bottom, lessThanOrEqualTo(canvas.height + 0.01));
    }
  });

  test('camera pan range is large enough to read as a follow', () async {
    final game = await bootGame();

    advance(game, 3, pinX: 0);
    final leftMost = game.camera.viewfinder.position.x;
    advance(game, 3, pinX: game.arenaConfig.canvas.width);
    final rightMost = game.camera.viewfinder.position.x;

    // canvasWidth - canvasWidth / zoom, i.e. what the "leve zoom" buys.
    final expectedRange = game.arenaConfig.canvas.width -
        game.arenaConfig.canvas.width / cameraZoomFactor;
    expect(rightMost - leftMost, closeTo(expectedRange, 1.0));
  });

  test(
    'backdrop layers shift by different amounts, driven by the camera',
    () async {
      final game = await bootGame();

      // The parallax offset each layer applies is
      // `(1 - factor) * (cameraX - referenceX)`, so over the same camera
      // travel `far` must slide further than `mid`, and both less than the
      // world itself (which slides by the full camera travel).
      advance(game, 3, pinX: 0);
      final cameraLeft = game.camera.viewfinder.position.x;

      advance(game, 3, pinX: game.arenaConfig.canvas.width);
      final cameraRight = game.camera.viewfinder.position.x;

      final cameraTravel = cameraRight - cameraLeft;
      expect(cameraTravel, greaterThan(0));

      final farShift = (1 - parallaxFactorFar) * cameraTravel;
      final midShift = (1 - parallaxFactorMid) * cameraTravel;

      expect(
        farShift,
        greaterThan(midShift),
        reason: 'the far layer must lag more than the mid layer',
      );
      expect(
        midShift,
        greaterThan(0),
        reason: 'the mid layer must still lag behind the world',
      );
      expect(
        farShift,
        lessThan(cameraTravel),
        reason: 'no layer may lag more than the camera itself travels',
      );
    },
  );

  test('screen shake displaces the camera and then fully settles back',
      () async {
    final game = await bootGame();

    const pinX = 800.0;
    advance(game, 3, pinX: pinX);
    final resting = game.camera.viewfinder.position.clone();

    game.cameraDirector.shake();
    var maxDisplacement = 0.0;
    final steps = (wagonFallShakeDuration * 60).round();
    for (var i = 0; i < steps; i++) {
      game.player.position.setValues(pinX, pinY);
      game.update(1 / 60);
      final d = (game.camera.viewfinder.position - resting).length;
      if (d > maxDisplacement) {
        maxDisplacement = d;
      }
    }

    expect(maxDisplacement, greaterThan(0.5), reason: 'shake did nothing');
    expect(
      maxDisplacement,
      lessThan(wagonFallShakeAmplitude * 2),
      reason: 'shake is meant to be subtle',
    );

    advance(game, 1, pinX: pinX);
    expect(
      (game.camera.viewfinder.position - resting).length,
      lessThan(0.01),
      reason: 'camera must return exactly to its resting position',
    );
  });
}
