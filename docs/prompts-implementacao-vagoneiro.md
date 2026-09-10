# Prompts de Implementação — Boss "O Vagoneiro" (modularizado)

**Como usar este documento:** cada módulo abaixo é um prompt **independente e testável**, pensado para ser enviado, um de cada vez, a um agente de implementação (ex.: Claude Code). Não avance para o próximo módulo antes de validar o "Critério de teste" do módulo atual — cada prompt já assume que os módulos anteriores estão prontos e funcionando.

**Arquivos de referência que devem ser anexados/citados em todos os prompts:**
- `boss-vagoneiro-design.md` — documento de design (versão com slots fixos)
- `slots_config.json` — coordenadas exportadas do motor gráfico (posições de slots, boss, death zone, âncoras decorativas)
- `caverna-gotica-pixelart.png` — background da arena
- `flutter_flame_gamedev_skill.md` — skill de implementação Flutter+Flame; **todos os prompts abaixo devem ser executados seguindo essa skill** (validar escopo antes de codar, tratar o `.md` de design como fonte de verdade, respeitar o modelo de slots fixos da seção 11.1, não reimplementar colisão — seção 12.1)

> ⚠️ **Instrução obrigatória para o agente — validar antes de cada prompt:** antes de iniciar QUALQUER módulo abaixo, o agente deve validar que os 4 arquivos de referência (`boss-vagoneiro-design.md`, `slots_config.json`, `caverna-gotica-pixelart.png`, `flutter_flame_gamedev_skill.md`) estão presentes, legíveis e íntegros, e que o conteúdo citado no prompt (seções do `.md`, campos do JSON, seções da skill) realmente existe neles. Se algum arquivo estiver ausente, corrompido, ilegível ou divergente do que o prompt descreve (ex.: seção citada não existe, campo ausente no JSON, imagem não abre), **o agente deve parar e reportar o problema antes de escrever qualquer código**, em vez de assumir valores ou seguir adiante.

**Stack:** Flutter + Flame. **Premissa importante que deve constar em todos os prompts:** o motor gráfico usado no projeto já resolve colisão a partir de coordenadas — os prompts abaixo pedem para **posicionar** colliders nos pontos do JSON, não para implementar um sistema de colisão do zero.

**Estrutura de diretórios (definida na skill, seção 10 — manter em todos os módulos):**

```text
lib/
  game/
    boss/
      vagoneiro_boss.dart
      vagoneiro_animations.dart
    wagon/
      vagao.dart
      vagao_animations.dart
    player/
      player.dart
      player_animations.dart
    track/
      circular_track.dart      # carrega e expõe a lista encadeada de Slot
      slot.dart                 # posição fixa + next/prev + Vagao? opcional
    components/
    effects/
    config/
      arena_config.dart         # lê e tipa o slots_config.json
```

---

## Módulo 0 — Setup do projeto e carregamento de configuração

**Objetivo:** ter a arena carregando o background e o `slots_config.json`, sem nenhuma entidade de gameplay ainda.

**Escopo:**
- Carregar `caverna-gotica-pixelart.png` como camada de fundo, respeitando as dimensões do JSON (`canvas.width`/`canvas.height`).
- Criar `lib/game/config/arena_config.dart`: um serviço/loader que lê `slots_config.json` no `onLoad` da arena e expõe os dados tipados (ex.: classe `ArenaConfig` com `track`, `slots`, `boss`, `deathZone`, `decorativeAnchors`), seguindo a checklist de validação de config JSON da skill (seção 9).
- Não instanciar Boss, vagões ou player ainda — apenas validar que a configuração é lida corretamente (ex.: um `print`/log listando os 8 slots).

**Fora de escopo:** qualquer entidade visual além do background.

**Critério de teste:** rodar o jogo e confirmar via log/debug que os 8 slots, a posição do boss e o `deathZone.y` foram carregados com os valores exatos do JSON.

