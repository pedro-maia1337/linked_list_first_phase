import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'fx_config.dart';

/// Solid colour painted behind every backdrop layer (Módulo 12, item 1:
/// "uma cor sólida de preenchimento atrás de tudo, sampleada do tom de céu
/// de layer-far.png, para cobrir a faixa sem pintura que sobra no topo").
///
/// Fills the camera's whole visible world rect rather than a fixed
/// canvas-sized box, so it also covers anything the camera's shake or the
/// horizontal pan momentarily exposes outside the 1672x941 canvas — there
/// is never a bare/black edge to see.
///
/// A plain [Component] (not a [PositionComponent]): the world's canvas is
/// already in world coordinates, so [visibleWorldRect] can be drawn
/// verbatim without any local transform.
class SkyFill extends Component {
  final CameraComponent camera;
  final Paint _paint;

  SkyFill({required this.camera, required Color color})
      : _paint = Paint()..color = color,
        super(priority: fxPrioritySkyFill);

  @override
  void render(Canvas canvas) {
    // inflate: guards against a sub-pixel seam at the rect's own edges when
    // the camera sits on a fractional world coordinate.
    canvas.drawRect(camera.visibleWorldRect.inflate(2), _paint);
  }
}

/// One horizontally-wrapping backdrop layer that scrolls at a fraction of
/// the camera's own movement (Módulo 12, item 1 + item 5: "acionando o
/// parallax do item 1 em resposta ao movimento de câmera (não só ao do
/// player)").
///
/// The layer is driven by [CameraComponent.viewfinder]'s position, not by
/// the player's — so it keeps reacting correctly while the camera is still
/// easing towards the player, while it is clamped at a track boundary, and
/// while it is being shaken.
///
/// ## How the parallax offset is derived
///
/// A component sitting at a fixed world coordinate scrolls, relative to the
/// screen, at exactly the camera's speed — i.e. parallax factor 1. To make
/// this layer appear to scroll at [parallaxFactor] instead, its content is
/// drawn shifted by the *difference*:
///
///     shift = (1 - parallaxFactor) * (cameraX - referenceX)
///
/// At `cameraX == referenceX` the shift is zero, so the layer lines up with
/// the world exactly as authored; a `parallaxFactor` of 1 gives a shift of
/// zero everywhere (moves with the world) and 0 gives a shift equal to the
/// camera's whole displacement (pinned to the screen).
///
/// ## Wrapping
///
/// Both source images are authored to tile horizontally without a seam, so
/// the layer just draws however many whole copies the visible rect spans,
/// indexed from the shifted origin. Each tile is drawn with a half-pixel
/// [Sprite.render] `bleed`, which stretches the destination rect outwards
/// by 0.5px on every side: adjacent tiles then overlap slightly instead of
/// meeting exactly, which is what kills the 1px transparent seam that
/// fractional camera zoom would otherwise produce between copies. The
/// stretch is 1px over a 1376px tile (0.07%) and is not perceptible.
///
/// ## Vertical placement
///
/// Both layers are aligned by their **base** to [baselineY] (the canvas's
/// bottom edge), at their native pixel height — never stretched to fill.
/// layer-far (639px) therefore tops out 129px lower than layer-mid (768px),
/// and [SkyFill] is what covers that band.
class ParallaxLayer extends Component {
  final CameraComponent camera;
  final Sprite sprite;
  final double parallaxFactor;

  /// World y of the layer's *bottom* edge.
  final double baselineY;

  /// Camera x at which this layer's shift is zero.
  final double referenceX;

  /// Height (world px) of a vertical fade painted over this layer's own top
  /// edge, from [skyFillColor] fully opaque at the edge down to
  /// fully transparent [topFadeHeight] px below it.
  ///
  /// Without it, a base-aligned layer that is shorter than the visible rect
  /// ends on a dead-straight horizontal line — clearly visible in the build
  /// as a band change right where layer-far's 639px top edge sits. Fading
  /// into the *same* colour [SkyFill] paints behind everything dissolves
  /// that line into the fill instead, so the cave ceiling reads as
  /// disappearing into haze. It does not replace the solid fill; it only
  /// blends into it.
  final double topFadeHeight;

  /// The solid colour [SkyFill] paints; the top fade blends into it.
  final Color skyFillColor;

  final Paint _paint = Paint()
    // Pixel art: never let the sampler blend neighbouring texels, which
    // would both soften the art and reintroduce tile seams.
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  ParallaxLayer({
    required this.camera,
    required this.sprite,
    required this.parallaxFactor,
    required this.baselineY,
    required this.referenceX,
    required this.topFadeHeight,
    required this.skyFillColor,
    required int priority,
  }) : super(priority: priority);

