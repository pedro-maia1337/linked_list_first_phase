/// Shared visual tuning — constants used by code under `lib/shared/`
/// (player juice, camera, vignette, contact shadow, generic particles and
/// combat flashes). Phase-specific tuning lives in each phase's own
/// `*_fx_config.dart` (e.g. `phases/linked_list/fx/linked_list_fx_config.dart`).
///
/// Split out of the Módulo 12-15 `fx_config.dart` without changing any
/// value. **Nothing here feeds physics, collision, scale or state-machine
/// logic** — every value below only affects what is drawn.
library;

import 'dart:ui' show Color;

// ---------------------------------------------------------------------------
// Asset paths (relative to `Flame.images.prefix`, which the game sets to
// 'assets/').
// ---------------------------------------------------------------------------

/// 128x128 additive amber glow.
const String fxGlowWarmSoftAssetPath = 'shared/effects/glow-warm-soft.png';

/// 96x32 contact shadow (dark ellipse centred in the frame).
const String fxContactShadowAssetPath = 'shared/effects/contact-shadow.png';

/// 6-frame 48x48 spritesheet (sheet is 288x48), baseline-aligned: the
/// opaque content of every frame bottoms out at y≈46/48, so
/// [Anchor.bottomCenter] puts the puff's contact point on the ground.
const String fxDustPoofAssetPath = 'shared/effects/particles/dust-poof.png';

// ---------------------------------------------------------------------------
// Render order (generic layers). Phase-specific priorities live in the
// phase's fx config and must fit between these.
//
// Every world entity (boss, platforms, player, debug markers) sits at the
// default `priority: 0` and relies on insertion order for paint order.
// Backdrop layers take large negative priorities (always behind).
// ---------------------------------------------------------------------------

const int fxPrioritySkyFill = -100;
const int fxPriorityLayerFar = -90;
const int fxPriorityLayerMid = -80;

/// Viewport-space priority for the vignette. Deliberately **below** the
/// debug HUD's default `priority: 0` so the existing `DebugHelpOverlay`
/// legend keeps rendering on top of it, fully legible — the debug HUD is
/// explicitly out of scope for this module.
const int fxPriorityVignette = -10;

/// Combat overlays that must read on top of the track: the chain
/// telegraph, the cycle arc and its Floyd markers, and the highlight ring
/// on the slot the player has to attack.
const int fxPriorityCombatOverlay = 5;

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

/// Default screen shake ([CameraDirector.shake]). Small and short —
/// "sutil". (Originally tuned for a wagon entering `falling`.)
const double cameraShakeAmplitude = 6;
const double cameraShakeDuration = 0.35;

// ---------------------------------------------------------------------------
// Combat feedback.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Scripted player move (`Player.shoveToSlot`).
// ---------------------------------------------------------------------------

/// Duration of the eased tween that carries the player to a new position
/// (0.35-0.5s reads as travel rather than a teleport).
const double playerShoveTweenDuration = 0.42;

/// Squash on the frame the player settles: a 13% compression.
const double playerShoveLandSquashFactor = 0.87;

/// How long that squash takes to spring back (~2.5 frames at 60fps).
const double playerShoveLandSquashDuration = 0.042;