> ### Prompt pronto
> ```
> Contexto: projeto Flutter + Flame de um jogo educativo de estruturas de dados.
> Anexos: boss-vagoneiro-design.md, slots_config.json, caverna-gotica-pixelart.png,
> flutter_flame_gamedev_skill.md.
>
> Validação prévia obrigatória: confirme que os 4 arquivos acima estão
> presentes e legíveis, que caverna-gotica-pixelart.png abre corretamente,
> que slots_config.json é um JSON válido contendo canvas.width/height, 8
> slots, boss e deathZone, e que a seção 9 da skill (checklist de config)
> existe. Se algo faltar ou divergir, pare e reporte antes de codar.
>
> Siga a skill flutter_flame_gamedev_skill.md (validar escopo antes de codar,
> respeitar a arquitetura de diretórios da seção 10, tratar o slots_config.json
> como fonte de verdade das coordenadas — seção 9).
>
> Tarefa: crie a arena inicial do boss "O Vagoneiro":
> 1. Carregue caverna-gotica-pixelart.png como background, usando exatamente as
>    dimensões de canvas.width/canvas.height do slots_config.json.
> 2. Crie lib/game/config/arena_config.dart: um loader/serviço que lê
>    slots_config.json no onLoad e expõe os dados tipados (track, slots[],
>    boss, deathZone, decorativeAnchors) para o resto do jogo consumir.
> 3. Não instancie boss, vagões ou player ainda — apenas valide via log que os
>    8 slots, a posição do boss e o deathZone.y foram lidos corretamente.
>
> Não implemente nada além disso. Ao final, rode o jogo e mostre no console os
> valores carregados para eu conferir contra o JSON original.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] O jogo roda sem erros e exibe caverna-gotica-pixelart.png como fundo.
> - [ ] As dimensões do background batem exatamente com canvas.width/height do JSON.
> - [ ] O log/console mostra os 8 slots com coordenadas idênticas ao slots_config.json.
> - [ ] O log mostra a posição do boss e o deathZone.y com os valores exatos do JSON.
> - [ ] Nenhuma entidade de gameplay (boss, vagão, player) foi instanciada.
> ```

---

## Módulo 1 — Estrutura de dados dos Slots (lista encadeada) + Boss estático

**Objetivo:** ter o `VagoneiroBoss` instanciado na posição fixa do JSON, controlando uma lista encadeada real de slots (seção 2 e 3.0 do `.md`).

**Escopo:**
- Implementar `Slot` em `lib/game/track/slot.dart` (posição `x`/`y`, referências `next`/`prev`, e um `Vagao?` opcional) e montar a lista encadeada circular em `lib/game/track/circular_track.dart`, a partir de `slots_config.json` (8 nós, fechando o ciclo) — seguindo o modelo da skill, seção 11.1 (a lista vive nos `Slot`, não nos `Vagao`).
- Instanciar `VagoneiroBoss` (`lib/game/boss/vagoneiro_boss.dart`) na posição `boss.x`/`boss.y` do JSON, com `facing: left`, exibindo a animação `idle` (única obrigatória nesta etapa — seção 4.1 do `.md`).
- Expor no Boss os métodos públicos (ainda sem uso real): `occupySlot(int index, {VagaoState estadoInicial})` e `clearSlot(int index)` — podem lançar `UnimplementedError` por enquanto ou apenas logar, serão implementados no Módulo 2.

**Fora de escopo:** vagões visuais, player, qualquer ataque.

