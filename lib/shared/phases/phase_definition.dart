import 'phase_game.dart';

/// The contract every phase declares (see `docs/ESTRUTURA.md`).
///
/// One constant per phase, collected in `lib/phases/phase_registry.dart`.
/// The spawn point and victory condition are answered by the phase's
/// [PhaseGame], since both depend on the loaded level.
class PhaseDefinition {
  /// Stable identifier — also the phase's folder name under `lib/phases/`
  /// and `assets/phases/`, and the key a future hub/save file will use.
  final String id;

  /// Name of the data structure the phase teaches, as shown to the player.
  final String title;

  /// The phase's boss.
  final String bossName;

  /// Root of the phase's assets relative to `Flame.images.prefix`
  /// (`'phases/<id>/'`).
  final String assetRoot;

  /// Asset-bundle key of the phase's level layout file.
  final String levelConfigPath;

  /// Builds a fresh game for this phase.
  final PhaseGame Function() createGame;

  const PhaseDefinition({
    required this.id,
    required this.title,
    required this.bossName,
    required this.assetRoot,
    required this.levelConfigPath,
    required this.createGame,
  });
}
