import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'boss/attack_director.dart';
import 'boss/boss_combat.dart';
import 'boss/vagoneiro_boss.dart';
import 'components/debug_help_overlay.dart';
import 'components/debug_marker.dart';
import 'components/height_ruler.dart';
import 'config/arena_config.dart';
import 'fx/ambient_light.dart';
import 'fx/boss_dock.dart';
import 'fx/boss_rim_light.dart';
import 'fx/camera_director.dart';
import 'fx/contact_shadow.dart';
import 'fx/fx_config.dart';
import 'fx/glow_light.dart';
import 'fx/parallax_backdrop.dart';
import 'fx/sprite_burst.dart';
import 'fx/wagon_fx_observer.dart';
import 'hud/combat_hud.dart';
import 'player/player.dart';
import 'track/linear_track.dart';
import 'wagon/chain_anchor.dart';
import 'wagon/chain_segment.dart';

/// Maps digit keys 0-7 to their slot index, for the debug occupy/clear
/// controls requested for this etapa (0-7 = occupySlot, Shift+0-7 =
/// clearSlot).
final Map<LogicalKeyboardKey, int> _debugSlotKeys = {
  LogicalKeyboardKey.digit0: 0,
  LogicalKeyboardKey.digit1: 1,
  LogicalKeyboardKey.digit2: 2,
  LogicalKeyboardKey.digit3: 3,
  LogicalKeyboardKey.digit4: 4,
  LogicalKeyboardKey.digit5: 5,
  LogicalKeyboardKey.digit6: 6,
  LogicalKeyboardKey.digit7: 7,
};

