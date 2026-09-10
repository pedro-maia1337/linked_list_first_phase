/// Módulo 12 — polish visual / "juice".
///
/// Central place for every constant this module introduces, so the visual
/// tuning can be reviewed (and reverted) in one file without hunting
/// through the gameplay classes. **Nothing here feeds physics, collision,
/// scale or state-machine logic** — every value below only affects what is
/// drawn, never what the game does. The already-calibrated numbers from
/// Módulo 11 (player 110px, vagão ≈45px visual / ≈38px collider, boss
/// 176px, jump apex ≈145px, foot anchoring) are *read* from their owning
/// files and never redefined here.
library;

import 'dart:ui' show Color;

// ---------------------------------------------------------------------------
// Asset paths (relative to `Flame.images.prefix`, which the game sets to
// 'assets/'). All seven files were verified to exist at the declared
// dimensions before this module was written.
// ---------------------------------------------------------------------------

/// 1376x639, opaque RGBA, horizontally tileable — the *distant* backdrop
/// layer (aerial perspective: lighter, hazier version of the cave).
const String backgroundLayerFarAssetPath = 'background/layer-far.png';

/// 1376x768, RGBA with real alpha in the arch openings, horizontally
/// tileable — the *intermediate* backdrop layer; its transparent gaps are
/// what reveals [backgroundLayerFarAssetPath] behind it.
const String backgroundLayerMidAssetPath = 'background/layer-mid.png';

/// 128x128 additive amber glow.
const String fxGlowWarmSoftAssetPath = 'effects/glow-warm-soft.png';

/// 96x32 contact shadow (dark ellipse centred in the frame).
const String fxContactShadowAssetPath = 'effects/contact-shadow.png';

/// 6-frame 32x32 spritesheet (sheet is 192x32).
const String fxSparkEmberAssetPath = 'effects/particles/spark-ember.png';

/// 6-frame 48x48 spritesheet (sheet is 288x48), baseline-aligned: the
/// opaque content of every frame bottoms out at y≈46/48, so
/// [Anchor.bottomCenter] puts the puff's contact point on the ground.
const String fxDustPoofAssetPath = 'effects/particles/dust-poof.png';

/// 6-frame 48x64 spritesheet (sheet is 288x64), baseline-aligned.
const String fxSmokeWispAssetPath = 'effects/particles/smoke-wisp.png';

// ---------------------------------------------------------------------------
// Render order.
//
// Every pre-existing world component (background, boss, chains, wagons,
// debug markers, player, rulers) sits at the default `priority: 0` and
// relies on insertion order for paint order — see
// `VagoneiroArenaGame._addChainSegments`'s doc. To avoid disturbing that,
// this module never inserts anything at priority 0 in the world: backdrop
// layers take large negative priorities (always behind), and the boss's
// rim light / smoke take -1 (behind everything at 0, which is what makes
// the rim read as a backlight rather than an overlay).
// ---------------------------------------------------------------------------

const int fxPrioritySkyFill = -100;
const int fxPriorityLayerFar = -90;
const int fxPriorityLayerMid = -80;
const int fxPriorityLanternGlow = -70;
const int fxPriorityBossBackdropFx = -1;

/// Módulo 13, tarefa 6: the end-of-track wall anchors, one step further
/// back than the boss's backdrop fx. They are scenery bolted into the cave
/// wall, so they must paint *behind* every entity at priority 0 — in
/// particular behind the boss, whose silhouette is what swallows the
/// boss-side anchor's chain and makes it read as continuing into the
/// existing boss->slot 0 segment.
const int fxPriorityChainAnchor = -2;

/// Viewport-space priority for the vignette. Deliberately **below** the
/// debug HUD's default `priority: 0` so the existing `DebugHelpOverlay`
/// legend keeps rendering on top of it, fully legible — the debug HUD is
/// explicitly out of scope for this module.
const int fxPriorityVignette = -10;

// ---------------------------------------------------------------------------
// Parallax.
// ---------------------------------------------------------------------------

