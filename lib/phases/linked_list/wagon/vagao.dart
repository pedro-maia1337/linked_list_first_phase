import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';

import '../../../shared/fx/contact_shadow.dart';
import '../../../shared/fx/game_curves.dart';
import '../../../shared/physics/player_platform.dart';
import '../fx/ambient_light.dart';
import '../fx/linked_list_fx_config.dart';
import '../linked_list_assets.dart';

/// States a [Vagao] can be in (see docs/boss-vagoneiro-design.md, section
/// 3.3). `tremor`/`falling`/`removed` drive the removal sequence
/// (section 4.3/5), triggered via [Vagao.playVagaoFantasmaSequence] —
/// which from Módulo 15 is what the `RemoverNo` primitive plays.
enum VagaoState { spawning, idle, tremor, falling, removed }

/// One frame of wagon art, plus the horizontal registration correction it
/// needs (Módulo 13).
///
/// The regenerated `wagons/states/frame_*.png` set (section 3.2 of this
/// module) is authored on ~307x300 canvases whose *content* is not
/// centred: the cart drifts from +73.5 native px right of the canvas
/// centre (`frame_02_tremor1`) to -41 px left of it (`frame_05_tremor4`),
/// and keeps drifting through the falling frames. Painting those canvases
/// centre-aligned would slide the art up to 114 native px — ~44 world px,
/// wider than the whole 45px wagon — off the slot it is supposed to sit
/// on, while the collider and the contact shadow stayed put.
///
/// [contentCentreOffsetX] is that drift, measured per frame as
/// `(opaqueBBox.left + opaqueBBox.right) / 2 - (canvasWidth - 1) / 2`
/// with an alpha > 10 threshold. [Vagao] subtracts it (scaled) from the
/// sprite's local position, so every frame's content is centred on the
/// slot. **Only X is corrected** — the vertical crop of each canvas
/// (308px for idle/tremor, 299px while breaking loose, 275px on impact)
/// is authored intent, and bottom-aligning them is what makes the wagon
/// visibly drop as it falls.
class VagaoFrame {
  final String assetPath;
  final double contentCentreOffsetX;

  const VagaoFrame(this.assetPath, this.contentCentreOffsetX);
}

/// Idle asset (section 8.1: `idle` -> the wagon hanging, connected
/// normally).
const VagaoFrame vagaoIdleFrame =
    VagaoFrame('${linkedListAssetRoot}wagons/states/frame_01_idle.png', 49.5);

/// Tremor/telegraph frames (section 8.1: `tremor`). The regenerated set
/// splits what used to be one static `marcado` sprite into a 4-frame
/// shudder (cart rocking on its chains, sparks igniting at the link), so
/// this is a *loop* played for the unchanged [vagaoTremorDuration] rather
/// than a single sprite swap. The state machine is untouched: `tremor` is
/// still one state, entered and left at exactly the same moments.
const List<VagaoFrame> vagaoTremorFrames = [
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_02_tremor1.png', 73.5),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_03_tremor2.png', 21.5),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_04_tremor3.png', -4.0),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_05_tremor4.png', -41.0),
];

/// Falling sequence, in the chronological order section 8.1 specifies:
/// elo começando a se soltar (faísca) -> elo já solto/pendurado ->
/// inclinado, caindo, girando -> impacto final com destroços. The
/// regenerated set spells that same progression out over 10 frames
/// instead of 4; the mapping is unchanged, only its resolution.
const List<VagaoFrame> vagaoFallingFrames = [
  // elo começando a se soltar
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_06_break1.png', 51.0),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_07_break2.png', 70.5),
  // elo já solto / pendurado
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_08_link_detached1.png', 23.5),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_09_link_detached2.png', -4.0),
  // caindo / girando
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_10_falling1.png', -29.5),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_11_falling2.png', 43.0),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_12_falling3.png', 0.0),
  // impacto final
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_13_impact1.png', -13.5),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_14_impact2.png', 18.0),
  VagaoFrame('${linkedListAssetRoot}wagons/states/frame_15_final.png', -31.5),
];