**Critério de teste:** o Boss aparece parado na arena, na posição correta, tocando `idle` em loop. Um teste/debug simples percorrendo `slot.next` a partir do slot 0 deve retornar aos 8 índices em ordem e voltar ao slot 0 (prova de que a lista está circular e correta).

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 0 (arena + config carregada).
> Anexos: boss-vagoneiro-design.md (seções 2, 3.0 e 4.1), slots_config.json,
> flutter_flame_gamedev_skill.md (seções 10 e 11.1).
>
> Validação prévia obrigatória: confirme que boss-vagoneiro-design.md contém
> de fato as seções 2, 3.0 e 4.1, que a skill contém as seções 10 e 11.1, e
> que slots_config.json possui os 8 slots e a posição do boss. Confirme
> também que os artefatos do Módulo 0 (arena_config.dart, background) estão
> presentes e funcionando. Se algo faltar, pare e reporte antes de codar.
>
> Siga a arquitetura de diretórios e o modelo de lista encadeada por Slot
> definidos na skill — a lista next/prev vive no Slot, não no Vagao.
>
> Tarefa:
> 1. Implemente lib/game/track/slot.dart (x, y, next, prev, Vagao? vagao) e
>    monte em lib/game/track/circular_track.dart, a partir de
>    slots_config.json, uma lista encadeada CIRCULAR de 8 slots (o next do
>    último slot deve apontar para o slot 0).
> 2. Em lib/game/boss/vagoneiro_boss.dart, instancie VagoneiroBoss na posição
>    boss.x/boss.y do JSON, virado para a esquerda, tocando a animação idle
>    (fileira 1 do spritesheet, seção 4.1) em loop contínuo.
> 3. Adicione em VagoneiroBoss os métodos públicos occupySlot(index, estado) e
>    clearSlot(index) apenas como stubs (podem logar "TODO" por enquanto).
>
> Não implemente vagões visuais, player ou ataques ainda.
>
> Teste de validação a entregar: uma função de debug que percorre slot.next a
> partir do slot 0 e imprime a sequência de índices, provando que após 8 passos
> voltamos ao slot 0.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] O Boss aparece parado na posição exata de boss.x/boss.y do JSON.
> - [ ] O Boss está virado para a esquerda e toca a animação idle em loop, sem travar.
> - [ ] A lista de slots é circular: partindo do slot 0 e seguindo next 8 vezes, retorna ao slot 0.
> - [ ] occupySlot e clearSlot existem como métodos públicos (mesmo como stub/TODO).
> - [ ] Nenhum vagão visual ou player foi implementado.
> ```

---

## Módulo 2 — Inserção e remoção de vagões (occupySlot / clearSlot)

**Objetivo:** vagões realmente aparecendo/desaparecendo nos slots, sem nenhuma movimentação livre pela curva (seção 3 do `.md`).

**Escopo:**
- Implementar de fato `occupySlot(index, estado)`: instancia um `Vagao` na posição fixa daquele slot, tocando `spawning` (fade-in/pop simples) e transicionando para `idle`.
- Implementar `clearSlot(index)`: remove o `Vagao` do slot (nesta etapa, remoção instantânea ou fade-out simples — a sequência completa `tremor → falling → removed` fica para o Módulo 5). **Importante (skill, seção 11.1):** `clearSlot` só deve zerar o campo `vagao` do `Slot` — o `Slot` em si e seus `next`/`prev` permanecem intactos na lista.
- Vagão inicial: no `onLoad` da arena, chamar `boss.occupySlot(0)` automaticamente (substitui a antiga "caminhada até o boss" — seção 3.1).
- Usar os assets de `wagons/states/` conforme mapeamento da seção 8.1 do `.md`.

**Fora de escopo:** collider de plataforma (Módulo 4), qualquer estado de queda (Módulo 5), player.

**Critério de teste:** ao rodar o jogo, um vagão aparece automaticamente no slot 0 (junto ao boss) com uma transição visual de entrada. Um método de debug deve permitir chamar `occupySlot`/`clearSlot` em qualquer um dos 8 índices em tempo real (ex.: teclas 0–7 para ocupar, Shift+0–7 para limpar) para validar visualmente que cada slot aparece na posição correta do trilho.

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 1 (lista de slots + boss idle prontos).
> Anexos: boss-vagoneiro-design.md (seções 3, 4.3 e 8.1), slots_config.json.
>
> Validação prévia obrigatória: confirme que as seções 3, 4.3 e 8.1 do
> design existem e descrevem os assets de wagons/states/ citados, que
> slots_config.json continua consistente com o Módulo 1, e que a lista
> circular e o boss idle do Módulo 1 estão funcionando. Pare e reporte
> qualquer divergência antes de codar.
>
> Tarefa:
> 1. Implemente occupySlot(index, estado) de verdade: instancia um Vagao na
>    posição fixa daquele slot (sem nenhum deslocamento/tween de posição),
>    tocando a transição spawning (fade-in ou pop de escala) e terminando em
>    idle (asset vagao-normal.png).
> 2. Implemente clearSlot(index): remove o Vagao do slot (remoção simples por
>    enquanto — a sequência tremor/falling/removed vem em outro módulo).
> 3. No onLoad da arena, chame boss.occupySlot(0) automaticamente para simular
>    o vagão inicial nascendo junto ao boss.
> 4. Adicione um método de debug acionável por teclado (teclas 0-7 para ocupar
>    aquele slot, Shift+0-7 para limpar) para eu testar manualmente cada slot.
>
> Não implemente collider de plataforma, queda de vagão nem player ainda.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] Ao rodar o jogo, um vagão aparece automaticamente no slot 0 com transição de spawning visível.
> - [ ] occupySlot(index) funciona para qualquer um dos 8 índices via debug (teclas 0-7).
> - [ ] clearSlot(index) remove o vagão do slot correspondente via debug (Shift+0-7).
> - [ ] Cada vagão aparece na posição fixa exata do slot, sem deslocamento/tween.
> - [ ] Nenhum collider de plataforma, queda ou player foi implementado.
> ```