/// Initial arena for the boss "O Vagoneiro".
///
/// Scope for this step (see docs/boss-vagoneiro-design.md, sections 3, 4.3,
/// 8.1 and 9): the parallax backdrop (Módulo 12, replacing the single
/// canvas-sized background sprite of Módulos 0-11), the [LinearTrack]
/// linked list of [Slot]s built from slots_config.json, [VagoneiroBoss]
/// standing at its fixed position playing `idle`, its real
/// `occupySlot`/`clearSlot` wired to spawn/remove [Vagao]s, and [Player]
/// with gravity/jump landing on wagons via Flame's own collision engine
/// ([HasCollisionDetection] — no hand-rolled overlap detection).
class VagoneiroArenaGame extends FlameGame
    with KeyboardEvents, HasCollisionDetection {
  late final ArenaConfig arenaConfig;
  late final LinearTrack track;
  late final VagoneiroBoss boss;
  late final Player player;

  /// Módulo 12: eased horizontal follow + screen shake. Also the single
  /// thing driving the parallax layers, which read the camera's position
  /// (not the player's) every frame.
  late final CameraDirector cameraDirector;

  /// Módulo 14 — the fight. [combatHud] is the read-out, [attackDirector]
  /// the scheduler; both are added in [onLoad] after the boss and the
  /// player exist, since they read (and only read) both.
  late final CombatHud combatHud;
  late final AttackDirector attackDirector;

  /// Every decorative chain segment in the arena, kept so phase 2 can turn
  /// them all gold in one call (Módulo 14, section 4.2 ④). The list is
  /// write-once at load and read-only afterwards.
  final List<ChainSegment> _chainSegments = [];

  bool _debugMarkersVisible = true;
  final List<DebugMarker> _debugMarkers = [];

  bool _heightRulersVisible = false;
  final List<HeightRuler> _heightRulers = [];

  Set<LogicalKeyboardKey> _pressedKeys = {};

  /// Test/debug hook: holds or releases the jump key without a real key
  /// event.
  ///
  /// Mudança 3's double jump is defined on the *edge* of the key (press,
  /// release, press), so verifying it needs control of the held state
  /// across frames — which `onKeyEvent` cannot give a headless test.
  /// Deliberately writes the same [_pressedKeys] set the real handler
  /// writes, so the test drives production input rather than a parallel
  /// path.
  void debugHoldJumpForTest(bool held) {
    _pressedKeys = held ? {LogicalKeyboardKey.space} : <LogicalKeyboardKey>{};
  }

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    arenaConfig = await ArenaConfig.load();

    // Módulo 12, item 5 ("leve zoom"): frame `canvas / cameraZoomFactor`
    // instead of the whole canvas. Kept as `visibleGameSize` rather than a
    // raw `zoom` value so Flame keeps recomputing the right zoom on every
    // window resize, exactly as it did before.
    camera.viewfinder.visibleGameSize = Vector2(
      arenaConfig.canvas.width / cameraZoomFactor,
      arenaConfig.canvas.height / cameraZoomFactor,
    );
    camera.viewfinder.position =
        Vector2(arenaConfig.canvas.width / 2, arenaConfig.canvas.height / 2);
    camera.viewfinder.anchor = Anchor.center;

    await _addParallaxBackdrop();

    // Created before the boss, because the boss's `onOperation` callback
    // starts firing as soon as `debugSpawnTestTrack()` populates the track.
    // Viewport-space, like the debug legend and the vignette.
    combatHud = CombatHud(
      bossHp: () => boss.hp,
      bossPhase: () => boss.phase,
      bossExposed: () => boss.isExposed,
      playerHp: () => player.hp,
    );
    await camera.viewport.add(combatHud);

    track = LinearTrack.fromConfig(arenaConfig.slots);
    track.debugLogTraversal();

    boss = VagoneiroBoss(
      position: Vector2(arenaConfig.boss.x, arenaConfig.boss.y),
      facing: arenaConfig.boss.facing,
      track: track,
      container: world,
      // Módulo 14: every list operation the fight performs is echoed to
      // the HUD, so `occupySlot(3)` / `slot[7].next = null` are things the
      // player reads while they happen.
      onOperation: (operation) => combatHud.showOperation(operation),
      onPhaseChanged: (phase) => attackDirector.onPhaseChanged(phase),
      onDefeated: _onBossDefeated,
    );
    world.add(boss);

    // Módulo 14, Frente 1: the dock and the contact shadow that put the
    // boss *in* the scene instead of on top of it. Both are registered
    // against `boss.visibleFootY`, and neither writes anything on the boss.
    await _addBossDock();

    await _addBossHighlightFx();
    await _addLanternGlows();

    await _addChainSegments();

    // DEBUG-ONLY: occupies every slot at once so multi-slot jump sequences
    // can be tested before Módulo 5 implements real progressive spawn/fall
    // gameplay. Remove/replace this call once that module exists — see
    // debugSpawnTestTrack() below.
    debugSpawnTestTrack();

    await _addDebugMarkers();

    // Fixed test position for this etapa: above slot 0's wagon, so gravity
    // pulls the player down onto it immediately, near the track's y-range
    // (a meaningful spot to test landing/jumping now that gravity exists).
    final respawnPosition = Vector2(arenaConfig.slots[0].x, 400);
    player = Player(
      position: respawnPosition.clone(),
      getPressedKeys: () => _pressedKeys,
      deathZoneY: arenaConfig.deathZone.y,
      respawnPosition: respawnPosition,
      track: track,
      // Módulo 12, item 4: dust on landing, at the foot contact point the
      // player itself reports (the anchor recalculated in Módulo 11) —
      // this game class never re-derives that point.
      onLanded: (footPosition, _) => _spawnLandingDust(footPosition),
      // Módulo 14/15, RemoverNo — the removal is not cosmetic. Two
      // separate moments, both charged as combat damage and both protected
      // from double-charging by the player's own invulnerability window:
      // losing the floor, and (only if the fall is not recovered) crossing
      // the death line through the pre-existing `onDeath` extension point.
      // Mudança 1 (a) is explicit that this is the hook to reuse, and no
      // new hitbox exists anywhere for it.
      onSupportLost: (_) {
        combatHud.showCaption('Nó removido: suporte perdido.');
        player.takeCombatDamage(removerNoDamage, reason: 'RemoverNo');
      },
      onDeath: () => player.takeCombatDamage(quedaDamage, reason: 'queda'),
      // Deliberately the ticker and not the caption: the caption is where
      // the *lesson* goes ("Nó removido.", "Fim da linha."), and a generic
      // damage notice firing a frame later would overwrite it every time.
      // The HP pips already show the loss.
      //
      // This is also the single place the defeat check hangs off, rather
      // than each damage site calling it: `onDamaged` fires for every
      // source that actually lands (chain, phantom wagon, head-push,
      // fall), so no source can reach 0 HP without the fight noticing.
      onDamaged: (reason, hp) {
        combatHud
            .showOperation('-1 HP ($reason) — maquinista $hp/$playerMaxHp');
        _checkPlayerDefeat();
      },
    );
    world.add(player);

    // Módulo 12, item 5: eased horizontal follow, clamped to the arena, and
    // the owner of the screen shake. Added to the game (not the world) so
    // it updates once per frame without participating in world rendering.
    cameraDirector = CameraDirector(
      camera: camera,
      target: player,
      worldWidth: arenaConfig.canvas.width,
      worldHeight: arenaConfig.canvas.height,
    );
    await add(cameraDirector);

    // Módulo 12, item 4: watches wagon states from the outside and plays
    // the tremor/falling juice. Adds nothing to, and reads nothing private
    // from, the wagon state machine.
    await add(
      WagonFxObserver(
        track: track,
        effectsParent: world,
        onWagonEnteredFalling: () => cameraDirector.shake(),
      ),
    );

    // Módulo 13, item 2: the warm half of the ambient-light integration —
    // wagons standing near a lantern anchor get a low, flickering pool of
    // that lantern's light on their roof, wagons in the dark stretches get
    // nothing. The cool half (the shared palette wash) is applied by the
    // wagons and the boss themselves in their own `onLoad`.
    await add(
      WagonLanternLightObserver(
        track: track,
        lanternAnchors: [
          for (final group in arenaConfig.decorativeAnchors.values) ...group,
        ],
      ),
    );

    _buildHeightRulers();

    // Módulo 14 — the fight's scheduler. Added to the game (not the world)
    // for the same reason `CameraDirector` is: it ticks once per frame and
    // renders nothing.
    attackDirector = AttackDirector(
      boss: boss,
      track: track,
      player: player,
      overlayParent: world,
      hud: combatHud,
      shakeCamera: () => cameraDirector.shake(),
      // Mudança 2: the same landing-dust spawner the player's own touchdown
      // uses, so the push's dust and a jump's dust are one effect with one
      // owner rather than two that drift apart.
      spawnDust: _spawnLandingDust,
    );
    await add(attackDirector);

    // Módulo 12, item 1: subtle edge darkening. Also viewport-space, but at
    // `fxPriorityVignette` (-10) — i.e. *below* the debug legend added just
    // below at its default priority 0, which therefore keeps rendering on
    // top of it, untouched and fully legible.
    camera.viewport.add(Vignette(camera: camera));

    // Pinned to the screen (viewport, not world) — see docs/boss-vagoneiro-
    // design.md section 11 for the acceptance criteria this legend exists
    // to make manually testable without touching code.
    camera.viewport.add(DebugHelpOverlay(position: Vector2(16, 16)));

    _logLoadedArenaConfig();
  }

  /// DEBUG-ONLY / TEMPORÁRIO: occupies all 8 slots at once purely so a
  /// tester can jump across the whole sequence of wagons before Módulo 5
  /// implements the real spawn/queda gameplay (progressive occupySlot
  /// calls driven by attack patterns). Replace or delete this method once
  /// that module exists — it has no gameplay meaning of its own, it's a
  /// QA shortcut for slots_config.json.
  void debugSpawnTestTrack() {
    for (final slot in track.slots) {
      boss.occupySlot(slot.index);
    }
  }

  /// Purely decorative: one [ChainSegment] per entry in
  /// `slots_config.json`'s `chainConnections.connections` (boss<->slot0
  /// and every consecutive slot pair — see module prompt, Tarefa 1/2).
  /// Every anchor point comes straight from that config; nothing here
  /// re-derives a position from `slot.x`/`slot.y`/`boss.x`/`boss.y`
  /// (those are ground-level, not where the chain should touch the
  /// wagon/boss art).
  ///
  /// Left at the default `priority` (same as the boss) and added here —
  /// after the boss, before `debugSpawnTestTrack()` spawns any [Vagao] — so
  /// same-priority paint order (insertion order) puts it below every wagon
  /// added afterwards. It sits above the backdrop unconditionally, since
  /// Módulo 12's parallax layers all take negative priorities (see
  /// `fx/fx_config.dart`) rather than sharing priority 0 the way the old
  /// single background sprite did.
  Future<void> _addChainSegments() async {
    for (final connection in arenaConfig.chainConnections.connections) {
      final segment = ChainSegment(
        fromAnchor: Vector2(connection.fromAnchor.x, connection.fromAnchor.y),
        toAnchor: Vector2(connection.toAnchor.x, connection.toAnchor.y),
        segmentDistance: connection.distance,
        farSlot: track.slotAt(connection.to),
      );
      _chainSegments.add(segment);
      await world.add(segment);
    }

    await _addEndAnchors();
  }

  /// Módulo 14, Frente 1 — the dock under the boss, plus the contact
  /// shadow on its deck.
  ///
  /// The shadow is a world sibling at [fxPriorityBossContactShadow] rather
  /// than a child of the boss: Flame draws a component's children *after*
  /// its own render, so a child shadow would be painted over the character
  /// instead of under him (the same reason `BossRimLight` is a sibling).
  /// It is centred on `boss.visibleFootY` — the real base of the art —
  /// which is the same line the dock's deck was placed on, so there is no
  /// gap between the boss's boots, his shadow and the plating by
  /// construction.
  Future<void> _addBossDock() async {
    final dock = await BossDock.under(boss);
    await world.add(dock);

    final shadow = ContactShadow(
      width: bossContactShadowWidth,
      baseOpacity: bossContactShadowOpacity,
      priority: fxPriorityBossContactShadow,
    )
      ..position = Vector2(boss.position.x, boss.visibleFootY)
      ..sprite = Sprite(await images.load(fxContactShadowAssetPath));
    await world.add(shadow);
  }

  void _onBossDefeated() {
    attackDirector.finish();
    combatHud.showCaption('VAGONEIRO DERROTADO', duration: 4);
    combatHud.showOperation('lista estabilizada');
    cameraDirector.shake(amplitude: 12, duration: 0.8);
  }

  /// Ends the fight if the player has run out of hit points, and resets
  /// both sides for another attempt. Deliberately a *restart* rather than a
  /// game-over screen: this module's scope is making the fight playable,
  /// and UI flow is still out of scope (design doc section 6).
  void _checkPlayerDefeat() {
    if (!player.isDefeated) {
      return;
    }
    combatHud.showCaption('MAQUINISTA CAIU — reiniciando', duration: 2.5);
    boss.resetCombat();
    attackDirector.restart();
    player.resetCombat();
  }

  /// Módulo 13, tarefa 6 — closes off the two ends of the track.
  ///
  /// Until now the chain decoration only ran wagon-to-wagon (plus
  /// boss-to-slot-0), so the wagon at either extremity had a chain leaving
  /// on one side and nothing at all on the other, which read as floating in
  /// the void. Each `endAnchors` entry in `slots_config.json` puts a wall
  /// fitting at a fixed point and, where it declares a `chainToSlot`, runs
  /// an ordinary [ChainSegment] from it to that slot's existing attach
  /// point.
  ///
  /// This is decoration only. The anchors have no hitbox, the segment is
  /// the same purely visual component already used between wagons, and
  /// nothing here reads or writes `next`/`prev`, slot coordinates, or the
  /// linked list.
  Future<void> _addEndAnchors() async {
    for (final endAnchor in arenaConfig.chainConnections.endAnchors) {
      await world.add(
        await ChainAnchor.at(
          tip: Vector2(endAnchor.tip.x, endAnchor.tip.y),
          side: ChainAnchorSide.fromConfig(endAnchor.sprite),
        ),
      );

      final slotIndex = endAnchor.chainToSlot;
      final toAnchor = endAnchor.toAnchor;
      if (slotIndex == null || toAnchor == null) {
        // An anchor whose own baked-in chain is the whole decoration (the
        // boss-side one, whose links disappear behind the boss and
        // continue as the pre-existing boss->slot 0 segment).
        continue;
      }

      final segment = ChainSegment(
        fromAnchor: Vector2(endAnchor.tip.x, endAnchor.tip.y),
        toAnchor: Vector2(toAnchor.x, toAnchor.y),
        segmentDistance: endAnchor.distance ??
            (Vector2(toAnchor.x, toAnchor.y) -
                    Vector2(endAnchor.tip.x, endAnchor.tip.y))
                .length,
        // Mirrors that wagon's state like any other segment, so this
        // chain breaks along with the one on its other side when the
        // end wagon falls.
        farSlot: track.slotAt(slotIndex),
      );
      // Registered like every other segment, so the phase-2 gold repaint
      // does not leave the track's end chain the one iron link in a gold
      // arena.
      _chainSegments.add(segment);
      await world.add(segment);
    }
  }

  /// Debug visual markers at every slot.x/y and at boss.x/y (ground-level,
  /// cyan/yellow), so position bugs (wrong coordinate) can be told apart
  /// from scale/collider bugs (right coordinate, wrong size) by eye — plus
  /// one magenta marker per `chainConnections` `fromAnchor`/`toAnchor`
  /// (the chain-attach points, ~[ChainConnectionsConfig.attachHeightAboveGround]
  /// above ground), to visually confirm each chain segment actually
  /// touches its two anchor points instead of floating or overshooting.
  /// Toggle with the `M` key.
  Future<void> _addDebugMarkers() async {
    for (final slot in track.slots) {
      final marker = DebugMarker(
        position: Vector2(slot.x, slot.y),
        color: const Color(0xFF00E5FF),
      );
      _debugMarkers.add(marker);
      await world.add(marker);
    }

    final bossMarker = DebugMarker(
      position: Vector2(arenaConfig.boss.x, arenaConfig.boss.y),
      color: const Color(0xFFFFEB3B),
    );
    _debugMarkers.add(bossMarker);
    await world.add(bossMarker);

    final seenAnchors = <String>{};
    for (final connection in arenaConfig.chainConnections.connections) {
      for (final anchor in [connection.fromAnchor, connection.toAnchor]) {
        // fromAnchor/toAnchor are shared between adjacent connections
        // (slot[i]'s toAnchor == slot[i]'s next connection's fromAnchor) —
        // dedupe so overlapping markers don't stack.
        final key = '${anchor.x},${anchor.y}';
        if (!seenAnchors.add(key)) {
          continue;
        }
        final marker = DebugMarker(
          position: Vector2(anchor.x, anchor.y),
          color: const Color(0xFFFF00FF),
          radius: 4,
        );
        _debugMarkers.add(marker);
        await world.add(marker);
      }
    }
  }

  /// Builds (but does not show) one [HeightRuler] per entity type — player,
  /// slot-0 wagon, boss — all sharing the same fixed [playerRenderedHeightPx]
  /// length (module task item 4: "régua/linha de referência de altura fixa
  /// ao lado do player, de um vagão e do boss simultaneamente"), so the
  /// section 2.1 scale ratios can be checked by eye: hidden by default,
  /// toggled with `L`. Uses the player's *rendered* height (110px post-
  /// Módulo 11, not the old raw-native 230px) so the ruler always reflects
  /// the player's real current on-screen size. The wagon ruler follows
  /// whatever wagon currently occupies slot 0, falling back to the bare
  /// slot ground point if that slot has been cleared via the debug
  /// controls.
  void _buildHeightRulers() {
    final slot0 = track.slotAt(0);

    _heightRulers.addAll([
      HeightRuler(
        groundAnchor: () => player.position,
        heightPx: playerRenderedHeightPx,
        color: const Color(0xFF00FF66),
        label: 'player',
      ),
      HeightRuler(
        groundAnchor: () =>
            slot0.vagao?.position ?? Vector2(slot0.x, slot0.y),
        heightPx: playerRenderedHeightPx,
        color: const Color(0xFF00E5FF),
        label: 'vagão (slot 0)',
      ),
      HeightRuler(
        groundAnchor: () => boss.position,
        heightPx: playerRenderedHeightPx,
        color: const Color(0xFFFFEB3B),
        label: 'boss',
      ),
    ]);
  }

  void _toggleHeightRulers() {
    _heightRulersVisible = !_heightRulersVisible;
    for (final ruler in _heightRulers) {
      if (_heightRulersVisible) {
        if (ruler.parent == null) {
          world.add(ruler);
        }
      } else {
        ruler.removeFromParent();
      }
    }
  }

  void _toggleDebugMarkers() {
    _debugMarkersVisible = !_debugMarkersVisible;
    for (final marker in _debugMarkers) {
      if (_debugMarkersVisible) {
        if (marker.parent == null) {
          world.add(marker);
        }
      } else {
        marker.removeFromParent();
      }
    }
  }

  /// Debug controls for this etapa: digit keys 0-7 call `occupySlot`,
  /// Shift+0-7 call `clearSlot`, `M` toggles the slot/boss position
  /// markers, for manual testing of every slot.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Snapshot of currently-held keys, polled every frame by Player for
    // continuous movement (arrows/A-D) — separate from the one-shot
    // KeyDownEvent handling below for the debug slot/marker controls.
    _pressedKeys = keysPressed;

    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _toggleDebugMarkers();
      return KeyEventResult.handled;
    }

    // Debug-only: toggle the fixed-height reference rulers (module task
    // item 4) beside the player, slot-0 wagon and boss.
    if (event.logicalKey == LogicalKeyboardKey.keyL) {
      _toggleHeightRulers();
      return KeyEventResult.handled;
    }

    // Debug-only isolated boss animation triggers (design doc section 4.1):
    // H = hit/stunned, X = exposed -> recovering -> idle.
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      boss.debugPlayHit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyX) {
      boss.debugPlayExposed();
      return KeyEventResult.handled;
    }

    // Debug-only isolated player animation preview (module task item 6):
    // N = walkNorth, S = walkSouth. Visual-only, no vertical movement.
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      player.debugPlayWalkNorth();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      player.debugPlayWalkSouth();
      return KeyEventResult.handled;
    }

    // Debug-only manual reset: reuses the real onPlayerDeath() hook
    // (Módulo 5), not a separate reset code path.
    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      player.onPlayerDeath();
      return KeyEventResult.handled;
    }

    // Módulo 14 — the player's attack. One key, one resolution: the rules
    // for what it hits (orphan / cycle entry / exposed boss / nothing) all
    // live in `AttackDirector.resolvePlayerAttack`.
    if (event.logicalKey == LogicalKeyboardKey.keyJ) {
      attackDirector.resolvePlayerAttack();
      return KeyEventResult.handled;
    }

    // Debug-only: force the next attack in the current phase's rotation,
    // instead of waiting out the interval.
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      attackDirector.runNextAttack();
      return KeyEventResult.handled;
    }

    // Debug-only: knock a chunk off the boss's HP so the phase
    // transitions (and the gold chains / orphan node they unlock) can be
    // reached without playing the whole fight.
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      boss.enterExposed(0.2);
      boss.takeDamage(3);
      return KeyEventResult.handled;
    }

    final index = _debugSlotKeys[event.logicalKey];
    if (index == null) {
      return KeyEventResult.ignored;
    }

    final isShiftPressed = keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight);
    final isControlPressed = keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        keysPressed.contains(LogicalKeyboardKey.controlRight);

    if (isControlPressed) {
      // Ctrl+0-7: RemoverNo debug trigger (tremor -> falling ->
      // clearSlot). Deliberately bypasses the non-adjacency rule — a debug
      // key exists to set up arrangements the boss would never choose.
      boss.debugTriggerVagaoFantasma(index);
    } else if (isShiftPressed) {
      boss.clearSlot(index);
    } else {
      boss.occupySlot(index);
    }
    return KeyEventResult.handled;
  }

  /// Módulo 12, item 1 — the parallax backdrop that replaces the single
  /// static `caverna-gotica-pixelart.png` sprite the arena used through
  /// Módulos 0-11.
  ///
  /// The replacement is deliberate and unavoidable: that sprite is fully
  /// opaque at exactly the canvas size, so any layer placed behind it would
  /// never be visible. `layer-far.png`/`layer-mid.png` are a decomposition
  /// of that same gothic-cave artwork — `far` is the hazier, aerial-
  /// perspective distance, `mid` is the same scene darker with its arch
  /// openings punched out to real alpha, which is what lets `far` show
  /// through it.
  ///
  /// Stack, back to front:
  ///  1. [SkyFill] — the solid sampled sky tone, covering the whole visible
  ///     rect (in particular the band above `far`'s 639px top edge that
  ///     `mid`'s 768px reaches but `far` does not);
  ///  2. `layer-far` at [parallaxFactorFar];
  ///  3. `layer-mid` at [parallaxFactorMid].
  ///
  /// Both layers are base-aligned to the canvas bottom at their native
  /// pixel height and wrap horizontally. Their scroll is driven by the
  /// camera, so they respond to the easing and the clamping in
  /// [CameraDirector], not just to raw player movement.
  Future<void> _addParallaxBackdrop() async {
    final baselineY = arenaConfig.canvas.height;
    // The camera x at which both layers line up with the world as authored:
    // the canvas centre, i.e. where the camera starts.
    final referenceX = arenaConfig.canvas.width / 2;

    await world.add(SkyFill(camera: camera));

    await world.add(
      await ParallaxLayer.load(
        camera: camera,
        assetPath: backgroundLayerFarAssetPath,
        parallaxFactor: parallaxFactorFar,
        baselineY: baselineY,
        referenceX: referenceX,
        topFadeHeight: parallaxTopFadeFar,
        priority: fxPriorityLayerFar,
      ),
    );

    await world.add(
      await ParallaxLayer.load(
        camera: camera,
        assetPath: backgroundLayerMidAssetPath,
        parallaxFactor: parallaxFactorMid,
        baselineY: baselineY,
        referenceX: referenceX,
        topFadeHeight: parallaxTopFadeMid,
        priority: fxPriorityLayerMid,
      ),
    );
  }

  /// Módulo 12, item 2 (lanterns): one additive glow per
  /// `decorativeAnchors` entry in `slots_config.json`, at that anchor's
  /// exact coordinate. Every anchor group in the config is used, so a
  /// future group added there lights up without a code change.
  ///
  /// Added at [fxPriorityLanternGlow] — above the backdrop layers, below
  /// every gameplay entity — so the light pools sit on the scenery and
  /// never wash out the player, wagons or boss.
  Future<void> _addLanternGlows() async {
    var index = 0;
    for (final anchors in arenaConfig.decorativeAnchors.values) {
      for (final anchor in anchors) {
        await world.add(
          await GlowLight.load(
            position: Vector2(anchor.x, anchor.y),
            diameter: lanternGlowDiameter,
            baseOpacity: lanternGlowOpacity,
            pulseOpacityAmplitude: lanternGlowFlickerAmplitude,
            pulseSpeed: lanternGlowFlickerSpeed,
            // Staggered phases so the lanterns flicker independently
            // instead of breathing in unison.
            phase: index * 1.31,
            priority: fxPriorityLanternGlow,
          ),
        );
        index++;
      }
    }
  }

  /// Módulo 12, items 2 and 3 — everything that makes the boss the focal
  /// point, all of it read-only with respect to the boss itself:
  ///  * [BossRimLight]: a warm backlit halo behind the silhouette, in the
  ///    world at [fxPriorityBossBackdropFx] so it paints under the boss;
  ///  * a pulsing, hotter-tinted [GlowLight] over the eyes, added as a
  ///    *child* of the boss (children always paint over their parent) at
  ///    the eye position measured off the spritesheet and converted through
  ///    the already-calibrated [bossDisplayScale];
  ///  * an optional slow `smoke-wisp` loop drifting off the boss.
  ///
  /// None of this touches `boss.position`, `boss.size`, `bossDisplayScale`
  /// or the boss's animation/state machine.
  Future<void> _addBossHighlightFx() async {
    await world.add(BossRimLight(boss: boss));

    await boss.add(
      await GlowLight.load(
        // Boss-local coordinates: frame-space eye position scaled by the
        // component's own frame->world ratio, which *is* bossDisplayScale.
        position: Vector2(
          bossEyeFrameX * bossDisplayScale,
          bossEyeFrameY * bossDisplayScale,
        ),
        diameter: bossEyeGlowDiameter,
        baseOpacity: bossEyeGlowOpacity,
        pulseOpacityAmplitude: bossEyeGlowPulseOpacityAmplitude,
        pulseScaleAmplitude: bossEyeGlowPulseScaleAmplitude,
        pulseSpeed: bossEyeGlowPulseSpeed,
        tint: bossEyeGlowTint,
      ),
    );

    await add(_BossSmokeEmitter(boss: boss, effectsParent: world));
  }

  /// Módulo 12, item 4: the landing puff, at the foot contact point the
  /// player reports.
  Future<void> _spawnLandingDust(Vector2 footPosition) async {
    await world.add(await SpriteBurst.dustPoof(footPosition));
  }

  void _logLoadedArenaConfig() {
    final buffer = StringBuffer()
      ..writeln('=== ArenaConfig loaded from $arenaConfigAssetPath ===')
      ..writeln(
        'canvas: width=${arenaConfig.canvas.width}, '
        'height=${arenaConfig.canvas.height}, '
        'source=${arenaConfig.canvas.source}',
      )
      ..writeln(
        'track: type=${arenaConfig.track.type}, '
        'orientation=${arenaConfig.track.orientation}, '
        'slotCount=${arenaConfig.track.slotCount}, '
        'startX=${arenaConfig.track.startX}, endX=${arenaConfig.track.endX}',
      )
      ..writeln('slots (${arenaConfig.slots.length}):');
    for (final slot in arenaConfig.slots) {
      buffer.writeln(
        '  slot[${slot.index}] x=${slot.x}, y=${slot.y}, '
        'next=${slot.next}, prev=${slot.prev}',
      );
    }
    buffer
      ..writeln(
        'boss: x=${arenaConfig.boss.x}, y=${arenaConfig.boss.y}, '
        'anchor=${arenaConfig.boss.anchor}, facing=${arenaConfig.boss.facing}',
      )
      ..writeln(
        'deathZone: type=${arenaConfig.deathZone.type}, '
        'y=${arenaConfig.deathZone.y}',
      )
      ..writeln('decorativeAnchors:');
    for (final entry in arenaConfig.decorativeAnchors.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value.length} anchor(s)');
      for (final anchor in entry.value) {
        buffer.writeln('    x=${anchor.x}, y=${anchor.y}');
      }
    }
    buffer.write('=== end of ArenaConfig ===');

    developer.log(buffer.toString(), name: 'VagoneiroArenaGame');
    // ignore: avoid_print
    print(buffer.toString());
  }
}