/// Convenience alias kept for the `spawning` mapping in section 8.1 ("sem
/// sprite dedicado — o asset de idle com fade-in/pop").
const String vagaoIdleAssetPath = '${linkedListAssetRoot}wagons/states/frame_01_idle.png';

/// Telegraph duration before the wagon starts falling (design doc section
/// 4.3/5: "~1.2s").
const double vagaoTremorDuration = 1.2;

/// How long each frame of the falling sequence is shown. Módulo 13: the
/// regenerated set has 10 falling frames instead of 4, so the per-frame
/// time is shortened to keep the whole sequence in the same ballpark as
/// before (10 x 0.08 = 0.80s, against the old 4 x 0.15 = 0.60s) rather
/// than stretching the fall to 1.5s.
const double vagaoFallingFrameDuration = 0.08;

/// How long each frame of the [vagaoTremorFrames] loop is shown. Chosen so
/// the 4-frame shudder cycles three times inside the unchanged
/// [vagaoTremorDuration] (4 x 0.1 x 3 = 1.2s) — the telegraph reads as a
/// tremble, and its total length is bit-for-bit what it was.
const double vagaoTremorFrameDuration = 0.1;

/// Duration of the spawn "pop" transition (section 3.1: "fade-in ou leve
/// pop de escala" — not spec'd numerically, chosen as a reasonable default).
const double vagaoSpawnDuration = 0.25;

/// Native canvas width of every regenerated wagon frame (307px for all 15;
/// three of them are 308px, which the per-frame [VagaoFrame] registration
/// already absorbs). The sprite is scaled by
/// `vagaoDisplayWidth / vagaoNativeCanvasWidth`.
const double vagaoNativeCanvasWidth = 307;

/// Native (unscaled) height of the wagon **body** in `frame_01_idle.png`
/// — the cart itself, not the two chains hanging above it that the
/// regenerated art bakes into the same canvas.
///
/// Measured with a pixel-alpha row-width scan (threshold alpha > 10) on
/// the 307x308 canvas: the two chains occupy rows 67..162 as thin columns
/// (row width 16..47px), then the row width jumps to 93 and then 162+ at
/// row 163 where the cart's roof starts, and opaque content ends at row
/// 278. Body = rows 163..278 = **116px**.
///
/// This distinction is new in Módulo 13 and matters: the *full* opaque
/// bbox of the frame is 212px tall, and calibrating against that would
/// render the cart at 45 * (116/212) ≈ 25px — barely half the ≈45px the
/// design doc's section 2.3 pins it at. A raw measurement fact,
/// independent of any target display size.
const double vagaoOpaqueHeightNative = 116;

/// Native transparent padding below the wagon body in `frame_01_idle.png`:
/// the canvas is 308px tall and the body's lowest opaque row is 278, so
/// 29px of empty canvas sit under it. Consumed by
/// [vagaoContactShadowYOffset] to put the shadow on the *visible* base.
const double vagaoNativePaddingBelowBody = 29;

/// Target on-screen width (world pixels) for the wagon's visible art.
///
/// Recomputed in Módulo 13 for the regenerated asset set, against the
/// unchanged ≈45px target visual height from design doc section 2.3 (the
/// calibration is *respected*, not redone — only the native measurements
/// feeding it changed, because the art did):
///   scale = 45 / 116 (vagaoOpaqueHeightNative) = 0.3879
///   vagaoDisplayWidth = scale * 307 (vagaoNativeCanvasWidth) = 119.1
/// Check: 116 * (119.1 / 307) = 45.0px of cart, and the chains above it
/// add a further 96 * 0.3879 ≈ 37px of purely decorative art that is not
/// part of the calibrated wagon height. Still well under the ~180px slot
/// spacing from slots_config.json. See [bossDisplayScale] in
/// vagoneiro_boss.dart for the boss's equivalent fixed-height calibration.
const double vagaoDisplayWidth = 119.1;

