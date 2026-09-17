/// The linked_list phase's debug legend, rendered by the shared
/// `DebugHelpOverlay`. The keys themselves are handled in
/// `VagoneiroArenaGame.onKeyEvent`.
const List<String> linkedListDebugLegend = [
  'DEBUG — Vagoneiro (Módulos 0-15)',
  'J          espada (combo 2 golpes; só fere o boss na janela exposed)',
  'C          dash',
  'K          forçar o próximo ataque (RemoverNo / InserirNo)',
  'P          -3 HP no boss (pular para a próxima fase)',
  '0-7        occupySlot(index)',
  'Shift+0-7  clearSlot(index)',
  'Ctrl+0-7   RemoverNo (tremor -> falling -> clearSlot)',
  'H          boss.debugPlayHit()',
  'X          boss.debugPlayExposed()',
  'R          reset player position (onPlayerDeath)',
  'Espaço/W/↑ pular (2x — double jump, Mudança 3)',
  'M          toggle slot/boss position markers',
  'L          toggle fixed-height reference rulers (player/vagão/boss)',
];
