import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';

import 'player_animations.dart';

/// Módulo 15 — the player's own effect sprites (dash trail, double-jump
/// burst, sword slash arc), preloaded once in `Player.onLoad` so spawning
/// them mid-move is synchronous and never waits a frame on image decoding.
class PlayerFx {
  final Map<PlayerFacing, SpriteAnimation> _dashTrail;
  final SpriteAnimation _doubleJumpBurst;
  final Map<(PlayerFacing, int), SpriteAnimation> _slashArc;

  PlayerFx._(this._dashTrail, this._doubleJumpBurst, this._slashArc);

  /// Dash trail frame time — 6 frames fading out over ~0.18s.
  static const double dashTrailStepTime = 0.03;

  /// Rendered size of one 64x32 trail cell (content is a small streak, so
  /// it is drawn 3x).
  static const double dashTrailScale = 3;

  static const double doubleJumpBurstStepTime = 0.05;

  /// 96px cell drawn at 1.5x: the ring (43px native) reads ~65px wide, a
  /// little wider than the player's feet.
  static const double doubleJumpBurstScale = 1.5;

  /// Anchor of the burst cell: the ring's centre sits at native (48, 65).
  static final Anchor doubleJumpBurstAnchor = Anchor(0.5, 65 / 96);

  static const double slashArcStepTime = 0.05;

  /// The arc's opaque width is 130px native; drawn so it spans the
  /// hitbox reach (1.4x the 110px player).
  static const double slashArcScale = 154 / 130;

  /// Vertical offset of each row's opaque content centre from its cell
  /// centre, already scaled (alpha > 10 bbox: row 0 rows 100..160 -> +34
  /// native, row 1 rows 24..148 -> -10 native).
  static const List<double> slashArcContentOffsetY = [
    34 * slashArcScale,
    -10 * slashArcScale,
  ];

  /// Where each arc should be centred, relative to the feet: golpe 1 on
  /// the blade line of attack1's peak frame (row ~142 of 256, ≈63px up);
  /// golpe 2's tall diagonal around mid-body so it sweeps from above the
  /// head down to the feet.
  static const List<double> slashArcBladeY = [-63, -50];

  static Future<PlayerFx> load() async {
    Future<SpriteSheet> sheet(String path, Vector2 cell) async =>
        SpriteSheet(image: await Flame.images.load(path), srcSize: cell);

    final dashTrail = <PlayerFacing, SpriteAnimation>{};
    final slashArc = <(PlayerFacing, int), SpriteAnimation>{};
    for (final facing in PlayerFacing.values) {
      final trailSheet =
          await sheet(playerDashTrailAssetPath(facing), Vector2(64, 32));
      dashTrail[facing] = trailSheet.createAnimation(
        row: 0,
        stepTime: dashTrailStepTime,
        to: playerDashTrailFrameCount,
        loop: false,
      );

      final arcSheet = await sheet(
        playerSlashArcAssetPath(facing),
        Vector2.all(playerSlashArcFrameSize),
      );
      for (var row = 0; row < playerSlashArcRows; row++) {
        slashArc[(facing, row)] = arcSheet.createAnimation(
          row: row,
          stepTime: slashArcStepTime,
          to: playerSlashArcColumns,
          loop: false,
        );
      }
    }

    final burstSheet =
        await sheet(playerDoubleJumpBurstAssetPath, Vector2.all(96));
    final burst = burstSheet.createAnimation(
      row: 0,
      stepTime: doubleJumpBurstStepTime,
      to: playerDoubleJumpBurstFrameCount,
      loop: false,
    );

    return PlayerFx._(dashTrail, burst, slashArc);
  }

  /// One puff of trail, centred at [position] (world space).
  PlayerFxSprite dashTrail(PlayerFacing facing, Vector2 position) =>
      PlayerFxSprite(
        kind: PlayerFxKind.dashTrail,
        animation: _dashTrail[facing]!,
        position: position,
        size: Vector2(64, 32) * dashTrailScale,
        anchor: Anchor.center,
      );

  /// The burst, with its ring centred on the player's feet [footPosition].
  PlayerFxSprite doubleJumpBurst(Vector2 footPosition) => PlayerFxSprite(
        kind: PlayerFxKind.doubleJumpBurst,
        animation: _doubleJumpBurst,
        position: footPosition,
        size: Vector2.all(96 * doubleJumpBurstScale),
        anchor: doubleJumpBurstAnchor,
      );

  /// The slash arc for swing [row] (0 = golpe 1, 1 = golpe 2), in the
  /// player's local space.
  PlayerFxSprite slashArc(PlayerFacing facing, int row, Vector2 position) =>
      PlayerFxSprite(
        kind: PlayerFxKind.slashArc,
        animation: _slashArc[(facing, row)]!,
        position: position,
        size: Vector2.all(playerSlashArcFrameSize * slashArcScale),
        anchor: Anchor.center,
        // Above the player's own art (a sibling child at priority 0).
        priority: 1,
      );
}

enum PlayerFxKind { dashTrail, doubleJumpBurst, slashArc }

/// A one-shot effect that removes itself after its last frame.
class PlayerFxSprite extends SpriteAnimationComponent {
  final PlayerFxKind kind;

  PlayerFxSprite({
    required this.kind,
    required super.animation,
    required super.position,
    required super.size,
    required super.anchor,
    super.priority,
  }) : super(removeOnFinish: true) {
    paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
  }
}