/// Fixed logical platform-top collider size (world pixels), independent of
/// any art asset's bounding box (design doc section 9.1: different wagon
/// states used to have different padding around the art before the
/// gothic-cave art pass unified every state to 417x420 — the collider
/// still must never be derived from the loaded image's size, since a
/// future art pass could reintroduce per-state padding).
///
/// Sized to stay under the wagon's rendered art width, so the player never
/// visibly stands on thin air past the cart's edges, with the height
/// matching [playerHitboxHeight] (10px) — see [vagaoColliderOffsetY] for
/// how the two combine to hit the ≈38px target surface height.
///
/// **Unchanged in Módulo 13**, and re-verified against the regenerated
/// art: the cart body is 172 native px wide, which at the new display
/// scale (119.1 / 307 = 0.3879) renders as 172 * 0.3879 ≈ 66.7px — still
/// comfortably wider than this 55px box, exactly as the Módulo 11
/// calibration required.
const double vagaoColliderWidth = 55;
const double vagaoColliderHeight = 10;

/// Fixed vertical offset (world pixels, negative = up) from the slot's
/// ground point (the [Vagao]'s own anchor-bottomCenter position) to
/// [platformHitbox]'s own anchor (bottomCenter) — i.e. the *bottom* edge
/// of the collider box, not its top.
///
/// Módulo 11 calibration: the fixed target is the collider's TOP surface —
/// what [Player.onCollision] actually snaps to via
/// `platformHitbox.absoluteTopLeftPosition.y` — sitting ≈38px above the
/// wagon's base. Since the box's own anchor (this offset) is its *bottom*,
/// not its top:
///   topSurfaceY = offsetY - vagaoColliderHeight  (want = -38)
///   offsetY = -38 + vagaoColliderHeight = -38 + 10 = -28
///
/// **Unchanged in Módulo 13**, and re-verified against the regenerated
/// art: at the new display scale (0.3879) the cart's visible body spans
/// from 11px (its base, above the canvas padding) to 56px (its roof)
/// above the slot's ground point, so the 38px landing surface still sits
/// inside that visible range, a few px below the peak — avoiding the
/// chain hooks poking above the actual flat platform surface (design doc
/// section 9.1).
const double vagaoColliderOffsetY = -28;

/// A wagon occupying a fixed [Slot] position. Never moves/tweens position —
/// it appears directly at the coordinate it's given (section 3.0: "nenhum
/// vagão se move de um slot para outro").
///
/// Structured as a plain (unscaled) [PositionComponent] with two children:
/// a scaled-down visual [SpriteComponent] and a fixed-size
/// [RectangleHitbox]. Keeping the hitbox as a sibling of the visual — not
/// nested inside it — is what makes the collider size independent of the
/// display scale/art bounding box (a child of the scaled visual would be
/// scaled down with it).
class Vagao extends PositionComponent implements PlayerPlatform {
  VagaoState state = VagaoState.spawning;

  /// Whether this node is part of the linked list of slots.
  ///
  /// A wagon can exist physically
  /// — solid, standing in the arena, walkable — while being outside the
  /// list entirely. Such a node has no `next`/`prev` (it occupies no
  /// [Slot] at all, which is what makes that literally true rather than a
  /// flag pretending it), is never reachable by
  /// `boss.occupySlot`/`boss.clearSlot`, and any player attack against it
  /// is a guaranteed miss. `true` for every wagon the boss puts on the
  /// track. Módulo 15 removed the one component that ever set it false
  /// (the Nó Órfão), but the flag stays: it is what
  /// `Player.onCollision` reads to decide whether landing on something
  /// changes the player's logical position in the list, and hardcoding
  /// that to `true` would bake an assumption the model does not make.
  final bool linked;

  /// Art this wagon renders in its resting state, and the on-screen width
  /// that art is scaled to. Parameters rather than constants so the
  /// orphan node can reuse this entire component (collider, contact
  /// shadow, spawn tween, ambient tint) with its own sprite — the point of
  /// the orphan is that it is a wagon in every way *except* its place in
  /// the list.
  final VagaoFrame idleFrame;
  final double displayWidth;

  /// Whether this wagon casts a contact shadow. The orphan node hangs off
  /// the track rather than resting on it, so it has no contact to shade.
  final bool castsContactShadow;

