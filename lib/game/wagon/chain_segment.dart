import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';

import '../fx/ambient_light.dart';
import '../track/slot.dart';
import 'vagao.dart';

/// Spritesheet of individual, repeatable chain-link tiles (module prompt:
/// "sistema de ELO REPETÍVEL"), replacing the old approach of stretching
/// one whole pre-drawn curve image between two anchors (which distorted
/// badly once the real per-segment distances/angles varied). 1536x1024,
/// grid of 3 columns x 2 rows, each cell 512x512.
const String chainLinkSheetAssetPath = 'wagons/spritesheets/chains.png';
const double chainLinkCellSize = 512;

/// One tile in the sheet, keyed by (row, column) — module prompt, Tarefa 2a.
enum ChainLinkKind {
  intact(0, 0),
  tremor(0, 1),
  cracking(0, 2),
  breaking(1, 0),
  brokenTip(1, 1),
  smoothTip(1, 2);

  final int row;
  final int column;
  const ChainLinkKind(this.row, this.column);
}

/// Native (pre-scale) opaque art width of a single link tile, measured
/// directly off `chains.png` cell (0,0) — 418px wide (includes the
/// connecting stub nubs of the neighboring links baked into the art on
/// both sides). Used, per module prompt Tarefa 2b, to size link spacing
/// from the sprite's real dimensions instead of dividing `distance` by an
/// arbitrary count.
const double _chainLinkArtWidth = 418;

/// Fraction of [_chainLinkArtWidth] used as the center-to-center spacing
/// between consecutive links, since each tile's stub nubs are meant to
/// overlap with its neighbors' (the sheet shows one full ring per cell
/// plus a partial peek of the previous/next ring at each edge) rather
/// than sit edge-to-edge. Tuned visually against the Windows build (per
/// module prompt: "execute o game pela build windows") — not derived
/// analytically, since the exact interlock geometry isn't specified
/// anywhere in the provided docs.
const double _chainLinkPitchFraction = 0.62;

/// Render scale applied to every link tile. Combined with
/// [_chainLinkPitchFraction] this determines the on-screen center-to-
/// center spacing between links — see [_chainLinkWorldPitch]. Tuned
/// visually so a handful of links comfortably fit the shortest segment
/// (boss<->slot0, ~90px) while longer segments (~197-216px) clearly show
/// more of them.
const double chainLinkRenderScale = 0.052;

double get _chainLinkWorldPitch =>
    _chainLinkArtWidth * _chainLinkPitchFraction * chainLinkRenderScale;

/// How much a segment sags below the straight line between its two
/// anchors, as a fraction of the segment's horizontal span — the "curva
/// de catenária simples" from the module prompt (Tarefa 2b/c). See
/// [_CatenaryCurve] for the actual curve math.
const double _chainSagRatio = 0.16;

/// Loads (once) and caches the [SpriteSheet] backing every [ChainSegment]
/// — sharing one loaded sheet instead of each segment re-decoding the
/// same image.
class ChainLinkSheet {
  static SpriteSheet? _sheet;

  static Future<SpriteSheet> load() async {
    final cached = _sheet;
    if (cached != null) {
      return cached;
    }
    final image = await Flame.images.load(chainLinkSheetAssetPath);
    final sheet = SpriteSheet(image: image, srcSize: Vector2.all(chainLinkCellSize));
    _sheet = sheet;
    return sheet;
  }
}

/// `dart:math` has no hyperbolic functions.
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

/// A symmetric catenary-like droop added on top of the straight-line
/// interpolation between two (possibly unequal-height) points. Not the
/// exact unequal-support catenary equation — a standard, much simpler
/// game-dev approximation: solve the horizontal-span-only catenary sag
/// `a*(cosh(L/2a) - 1)` for the parameter `a` that hits a target sag
/// (fraction of the horizontal span), then add that shape's vertical
/// offset on top of the plain lerp between the two endpoints. Visually
/// indistinguishable from a true catenary at this scale, and avoids
/// solving the transcendental unequal-height case.
class _CatenaryCurve {
  final Vector2 from;
  final Vector2 to;
  final double _a;
  final double _horizontalSpan;

