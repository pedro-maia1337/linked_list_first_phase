# Estrutura do projeto e como adicionar uma fase

**DataQuest: Codex das Estruturas** tem uma fase por estrutura de dados (lista encadeada, pilha, fila, árvore, tabela hash, grafo…), cada uma com seu bioma e seu boss, todas acessíveis a partir de um hub central ("O Repositório"). Hoje só existe a fase **`linked_list`** (Boss Vagoneiro).

A regra que organiza tudo:

> **`shared/` nunca depende de uma fase.** Player, HUD, efeitos genéricos, física e debug são escritos uma vez só; cada fase *usa* essas peças e fornece o que é dela (boss, plataformas, layout, arte, números de dano).

A regra é verificada por teste (`test/shared/phase_structure_test.dart`): um `import` de `lib/phases/...` dentro de `lib/shared/` faz a suíte falhar.

---

## 1. Árvore

```
lib/
  main.dart                      # abre a primeira fase do registro (ainda não há hub)
  shared/                        # genérico — vale para todas as fases
    player/                      # Player (Módulo 15): movimento, pulo duplo, dash, espada
      player.dart                #   re-exporta os arquivos abaixo + PlayerPlatform
      player_animations.dart     #   estados e folhas west/east
      attack_controller.dart     #   combo de espada (lógica pura)
      dash_controller.dart       #   dash (lógica pura)
      player_fx.dart             #   rastro, burst, arco de corte
      sword_hitbox.dart
      player_combat_config.dart  #   HP, invulnerabilidade, stagger, dano da espada
    physics/
      player_platform.dart       # contrato: o que o player pode pisar
      arena_wall.dart            # parede sólida (cancela dash)
    hud/
      combat_hud.dart            # barra do boss + HP do player + ticker + legenda (parametrizado)
    fx/                          # câmera, sombra de contato, glow, parallax, curvas,
      ...                        # partículas genéricas (poeira), flash de combate
      fx_config.dart             # constantes visuais genéricas
    debug/                       # marcadores, régua de altura, legenda de teclas
    phases/
      phase_definition.dart      # CONTRATO de uma fase
      phase_game.dart            # classe-base do jogo de cada fase
    # hub/                       # reservado para "O Repositório" (ainda não existe)
  phases/
    phase_registry.dart          # lista de todas as fases
    linked_list/                 # uma pasta por fase; o nome da pasta é o id da fase
      linked_list_phase.dart     #   PhaseDefinition desta fase
      linked_list_assets.dart    #   raiz de assets + caminho do layout
      linked_list_debug_keys.dart#   legenda das teclas de debug desta fase
      vagoneiro_arena_game.dart  #   o PhaseGame da fase
      boss/  wagon/  track/  config/
      fx/                        #   efeitos só desta fase + linked_list_fx_config.dart

assets/
  shared/
    player/spritesheets/         # idle, walk, dash, jump_rise/fall, double_jump, attack1/2 (west/east)
    player/effects/particles/    # dash-trail, double-jump, sword-slash-arc
    effects/                     # contact-shadow, glow-warm-soft
    effects/particles/           # dust-poof
  phases/
    linked_list/
      background/  boss/  wagons/  tilesets/  effects/
      level/slots_config.json    # layout do nível (antes em docs/)

test/
  shared/                        # testes do que é compartilhado + da estrutura
  phases/linked_list/            # testes da fase (boss, cena, câmera, snapshot)

docs/
  ESTRUTURA.md                   # este guia
  phases/linked_list/            # documento de design da fase (Boss Vagoneiro)
```

### O que é compartilhado e o que é da fase

| Vai em `shared/` | Fica em `phases/<id>/` |
|---|---|
| Player e tudo o que ele usa (animação, dash, espada, efeitos próprios) | O boss, seus ataques, fases e regras de dano |
| HUD de combate (recebe nome, HP máximo, limiares e rótulo de fase do boss) | As plataformas (`Vagao` implementa `PlayerPlatform`) |
| Câmera, parallax, vinheta, sombra de contato, glow, partículas genéricas | Arte do bioma, parallax concreto (arquivos, fatores, cor do céu) |
| Parede, contrato de plataforma | Layout do nível e o seu parser |
| Ferramentas de debug (o componente de legenda) | O conteúdo da legenda e o tratamento das teclas |
| Contrato de fase (`PhaseDefinition`, `PhaseGame`) | A declaração da fase e seu registro |

Critério para decidir casos novos: se uma segunda fase precisaria da mesma coisa **sem mudar nada**, vai para `shared/`; se precisaria de outros valores, o código vai para `shared/` e os **valores** entram por parâmetro, vindos da fase (foi o que aconteceu com o HUD, o `SkyFill`/`ParallaxLayer` e a legenda de debug).

---

## 2. O contrato de uma fase