/// How much of the camera's horizontal movement each backdrop layer
/// reproduces: 0 = pinned to the screen (infinitely far), 1 = pinned to the
/// world (moves exactly with gameplay). `far` < `mid` < 1 gives the depth
/// ordering the module asks for.
const double parallaxFactorFar = 0.25;
const double parallaxFactorMid = 0.55;

/// Height of the haze fade each layer paints over its own top edge, down
/// into [parallaxSkyFillColor]. Sized so neither fade reaches the layer
/// below it: `mid` tops out at canvas y 173 and `far` at 302, so mid's
/// 44px fade ends at 217, comfortably above far's edge.
const double parallaxTopFadeFar = 58;
const double parallaxTopFadeMid = 44;

/// Solid fill painted behind every layer, covering the unpainted band the
/// height difference leaves at the top (layer-far is 639px tall against
/// layer-mid's 768px, both aligned by the canvas base).
///
/// Sampled from layer-far.png itself: the modal colour of its top rows is
/// RGB(152, 140, 152) — the pale, misty "sky" the cave ceiling hangs into
/// (those rows' *median* is dark, but that's the ceiling rock drawn in
/// front of the mist, not the sky behind it).
const Color parallaxSkyFillColor = Color(0xFF988C98);

// ---------------------------------------------------------------------------
// Vignette.
// ---------------------------------------------------------------------------

/// Fraction of the screen's half-diagonal at which the vignette starts
/// darkening — everything inside stays completely untouched, so the
/// gameplay band in the middle of the screen is never dimmed.
const double vignetteInnerStop = 0.58;

/// Opacity at the very corners. Kept low on purpose: the acceptance
/// criterion is "sutil sem esconder gameplay".
const double vignetteCornerOpacity = 0.42;

// ---------------------------------------------------------------------------
// Lighting.
// ---------------------------------------------------------------------------

/// On-screen diameter (world px) of the glow placed over each lantern
/// anchor from `slots_config.json`'s `decorativeAnchors`.
/// Tuned against the Windows build: the first pass (168px at 0.5) blew out
/// into flat blobs over the pale, misty upper half of layer-far, because an
/// additive blend has the most headroom over *dark* pixels and almost none
/// over light ones. Smaller and dimmer reads as a halo at both extremes.
const double lanternGlowDiameter = 150;
const double lanternGlowOpacity = 0.34;

/// Very slow, very small flicker so the lantern pools read as living fire
/// rather than as a decal. Deliberately an order of magnitude weaker than
/// the boss's eye pulse below, which is the one the module asks to be
/// noticeably pulsing.
const double lanternGlowFlickerAmplitude = 0.05;
const double lanternGlowFlickerSpeed = 1.7;

/// Boss eye glow: smaller, more saturated, clearly pulsing.
///
/// Tuned against the Windows build: 62px is ~35% of the boss's calibrated
/// 176px height, which swallowed the whole head. 30px lands on the eye
/// socket and leaves the face readable, which matters because the face is
/// what the rim light is framing.
const double bossEyeGlowDiameter = 30;
const double bossEyeGlowOpacity = 0.6;
const double bossEyeGlowPulseOpacityAmplitude = 0.22;
const double bossEyeGlowPulseScaleAmplitude = 0.11;
const double bossEyeGlowPulseSpeed = 3.4;

/// Modulated over the amber glow sprite to push it towards a hotter, more
/// saturated ember tone than the lanterns'.
const Color bossEyeGlowTint = Color(0xFFFF6A28);

/// Eye position measured directly off `boss/sprite.png`, in *frame*
/// coordinates. **Re-measured in Módulo 14** for the caricatured
/// replacement sheet, whose cells are 300px (not the old 256px) and whose
/// character sits at a different point inside them: masking for warm,
/// high-saturation, high-alpha pixels in the upper half of each idle cell
/// (r > 170, r > 1.4g, r > 1.6b, sat > 0.5) gives a centroid of
/// (165.5, 108.5), stable within ±3px across all 6 idle columns — the
/// single glowing orange eye under the cap brim. Converted to the boss
/// component's local space by scaling with `bossDisplayScale`, i.e.
/// derived from the already-calibrated 176px height, never re-deriving it.
const double bossEyeFrameX = 165.5;
const double bossEyeFrameY = 108.5;

