import 'dart:io';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/shared/debug/debug_help_overlay.dart';
import 'package:linked_list_first_phase/shared/debug/debug_marker.dart';
import 'package:linked_list_first_phase/phases/linked_list/boss/boss_combat.dart';
import 'package:linked_list_first_phase/shared/hud/combat_hud.dart';
import 'package:linked_list_first_phase/phases/linked_list/vagoneiro_arena_game.dart';

/// Offscreen renderer for eyeballing the arena without opening a window.
///
/// Boots the real [VagoneiroArenaGame] headlessly — exactly the way the
/// other tests in this folder do — renders one frame into a
/// [PictureRecorder], and writes it to `SNAPSHOT_OUT`. It asserts nothing;
/// it exists so a visual change can be reviewed against the real render
/// path (same components, same priorities, same camera) instead of a
/// hand-rolled mock-up.
///
/// Run with:
///   flutter test test/phases/linked_list/scene_snapshot_tool.dart ///     --dart-define=SNAPSHOT_OUT=`the png path`
///
/// Two optional switches:
///  * `SNAPSHOT_FULL_ARENA=true` drops the `CameraDirector` and frames the
///    whole 1672x941 canvas, so both ends of the track are in shot at once
///    (the follow camera normally has one end or the other off-screen).
///  * `SNAPSHOT_FANTASMA_SLOT=<n>` fires the RemoverNo sequence on
///    that slot before the settle loop, so a tremor/falling frame can be
///    reviewed instead of the resting scene.
///  * `SNAPSHOT_CLEAN=true` removes the debug markers and both HUDs, which
///    otherwise cover the scene in coloured dots and — in a headless test,
///    where there is no font — solid blocks.
///  * `SNAPSHOT_PHASE=2` (or 3) drives the fight into that phase before the
///    frame is taken. Módulo 15 left phases with no dressing of their own
///    — only cadence — so this now changes the HUD caption and nothing on
///    the track.
///  * `SNAPSHOT_INSERIR=true` runs one InserirNo before the frame is taken,
///    for reviewing the push and the relabel it leaves behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const outPath = String.fromEnvironment('SNAPSHOT_OUT');
  const fullArena = bool.fromEnvironment('SNAPSHOT_FULL_ARENA');
  const clean = bool.fromEnvironment('SNAPSHOT_CLEAN');
  const fantasmaSlot = int.fromEnvironment('SNAPSHOT_FANTASMA_SLOT', defaultValue: -1);
  // `double.fromEnvironment` does not exist — settle time is given in
  // whole frames at 60fps instead.
  const settleFrames =
      int.fromEnvironment('SNAPSHOT_SETTLE_FRAMES', defaultValue: 120);
  const phase = int.fromEnvironment('SNAPSHOT_PHASE', defaultValue: 1);
  const inserir = bool.fromEnvironment('SNAPSHOT_INSERIR');

  test('render one arena frame to a png', () async {
    if (outPath.isEmpty) {
      // Run without --dart-define=SNAPSHOT_OUT there is nowhere to write;
      // skip rather than throwing on File('').
      markTestSkipped('pass --dart-define=SNAPSHOT_OUT=<path> to render');
      return;
    }
    final game = VagoneiroArenaGame();
    game.onGameResize(Vector2(1672, 941));
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    await game.ready();

    if (clean) {
      // Debug scaffolding only — removing it changes nothing about what
      // the gameplay/fx components draw.
      for (final marker in game.world.children.whereType<DebugMarker>().toList()) {
        marker.removeFromParent();
      }
      for (final hud
          in game.camera.viewport.children.whereType<DebugHelpOverlay>().toList()) {
        hud.removeFromParent();
      }
      // Módulo 14: the combat HUD renders text too, which a headless test
      // (no font loaded) paints as solid blocks over the scene.
      for (final hud
          in game.camera.viewport.children.whereType<CombatHud>().toList()) {
        hud.removeFromParent();
      }
    }

    // Módulo 14: drive the fight forward before the frame is taken, so the
    // phase dressing is on screen. Goes through the real transition hook,
    // not a hand-set flag, so what is reviewed is what a player would see.
    if (phase >= 2) {
      game.attackDirector.onPhaseChanged(
        phase >= 3 ? BossPhase.fase3 : BossPhase.fase2,
      );
    }
    // Módulo 15: SNAPSHOT_CICLO is gone with the Ciclo Corrompido. The
    // insertion is what replaces it as the interesting frame to review —
    // it is the attack with a visible consequence for the whole rail.
    if (inserir) {
      await game.attackDirector.inserirNo();
    }

    if (fantasmaSlot >= 0) {
      // Let the spawn tween land first — a sequence started inside the
      // 0.25s spawn window has its `tremor` overwritten by the tween's
      // `onComplete` (pre-existing wagon behaviour, see the note in
      // wagon_and_player_fx_test.dart).
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
      game.boss.debugTriggerVagaoFantasma(fantasmaSlot);
    }

    // Let the spawn tweens finish and the async decorations (lantern pools,
    // chain links, anchors) actually attach before the frame is taken.
    for (var i = 0; i < settleFrames; i++) {
      game.update(1 / 60);
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    if (fullArena) {
      // Frame the whole canvas. Done after the settle loop so the
      // CameraDirector's own easing/clamping has already run — this only
      // overrides where the finished frame is shot from.
      game.cameraDirector.removeFromParent();
      game.camera.viewfinder.visibleGameSize = Vector2(1672, 941);
      game.camera.viewfinder.position = Vector2(1672 / 2, 941 / 2);
      game.update(0);
    }
    game.update(0);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    game.render(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1672, 941);
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('SNAPSHOT WRITTEN: $outPath');
  });
}