---

## Módulo 3 — Movimentação do Player pela arena (sem colisão com vagões ainda)

**Objetivo:** player andando livremente pela arena com os spritesheets de caminhada, isolado de qualquer lógica de vagão/colisão de plataforma (seção 4.2 do `.md`).

**Escopo:**
- Implementar `Player` com movimentação horizontal usando `player/spritesheets/direita.png` e `esquerda.png`.
- Atenção à inconsistência de resolução entre os dois spritesheets (128x128 vs 256x256 — seção 8.2 do `.md`): carregar cada um com seu próprio `frameSize`, sem assumir tamanho único.
- Sem animação de `idle`/`hit` (fora de escopo, confirmado no `.md`).
- Posição inicial do player: um ponto fixo qualquer da arena (ex.: perto do slot 0), apenas para testes — ainda sem gravidade nem colisão com o chão/vagões.

**Fora de escopo:** física de pulo, colisão com vagões, morte por queda (todos vêm nos módulos seguintes).

**Critério de teste:** player se move para a esquerda/direita pela tela com a animação de caminhada correta em cada direção, sem cortes/distorção de sprite (validando a correção do `frameSize` duplo).

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 2 (vagões aparecem/somem nos slots via debug).
> Anexos: boss-vagoneiro-design.md (seções 4.2 e 8.2).
>
> Validação prévia obrigatória: confirme que as seções 4.2 e 8.2 do design
> existem e que a inconsistência de resolução entre direita.png (128x128) e
> esquerda.png (256x256) está de fato documentada nelas. Confirme que os
> spritesheets do player estão presentes no projeto. Pare e reporte antes de
> codar se algo divergir.
>
> Tarefa:
> 1. Implemente o componente Player com movimentação horizontal (input de
>    teclado, ex. setas ou A/D) usando player/spritesheets/direita.png e
>    esquerda.png.
> 2. ATENÇÃO: direita.png tem frames de 128x128 e esquerda.png tem frames de
>    256x256 (resolução inconsistente, ainda não corrigida pelo time de arte).
>    Carregue cada spritesheet com seu próprio frameSize — não assuma um valor
>    único para os dois. Deixe um comentário // TODO: alinhar resolução com
>    direita.png quando o asset for corrigido.
> 3. Não implemente idle nem hit (fora de escopo). Apenas caminhada.
> 4. Posicione o player em um ponto fixo qualquer da arena para teste. Sem
>    gravidade, sem colisão com vagões ainda — isso vem depois.
>
> Critério de teste: o player deve andar para os dois lados com a animação de
> caminhada correta, sem distorção/corte de sprite em nenhuma das direções.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] O player se move para a esquerda e para a direita via input de teclado.
> - [ ] direita.png é carregado com frameSize 128x128 e esquerda.png com 256x256, cada um independente.
> - [ ] Não há distorção nem corte de sprite em nenhuma das duas direções.
> - [ ] Nenhuma animação idle/hit foi implementada.
> - [ ] Não há gravidade, colisão com vagões ou lógica de queda ainda.
> ```

---

## Módulo 4 — Física de pulo + colisão de plataforma com os vagões

**Objetivo:** player pulando e pousando sobre os vagões, usando os colliders posicionados a partir do `slots_config.json` (seção 9 do `.md`; seção 12.1 da skill — colisão delegada ao motor gráfico, o código apenas posiciona).

**Escopo:**
- Adicionar gravidade e input de pulo ao `Player` (sem animação dedicada — reaproveitar frame de caminhada/parado como placeholder, seção 9.3).
- Cada `Vagao` expõe um collider sólido no topo, com **tamanho lógico fixo** (independente do bounding box variável da arte — seção 9.1), posicionado uma única vez na coordenada do slot (sem necessidade de atualização por frame, já que os vagões não se movem mais).
- Tabela de solidez por estado (seção 9.2 do `.md`): `spawning`/`idle`/`tremor` são sólidos; `falling`/vazio não são (o estado `falling` só existe a partir do Módulo 5, mas já deixe o gancho pronto: `Vagao.isSolid` como getter que os módulos futuros podem alterar).

**Fora de escopo:** sequência de queda do vagão (Módulo 5), morte do player (Módulo 5).

**Critério de teste:** usando o debug de teclado do Módulo 2 para ocupar 2–3 slots diferentes, o player deve conseguir pular de um vagão para o outro e pousar corretamente em cada um, sem atravessar o collider nem "flutuar" acima/abaixo da superfície esperada.

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 3 (player caminha, sem colisão ainda).
> Anexos: boss-vagoneiro-design.md (seção 9), slots_config.json.
>
> Validação prévia obrigatória: confirme que a seção 9 do design (tamanho
> lógico do collider e tabela de solidez por estado) existe, que
> slots_config.json continua consistente, e que o Player do Módulo 3 e os
> vagões do Módulo 2 estão funcionando. Pare e reporte antes de codar se algo
> divergir.
>
> Tarefa:
> 1. Adicione gravidade e pulo ao Player (sem animação dedicada — reaproveite
>    o frame de caminhada ou parado durante o salto).
> 2. Em Vagao, exponha um collider sólido no topo com tamanho lógico FIXO
>    (não usar o bounding box da imagem, que varia entre vagao-normal.png,
>    vagao-marcado.png etc.). Posicione esse collider uma única vez, na
>    coordenada do slot em que o vagão existe — sem recalcular por frame.
> 3. Implemente Vagao.isSolid como getter (true para spawning/idle/tremor,
>    false para qualquer outro caso) para os módulos futuros usarem.
> 4. Use o motor gráfico do projeto para resolver a colisão em si — meu
>    trabalho aqui é só posicionar os colliders corretamente, não reimplementar
>    detecção de colisão.
>
> Critério de teste: usando o debug de teclado do módulo anterior para ocupar
> 2-3 slots, eu devo conseguir pular de um vagão para o outro e pousar de forma
> estável em cada um.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] O player pula com gravidade aplicada, usando placeholder visual (sem animação dedicada).
> - [ ] O player pousa de forma estável sobre vagões em 2-3 slots diferentes, sem atravessar nem flutuar.
> - [ ] O collider do vagão tem tamanho lógico fixo, independente do bounding box da arte.
> - [ ] Vagao.isSolid retorna true para spawning/idle/tremor e false para os demais estados.
> - [ ] A colisão é resolvida pelo motor gráfico do projeto, não reimplementada do zero.
> ```