// ---------------------------------------------------------------------------
// Contact shadows.
// ---------------------------------------------------------------------------

/// Player: rendered opaque art is ~50px wide (native bbox 105px at the
/// calibrated 110px-height scale), so a 56px shadow reads as sitting just
/// under the feet.
const double playerContactShadowWidth = 56;
const double playerContactShadowOpacity = 0.55;

/// How far the shadow fades while the player is airborne. Never fully
/// hidden, so the "no gap between character base and shadow" check still
/// holds at the moment of contact.
const double playerContactShadowAirborneOpacity = 0.18;

/// Wagon: the cart body is 172 native px wide, which at the calibrated
/// ≈45px-height scale (0.3879) renders as ≈66.7px.
const double vagaoContactShadowWidth = 66;
const double vagaoContactShadowOpacity = 0.45;

/// The wagon's *visible* base is not its anchor. Every regenerated
/// `frame_*.png` is a 307x308 canvas whose cart body bottoms out at
/// y=278, i.e. `vagaoNativePaddingBelowBody` (29) native px of transparent
/// canvas sit below it; at the display scale (119.1/307 = 0.3879) that is
/// 29 * 0.3879 ≈ 11.25 world px. A shadow centred on the anchor would
/// therefore float ~11px *below* the art, which is exactly the gap the
/// acceptance criterion rules out. Lifting the shadow by that measured
/// padding puts it back on the wagon's real base.
///
/// Only the shadow moves: the anchor, the platform collider
/// (`vagaoColliderOffsetY`) and the display scale are all untouched.
///
/// Módulo 13: recomputed from -13.9 (which was the old 417x420 art's 70px
/// of padding) for the regenerated asset set.
const double vagaoContactShadowYOffset = -11.25;

// ---------------------------------------------------------------------------
// Boss rim light.
// ---------------------------------------------------------------------------

/// Offset (world px) the silhouette is redrawn at to build the halo — the
/// rim's thickness where the light hits square on. Each redraw's own offset
/// is scaled down by its weight, so the rim tapers along the flanks instead
/// of keeping full thickness all the way round.
const double bossRimLightWidth = 3.2;

/// Peak brightness of the finished rim.
///
/// Módulo 13: this is now the brightness of the *whole* halo, not of each
/// redraw. The redraw weights are normalised to sum to 1 before this is
/// applied (see `BossRimLight`), so nine additive copies no longer stack
/// into a blown-out near-white stroke the way they did at 0.5 each — which
/// is the other half of why the old rim read as a gold outline rather than
/// as light.
const double bossRimLightOpacity = 0.45;

/// Warm backlight tone, a touch cooler than the eye glow so the eyes stay
/// the hottest point on the character.
const Color bossRimLightColor = Color(0xFFFFB35C);

/// Slow breathing on the rim so the boss reads as the animated focal point
/// of the scene even while `idle` loops.
const double bossRimLightPulseAmplitude = 0.16;
const double bossRimLightPulseSpeed = 1.9;

/// Optional ambience: smoke drifting off the boss.
const double bossSmokeInterval = 1.15;
const double bossSmokeOpacity = 0.22;
const double bossSmokeHeight = 74;

// ---------------------------------------------------------------------------
// Juice — player squash & stretch.
//
// Expressed as multipliers of the player's calibrated 110px base height
// (`playerRenderedHeightPx`), applied on top of `playerDisplayScale` and
// never replacing it: peak stretch adds ~110 * 0.16 ≈ 18px of height, peak
// squash removes ~110 * 0.18 ≈ 20px. Width counter-scales as 1/sy so the
// silhouette's area stays constant (classic 2D squash-and-stretch). Purely
// a change to the *visual* child's scale — the feet anchor, the collider
// and the physics constants are untouched.
// ---------------------------------------------------------------------------

const double playerJumpStretchFactor = 1.16;
const double playerJumpStretchDuration = 0.18;
const double playerLandSquashFactor = 0.82;
const double playerLandSquashDuration = 0.20;