  /// Loads [assetPath] through Flame's shared image cache and builds a
  /// layer from it at the image's native size.
  static Future<ParallaxLayer> load({
    required CameraComponent camera,
    required String assetPath,
    required double parallaxFactor,
    required double baselineY,
    required double referenceX,
    required double topFadeHeight,
    required Color skyFillColor,
    required int priority,
  }) async {
    final image = await Flame.images.load(assetPath);
    return ParallaxLayer(
      camera: camera,
      sprite: Sprite(image),
      parallaxFactor: parallaxFactor,
      baselineY: baselineY,
      referenceX: referenceX,
      topFadeHeight: topFadeHeight,
      skyFillColor: skyFillColor,
      priority: priority,
    );
  }

  @override
  void render(Canvas canvas) {
    final visible = camera.visibleWorldRect;
    final tileWidth = sprite.srcSize.x;
    final tileHeight = sprite.srcSize.y;
    if (tileWidth <= 0) {
      return;
    }

    final shift =
        (1 - parallaxFactor) * (camera.viewfinder.position.x - referenceX);
    final top = baselineY - tileHeight;

    final firstIndex = ((visible.left - shift) / tileWidth).floor();
    final lastIndex = ((visible.right - shift) / tileWidth).ceil();

    final size = Vector2(tileWidth, tileHeight);
    for (var i = firstIndex; i <= lastIndex; i++) {
      sprite.render(
        canvas,
        position: Vector2(shift + i * tileWidth, top),
        size: size,
        overridePaint: _paint,
        bleed: 0.5,
      );
    }

    _renderTopFade(canvas, visible, top);
  }

  /// Dissolves this layer's hard top edge into [SkyFill]'s colour — see
  /// [topFadeHeight]. Drawn as part of *this* layer's render, so it lands
  /// after the layer's own tiles and before the next (nearer) layer's,
  /// which is what keeps a nearer layer from being fogged by a farther
  /// one's fade.
  void _renderTopFade(Canvas canvas, Rect visible, double top) {
    if (topFadeHeight <= 0 || top >= visible.bottom) {
      return;
    }
    // Starts slightly *above* the layer's own top edge: the tiles are drawn
    // with `bleed: 0.5`, so they paint a half-pixel higher than `top`, and a
    // fade starting exactly at `top` leaves that sliver uncovered — which
    // showed up in the build as a 1px dark line wherever the source image's
    // first row happens to be dark rock. Everything above `top` is already
    // the identical [skyFillColor] from [SkyFill], so overshooting
    // into it costs nothing.
    final fadeTop = top - 2;
    final fadeRect = Rect.fromLTRB(
      visible.left - 2,
      fadeTop,
      visible.right + 2,
      top + topFadeHeight,
    );
    if (!fadeRect.overlaps(visible)) {
      return;
    }
    canvas.drawRect(
      fadeRect,
      Paint()
        ..shader = Gradient.linear(
          Offset(fadeRect.left, fadeRect.top),
          Offset(fadeRect.left, fadeRect.bottom),
          <Color>[
            skyFillColor,
            skyFillColor.withAlpha(0),
          ],
        ),
    );
  }
}

/// Subtle edge darkening, drawn in **viewport** (screen) space so it stays
/// pinned to the screen's borders regardless of where the camera is.
///
/// Added at [fxPriorityVignette] (negative) so it renders *before* — and
/// therefore underneath — the existing `DebugHelpOverlay`, which keeps its
/// default `priority: 0`. The debug HUD is out of scope for this module and
/// must stay exactly as legible as it was.
///
/// The gradient is fully transparent out to [vignetteInnerStop] of the
/// screen's half-diagonal, so the entire central gameplay band is drawn at
/// unmodified brightness — only the corners darken, to at most
/// [vignetteCornerOpacity].
class Vignette extends Component {
  final CameraComponent camera;

  Vignette({required this.camera}) : super(priority: fxPriorityVignette);

  Rect? _cachedRect;
  Paint? _cachedPaint;

  @override
  void render(Canvas canvas) {
    final size = camera.viewport.size;
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Building a gradient shader is not free, and the viewport only
    // changes size on a window resize — cache it between frames.
    if (_cachedRect != rect || _cachedPaint == null) {
      _cachedRect = rect;
      final hw = rect.width / 2;
      final hh = rect.height / 2;
      _cachedPaint = Paint()
        ..shader = Gradient.radial(
          rect.center,
          // Half-diagonal, so the gradient's outer stop lands exactly on
          // the screen corners and `vignetteInnerStop` is a fraction of
          // that same distance.
          math.sqrt(hw * hw + hh * hh),
          <Color>[
            const Color(0x00000000),
            const Color(0x00000000),
            // Target corner opacity baked into the gradient itself —
            // `Paint.color` is documented as unused once a shader is set.
            const Color.fromRGBO(0, 0, 0, vignetteCornerOpacity),
          ],
          const <double>[0, vignetteInnerStop, 1],
        );
    }

    canvas.drawRect(rect, _cachedPaint!);
  }
}