  /// Whether this wagon is currently a solid platform (design doc section
  /// 9.2): true for `spawning`/`idle`/`tremor`, false for `falling`
  /// (loses support mid-fall) and `removed` (no platform left at all).
  @override
  bool get isSolid =>
      state == VagaoState.spawning ||
      state == VagaoState.idle ||
      state == VagaoState.tremor;

  /// [PlayerPlatform]: the top edge of [platformHitbox], in world space —
  /// the surface the player's feet snap to.
  @override
  double get platformTopY => platformHitbox.absoluteTopLeftPosition.y;

  /// Fixed-size logical collider representing the platform surface on top
  /// of the wagon (design doc section 9.1), consumed by [Player]'s
  /// collision handling this etapa.
  late final RectangleHitbox platformHitbox;

  late final SpriteComponent _visual;
  late final double _targetScale;

  /// Módulo 13: the contact shadow, kept as a field so it can be hidden
  /// while the wagon is falling (the module scopes the shadow to
  /// `spawning`/`idle`/`tremor` — a wagon in mid-air has nothing to cast a
  /// contact shadow onto, and leaving one behind on the empty slot was
  /// reading as a stain on the track).
  late final ContactShadow _contactShadow;

  /// Resting local position of [_visual]: the current frame's registration
  /// correction (see [VagaoFrame]), *without* any tremor jitter. Public so
  /// tests and observers can tell "back at rest" from "still displaced"
  /// without assuming that rest means zero — which it no longer does.
  Vector2 get visualRestingOffset => _frameOffset.clone();
  Vector2 _frameOffset = Vector2.zero();
  final Vector2 _jitter = Vector2.zero();

  /// Asset path currently applied to [_visual], kept public (read-only) so
  /// decorative observers (e.g. `ChainSegment`) can mirror this wagon's
  /// exact visual state without this class needing to know they exist —
  /// see `wagon/chain_segment.dart`.
  String get currentAssetPath => _currentAssetPath;
  // Defaults to the idle asset (not `late`) so an observer reading this
  // before `onLoad` finishes — a real race, since `Vagao` is registered in
  // `Slot.vagao` synchronously in `occupySlot`, before its async `onLoad`
  // runs — sees a value consistent with what `onLoad` sets moments later,
  // instead of a `LateInitializationError`.
  late String _currentAssetPath = idleFrame.assetPath;

  /// Guards against [playVagaoFantasmaSequence] being triggered twice
  /// concurrently on the same wagon (e.g. the debug key mashed while a
  /// sequence is already running).
  bool _fantasmaSequenceRunning = false;

  Vagao({
    required Vector2 position,
    this.linked = true,
    this.idleFrame = vagaoIdleFrame,
    this.displayWidth = vagaoDisplayWidth,
    this.castsContactShadow = true,
    this.contactShadowWidth = vagaoContactShadowWidth,
    this.contactShadowYOffset = vagaoContactShadowYOffset,
    super.priority,
  }) : super(position: position, anchor: Anchor.bottomCenter);

  /// Geometry of this wagon's contact shadow, measured per asset (the
  /// padding under the art's visible base differs between sets).
  final double contactShadowWidth;
  final double contactShadowYOffset;