---

## Módulo 5 — Ataque de teste: Vagão-Fantasma (tremor → falling → removed) + morte do player

**Objetivo:** primeiro ataque completo, isolado e disparável via debug, incluindo a morte do player por erro de plataforma (seções 4.3, 5 e 10 do `.md`).

**Escopo:**
- Implementar a sequência de estados do vagão: `tremor` (~1.2s, telegraph) → `falling` (animação de queda) → `boss.clearSlot(index)` ao final.
- Ao entrar em `falling`, o vagão deixa de ser sólido (`isSolid == false`) imediatamente — se o player estiver em cima, deve perder o suporte e cair junto.
- Implementar `onPlayerDeath()` como hook chamado quando: (a) o player perde suporte sobre um vagão em `falling`; (b) o player cai no buraco de um slot vazio; (c) o player ultrapassa o `deathZone.y` do JSON. Nesta etapa, o hook pode só logar/reiniciar a posição do player (o sistema real de respawn/game over vem depois).
- Método de debug: `boss.debugTriggerVagaoFantasma(index)` disparando a sequência completa em qualquer slot ocupado.

**Fora de escopo:** dano de combate, HP, qualquer outro ataque da seção 7.

**Critério de teste (o primeiro ataque "de verdade" jogável):**
1. Ocupar um slot, ficar em cima dele e disparar `debugTriggerVagaoFantasma` — o player deve tremer visualmente (telegraph), depois cair junto com o vagão, e `onPlayerDeath()` deve dispersar.
2. Ocupar um slot, pular para o slot vizinho vazio (buraco) — o player deve cair e `onPlayerDeath()` deve disparar.
3. Andar/pular para fora dos limites verticais (`deathZone.y`) — mesmo resultado.

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 4 (pulo e colisão com vagões funcionando).
> Anexos: boss-vagoneiro-design.md (seções 4.3, 5 e 10), slots_config.json.
>
> Validação prévia obrigatória: confirme que as seções 4.3, 5 e 10 do design
> existem e descrevem a sequência tremor/falling/removed e o deathZone.y, que
> slots_config.json contém deathZone.y, e que o Módulo 4 (pulo + colisão)
> está funcionando. Pare e reporte antes de codar se algo divergir.
>
> Tarefa:
> 1. Implemente a sequência de estados do vagão: tremor (~1.2s, usando
>    vagao-marcado.png) -> falling (vagao-rompido2 -> vagao-rompido ->
>    vagao-caindo -> vagao-caindo3, ou o spritesheet combinado
>    vagao-soltar-cair.png) -> ao final, chame boss.clearSlot(index).
> 2. No instante em que o vagão entra em falling, Vagao.isSolid deve virar
>    false imediatamente. Se o player estiver sobre o vagão nesse momento, ele
>    deve perder o suporte e cair também.
> 3. Implemente o hook onPlayerDeath(), chamado quando: o player cai porque o
>    vagão embaixo virou falling; o player cai no buraco de um slot vazio; ou
>    o player ultrapassa deathZone.y do slots_config.json. Por enquanto o hook
>    pode só logar e resetar a posição do player.
> 4. Adicione boss.debugTriggerVagaoFantasma(index) para disparar essa
>    sequência completa em qualquer slot ocupado, via tecla de debug.
>
> Critérios de teste que preciso conseguir validar manualmente:
> a) ficar em cima de um vagão e disparar o debug -> tremor visível, depois
>    queda do player junto com o vagão, onPlayerDeath disparado;
> b) pular para o buraco de um slot vazio -> onPlayerDeath disparado;
> c) sair da arena verticalmente -> onPlayerDeath disparado.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] debugTriggerVagaoFantasma(index) dispara tremor (~1.2s) -> falling -> boss.clearSlot(index), nessa ordem.
> - [ ] Vagao.isSolid vira false no instante em que entra em falling.
> - [ ] Player em cima de um vagão que vira falling perde suporte e cai junto.
> - [ ] onPlayerDeath() dispara nos 3 casos: vagão falling, buraco de slot vazio, e deathZone.y ultrapassado.
> - [ ] Nenhum dano de combate, HP ou outro ataque foi implementado.
> ```

---

## Módulo 6 — Estados isolados do Boss (hit / stunned / exposed / recovering)

**Objetivo:** deixar prontas e testáveis as animações de combate do Boss, sem nenhuma lógica de dano real acionando-as (seção 4.1 do `.md`).

**Escopo:**
- Implementar os estados `hit`/`stunned` (fileira 3) e `exposed`/`recovering` (fileira 4) do spritesheet do Boss.
- Métodos de debug isolados: `boss.debugPlayHit()`, `boss.debugPlayExposed()` — cada um toca a animação correspondente e retorna a `idle` ao final (sem afetar HP, sem hitbox de combate).
- Opcional/reservado (não obrigatório): mapear `observing` e `chainAttack` no enum `BossState`, sem uso ainda.

**Fora de escopo:** qualquer lógica que decida quando o boss deve ficar `hit`/`exposed` de verdade (isso é combate, fora de escopo do documento inteiro por enquanto).

**Critério de teste:** acionar `debugPlayHit()` e `debugPlayExposed()` via teclado e confirmar visualmente que o boss reproduz a animação certa e volta ao `idle` sozinho ao final, sem travar em nenhum frame.

> ### Prompt pronto
> ```
> Contexto: continuando o Módulo 5 (primeiro ataque completo e morte do player
> funcionando).
> Anexos: boss-vagoneiro-design.md (seção 4.1).
>
> Validação prévia obrigatória: confirme que a seção 4.1 do design descreve
> de fato as fileiras 3 (hit/stunned) e 4 (exposed/recovering) do spritesheet
> do boss, e que os Módulos 1-5 (boss idle, vagões, player, morte) estão
> funcionando. Pare e reporte antes de codar se algo divergir.
>
> Tarefa:
> 1. Implemente os estados hit/stunned (fileira 3 do spritesheet do boss, 4
>    frames) e exposed/recovering (fileira 4, frames 1-3 e 4-6) como animações
>    isoladas e testáveis.
> 2. Adicione boss.debugPlayHit() e boss.debugPlayExposed(), cada uma tocando
>    a animação correspondente e retornando sozinha ao idle ao final.
> 3. Não implemente nenhuma lógica que decida QUANDO essas animações devem
>    tocar de verdade (isso é combate, fora de escopo).
>
> Critério de teste: acionar as duas funções de debug via teclado e ver o boss
> reproduzir cada animação corretamente, voltando ao idle sozinho no final.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] debugPlayHit() toca a animação da fileira 3 (hit/stunned) e retorna ao idle sozinho.
> - [ ] debugPlayExposed() toca a animação da fileira 4 (exposed/recovering) e retorna ao idle sozinho.
> - [ ] Nenhuma animação trava em um frame ao final da sequência.
> - [ ] Nenhuma lógica de dano/HP/combate real decide quando essas animações tocam.
> ```

---

## Módulo 7 — Harness de debug consolidado

**Objetivo:** um painel/atalho único que reúne todos os gatilhos de debug dos módulos anteriores, para facilitar QA contínuo enquanto os próximos ataques (seção 7 do `.md`) forem implementados no futuro.

**Escopo:**
- Tela ou overlay simples (pode ser texto na tela, não precisa de UI polida) listando os atalhos disponíveis: ocupar/limpar slot (0–7), disparar Vagão-Fantasma em um slot, tocar `hit`/`exposed` do boss, resetar player.
- Nenhuma lógica nova — é só consolidar o que já existe em um único lugar de fácil acesso para os próximos agentes/testers.

**Critério de teste:** todos os critérios de aceite da seção 11 do `.md` devem poder ser validados manualmente a partir desse harness, sem precisar editar código para testar cada peça.

> ### Prompt pronto
> ```
> Contexto: todos os módulos anteriores (0-6) já implementados e testados
> individualmente.
> Validação prévia obrigatória: confirme que boss-vagoneiro-design.md,
> slots_config.json, caverna-gotica-pixelart.png e
> flutter_flame_gamedev_skill.md continuam presentes e consistentes com a
> implementação atual, que a seção 11 do design (critérios de aceite) existe,
> e que todos os gatilhos de debug dos Módulos 0-6 estão funcionando antes de
> consolidá-los. Pare e reporte antes de codar se algo divergir.
>
> Anexos: boss-vagoneiro-design.md (seção 11 - critérios de aceite).
>
> Tarefa: crie um overlay simples de debug (texto na tela é suficiente, não
> precisa de UI polida) consolidando todos os atalhos já existentes:
> - ocupar/limpar qualquer slot (0-7)
> - disparar a sequência Vagão-Fantasma em um slot ocupado
> - tocar debugPlayHit() e debugPlayExposed() do boss
> - resetar a posição do player
>
> Não crie nenhuma lógica nova de gameplay — apenas organize os gatilhos que já
> existem num único lugar acessível, para eu conseguir validar manualmente
> todos os critérios de aceite da seção 11 do documento de design sem precisar
> mexer em código.
>
> Critérios de aceite (todos devem ser satisfeitos):
> - [ ] O overlay lista todos os atalhos: ocupar/limpar slot (0-7), disparar Vagão-Fantasma, hit/exposed do boss, resetar player.
> - [ ] Cada atalho listado funciona de fato ao ser acionado.
> - [ ] É possível validar manualmente todos os critérios da seção 11 do `.md` sem editar código.
> - [ ] Nenhuma lógica nova de gameplay foi criada — só consolidação dos gatilhos existentes.
> ```

---

## Ordem recomendada e dependências

```
Módulo 0 (setup/config)
   └─ Módulo 1 (slots + boss idle)
         └─ Módulo 2 (occupySlot/clearSlot)
               ├─ Módulo 3 (player caminhando, independente dos vagões)
               │     └─ Módulo 4 (pulo + colisão com vagões)
               │           └─ Módulo 5 (Vagão-Fantasma + morte do player)
               └─ Módulo 6 (estados do boss — pode rodar em paralelo ao 3/4/5)
                     └─ Módulo 7 (harness de debug consolidado)
```

Os Módulos 3 e 6 podem ser feitos em paralelo por agentes/desenvolvedores diferentes, já que um mexe em player+colisão e o outro só em animação do boss — nenhum dos dois depende do outro, só ambos dependem do Módulo 2 (vagões existindo nos slots).