```dart
// lib/shared/phases/phase_definition.dart
class PhaseDefinition {
  final String id;              // 'linked_list' — nome da pasta em lib/phases e assets/phases
  final String title;           // 'Lista Encadeada'
  final String bossName;        // 'O Vagoneiro'
  final String assetRoot;       // 'phases/linked_list/' (relativo a Flame.images.prefix)
  final String levelConfigPath; // 'assets/phases/linked_list/level/slots_config.json'
  final PhaseGame Function() createGame;
}

// lib/shared/phases/phase_game.dart
abstract class PhaseGame extends FlameGame {
  PhaseDefinition get definition;
  Vector2 get spawnPoint;   // onde o player (re)nasce
  bool get isCompleted;     // condição de vitória (ex.: boss derrotado)
}
```

O spawn e a vitória ficam no `PhaseGame` porque dependem do nível já carregado.

O teste de estrutura confere, para toda fase registrada: `id` único; existência de `lib/phases/<id>/` e `assets/phases/<id>/`; `assetRoot == 'phases/<id>/'`; existência do arquivo de layout; o jogo criado devolvendo a própria definição; e a raiz de assets da fase listada no `pubspec.yaml`.

---

## 3. Passo a passo: adicionar uma fase (ex.: `stack`)

Nada em `lib/shared/` precisa mudar.

1. **Assets:** crie `assets/phases/stack/` com as subpastas que a fase usar (`background/`, `boss/`, `level/`, `effects/`…) e o arquivo de layout em `level/`.
2. **`pubspec.yaml`:** adicione um bloco `# Phase: stack` listando cada subpasta (o Flutter não inclui subpastas automaticamente).
3. **Código:** crie `lib/phases/stack/` com:
   - `stack_assets.dart` — `const stackAssetRoot = 'phases/stack/';` e o caminho do layout (`'assets/${stackAssetRoot}level/...'`). **Todo** caminho de asset da fase é montado a partir dessa raiz.
   - suas plataformas, implementando `PlayerPlatform` (`isSolid`, `platformTopY`);
   - o boss e as regras de dano da fase (o dano de cada perigo é da fase; o HP e a invulnerabilidade do player vêm de `shared/player/player_combat_config.dart`);
   - `stack_fx_config.dart` com as constantes visuais da fase;
   - `stack_debug_keys.dart` com a legenda de debug;
   - `stack_game.dart`, uma classe que **estende `PhaseGame`** e, no `onLoad`, monta a cena com as peças compartilhadas:
     - `Player(..., platformIndexOf: ..., onSupportLost: ..., onDeath: ..., onSwordContact: ...)` — a fase decide o que cada evento custa e o que a espada acerta;
     - `CombatHud(bossName: ..., bossMaxHp: ..., phaseThresholds: ..., phaseLabel: ...)`;
     - `CameraDirector`, `SkyFill(color: ...)`, `ParallaxLayer.load(..., skyFillColor: ...)`, `ArenaWall`, `DebugHelpOverlay(lines: ...)`;
     - `images.prefix = 'assets/'`, como na fase `linked_list`;
   - `stack_phase.dart` com `const stackPhase = PhaseDefinition(id: 'stack', ..., createGame: StackGame.new);`.
4. **Registro:** acrescente `stackPhase` em `lib/phases/phase_registry.dart`.
5. **Testes:** crie `test/phases/stack/`. O `phase_structure_test.dart` já passa a cobrir a fase nova automaticamente.
6. **Documentação:** crie `docs/phases/stack/` com o documento de design da fase.

Enquanto não existir o hub, o `main.dart` abre `phaseRegistry.first`. Para testar a fase nova no app, mude temporariamente a ordem do registro ou use `phaseById('stack')`.

---

## 4. Limitações conhecidas (decisões desta reorganização)

- **Cada fase ainda é o seu próprio `FlameGame`.** Não há um game loop único que carregue fases como `World`. Foi uma escolha deliberada para não mexer no ciclo de vida nem nos testes nesta refatoração. O `PhaseGame` é o ponto de extensão para essa migração.
- **O hub ("O Repositório") não existe.** O registro de fases é o que ele vai listar.
- **Alguns nomes no Player ainda lembram a fase 1:** `currentSlotIndex` (índice lógico da plataforma, calculado pela fase via `platformIndexOf`) e `shoveToSlot` (movimento roteirizado genérico). O comportamento é genérico; os nomes foram mantidos para não quebrar os testes existentes.
- **`test/shared/player_upgrade_test.dart` sobe o jogo da fase `linked_list`**, porque é a única cena existente para exercitar o Player.
- **A tonalidade fria (`applyAmbientCoolTint`) é da fase `linked_list`:** a cor foi amostrada da caverna gótica. Uma fase nova define a própria paleta.
- **Assets sem uso no código continuam na pasta da fase** e não foram apagados: `boss/soco.png`, `boss/transicao.png`, `effects/ciclo-corrompido.png`, `effects/corrente-restritiva.png`, `wagons/decorative/no-orfao.png`, `tilesets/*`. O `double-jump-west.png` compartilhado também não é usado.
- **Referências antigas no documento de design da fase:** caminhos como `lib/game/...` em `docs/phases/linked_list/boss-vagoneiro-design.md` descrevem o estado de cada módulo quando foi entregue. O mapa para os caminhos novos está no fim daquele documento.