  @override
  Future<void> onLoad() async {
    final image = await Flame.images.load(idleFrame.assetPath);
    _targetScale = displayWidth / image.width;
    final visualSize = Vector2(image.width.toDouble(), image.height.toDouble());

    _visual = SpriteComponent(
      sprite: Sprite(image),
      size: visualSize,
      anchor: Anchor.bottomCenter,
      scale: Vector2.all(_targetScale * 0.6),
    );
    // Módulo 13, item 2: the shared cool wash, set once on the component's
    // own `paint`. `_setVisualFrame` only ever replaces the `Sprite`, so
    // this survives every state swap without being re-applied.
    applyAmbientCoolTint(_visual);
    _frameOffset = _offsetFor(idleFrame);
    _syncVisualPosition();
    await add(_visual);

    _visual.add(
      ScaleEffect.to(
        Vector2.all(_targetScale),
        // Mudança 5: the project curve, not a locally chosen one. This was
        // already `Curves.easeOutBack` — the same shape `GameCurves.impactOut`
        // names — so nothing about how a wagon spawns changes here; what
        // changes is that retuning the game's feel is now one edit in
        // `fx/game_curves.dart` instead of a search for every call site.
        EffectController(
          duration: vagaoSpawnDuration,
          curve: GameCurves.impactOut,
        ),
        onComplete: () => state = VagaoState.idle,
      ),
    );

    // Sibling of `visual`, not a child of it — its size stays
    // `vagaoColliderWidth`x`vagaoColliderHeight` regardless of the visual's
    // scale/spawn animation or which wagon art asset was loaded.
    platformHitbox = RectangleHitbox(
      size: Vector2(vagaoColliderWidth, vagaoColliderHeight),
      anchor: Anchor.bottomCenter,
      position: Vector2(0, vagaoColliderOffsetY),
      // Static platform — never moves — so it's excluded from the
      // active-active broad-phase pairing the engine does for the player.
      collisionType: CollisionType.passive,
    );
    await add(platformHitbox);

    // Módulo 12 (polish visual): a contact shadow centred on this wagon's
    // own ground point (local y = 0, the anchor-bottomCenter position it
    // was given), lifted by `vagaoContactShadowYOffset` onto the art's
    // *visible* base. Added at `priority: -1` so it paints before `_visual`
    // (Flame orders siblings by priority, then insertion) — i.e. under the
    // wagon art, never over it. Purely decorative: not a collider, not a
    // sibling the hitbox knows about, and unaffected by the spawn tween or
    // by [applyVisualJitter].
    _contactShadow = await ContactShadow.load(
      width: contactShadowWidth,
      baseOpacity: castsContactShadow ? vagaoContactShadowOpacity : 0,
      yOffset: contactShadowYOffset,
    );
    await add(_contactShadow);
  }

  /// The registration correction for [frame], in this wagon's local world
  /// pixels — the frame's measured content drift scaled by the display
  /// scale, negated so it cancels out. See [VagaoFrame].
  Vector2 _offsetFor(VagaoFrame frame) =>
      Vector2(-frame.contentCentreOffsetX * _targetScale, 0);

  /// [_visual]'s local position is the sum of two independent things: the
  /// current frame's registration correction (which changes when the art
  /// changes) and the tremor jitter (which changes every frame while
  /// trembling). Keeping them separate is what lets the jitter return to
  /// *this frame's* resting offset instead of to zero.
  void _syncVisualPosition() {
    _visual.position.setValues(
      _frameOffset.x + _jitter.x,
      _frameOffset.y + _jitter.y,
    );
  }

  /// Módulo 12 (polish visual): offsets the wagon's **sprite only** by
  /// [offset] world pixels, used by `WagonFxObserver` to shake a wagon
  /// while it is in [VagaoState.tremor].
  ///
  /// Deliberately scoped to `_visual`: this component's own `position`,
  /// [platformHitbox] and the contact shadow all stay exactly where they
  /// were, so a wagon that trembles is still, to the collision engine and
  /// to [Player.onCollision], the same immobile platform it always was.
  /// Pass [Vector2.zero] to restore the resting position.
  void applyVisualJitter(Vector2 offset) {
    if (!isLoaded) {
      // `_visual` is `late` and only assigned in [onLoad]; a wagon can be
      // spawned and cleared again before that finishes (the debug slot
      // keys make this easy to hit).
      return;
    }
    _jitter.setFrom(offset);
    _syncVisualPosition();
  }

  /// Swaps the wagon's visible art to [frame], keeping the same target
  /// display scale/anchor as the idle sprite and re-applying that frame's
  /// registration correction so its content stays centred on the slot.
  ///
  /// The scale is recalculated per image rather than reused verbatim
  /// because the regenerated set still varies its canvas height between
  /// states (308 / 299 / 275) even though the widths agree.
  Future<void> _setVisualFrame(VagaoFrame frame) async {
    final image = await Flame.images.load(frame.assetPath);
    _visual.sprite = Sprite(image);
    _visual.size = Vector2(image.width.toDouble(), image.height.toDouble());
    _visual.scale = Vector2.all(_targetScale);
    _frameOffset = _offsetFor(frame);
    _syncVisualPosition();
    _currentAssetPath = frame.assetPath;
  }