/// Below this downward speed (px/s) a contact is treated as "no real
/// vertical movement" and produces neither squash nor dust — the same
/// principle the Módulo 11 animation fix applies horizontally (no motion,
/// no animation).
const double playerLandingImpactThreshold = 120;

/// Diameter (world px) of the landing dust puff, sized against the
/// player's ~50px rendered width.
const double dustPoofWidth = 62;
const double dustPoofStepTime = 0.055;

// ---------------------------------------------------------------------------
// Juice — wagon tremor / falling.
// ---------------------------------------------------------------------------

/// Amplitude (world px) of the purely visual jitter applied to a trembling
/// wagon's sprite. Applied to the wagon's *visual child only* — the `Vagao`
/// component itself and its `platformHitbox` never move, so landing
/// geometry during `tremor` is bit-for-bit what it was before.
const double vagaoTremorJitterAmplitude = 1.5;

/// Spark emitter cadence and geometry while a wagon is in `tremor`.
const double sparkEmberStepTime = 0.07;
const double sparkEmberWidth = 22;
const double sparkEmberBurstInterval = 0.19;
const double sparkEmberSpreadX = 24;

/// Screen shake fired when a wagon enters `falling`. Small and short —
/// "sutil", per the module brief.
const double wagonFallShakeAmplitude = 6;
const double wagonFallShakeDuration = 0.35;

// ---------------------------------------------------------------------------
// Camera.
// ---------------------------------------------------------------------------

/// "Leve zoom": the camera frames `canvas / cameraZoomFactor` instead of
/// the whole canvas.
///
/// The arena is only 1672px wide, so the zoom factor *is* the pan range:
/// the camera can travel `canvasWidth - canvasWidth / zoom` before the
/// clamp in [CameraDirector] stops it. At 1.2 that was ~216px on a 16:9
/// window — real, but too small to read as a following camera. 1.3 gives
/// ~386px while staying a "leve zoom", and still frames the whole track
/// (slot y 660..780), the death line (y 900) and the jump apex.
///
/// Trade-off, deliberate: the vertical window at 1.3 starts at canvas
/// y≈217, so the two highest `decorativeAnchors` lantern glows (y=148 and
/// y=212) sit at or above the top edge. They are decorative light pools on
/// the backdrop, not gameplay, and the camera is the explicit acceptance
/// criterion here.
const double cameraZoomFactor = 1.3;

/// Exponential-smoothing stiffness for the horizontal follow: the camera
/// closes `1 - e^(-k*dt)` of the remaining distance each frame, which is
/// frame-rate independent easing (unlike a raw `lerp(.., 0.1)` per frame).
const double cameraFollowStiffness = 3.4;

// ---------------------------------------------------------------------------
// Módulo 13 — integração da cena.
//
// Everything below exists for one complaint: wagons and the boss read as
// stickers pasted onto the backdrop instead of objects standing in it.
// Nothing here touches physics, colliders, slot positions, the wagon/boss
// state machines, or the section 2.3 scale calibration.
// ---------------------------------------------------------------------------

/// Shared cool tint laid over the wagons and the boss so their palette
/// belongs to the same cave the backdrop is painted in (module task 2).
///
/// Sampled from the backdrop itself rather than picked by eye: quantising
/// `layer-mid.png` and `caverna-gotica-pixelart.png` to 8 colours and
/// taking the modal bands of the gameplay half of the canvas gives a
/// consistent desaturated plum — RGB(53,33,48) H=315 S=0.38, RGB(34,21,37)
/// H=289 S=0.43, RGB(19,13,28) H=264 S=0.54. This is the middle of that
/// family, lifted in value so it tints rather than simply darkens.
const Color ambientCoolTintColor = Color(0xFF4A3A63);

/// Strength of that tint. The module asks for 5-15%; 0.11 sits in the
/// middle — enough to pull the wagons' and boss's highlights off pure
/// neutral, not enough to mud up the art or hurt readability against the
/// backdrop.
///
/// Applied as `ColorFilter.mode(colour.withOpacity(this), srcATop)`, which
/// composites the tint over the sprite's own pixels *restricted to their
/// alpha* — so transparent padding stays transparent and no silhouette is
/// widened. See `fx/ambient_light.dart`.
const double ambientCoolTintOpacity = 0.11;

