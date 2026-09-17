import '../../shared/phases/phase_definition.dart';
import 'linked_list_assets.dart';
import 'vagoneiro_arena_game.dart';

/// Fase 1 — Lista Encadeada (Boss: O Vagoneiro).
const PhaseDefinition linkedListPhase = PhaseDefinition(
  id: 'linked_list',
  title: 'Lista Encadeada',
  bossName: 'O Vagoneiro',
  assetRoot: linkedListAssetRoot,
  levelConfigPath: linkedListLevelConfigPath,
  createGame: VagoneiroArenaGame.new,
);