  /// Runs the full removal sequence — what `RemoverNo` plays (design doc
  /// sections 4.3/5). The name is Módulo 0-13's and is kept:
  /// `tremor` (~1.2s telegraph) -> `falling` (isSolid flips to false the
  /// instant this state is entered, then plays the falling frames) ->
  /// `removed`, at which point [onRemoved] is invoked so the caller (the
  /// boss) can clear the slot. Never touches the slot/track itself — that
  /// stays the boss's responsibility (section 3.0: only the boss inserts
  /// / removes wagons).
  Future<void> playVagaoFantasmaSequence(void Function() onRemoved) async {
    if (_fantasmaSequenceRunning) {
      return;
    }
    _fantasmaSequenceRunning = true;

    state = VagaoState.tremor;

    // Módulo 13: `tremor` is now a 4-frame loop rather than a single
    // sprite swap. The *state* is unchanged — it is entered here and left
    // below at exactly the same moments, after exactly the same
    // `vagaoTremorDuration` — only what is drawn during it changed. Timing
    // is derived from the elapsed wall clock, not from a frame count, so
    // the telegraph is still 1.2s even if a frame load stalls.
    final tremorStart = DateTime.now();
    final tremorMillis = (vagaoTremorDuration * 1000).round();
    final tremorFrameMillis = (vagaoTremorFrameDuration * 1000).round();
    var tremorFrame = 0;
    while (true) {
      if (isRemoved) {
        return;
      }
      final elapsed = DateTime.now().difference(tremorStart).inMilliseconds;
      if (elapsed >= tremorMillis) {
        break;
      }
      await _setVisualFrame(
        vagaoTremorFrames[tremorFrame % vagaoTremorFrames.length],
      );
      tremorFrame++;
      final remaining = tremorMillis - elapsed;
      await Future<void>.delayed(
        Duration(
          milliseconds:
              remaining < tremorFrameMillis ? remaining : tremorFrameMillis,
        ),
      );
    }

    if (isRemoved) {
      return;
    }

    await playFall(onRemoved);
  }

  /// The `falling -> removed` half of the sequence on its own, without the
  /// [VagaoState.tremor] telegraph in front of it.
  ///
  /// Split out in Módulo 14 for the head-push (section 4.1 ③), where the
  /// wagon at the far end of the list has already been popped and the fall
  /// is only the visual receipt of that — there is nothing left to
  /// telegraph. [playVagaoFantasmaSequence] now calls straight into this,
  /// so both paths run identical falling code and the state machine
  /// (`spawning -> idle -> tremor -> falling -> removed`) is unchanged:
  /// this simply enters it one state later.
  Future<void> playFall(void Function() onRemoved) async {
    if (state == VagaoState.falling || state == VagaoState.removed) {
      return;
    }

    // Flips isSolid to false immediately (Vagao.isSolid reads `state`
    // directly, synchronously) — before any of the falling frames load.
    state = VagaoState.falling;

    // Módulo 13, item 1: the contact shadow is scoped to the states where
    // the wagon is actually resting on the track. Once it breaks loose
    // there is no contact left to shade, and the shadow that used to stay
    // behind read as a smudge painted on the empty slot.
    _contactShadow.opacity = 0;

    for (final frame in vagaoFallingFrames) {
      if (isRemoved) {
        // The wagon (or its parent) may have been removed from the tree
        // mid-sequence (e.g. a debug clearSlot elsewhere) — stop touching it.
        return;
      }
      await _setVisualFrame(frame);
      await Future<void>.delayed(
        Duration(milliseconds: (vagaoFallingFrameDuration * 1000).round()),
      );
    }

    state = VagaoState.removed;
    onRemoved();
  }
}