/// Radius (world px) inside which a lantern anchor from
/// `slots_config.json` casts a visible warm pool on a wagon's roof
/// (module task 2, second half). Falloff is linear to zero at this
/// distance, so wagons far from every lantern get nothing at all and the
/// track is lit unevenly — which is the point.
///
/// 340px is measured against the real layout: it picks out slot 7 (61px
/// from the lantern at (215,730)) strongly, slot 0 (292px from (1590,510))
/// and slot 5 (326px) faintly, and leaves the middle of the track dark.
const double wagonLanternGlowRadius = 340;

/// Peak diameter/opacity of that pool, for a wagon sitting right on top of
/// a lantern anchor. Deliberately weaker than [lanternGlowOpacity]: this
/// is bounced light landing on a 45px object, not the lamp itself.
///
/// Tuned down from 74px/0.30 after the first render: the wagon at slot 7
/// already sits inside the backdrop lantern pool at (215,730), and an
/// additive blend stacked on top of an *already lit* patch has almost no
/// headroom left — the cart came out washed pale and desaturated against
/// its unlit neighbours, which is the opposite of the integration this is
/// for. 60px/0.16 reads as the cart catching the lamp rather than as a
/// second lamp.
const double wagonLanternGlowDiameter = 60;
const double wagonLanternGlowMaxOpacity = 0.16;

/// Where the pool sits on the wagon, in the wagon's own local space
/// (negative = up from its ground point): the roof line, i.e. the top of
/// the platform collider. Read as a visual reference only — this module
/// neither defines nor changes that collider geometry.
const double wagonLanternGlowYOffset = -44;

/// Same slow flicker as the lantern pools themselves, so a lit wagon
/// breathes with the lamp lighting it instead of sitting under a decal.
const double wagonLanternGlowFlickerAmplitude = 0.04;

/// Direction the boss's rim light comes from, as a unit vector in world
/// space (y negative = up), and the angular width of the lit arc.
///
/// Módulo 13 fix. The rim was previously drawn by redrawing the silhouette
/// at eight offsets spread evenly around the compass, which is a uniform
/// stroke — a gold outline traced around the whole character, the exact
/// artefact this module was asked to remove. A rim light is not an
/// outline: it only exists where the light actually grazes the form.
///
/// The direction is taken from the scene, not invented: the two lantern
/// anchors nearest the boss's (1530, 760) are (1520, 300) — almost
/// straight above — and (1590, 510) — above and slightly right. Normalised,
/// that averages to roughly (+0.17, -0.99).
const double bossRimLightDirX = 0.17;
const double bossRimLightDirY = -0.985;

/// Half-width (radians) of the lit arc around that direction. Offsets
/// outside it are not drawn at all; inside it, both the weight and the
/// offset distance fall off with `cos²` of the angle, so the rim is
/// brightest and thickest where the light hits square on and thins to
/// nothing along the sides.
///
/// 0.8 rad ≈ 46°, a ~92° lit arc. The first attempt used 1.05 rad (60°),
/// which was still an outline in disguise: an offset 60° off vertical is
/// 87% horizontal, so it exposed a full-height band down *both* flanks of
/// the silhouette, right past the boots. At 46° the most lateral redraw is
/// 72% vertical and its offset is already tapered, so the flanks get a
/// sliver and the underside gets nothing.
const double bossRimLightArcHalfWidth = 0.8;

/// Render scale for `sprite_anchor_left.png` / `sprite_anchor_right.png`
/// (module task 6).
///
/// Chosen so the anchors' own chain links match the links the
/// `ChainSegment` catenaries are built from, which is what makes the wall
/// fitting read as the same chain rather than as separate scenery:
///   ChainSegment world pitch = 418 * 0.62 * 0.052 ≈ 13.5 px/link
///   anchor native pitch      ≈ 132.5 px/link (autocorrelated off the art)
///   scale = 13.5 / 132.5 ≈ 0.102
/// Rounded to 0.105. At that scale the whole 867x501 asset renders ≈91x53
/// world px, with its bolted wall plate ≈38px tall — a plausible fixture
/// beside a 45px wagon.
const double chainAnchorRenderScale = 0.105;