  _CatenaryCurve._(this.from, this.to, this._a, this._horizontalSpan);

  factory _CatenaryCurve(Vector2 from, Vector2 to, double sagRatio) {
    final horizontalSpan = (to.x - from.x).abs();
    if (horizontalSpan < 1e-3) {
      // No horizontal run (shouldn't happen for this track's slots, but
      // guarded so the curve degenerates to a straight line instead of
      // dividing by ~0 below).
      return _CatenaryCurve._(from, to, 1, horizontalSpan);
    }
    final targetSag = sagRatio * horizontalSpan;
    final a = _solveCatenaryParameter(horizontalSpan, targetSag);
    return _CatenaryCurve._(from, to, a, horizontalSpan);
  }

  /// Solves `a*(cosh(L/(2a)) - 1) = sag` for `a` via bisection. The LHS is
  /// monotonically decreasing in `a` (from +infinity as `a -> 0` to 0 as
  /// `a -> infinity`), so a unique root always exists for `sag > 0`.
  static double _solveCatenaryParameter(double span, double sag) {
    if (sag < 1e-6) {
      // Effectively a straight line — any huge `a` flattens the sag to
      // ~0, so returning a large constant is equivalent without a solve.
      return span * 1000;
    }
    var lo = span * 1e-4;
    var hi = span * 1000;
    double f(double a) => a * (_cosh(span / (2 * a)) - 1) - sag;

    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (f(mid) > 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Point on the curve at `t` in `[0, 1]` (0 = [from], 1 = [to]).
  Vector2 pointAt(double t) {
    final baseX = from.x + t * (to.x - from.x);
    final baseY = from.y + t * (to.y - from.y);
    if (_horizontalSpan < 1e-3) {
      return Vector2(baseX, baseY);
    }
    final sagOffset = _a * _cosh(_horizontalSpan / (2 * _a)) -
        _a * _cosh((t - 0.5) * _horizontalSpan / _a);
    return Vector2(baseX, baseY + sagOffset);
  }

  /// Tangent angle (radians) at `t`, via central finite difference —
  /// simpler and just as accurate at this resolution as differentiating
  /// the closed form by hand.
  double tangentAngleAt(double t) {
    const eps = 0.001;
    final t0 = (t - eps).clamp(0.0, 1.0);
    final t1 = (t + eps).clamp(0.0, 1.0);
    final delta = pointAt(t1) - pointAt(t0);
    return math.atan2(delta.y, delta.x);
  }
}

/// How the links along a segment should currently be drawn — derived 1:1
/// from the far-side [Vagao]'s current asset (module prompt, Tarefa 2d).
enum _SegmentMode { intact, tremor, crackingCenter, breakingCenter, ruptured }

/// Módulo 13: rebuilt over the regenerated 15-frame wagon set. The
/// contract is unchanged — the chain mirrors the far-side wagon's current
/// art — and so is the meaning of each mode; the regenerated art simply
/// spells the same progression out over more frames:
///  * idle                    -> intact
///  * the 4 tremor frames     -> tremor
///  * break1/break2           -> crackingCenter  (elo começando a se soltar)
///  * link_detached1/2        -> breakingCenter  (elo já solto/pendurado)
///  * falling* / impact*      -> ruptured        (o vagão se foi)
final Map<String, _SegmentMode> _modeForVagaoAsset = {
  vagaoIdleFrame.assetPath: _SegmentMode.intact,
  for (final frame in vagaoTremorFrames) frame.assetPath: _SegmentMode.tremor,
  vagaoFallingFrames[0].assetPath: _SegmentMode.crackingCenter,
  vagaoFallingFrames[1].assetPath: _SegmentMode.crackingCenter,
  vagaoFallingFrames[2].assetPath: _SegmentMode.breakingCenter,
  vagaoFallingFrames[3].assetPath: _SegmentMode.breakingCenter,
  for (final frame in vagaoFallingFrames.skip(4))
    frame.assetPath: _SegmentMode.ruptured,
};
/// Purely decorative chain segment between two adjacent track points
/// (boss<->slot0, or slot[i]<->slot[i+1]), rendered as a row of
/// individual, individually-rotated link tiles distributed along a
/// catenary-like curve — see module prompt for the full rationale behind
/// replacing the old single-stretched-image `ChainLink`.
///
/// Reacts to (never drives) the wagon occupying [farSlot], mirroring the
/// exact same synchronization contract the old component had:
/// - Invisible until [farSlot] is occupied for the first time.
/// - While occupied, mirrors [Vagao.currentAssetPath] via
///   [_modeForVagaoAsset] every frame.
/// - Once ruptured (the wagon starts actually falling) and the boss then
///   clears the slot, `farSlot.vagao` becomes null — this component just
///   stops polling and keeps showing the frozen ruptured layout (a full
///   near-side run of intact links ending in a [ChainLinkKind.brokenTip]
///   terminator), with no special-cased "removed" branch.
/// - A new [Vagao] later occupying the same slot is a different instance
///   (reference inequality) and resets the segment back to fully intact.
///
/// Never touches `farSlot.vagao`, colliders, or physics.
class ChainSegment extends PositionComponent {
  final Vector2 fromAnchor; // near-boss side, fixed anchor.
  final Vector2 toAnchor; // far-from-boss side, the side that "hangs" here.
  final double segmentDistance; // from slots_config.json, not re-derived.
  final Slot farSlot;

  late final _CatenaryCurve _curve;
  final List<SpriteComponent> _links = [];
  int _middleIndex = 0;

  SpriteSheet? _sheet;
  Vagao? _lastVagao;
  String? _lastVagaoAsset;

  /// Módulo 14, section 4.2 ④ — whether this segment is drawn as the gold
  /// chain of a doubly linked list. Purely a repaint: the catenary, the
  /// link count, the placements and the wagon-mirroring contract above are
  /// all untouched.

  ChainSegment({
    required this.fromAnchor,
    required this.toAnchor,
    required this.segmentDistance,
    required this.farSlot,
    super.priority,
  }) : super(position: Vector2.zero(), anchor: Anchor.topLeft);
  // This component itself stays at the world origin, unrotated — every
  // link is placed directly in world coordinates, since they each need
  // an independent position/rotation along the curve, not a shared one.

  @override
  Future<void> onLoad() async {
    _sheet = await ChainLinkSheet.load();
    _curve = _CatenaryCurve(fromAnchor, toAnchor, _chainSagRatio);

    final placements = _computeLinkPlacements();
    _middleIndex = placements.length ~/ 2;

    for (final placement in placements) {
      final link = SpriteComponent(
        sprite: _sheet!.getSprite(ChainLinkKind.intact.row, ChainLinkKind.intact.column),
        anchor: Anchor.center,
        position: placement.position,
        angle: placement.angle,
        scale: Vector2.all(chainLinkRenderScale),
      );
      // Módulo 13, item 2: same cool wash as the wagons the chain hangs
      // between — without it the links would be the one piece of the
      // wagon/chain art family still reading as pasted on.
      applyChainTint(link);
      link.opacity = 0;
      _links.add(link);
      await add(link);
    }
  }

  /// Samples the curve finely to get its real arc length, then places
  /// links at even arc-length intervals (not evenly in `t`, which would
  /// bunch them up on steeper stretches of a sagging curve).
  List<_LinkPlacement> _computeLinkPlacements() {
    const sampleCount = 64;
    final samples = <Vector2>[];
    final cumulativeLength = <double>[0];
    for (var i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      samples.add(_curve.pointAt(t));
      if (i > 0) {
        cumulativeLength.add(
          cumulativeLength.last + (samples[i] - samples[i - 1]).length,
        );
      }
    }
    final totalLength = cumulativeLength.last;
    final linkCount = math.max(1, (totalLength / _chainLinkWorldPitch).round());

    final placements = <_LinkPlacement>[];
    for (var i = 0; i < linkCount; i++) {
      final targetLength = (i + 0.5) * totalLength / linkCount;
      final t = _tAtArcLength(targetLength, cumulativeLength, sampleCount);
      placements.add(
        _LinkPlacement(position: _curve.pointAt(t), angle: _curve.tangentAngleAt(t)),
      );
    }
    return placements;
  }

  double _tAtArcLength(
    double targetLength,
    List<double> cumulativeLength,
    int sampleCount,
  ) {
    for (var i = 1; i <= sampleCount; i++) {
      if (cumulativeLength[i] >= targetLength) {
        final segStart = cumulativeLength[i - 1];
        final segEnd = cumulativeLength[i];
        final segFrac = segEnd > segStart
            ? (targetLength - segStart) / (segEnd - segStart)
            : 0.0;
        return ((i - 1) + segFrac) / sampleCount;
      }
    }
    return 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_sheet == null) {
      return;
    }

    final vagao = farSlot.vagao;
    if (vagao == null) {
      // Either never occupied yet (stay invisible) or just removed (keep
      // showing the frozen ruptured layout from the last update).
      return;
    }

    if (!identical(vagao, _lastVagao)) {
      _lastVagao = vagao;
      _lastVagaoAsset = null; // force a state re-apply below.
      for (final link in _links) {
        link.opacity = 1;
      }
    }

    final asset = vagao.currentAssetPath;
    if (asset == _lastVagaoAsset) {
      return;
    }
    _lastVagaoAsset = asset;
    _applyMode(_modeForVagaoAsset[asset] ?? _SegmentMode.intact);
  }

  void _applyMode(_SegmentMode mode) {
    final sheet = _sheet!;
    switch (mode) {
      case _SegmentMode.intact:
        for (final link in _links) {
          link.opacity = 1;
          link.sprite = sheet.getSprite(ChainLinkKind.intact.row, ChainLinkKind.intact.column);
        }
      case _SegmentMode.tremor:
        for (final link in _links) {
          link.opacity = 1;
          link.sprite = sheet.getSprite(ChainLinkKind.tremor.row, ChainLinkKind.tremor.column);
        }
      case _SegmentMode.crackingCenter:
        _applyCenterOverlay(ChainLinkKind.cracking);
      case _SegmentMode.breakingCenter:
        _applyCenterOverlay(ChainLinkKind.breaking);
      case _SegmentMode.ruptured:
        for (var i = 0; i < _links.length; i++) {
          if (i < _middleIndex) {
            _links[i].opacity = 1;
            _links[i].sprite =
                sheet.getSprite(ChainLinkKind.intact.row, ChainLinkKind.intact.column);
          } else if (i == _middleIndex) {
            _links[i].opacity = 1;
            _links[i].sprite =
                sheet.getSprite(ChainLinkKind.brokenTip.row, ChainLinkKind.brokenTip.column);
          } else {
            // The far side "fell" with the wagon — out of the chain's own
            // visual scope (module prompt, Tarefa 2d).
            _links[i].opacity = 0;
          }
        }
    }
  }

  /// Every link intact except the middle one, which shows [kind] — used
  /// for the two rompendo telegraph stages, where the chain is still
  /// fully connected end-to-end (module prompt, Tarefa 2d).
  void _applyCenterOverlay(ChainLinkKind kind) {
    final sheet = _sheet!;
    for (var i = 0; i < _links.length; i++) {
      _links[i].opacity = 1;
      _links[i].sprite = i == _middleIndex
          ? sheet.getSprite(kind.row, kind.column)
          : sheet.getSprite(ChainLinkKind.intact.row, ChainLinkKind.intact.column);
    }
  }
}

class _LinkPlacement {
  final Vector2 position;
  final double angle;

  const _LinkPlacement({required this.position, required this.angle});
}
