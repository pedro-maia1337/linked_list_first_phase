/// Módulo 15 (upgrade do player) — the player's animation states and the
/// spritesheet each one is sliced from.
///
/// Kept free of Flame so the table can be checked by tests against the real
/// PNGs without booting a game (same split as `boss/boss_combat.dart`).
///
/// The game is strictly side-on: every sheet exists as a `west`/`east` pair
/// and there is no vertical orientation anywhere in this table.
library;

/// Player states (design doc section 4.2 / section 15).
///
/// The first eight have real art. [hit], [damaged], [pulled], [attackAir]
/// and [death] are reserved names: no asset, no logic, and
/// [playerSheetFor] returns `null` for them.
enum PlayerState {
  idle,
  walk,
  dash,
  jumpRise,
  jumpFall,
  doubleJump,
  attack1,
  attack2,

  // Reserved — no asset this etapa.
  hit,
  damaged,
  pulled,
  attackAir,
  death,
}

/// Horizontal facing — the only orientation axis the game has.
enum PlayerFacing { west, east }

/// Every sheet is a single row of 256x256 cells.
const double playerFrameSize = 256;

/// One west/east spritesheet pair.
class PlayerSheetSpec {
  /// File stem; the assets are `player/spritesheets/<stem>_west.png` and
  /// `..._east.png`, except walk, whose files are `west.png`/`east.png`.
  final String stem;
  final int frameCount;
  final double stepTime;
  final bool loop;

  /// How much larger the character is drawn in this sheet than in the
  /// calibration reference ([PlayerState.idle], frame 0).
  ///
  /// The delivered sheets share a cell size and a foot baseline (row 199 in
  /// every sheet), but **not** a drawing scale: `jump_rise` draws the same
  /// character about 1.6x bigger than `idle`. Rendering every sheet at one
  /// scale would make the player visibly grow when it jumps, which is a
  /// section 2.3 regression, so each sheet is divided by its own factor.
  ///
  /// Measured, not guessed:
  ///  * standing sheets (walk) — ratio of opaque heights of the upright
  ///    frames (walk 87px vs idle 92px);
  ///  * the others have no upright frame, so the ratio comes from the face
  ///    (the only skin-tone region of the art, whose area scales with the
  ///    square of the drawing scale), cross-checked by eye against the hood
  ///    width. See section 15.1 of the design doc for the numbers.
  final double artScale;

  const PlayerSheetSpec({
    required this.stem,
    required this.frameCount,
    required this.stepTime,
    required this.loop,
    required this.artScale,
  });

  String assetPath(PlayerFacing facing) {
    final side = facing == PlayerFacing.west ? 'west' : 'east';
    return stem.isEmpty
        ? 'player/spritesheets/$side.png'
        : 'player/spritesheets/${stem}_$side.png';
  }

  double get duration => frameCount * stepTime;
}

const PlayerSheetSpec playerIdleSheet = PlayerSheetSpec(
  stem: 'idle',
  frameCount: 6,
  stepTime: 0.14,
  loop: true,
  artScale: 1.0,
);

const PlayerSheetSpec playerWalkSheet = PlayerSheetSpec(
  stem: '',
  frameCount: 8,
  stepTime: 0.1,
  loop: true,
  artScale: 87 / 92,
);

const PlayerSheetSpec playerDashSheet = PlayerSheetSpec(
  stem: 'dash',
  frameCount: 6,
  stepTime: 0.03,
  loop: false,
  artScale: 1.10,
);

const PlayerSheetSpec playerJumpRiseSheet = PlayerSheetSpec(
  stem: 'jump_rise',
  frameCount: 4,
  stepTime: 0.08,
  loop: false,
  artScale: 1.56,
);

const PlayerSheetSpec playerJumpFallSheet = PlayerSheetSpec(
  stem: 'jump_fall',
  frameCount: 4,
  stepTime: 0.1,
  loop: true,
  artScale: 1.17,
);

/// Lasts 0.51s — just past the 0.5s time-to-apex of the second impulse, so
/// the flip ends on the way down and hands over to [PlayerState.jumpFall].
const PlayerSheetSpec playerDoubleJumpSheet = PlayerSheetSpec(
  stem: 'double_jump',
  frameCount: 6,
  stepTime: 0.085,
  loop: false,
  artScale: 1.23,
);

const PlayerSheetSpec playerAttack1Sheet = PlayerSheetSpec(
  stem: 'attack1',
  frameCount: 6,
  stepTime: 0.07,
  loop: false,
  artScale: 1.10,
);

const PlayerSheetSpec playerAttack2Sheet = PlayerSheetSpec(
  stem: 'attack2',
  frameCount: 6,
  stepTime: 0.07,
  loop: false,
  artScale: 1.16,
);

/// The sheet backing [state], or `null` for a reserved state.
PlayerSheetSpec? playerSheetFor(PlayerState state) => switch (state) {
      PlayerState.idle => playerIdleSheet,
      PlayerState.walk => playerWalkSheet,
      PlayerState.dash => playerDashSheet,
      PlayerState.jumpRise => playerJumpRiseSheet,
      PlayerState.jumpFall => playerJumpFallSheet,
      PlayerState.doubleJump => playerDoubleJumpSheet,
      PlayerState.attack1 => playerAttack1Sheet,
      PlayerState.attack2 => playerAttack2Sheet,
      PlayerState.hit ||
      PlayerState.damaged ||
      PlayerState.pulled ||
      PlayerState.attackAir ||
      PlayerState.death =>
        null,
    };

// ---------------------------------------------------------------------------
// Effects (assets/player/effects/particles/)
// ---------------------------------------------------------------------------

/// 6 frames of 64x32 in one row.
String playerDashTrailAssetPath(PlayerFacing facing) =>
    facing == PlayerFacing.west
        ? 'player/effects/particles/dash-trail-west.png'
        : 'player/effects/particles/dash-trail-east.png';
const int playerDashTrailFrameCount = 6;

/// 6 frames of 96x96 in one row. The burst is radially symmetric, so one
/// file serves both facings (the delivered `-west` twin is pixel-identical
/// in bounding box and is intentionally unused).
const String playerDoubleJumpBurstAssetPath =
    'player/effects/particles/double-jump-east.png';
const int playerDoubleJumpBurstFrameCount = 6;

/// 4 columns x 2 rows of 192x192: row 0 = golpe 1, row 1 = golpe 2.
String playerSlashArcAssetPath(PlayerFacing facing) =>
    facing == PlayerFacing.west
        ? 'player/effects/particles/sword-slash-arc.png'
        : 'player/effects/particles/sword-slash-arc-east.png';
const int playerSlashArcColumns = 4;
const int playerSlashArcRows = 2;
const double playerSlashArcFrameSize = 192;