/// Where the plate/tip land inside the anchor art, in native px, measured
/// with an alpha > 10 scan. The two files are exact mirrors of each other.
///  * `sprite_anchor_left`  — plate at (153, 250), free chain tip at (745, 320)
///  * `sprite_anchor_right` — plate at (713, 250), free chain tip at (121, 320)
/// Consumed by `wagon/chain_anchor.dart` to place an anchor *by its chain
/// tip*, so the fitting's chain lines up with whatever it is terminating
/// instead of being eyeballed.
const double chainAnchorTipXLeft = 745;
const double chainAnchorTipXRight = 121;
const double chainAnchorTipY = 320;

// ---------------------------------------------------------------------------
// Módulo 14 — doca do Boss, arte caricata, combate.
//
// Same rule as Módulo 13: nothing in this block feeds physics, colliders,
// slot positions or the section 2.3 calibration. The combat *rules* live in
// `boss/boss_combat.dart`; what is here is only how the fight is drawn.
// ---------------------------------------------------------------------------

/// The boss's scenery dock (Módulo 14, seções 1.1/2.1/3.4). A single
/// static prop — no grid, no animation — loaded as one sprite.
const String bossDockAssetPath = 'boss/doca.png';

// Módulo 15, Mudança 1: `effects/corrente-restritiva.png`,
// `effects/ciclo-corrompido.png` and `wagons/decorative/no-orfao.png` are
// no longer referenced by any code path — the attacks that drew them were
// cut from the roster. The files are left in `assets/` rather than
// deleted: they cost nothing at runtime (nothing loads them) and throwing
// away delivered art is not this module's call to make.

// --- Render order -----------------------------------------------------------

/// The dock is scenery bolted to the wall, so it paints behind everything
/// at priority 0 *and* behind the two Módulo 13 chain anchors: the wagon at
/// slot 0 and the boss->slot 0 chain both cross its left tip and must stay
/// in front of it.
const int fxPriorityBossDock = -4;

/// The boss's contact shadow: above the dock it is cast on, below the boss
/// casting it. A sibling in the world rather than a child of the boss,
/// because Flame draws a component's children *after* its own render — a
/// child could only ever be an overlay (same reasoning as `BossRimLight`).
const int fxPriorityBossContactShadow = -3;

/// Combat overlays that must read on top of the track: the chain
/// telegraph, the cycle arc and its Floyd markers, and the highlight ring
/// on the slot the player has to attack.
const int fxPriorityCombatOverlay = 5;

// --- Doca do Boss -----------------------------------------------------------

/// `doca.png` is 1536x1024 with real alpha (verified: 79% of the canvas is
/// alpha == 0, opaque bbox (209,73)-(1325,956) — no baked checkerboard,
/// which was the failure the asset brief called out).
const double bossDockCanvasWidth = 1536;
const double bossDockCanvasHeight = 1024;

/// Row (native px) where the riveted deck's **top surface** starts, found
/// with an alpha>10 row-width scan: rows 575..599 are the support chains
/// only (310..370 px wide), and the width jumps to 882 at row 600 where the
/// planking begins. This is the line the boss's feet have to land on, so
/// the dock is positioned by it rather than by its canvas.
const double bossDockDeckTopNativeY = 600;

/// Horizontal centre and width (native px) of that deck, measured on row
/// 620: x spans 265..1318, so centre = 791.5, width = 1054.
const double bossDockDeckCentreNativeX = 791.5;
const double bossDockDeckNativeWidth = 1054;

/// Target on-screen width of the deck itself (not of the whole canvas).
///
/// 150px against the boss's calibrated 176px height: wide enough to carry
/// the widest pose in the sheet (the chain wind-up frame is 241 native px
/// = ~180 world px across, so the arms overhang, as they should on a
/// cramped dock) without the prop reaching across the slot-0 wagon, whose
/// art ends at x = 1499.5.
///   scale = 150 / 1054 = 0.14232
/// At that scale the whole prop renders 218.6 x 145.7 world px.
const double bossDockDeckWidth = 150;
const double bossDockRenderScale =
    bossDockDeckWidth / bossDockDeckNativeWidth;