/// Módulo 12, item 2 (optional ambience): releases a faint `smoke-wisp`
/// off the boss every [bossSmokeInterval] seconds.
///
/// Spawned into the world at [fxPriorityBossBackdropFx] so the smoke drifts
/// up *behind* the boss, reinforcing the rim light's separation from the
/// backdrop instead of covering the character. Positions are derived from
/// the boss's own `position`/`size` (i.e. from the calibrated 176px height)
/// and nothing here writes to the boss.
class _BossSmokeEmitter extends Component {
  final VagoneiroBoss boss;
  final Component effectsParent;

  double _timer = 0;
  final math.Random _random = math.Random();

  _BossSmokeEmitter({required this.boss, required this.effectsParent});

  @override
  void update(double dt) {
    super.update(dt);
    _timer -= dt;
    if (_timer > 0) {
      return;
    }
    _timer = bossSmokeInterval;
    _emit();
  }

  Future<void> _emit() async {
    // Shoulder height: roughly two thirds up the boss's rendered height,
    // jittered horizontally across the torso.
    final origin = Vector2(
      boss.position.x + (_random.nextDouble() * 2 - 1) * boss.size.x * 0.18,
      boss.position.y - boss.size.y * 0.62,
    );
    final wisp = await SpriteBurst.smokeWisp(
      origin,
      priority: fxPriorityBossBackdropFx,
    );
    if (isRemoved) {
      return;
    }
    await effectsParent.add(wisp);
  }
}