/// The deck is nudged slightly away from the track rather than centred on
/// the boss, so its far tip lands on the rock wall behind him and its near
/// tip stops short of the slot-0 wagon's art.
const double bossDockDeckCentreOffsetX = 15;

/// The art is drawn with its rock wall on the *left* and the deck running
/// right. The boss stands at the right-hand end of a left-running track,
/// so the prop is mirrored: the wall ends up against the arena's right
/// edge and the deck reaches back towards slot 0.
const bool bossDockFlipHorizontally = true;

/// Width of the boss's contact shadow. Sized the way the other two were —
/// just over the rendered art's own width — from the measured 133 native px
/// of the widest idle frame: 133 * `bossDisplayScale` ≈ 99px of character.
const double bossContactShadowWidth = 110;
const double bossContactShadowOpacity = 0.5;

// --- Slot telegraph (both primitives) ---------------------------------------

/// The pulsing ring the boss puts over a slot during his wind-up
/// (`SlotHighlight`). One shape for both primitives, two colours: amber
/// for the node about to be taken out, gold-white for the shove coming in
/// at slot 0. Reading the *colour* is the skill the fight asks for, which
/// is why the geometry deliberately does not vary.
const double slotTelegraphDiameter = 96;

/// How far above the slot's ground point the ring is centred, so it reads
/// as marking the wagon's roof rather than the rail under it.
const double slotTelegraphHeightAboveGround = 40;

/// RemoverNo: the node is about to shake loose and fall.
const Color removerNoTelegraphColor = Color(0xFFFF7A3D);

/// InserirNo: something is arriving at the head of the line.
const Color inserirNoTelegraphColor = Color(0xFFFFC24A);

// --- Combat feedback --------------------------------------------------------

/// The "clang vazio" of an attack that resolves against nothing (the Nó
/// Órfão, or the boss outside its exposed window).
const Color combatMissFlashColor = Color(0xFFBFC6D4);
const double combatMissFlashDiameter = 58;
const double combatMissFlashDuration = 0.28;

/// The hit spark when real damage lands.
const Color combatHitFlashColor = Color(0xFFFFD98A);
const double combatHitFlashDiameter = 84;
const double combatHitFlashDuration = 0.32;

/// How long the player's sprite flashes while invulnerable after a hit.
const double playerDamageFlashPeriod = 0.12;

// --- Mudança 2: the shove, made to read as a shove -------------------------
//
// The playtest complaint was that InserirNo looked like a hard cut: the
// player was simply *somewhere else* on the next frame. Four things fix
// that, and all four are visual only — none of them touches the relabel,
// the slot contents, the collider or the calibrated scales.
//   1. a longer, eased tween (this duration + `GameCurves.impactOut`);
//   2. a squash on the frame the player settles;
//   3. dust at the landing point;
//   4. a screen shake on the frame the new wagon enters slot 0.

/// Duration of the tween that carries the player to the new position of
/// the content they were standing on.
///
/// Módulo 14 used 0.28s on a plain ease-out, which is inside the range a
/// viewer reads as "teleport with a smear". Mudança 2 asks for 0.35-0.5s;
/// 0.42s sits in the middle of that window — long enough for the eye to
/// track the travel, short enough that control comes back before the
/// player needs it for the next hole.
const double empurraoPlayerTweenDuration = 0.42;

/// Vertical squash applied for the two or three frames the player lands on
/// the new slot: 0.87 is a 13% compression, inside Mudança 2's 10-15%.
/// Width counter-scales as 1/sy through the existing squash machinery, so
/// this is the same spring-back the jump landing already uses — not a
/// second, parallel deformation system.
const double empurraoLandSquashFactor = 0.87;

/// How long that squash takes to spring back. ~2.5 frames at 60fps, which
/// is the "2-3 frames" the brief asks for expressed as the duration the
/// squash system actually consumes.
const double empurraoLandSquashDuration = 0.042;
