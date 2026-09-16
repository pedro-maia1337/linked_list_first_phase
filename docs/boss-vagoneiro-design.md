# Boss: O Vagoneiro (Lista Encadeada) — Documento de Design Técnico

**Stack:** Flutter + Flame
**Destinatário:** Agente responsável pela implementação do Boss, das animações do Boss, dos Vagões, do Player e da apresentação visual da arena.
**Etapa atual:** estrutura, movimentação, animações, escala relativa, polish visual e integração de cena **já implementados e validados** (Módulos 0–13, ver log abaixo). **Fase concluída agora: combate real** — o Boss ganhou doca própria, arte caricata, HP/fases e os seis ataques da lista encadeada (Módulo 14, ver seção 14).

---

## Log de Implementação

> Histórico resumido do que já foi entregue e validado, na ordem em que aconteceu. Detalhes técnicos de cada item estão nas seções correspondentes do documento — este log é só o "changelog".

- ✅ **Módulos 0–7** — Boss (`VagoneiroBoss`) controlando slots fixos no trilho linear; vagões com máquina de estados completa (`spawning → idle → tremor → falling → removed`); Vagão-Fantasma disparável isoladamente; player caminhando/pulando/morrendo por queda; harness de debug (`DEBUG — Vagoneiro`) consolidado. Ver seções 2–4, 9 e 10.
- ✅ **Módulo 8 — Upgrade do asset do player.** Os spritesheets antigos (`direita.png` 128x128 / `esquerda.png` 256x256, resoluções inconsistentes) foram **substituídos** por 4 spritesheets uniformes de 4 direções: `west.png`, `east.png`, `north.png`, `south.png` (2048x256 cada, 8 frames de 256x256). `West`/`East` são as únicas usadas ativamente na movimentação horizontal; `North`/`South` estão carregadas e testáveis via debug, mas reservadas (sem mecânica de movimento vertical). Ver seções 4.2 e 8.
- ✅ **Correção de animação do player.** Bug identificado e corrigido: o player tocava o ciclo de `walk` em loop mesmo parado (inclusive no ápice do pulo). Não existe asset de `idle` nesta etapa — a correção foi congelar num frame estático de `walk` quando a velocidade horizontal é zero, retomando a animação ao voltar a se mover. Ver seção 4.2.
- ✅ **Módulo 10 — Harmonização de escala.** Calibração numérica da altura relativa entre player, vagão e boss (antes só havia descrição qualitativa "boss deve parecer maior"), com recálculo de colliders/ancoragem a partir do bounding box real de cada asset. Ver seção 2.3.
- ✅ **Módulo 13 — Integração da cena.** Vagões e Boss estavam lidos como adesivos sobre o parallax: nenhuma luz do fundo os afetava e o Boss carregava um contorno dourado uniforme. Entregue: sombra de contato ancorada na base visível do vagão, tonalidade fria compartilhada sobre vagões/Boss/correntes, glow quente nos vagões próximos de lanternas, rim light do Boss corrigido de contorno para luz direcional, troca dos assets de vagão pelo set regenerado de 15 frames (com registro por frame), e âncoras de parede fechando as duas pontas do trilho. Ver seção 13.
- ✅ **Módulo 14 — Doca do Boss, arte caricata e combate jogável.** Três frentes: (1) o Boss ganhou uma peça de cenário própria (`boss/doca.png`) com sombra de contato e tonalidade fria, encerrando a leitura de "colado no fundo" que o Módulo 13 já tinha resolvido para os vagões; (2) o `sprite.png` humanoide sombrio foi substituído pelo maquinista caricato (grade 6x4 de 300px agora, mapeamento de estados da seção 4.1 preservado célula a célula); (3) a fase virou jogável de verdade — HP e fases do Boss, janela `exposed`/invulnerabilidade, os seis ataques da lista encadeada e o HUD de operação em execução. Ver seção 14.
- ✅ **Módulo 15 — Upgrade do Player.** Quatro frentes: (1) `idle` real substituindo o congelamento do frame 0 de `walk`, e o pulo separado em `jumpRise`/`jumpFall`/`doubleJump`, com as folhas `west`/`east` novas carregadas e a calibração de 110px refeita contra a arte regenerada (referência passou a ser `idle` frame 0, com normalização de escala por folha); (2) dash em botão próprio (`C`), 2.1x a altura do player, cooldown de 0.6s, cancelável por parede/queda, com rastro; (3) duplo salto com animação granular, burst nos pés e queda 1.2x mais pesada sem mexer no ápice de ≈145px; (4) combo de espada de 2 golpes em `J` com hitbox real só nos frames de pico, arco de corte e dano pelo mesmo `boss.takeDamage()`. `north`/`south` saíram do projeto. Corrigido também o sinal do offset do pé do player. Ver seção 15.
- ✅ **Módulo 9 — Polish visual e juice.** Parallax de fundo (`layer-far.png`/`layer-mid.png`), iluminação funcional (lanternas, olhos do boss), sombra de contato, partículas de feedback (poeira, faísca, fumaça) e câmera com easing. Ver seção 12.

---

## 1. Contexto e Escopo desta Entrega

Este documento descreve a mecânica completa do boss "O Vagoneiro" para fins de contexto de design. O escopo funcional (estrutura, movimentação, animações, morte por queda) está **implementado e validado**; a fase atual adiciona **apenas acabamento visual**, sem introduzir mecânica nova:

- [x] Entidade do Boss (o Vagoneiro), controlando os vagões (spawn, movimentação, remoção) via **slots fixos** em um trilho **linear** (ver seção 3).
- [x] Entidade dos Vagões com máquina de estados completa e função de **plataforma sólida** (ver seção 9).
- [x] Animações do Boss — `idle` ativo continuamente; `hit`/`stunned`/`exposed`/`recovering` implementados e disparáveis isoladamente via debug, sem lógica de combate real (ver seção 4.1).
- [x] Movimentação do Player (câmera estritamente lateral, `west`/`east`) com `idle` real, dash, pulo granular e ataque com espada (ver seções 4.2 e 15).
- [x] Morte do Player por queda/erro de plataforma (ver seção 10).
- [x] Escala relativa entre player, vagão e boss calibrada numericamente (ver seção 2.3).
- [x] Polish visual e juice de gameplay — parallax, iluminação, sombra de contato, partículas de feedback, câmera com easing (ver seção 12).
- [x] Integração da cena — vagões/Boss recebendo a luz e a paleta do fundo, rim light direcional no Boss, set de vagão regenerado, âncoras nas pontas do trilho (ver seção 13). **Sem** mudança de regra de jogo, física ou lógica de combate.
- [x] **Combate real (Módulo 14):** doca do Boss, arte caricata, HP/fases 1-2-3, janela `exposed`/invulnerabilidade, os seis ataques da lista encadeada e HUD de operação em execução (ver seção 14).

---

## 2. Visão Geral do Boss — O Vagoneiro

O Vagoneiro é o boss principal da arena "Lista Encadeada". Ele **não ataca diretamente com o próprio corpo** na maior parte dos padrões — ele **comanda os vagões**, que funcionam como nós de uma lista encadeada: o Vagoneiro é o "controlador" (equivalente ao ponteiro `head`/à lógica que manipula a lista), e cada vagão é um nó que ele insere, remove ou reconecta.

O trilho é modelado como uma **lista encadeada real de slots fixos** (cada `Slot` tem `next`/`prev` apontando para o vizinho, e um `Vagao?` opcional ocupando aquela posição). Os slots são posições pré-calculadas uma única vez ao longo de um trilho **linear** (sem fechar em círculo/elipse — importante para o player ter uma borda consistente onde cair fora do trilho, ver seção 10). Nenhum vagão se desloca fisicamente entre slots: mudanças de estado trocam o conteúdo do slot (`boss.occupySlot(index, ...)` / `boss.clearSlot(index)`), nunca reposicionam um componente existente.

### 2.1 Área/Posição do Boss na Arena

- **Posição:** o Boss fica **parado em um ponto fixo em uma das extremidades do trilho linear** — o "maquinista" parado numa doca no fim da linha, com os vagões ocupando o trilho em sequência (slot 0 é o mais próximo do boss).
- **Orientação:** o Boss fica de frente para o trilho (perfil voltado para a esquerda, único ângulo disponível no spritesheet, ver seção 2.2).
- **Escala:** calibrada numericamente — ver seção 2.3. O Boss deve dominar visualmente a arena sem ocupar espaço desproporcional em relação ao trilho.

### 2.2 Spritesheet do Boss (personagem)

`assets/boss/sprite.png`, **1800x1200, grade de 6 colunas x 4 linhas (células de 300x300)** — substituído no Módulo 14 (seção 14.2). Personagem **caricato/cartoon** (casaco longo escuro com botões de latão, quepe enorme inclinado, sobrancelhas grossas, boca larga, olho laranja brilhante, corrente enrolada no antebraço), em vista lateral, organizado em 4 fileiras de poses. A grade mudou de 256px para 300px; o mapeamento fileira→estado da seção 4.1 foi preservado célula a célula.

> A versão anterior (1536x1024, células de 256x256, humanoide sombrio/realista) contrariava o pilar de arte do jogo — bosses são caricatos, em contraste cômico com a atmosfera séria do mundo. Ver seção 14.2 para a tabela de recalibração.

### 2.3 Escala Relativa entre Entidades (calibrado — Módulo 10)

O design original só descrevia a proporção qualitativamente ("o boss deve parecer maior"). Isso causava desarmonia visual em produção (player maior que o vagão em que pisa, boss do mesmo tamanho que o player). Os valores abaixo são a referência numérica atual e **devem ser respeitados** por qualquer trabalho futuro que toque em renderização, câmera ou efeitos visuais:

| Entidade | Altura (visual + collider) | Observação |
|---|---|---|
| Player | **110px** | referência-base; ancoragem do pé = base do bounding box de conteúdo real do frame atual (não um offset fixo herdado de versões antigas do asset) |
| Vagão (visual) | **~45px** | objeto pequeno onde o player pisa, não um personagem |
| Vagão (collider/topo) | **~38px** | ~0.35x a altura do player; recalculado a partir do sprite já redimensionado, não do canvas original do asset |
| Boss | **176px** | 1.6x a altura do player — reforça a leitura de "chefe" da arena |
| Ápice do pulo do player | **~145px** | ~1.3x a altura do player |

Essas medidas foram obtidas a partir do bounding box de conteúdo opaco real de cada asset (não do tamanho de canvas/frame declarado, que inclui padding variável — ver seção 9.1 para o caso já documentado dos vagões).

---

## 3. Sistema de Vagões (Wagon Nodes)

### 3.0 Modelo de Slots Fixos

O trilho é uma sequência **linear** de **N posições fixas pré-calculadas** ("slots"), definidas uma única vez no setup da arena (N sugerido = 8; slot mais próximo do Boss = "slot 0"/cabeça; último slot = fim da lista, sem voltar a apontar para o slot 0).

- Cada slot é uma coordenada no trilho, guardada como lista encadeada **linear** de `Slot` (`next`/`prev`; `next` do último slot é `null`).
- Um slot pode estar **vazio** (`null`) ou **ocupado** por um `Vagao` em algum dos estados da seção 3.3.
- Nenhum vagão se move de um slot para outro — trocar o conteúdo de um slot é remover o `Vagao` atual (se houver) e instanciar/destruir um novo ali.
- O Boss manipula os slots via `boss.occupySlot(int index, {VagaoState estadoInicial = VagaoState.idle})` e `boss.clearSlot(int index)`.

### 3.1 Comportamento inicial

A arena começa com um único vagão, instanciado diretamente no slot 0, em estado `idle`, com uma transição simples de entrada (`spawning`: fade-in/pop, sem deslocamento de posição).

### 3.2 Comportamento durante padrões de ataque (referência conceitual)

O Boss ocupa e limpa slots dinamicamente conforme o ataque "em cena" — cada ataque futuro decide quais índices afeta. Como não há deslocamento físico, inserir um vagão "no meio" da lista é trivial (só chamar `occupySlot` no índice desejado). A lógica de *quando* disparar isso (qual ataque está ativo) é fora de escopo desta etapa — os métodos já existem como pontos de extensão.

### 3.3 Estados de um Vagão (`Vagao`)

| Estado | Descrição |
|---|---|
| `spawning` | Vagão aparecendo no próprio slot (fade-in/pop) |
| `idle` | Vagão parado no slot, conectado normalmente |
| `tremor` | Telegraph do Vagão-Fantasma (tremendo antes de sumir) |
| `falling` | Vagão caindo (ver seção 4.3) |
| `removed` | Vagão removido do slot/cena; slot volta a `null` |

---

## 4. Animações

### 4.1 Animações do Boss (Vagoneiro)

Mapeamento validado célula a célula no spritesheet (**1800x1200, grade 6x4, células de 300x300** desde o Módulo 14 — as fileiras e o significado de cada uma não mudaram):

| Fileira | Frames | Estado (`BossState`) | Descrição |
|---|---|---|---|
| 1, colunas 1–6 | 6 (todas preenchidas) | `idle` | Postura parada, variação sutil de pose. **Único estado obrigatório e ativo continuamente.** |
| 2, colunas 1–4 | 4 | `observing` (reservado) | Boss observa o trilho com luneta/corneta — sem uso obrigatório ainda |
| 2, colunas 5–6 | 2 | `chainAttack` (reservado) | Combina com o futuro ataque "Corrente Restritiva" — não implementar lógica agora |
| 3, colunas 1–4 | **4** (colunas 5–6 vazias, não usar) | `hit`/`stunned` | Reação de atordoamento; disparável isoladamente via debug |
| 4, colunas 1–3 | 3 | `exposed` | Postura vulnerável; disparável isoladamente via debug |
| 4, colunas 4–6 | 3 | `recovering` | Volta gradual ao `idle` |
| — | 16 (grade 4x4, `boss/soco.png`) | futuro ataque de impacto | **Asset ainda não recebido**; reservado, não bloqueia nada |

`boss.debugPlayHit()` e `boss.debugPlayExposed()` continuam existindo com a mesma assinatura e as mesmas teclas (`H`/`X`), mas **desde o Módulo 14 há lógica de combate real acionando estes estados** — e os dois métodos passaram a chamar exatamente o mesmo caminho que o combate usa, em vez de um caminho paralelo de debug. `observing` e `chainAttack` saíram de "reservados": são tocados pela seleção de alvo e pelo telegraph da Corrente Restritiva (seção 14.3).

### 4.2 Animações do Player

> Atualizado no Módulo 15 (seção 15). O jogo é **estritamente lateral**: só existe a orientação `west`/`east`, sem asset, estado ou tecla de debug para outras direções.

| Estado (`PlayerState`) | Folha (`west`/`east`) | Frames | Gatilho |
|---|---|---|---|
| `idle` | `idle_*.png` | 6 (loop) | no chão, sem input horizontal |
| `walk` | `west.png`/`east.png` | 8 (loop) | no chão, com input horizontal |
| `dash` | `dash_*.png` | 6 | durante o dash |
| `jumpRise` | `jump_rise_*.png` | 4 (segura o último) | no ar, subindo |
| `jumpFall` | `jump_fall_*.png` | 4 (loop) | no ar, após o ápice |
| `doubleJump` | `double_jump_*.png` | 6 (0.51s) | ativação do segundo pulo |
| `attack1` / `attack2` | `attack1_*.png` / `attack2_*.png` | 6 cada | combo de espada (`J`) |

- A direção olhada acompanha o input horizontal no chão **e no ar** (e no início de um dash). Trocar de lado no meio do pulo preserva o frame da animação em curso. Ver seção 15.7.
- `hit`, `damaged`, `pulled`, `attackAir`, `death` — nomes reservados no enum, **sem asset e sem lógica**.

### 4.3 Animações dos Vagões

- `spawn` — surgimento no próprio slot (fade-in/pop, sem spritesheet dedicado).
- `idle` — `vagao-normal.png`.
- `tremor` — telegraph do Vagão-Fantasma, loop de ~1.2s antes da queda.
- `falling` — sequência de queda (ver seção 8.1 para a ordem correta dos frames — **não é a ordem crua do arquivo**), com leve rotação/aceleração.
- `removed` — remoção do componente ao final da animação de queda.
- `disconnect_fx` (opcional) — efeito visual de corrente quebrando (reforça o `next` quebrado).

---

## 5. Ataque 2 — Vagão-Fantasma (apenas visual/animação, sem dano)

Fluxo implementado e disparável isoladamente via debug, sem hitbox/dano:

1. Vagão em um slot entra em `tremor` por ~1.2s (telegraph).
2. Entra em `falling` e executa a animação de queda.
3. Ao final, o Boss limpa o slot (`boss.clearSlot(index)`) — vagão destruído, slot volta a `null`.

---

## 6. Fora de Escopo (ainda)

> **Atualizado no Módulo 14.** Tudo o que esta seção listava foi implementado — dano de combate, resolução de ataque, fases, erro conceitual, Ciclo Corrompido e HUD. Ver seção 14.3. O que continua de fora:

- Fluxo de UI de derrota/vitória (a luta hoje simplesmente reinicia quando o maquinista fica sem HP).
- Progressão entre fases da campanha, menus, save.
- Áudio (o "apito" do Empurrão de Cabeça é telegrafado só visualmente).
- O ataque de impacto corpo a corpo do Boss (`boss/soco.png`, 4x4 de 376px): o asset está entregue e mapeado, mas nenhum padrão o usa ainda.

> A **morte por queda/plataforma** (seção 10) continua sendo o mesmo caminho de sempre; desde o Módulo 14 ela também cobra dano de combate, através do `onDeath` que a seção 10.2 já reservava como ponto de extensão.

---

## 7. Referência Completa do Design (contexto conceitual, não implementar ainda)

**Arena:** trilho ferroviário linear com vagões-nó em slots fixos, conectados por correntes brilhantes (representando ponteiros `next`). Conceito central: só se pode alcançar um elemento percorrendo o `next` a partir da cabeça.

**Fase 1 (100–66%)**
1. **Corrente Restritiva** — correntes entre 2 slots piscam em vermelho (telegraph); o Vagoneiro puxa o jogador se ele estiver no vagão errado. Erro conceitual: pular direto pra um slot distante ("acesso por índice") → puxado de volta.
2. **Vagão-Fantasma** — ver seção 5.
3. **Empurrão de Cabeça (`insertAtHead`)** — Boss ocupa um novo slot na posição da cabeça; marcador visual de "cabeça" muda de referência, sem nenhum vagão se mover fisicamente. Janela de exposição de 1.5s após a inserção.

**Fase 2 (65–33%)**
5. **Lista Dupla (Reversão)** — flag de direção inverte o sentido em que ataques varrem os slots; correntes ficam douradas.
6. **Nó Órfão** — slot fora da sequência principal, `linked: false`; atacar pensando que está na lista é miss garantido.

**Fase 3 (32–0%)**
7. **Ciclo Corrompido** — "nó de entrada do ciclo" é um slot pré-definido pela config do ataque; telegraph destaca visualmente o subconjunto de slots repetindo. Boss vulnerável por 3s após quebra correta.

**Falha comum a punir:** atacar vagões fora de ordem sequencial nunca causa dano.

---

## 8. Estrutura de Assets (`assets/`)

```
assets/
  audio/                              # (vazio) — sem áudio nesta etapa
  background/
    layer-far.png                     # 1376x639, RGBA opaco (pintado, não precisa de alfa
                                       # funcional), paleta dessaturada/enevoada, tileável
                                       # horizontalmente sem costura. Camada mais distante do
                                       # parallax (Módulo 9).
    layer-mid.png                     # 1376x768, RGBA com alfa real (vãos dos arcos são
                                       # transparentes de propósito, revelam a layer-far atrás),
                                       # tileável horizontalmente sem costura. Camada
                                       # intermediária do parallax (Módulo 9).
    caverna-gotica-pixelart.png       # 1672x941 — asset original de fundo único, anterior ao
                                       # sistema de parallax. Mantido como referência de
                                       # paleta/estilo; a camada de piso/trilho onde
                                       # player/vagões ficam continua baseada neste recorte.
  boss/
    sprite.png                        # 1800x1200, grade 6x4 (células 300x300) — ver seções 4.1 e 14.2
    doca.png                          # 1536x1024, prop estático — a doca do Boss (seção 14.1)
    soco.png                          # 1504x1504, grade 4x4 (células 376x376) — reservado
    soco.png                          # (não recebido ainda) ataque de impacto futuro, 16 frames
  effects/
    glow-warm-soft.png                # 128x128, glow radial âmbar dithered, alfa real, uso
                                       # aditivo — luz de lanternas e olhos do boss (Módulo 9)
    contact-shadow.png                # 96x32, elipse de sombra semitransparente, alfa real —
                                       # sombra de contato sob player/vagões (Módulo 9)
    particles/
      spark-ember.png                 # spritesheet 6 frames de 32x32 (192x32), baseline-aligned
                                       # — reforço visual do tremor do vagão (Módulo 9)
      dust-poof.png                   # spritesheet 6 frames de 48x48 (288x48), baseline-aligned
                                       # — poeira ao aterrissar de um pulo (Módulo 9)
      smoke-wisp.png                  # spritesheet 6 frames de 48x64 (288x64), baseline-aligned
                                       # — fumaça saindo do boss, opcional (Módulo 9)
  player/
    spritesheets/
                                       # todas com 256px de altura, 1 linha, células 256x256,
                                       # pé na linha 199 (padding inferior de 56px) — Módulo 15
      west.png / east.png             # 2048x256, 8 frames — walk
      idle_west.png / idle_east.png   # 1536x256, 6 frames — idle (referência de escala)
      dash_west.png / dash_east.png   # 1536x256, 6 frames
      jump_rise_west/east.png         # 1024x256, 4 frames
      jump_fall_west/east.png         # 1024x256, 4 frames
      double_jump_west/east.png       # 1536x256, 6 frames
      attack1_west/east.png           # 1536x256, 6 frames — corte horizontal (pico: frames 3-4)
      attack2_west/east.png           # 1536x256, 6 frames — diagonal de finalização (pico: frame 4)
    effects/
      particles/
        dash-trail-west/east.png      # 384x32, 6 frames de 64x32 — rastro do dash
        double-jump-east.png          # 576x96, 6 frames de 96x96 — burst do 2º pulo (simétrico,
        double-jump-west.png          #   usado nas duas direções; o gêmeo -west não é usado)
        sword-slash-arc.png           # 768x384, 4x2 de 192x192 — arco (west); linha 1 = golpe 1,
        sword-slash-arc-east.png      #   linha 2 = golpe 2; variante east
  ui/
    buttons/                          # (vazio) — sem UI/HUD nesta etapa
  wagons/
    spritesheets/
      chains.png                      # 1536x1024, grade 3x2 (células 512x512) — elos avulsos
                                       # repetíveis usados pelos `ChainSegment` entre vagões
      sprite_anchor_left.png          # 867x501 — placa de âncora cravada na rocha à ESQUERDA,
                                       # corrente saindo para a direita (Módulo 13, seção 13.3)
      sprite_anchor_right.png         # 866x501 — espelho exato da anterior (placa à direita)
    states/                           # set REGENERADO no Módulo 13 (substituiu vagao-*.png).
                                       # 15 frames, canvas ~307x300, com as correntes de
                                       # suspensão desenhadas dentro do próprio frame.
      frame_01_idle.png               # 307x308 — conectado normalmente (idle)
      frame_02_tremor1.png            # 307x308 ┐
      frame_03_tremor2.png            # 308x308 │ telegraph do Ataque 2: vagão balançando
      frame_04_tremor3.png            # 307x308 │ nas correntes, faísca no elo
      frame_05_tremor4.png            # 307x308 ┘
      frame_06_break1.png             # 307x299 ┐ elo começando a se soltar
      frame_07_break2.png             # 307x299 ┘
      frame_08_link_detached1.png     # 308x299 ┐ elo já solto/pendurado
      frame_09_link_detached2.png     # 307x299 ┘
      frame_10_falling1.png           # 307x299 ┐
      frame_11_falling2.png           # 307x275 │ inclinado, caindo, girando
      frame_12_falling3.png           # 307x275 ┘
      frame_13_impact1.png            # 308x275 ┐
      frame_14_impact2.png            # 307x275 │ impacto final com destroços
      frame_15_final.png              # 307x275 ┘
  tilesets/
    vagoes-lista-encadeada.png        # 1254x1254 — trilho, vagões, elos, âncoras de parede,
                                       # tochas, partículas de fogo, cena de referência
                                       # (y=926..1220, "reference_only")
    vagoes_tileset_reference.json     # mapeamento de tiles — fonte de verdade para extrair
                                       # cada tile ao montar o trilho linear
```

### 8.1 Mapeamento: assets → estados de animação

Atualizado no Módulo 13 para o set regenerado. **O mapeamento conceitual é o mesmo** — o que mudou foi a resolução: o que era um sprite por etapa virou uma sequência de frames por etapa.

| Estado (`VagaoState`) | Asset(s) |
|---|---|
| `idle` | `wagons/states/frame_01_idle.png` |
| `tremor` | loop de `frame_02_tremor1` → `frame_03_tremor2` → `frame_04_tremor3` → `frame_05_tremor4`, repetido durante os ~1.2s de telegraph (antes era um sprite estático) |
| `falling` | `frame_06_break1` → `frame_07_break2` (elo começando a se soltar) → `frame_08_link_detached1` → `frame_09_link_detached2` (elo já solto) → `frame_10_falling1` → `frame_11_falling2` → `frame_12_falling3` (caindo/girando) → `frame_13_impact1` → `frame_14_impact2` → `frame_15_final` (impacto final) |
| `orphan` (futuro) | sem asset no set regenerado — Nó Órfão segue fora de escopo |
| `spawning` | Sem sprite dedicado — `frame_01_idle.png` com fade-in/pop no próprio slot |

> **Registro por frame (importante).** O conteúdo opaco de cada frame não está centralizado no próprio canvas: ele desliza de +73.5px (frame 02) a -41px (frame 05) em px nativos. Desenhar os canvas centralizados jogaria a arte até ~44px de mundo para fora do slot, com o collider e a sombra parados. Cada frame carrega por isso uma correção de registro horizontal (`VagaoFrame.contentCentreOffsetX` em `lib/game/wagon/vagao.dart`), medida como `(bbox.left + bbox.right)/2 - (largura-1)/2` com limiar alpha > 10. Só X é corrigido: o corte vertical de cada canvas (308 → 299 → 275) é intencional e é o que faz o vagão descer ao cair. `test/scene_integration_test.dart` recompara essas constantes com os arquivos reais, então um novo export que desloque um frame quebra o teste em vez de passar despercebido.

| Estado (`BossState`) | Asset(s) |
|---|---|
| `idle` | `boss/sprite.png`, fileira 1, colunas 1–6 |
| `observing` (opcional) | `boss/sprite.png`, fileira 2, colunas 1–4 |
| `chainAttack` (reservado) | `boss/sprite.png`, fileira 2, colunas 5–6 |
| `hit`/`stunned` | `boss/sprite.png`, fileira 3, colunas 1–4 apenas |
| `exposed` | `boss/sprite.png`, fileira 4, colunas 1–3 |
| `recovering` | `boss/sprite.png`, fileira 4, colunas 4–6 |
| ataque de impacto (futuro) | `boss/soco.png` — não recebido, reservado |

| Estado (`PlayerState`) | Asset(s) |
|---|---|
| `walk` (esquerda) | `player/spritesheets/west.png` |
| `walk` (direita) | `player/spritesheets/east.png` |
| reservado (sem uso ativo) | `player/spritesheets/north.png`, `south.png` |
| `idle`/`hit`/`damaged`/`pulled` | fora de escopo nesta etapa |

---

## 9. Vagões como Plataforma

### 9.1 Colisão / hitbox do vagão

- Cada vagão expõe um collider sólido no topo (não a arte inteira do sprite) — altura calibrada em **~38px** (ver seção 2.3), fixa entre todos os estados.
- Os assets de vagão têm dimensões de canvas ligeiramente diferentes entre estados (ex.: `vagao-normal.png` 393x435 vs `vagao-marcado.png` 366x465 vs `vagao-orfao.png` 400x472 — variação de padding/efeito de partícula, não do vagão em si). O collider **não** usa o bounding box da imagem — usa o tamanho lógico fixo calibrado.
- O collider é filho do componente `Vagao`, posicionado uma única vez junto com o slot fixo; só reage a mudanças de **estado** (ex.: deixar de ser sólido em `falling`), não precisa atualizar por frame.

### 9.2 Solidez por estado

| Estado do vagão | É plataforma sólida? |
|---|---|
| `spawning` | Sim |
| `idle` | Sim |
| `tremor` (telegraph) | Sim — apenas aviso visual |
| `falling` | **Não** — o player perde suporte e cai se estiver em cima |
| `removed` | Não existe mais — vazio/buraco no trilho |

### 9.3 Pulo do player

Não há spritesheet de pulo dedicado. A física de pulo (input, arco, gravidade) usa o ápice calibrado de **~145px** (seção 2.3) e reaproveita o frame estático de `walk` (congelado, ver seção 4.2) como visual durante o salto — sem animação própria de pulo.

---

## 10. Morte do Player (queda / erro de plataforma)

### 10.1 Gatilhos de morte

- Pular/pisar em um vagão em estado `falling`.
- Pisar/pular no vazio deixado por um vagão `removed`.
- Sair dos limites verticais da arena (fallback de segurança).

### 10.2 Fluxo

1. A cada frame relevante, verificar suporte sólido logo abaixo do player (exceto durante pulo controlado).
2. Sem suporte → `PlayerState.falling` (queda livre por gravidade).
3. Ao sair da área visível (ou após tempo/altura definidos) → `onPlayerDeath()` (hook de extensão; respawn/game over ficam para depois).
4. Sem animação de morte dedicada — placeholder simples (cair até sumir da tela, ou fade/scale-down básico).

### 10.3 Separação de conceitos

- `FallDeath` (morte por queda) → **implementado**.
- `CombatDamage` (morte por dano de ataque) → **fora de escopo**, futuro.

---

## 11. Critérios de Aceite — Módulos 0–8 e 10 (concluído)

- [x] Boss instanciado em posição fixa, controlando lista encadeada linear de slots fixos (sem fechar em círculo).
- [x] Boss exibe `idle` continuamente; `hit`/`stunned`/`exposed`/`recovering` disparáveis isoladamente via debug.
- [x] Boss possui hitbox próprio (player não sobe nele), calibrado em 176px de altura.
- [x] Vagão inicial aparece no slot 0 sem deslocamento/caminhada.
- [x] Boss possui `occupySlot`/`clearSlot` funcionais.
- [x] Sequência `tremor → falling → removed` do vagão disparável isoladamente em qualquer slot.
- [x] Player se move com asset de 4 direções (West/East ativas, North/South reservadas), sem animação de idle/hit de verdade — só o congelamento de frame quando parado.
- [x] Player possui física de pulo funcional, ápice calibrado (~145px), pousa sobre vagões sem gap visual.
- [x] Vagões com collider sólido de tamanho lógico fixo (~38px), independente de variação no bounding box da arte.
- [x] Player morre (`onPlayerDeath()`) ao pisar em vagão em queda, cair em slot vazio, ou sair dos limites da arena.
- [x] Escala relativa entre player (110px), vagão (~45px) e boss (176px) calibrada e sem regressão de colisão/ancoragem.
- [x] Nenhuma lógica de combate, HP ou fases implementada ainda (documentado como próximo passo, seção 6).

---

## 12. Módulo 9 — Polish Visual e Juice de Gameplay (concluído)

**Objetivo:** acabamento visual e feedback de jogabilidade — nenhuma mudança de regra de jogo, física ou lógica de combate/morte. Os assets já foram gerados, limpos (transparência real validada) e calibrados em escala — o trabalho atual é **integração em código**, não geração de arte.

**Números de referência a respeitar** (não recalcular — ver seção 2.3): player 110px, vagão ~45px/~38px de collider, boss 176px, ápice de pulo ~145px.

### Escopo

1. **Parallax de fundo** — `layer-far.png` (mais lenta) e `layer-mid.png` (intermediária, revela a `far` por trás através dos vãos dos arcos via alfa real), alinhadas pela base do canvas, com wrap horizontal (ambas tileáveis sem costura). Preencher com cor sólida a faixa sem pintura que sobra no topo (far é 639px de altura contra 768px da mid). Vinheta sutil nas bordas.
2. **Iluminação funcional** — `glow-warm-soft.png` (blend aditivo) em cada âncora de lanterna e nos olhos do Boss (tint mais saturado, pulsante). `contact-shadow.png` sob o player e cada vagão ocupado, escalado conforme suas alturas calibradas (110px / ~45px), sem gap visual.
3. **Boss como ponto focal** — contraste/realce visual (rim light) combinado com o glow dos olhos, respeitando a escala já calibrada (176px) — sem alterar posição, escala ou máquina de estados do Boss.
4. **Juice de jogabilidade** — squash-and-stretch no player ao pular/aterrissar (proporcional aos 110px, só com movimento vertical real); `dust-poof.png` ao aterrissar, ancorado no mesmo ponto de pé já recalculado na escala; screen shake sutil quando um vagão entra em `falling`; `spark-ember.png` + shake de posição durante `tremor`, além da troca de sprite já existente.
5. **Câmera com easing** — segue o player horizontalmente com suavização e leve zoom (referência: 110px de altura do player), limites respeitando as bordas do cenário, acionando o parallax do item 1 em resposta ao movimento de câmera.

### Fora de escopo

- Gerar/editar os arquivos de asset (já prontos).
- Qualquer alteração em física de pulo, gatilhos de `onPlayerDeath()`, máquina de estados do vagão/boss, HUD de debug existente, ou nos valores de escala/ancoragem da seção 2.3.

### Critérios de aceite

- [x] `layer-far.png`/`layer-mid.png` em parallax com velocidades diferentes; tile sem costura; faixa do topo preenchida.
- [x] Vinheta sutil sem esconder gameplay.
- [x] Glow aditivo em lanternas e olhos do boss; `contact-shadow.png` sob player/vagões sem gap.
- [x] Boss com destaque visual (rim light) respeitando a escala de 176px.
- [x] Squash-and-stretch proporcional aos 110px; `dust-poof.png` na ancoragem correta de pé.
- [x] Screen shake em vagão `falling`; `spark-ember.png` + shake no `tremor`.
- [x] Câmera com easing, limites respeitados, parallax reagindo à câmera.
- [x] Nenhum critério de aceite da seção 11 regrediu.

---

## 13. Módulo 13 — Integração da Cena (concluído)

**Problema:** com o Módulo 9 no lugar, o fundo tinha parallax, névoa e halos de luz, mas nada disso alcançava as entidades. Vagões e Boss liam como adesivos colados por cima da cena, e o Boss ainda carregava um contorno dourado uniforme em volta de toda a silhueta.

**Objetivo:** acabamento visual apenas. Nada aqui toca física, colliders, posições de slot, máquina de estados de vagão/boss, `next`/`prev`, nem os valores calibrados da seção 2.3.

Toda constante deste módulo vive em `lib/game/fx/fx_config.dart`, na seção "Módulo 13", para que a afinação possa ser revista ou revertida num arquivo só.

### 13.1 Sombra de contato sob os vagões

A sombra já existia desde o Módulo 9, mas estava ancorada com o offset do asset antigo. Recalculada para o set regenerado: o canvas tem 308px e o corpo do vagão termina na linha 278, então 29px nativos de canvas vazio ficavam abaixo dele — na escala de exibição (0.3879), 11.25px de mundo. `vagaoContactShadowYOffset` levanta a sombra exatamente essa distância, colocando-a na base **visível** do vagão, sem gap.

Além disso a sombra passou a ser **escopada aos estados em que o vagão está apoiado no trilho** (`spawning`/`idle`/`tremor`). Ao entrar em `falling` ela é apagada: não há contato para sombrear, e a sombra que ficava para trás lia como uma mancha pintada no slot vazio.

### 13.2 Integração de luz ambiente

Duas metades, ambas em `lib/game/fx/ambient_light.dart`:

- **Tonalidade fria compartilhada.** Uma camada de `ambientCoolTintColor` (RGB 74,58,99) a `ambientCoolTintOpacity` = 0.11, aplicada via `ColorFilter.mode(cor, srcATop)` — `srcATop` compõe o tom sobre os pixels do sprite mas recortado pelo alfa deles, então padding transparente continua transparente e nenhuma silhueta engorda. A cor não foi escolhida a olho: quantizando `layer-mid.png` e `caverna-gotica-pixelart.png` em 8 cores, as bandas modais da metade jogável são ameixas dessaturadas em H 264–315, e este é o meio dessa família. Aplicada em **vagões, Boss e elos de corrente** — deixar as correntes de fora faria delas a única peça da família de arte ainda fora da paleta.
- **Glow quente por proximidade de lanterna.** `WagonLanternLightObserver` observa o trilho (mesmo formato do `WagonFxObserver`, e pelo mesmo motivo: `occupySlot` não deve saber o que é cenário) e pendura um `GlowLight` aditivo no teto dos vagões perto de uma âncora de lanterna, com falloff linear até `wagonLanternGlowRadius` = 340px a partir da lanterna **mais próxima**. O resultado é deliberadamente desigual: o slot 7 (a 61px da lanterna em (215,730)) acende bem, os slots 0 e 5 recebem um resto, e o miolo escuro do trilho (slots 2–4) não recebe nada.

> **Afinação aprendida na validação.** A primeira tentativa (74px a 0.30) estourou: o vagão do slot 7 já está dentro do halo de fundo daquela lanterna, e um blend aditivo empilhado sobre uma área já clara quase não tem headroom — o vagão saía lavado e dessaturado ao lado dos vizinhos. 60px a 0.16 lê como o vagão pegando a luz, não como uma segunda lâmpada.

### 13.3 Rim light do Boss (correção do contorno)

**O contorno dourado não vinha do PNG.** `assets/boss/sprite.png` foi inspecionado: o dourado dele é interno (cinto, galões, distintivo do quepe), não há stroke na silhueta. O contorno era produzido pelo `BossRimLight` do Módulo 9, e por dois motivos somados:

1. **Direção.** As redesenhas da silhueta estavam espalhadas pelos oito rumos da bússola, afinando mas nunca chegando a zero — ou seja, um stroke contínuo em volta da figura inteira. Corrigido para um arco em torno de `bossRimLightDirection`, tirado da cena e não da intuição: as duas lanternas mais próximas do Boss em `slots_config.json` são (1520,300) e (1590,510), quase em cima dele, o que normaliza para ≈(+0.17, −0.985). O arco tem meia-largura `bossRimLightArcHalfWidth` = 0.8 rad (≈46°); fora dele não se desenha nada, e o lado de baixo — voltado para o fundo escuro — fica sem luz nenhuma.
2. **Saturação.** Nove cópias aditivas a 0.5 de alfa cada somavam para branco estourado, que é o que dava a leitura de "traço", não de "luz". Os pesos agora são `cos²` do ângulo, **normalizados para somar 1** antes de multiplicar por `bossRimLightOpacity` — o halo inteiro chega a 0.45 no ponto mais claro, não cada cópia.

O peso também escala a **distância** de cada redesenha, então a borda afina nos flancos em vez de manter espessura constante ao redor. O blend mode já estava correto (`BlendMode.plus`, aditivo) e não mudou.

> Uma tentativa intermediária com arco de 1.05 rad (60°) ainda era um contorno disfarçado: um offset a 60° da vertical é 87% horizontal, então pintava uma faixa de altura inteira nos **dois** flancos, passando pelas botas.

### 13.4 Profundidade de campo — **não aplicada** (decisão)

A tarefa era condicional ("se algum vagão estiver visualmente mais distante da câmera"). Na composição atual **nenhum está**: os 8 slots ficam no mesmo plano do trilho, e o zigue-zague de `y` entre 660 e 780 é variação de **altura**, não de profundidade. Aplicar blur/dessaturação aqui inventaria uma profundidade que a cena não tem e custaria legibilidade justamente nas plataformas em que o player precisa pisar — o que a própria tarefa manda evitar. Se algum dia existirem vagões num plano de fundo real, o tratamento a espelhar é o de `layer-mid.png`/`layer-far.png`.

### 13.5 Substituição dos assets de estado do vagão

`wagons/states/` foi trocado pelo set regenerado de 15 frames. O mapeamento de estados da seção 8.1 foi **preservado** — mudou a resolução dele, não o significado. Ver seção 8.1 para a tabela e para a nota sobre **registro por frame**, que é o detalhe crítico dessa troca.

Consequências calibradas junto (tudo recalculado a partir do asset novo, mantendo os alvos da seção 2.3 intactos):

| | Antes (`vagao-normal.png`) | Depois (`frame_01_idle.png`) |
|---|---|---|
| Canvas nativo | 417x420 | 307x308 |
| Altura opaca usada na calibração | 226px (bbox inteiro) | **116px (só o corpo do vagão)** — o bbox inteiro agora tem 212px porque as correntes de suspensão vêm desenhadas no frame |
| `vagaoDisplayWidth` | 83 | 119.1 |
| Altura visual resultante | ≈45px | ≈45px (inalterada) |
| Collider (`55x10`, topo a −38px) | — | **inalterado**, e revalidado: o corpo renderiza com ≈66.7px de largura, ainda mais largo que o box de 55px |

> **Armadilha evitada.** Calibrar contra o bbox inteiro (212px, incluindo as correntes) renderizaria o vagão a ≈25px, quase metade do alvo da seção 2.3. A altura tem que ser medida no corpo do vagão, isolado pelo perfil de largura das linhas: as correntes ocupam as linhas 67–162 com 16–47px de largura, e a largura salta para 162+ na linha 163, onde começa o teto do vagão.

Duração dos frames: `tremor` virou um loop de 4 frames a 0.1s (3 voltas dentro dos mesmos 1.2s de telegraph, cronometrado por relógio de parede e não por contagem de frames), e `falling` passou de 4 para 10 frames com o tempo por frame reduzido a 0.08s, para a queda inteira ficar em 0.80s em vez de esticar para 1.5s. **A máquina de estados não mudou**: os estados são entrados e deixados exatamente nos mesmos momentos.

`ChainSegment` teve seu mapa `asset → modo de elo` refeito sobre os novos caminhos, com a mesma semântica (`break1/2` → elo trincando, `link_detached1/2` → elo rompendo, resto → rompido).

### 13.6 Âncoras de corrente nas pontas do trilho

A decoração de corrente só ligava vagão↔vagão (mais boss↔slot 0), então o vagão de cada ponta tinha corrente saindo de um lado e nada do outro — a leitura de "flutuando no vazio". Duas placas cravadas na parede fecham isso, declaradas em `slots_config.json` sob `chainConnections.endAnchors`:

| Ponta | Asset | Ponta livre da corrente | Corrente extra |
|---|---|---|---|
| Lado do Boss | `sprite_anchor_right.png` | (1566, 712) | nenhuma — a corrente do próprio asset some atrás da silhueta do Boss e reaparece como o segmento boss→slot 0 que já existia |
| Fim do trilho | `sprite_anchor_left.png` | (110, 660) | um `ChainSegment` comum até o ponto de engate do slot 7, em (180, 640) |

Detalhes que importam:

- **Posicionadas pela ponta da corrente, não pela placa.** É a ponta que precisa encostar no que a âncora termina; a posição da placa sai dela e da escala de render, então o config nunca repete geometria de arte.
- **Escala.** `chainAnchorRenderScale` = 0.105, escolhida para o passo de elo da âncora bater com o dos `ChainSegment`: 418 × 0.62 × 0.052 ≈ 13.5px/elo contra 132.5px/elo nativos da âncora → 13.5/132.5 ≈ 0.102.
- **Prioridade.** `fxPriorityChainAnchor` = −2, atrás de tudo que está em 0 — é o que faz a silhueta do Boss engolir a ponta da corrente do lado dele. Uma primeira tentativa com a ponta em x=1588, 4px além da borda do casaco, deixava a peça boiando ao lado dele em vez de passar atrás.
- **Zero impacto na lista.** As âncoras são `SpriteComponent` sem hitbox; o segmento novo é o mesmo componente decorativo já usado entre vagões e espelha o estado do vagão 7 como qualquer outro, então arrebenta junto quando ele cai. Nada aqui lê ou escreve slot, `next` ou `prev`.

### 13.7 Como isto foi validado

- **`test/scene_integration_test.dart`** (6 testes) cobre: as 15 constantes de registro recomparadas contra os PNGs reais; o alvo de ≈45px e o corpo mais largo que o collider; o rim light sem nenhuma redesenha para baixo, com pesos somando 1 e alcance vertical > 2x o lateral; o falloff de lanterna acendendo as pontas e deixando os slots 2–4 escuros; as duas âncoras presentes, com a ponta do lado do Boss dentro da silhueta dele e o slot 7 ainda sendo a cauda da lista.
- **`test/scene_snapshot_tool.dart`** renderiza um frame da arena real (mesmos componentes, mesmas prioridades, mesma câmera) para PNG, sem abrir janela. Não afirma nada — existe para revisar mudança visual contra o caminho de render de verdade. Não é coletado por `flutter test` (não termina em `_test.dart`); roda sob demanda:

```
flutter test test/scene_snapshot_tool.dart \
  --dart-define=SNAPSHOT_OUT=<caminho.png> \
  --dart-define=SNAPSHOT_FULL_ARENA=true \
  --dart-define=SNAPSHOT_CLEAN=true \
  --dart-define=SNAPSHOT_FANTASMA_SLOT=3 \
  --dart-define=SNAPSHOT_SETTLE_FRAMES=330
```

- Conferido em render: sombra encostada na base das rodas sem gap; vagão do slot 7 pegando a lanterna sem lavar; Boss sem contorno, com luz só na aba do quepe/ombro/topo do casaco; corrente do lado do Boss saindo da parede e sumindo atrás dele; âncora da esquerda ligada ao vagão 7; sequência tremor → queda → impacto → slot vazio com as correntes rompendo junto.

### Critérios de aceite

- [x] `contact-shadow.png` sob todo vagão ocupado em `spawning`/`idle`/`tremor`, na base visível (≈38px de collider preservados), sem gap.
- [x] Camada de tonalidade fria compartilhada (11%) sobre vagões, Boss e correntes.
- [x] `glow-warm-soft.png` aditivo, de baixa intensidade, no topo dos vagões próximos de lanternas visíveis; miolo escuro do trilho sem glow.
- [x] Contorno dourado do Boss eliminado; rim light aditivo, direcional, restrito às bordas iluminadas.
- [x] Profundidade de campo avaliada e **dispensada** com justificativa (13.4).
- [x] Assets de estado do vagão substituídos pelo set regenerado, mantendo o mapeamento da seção 8.1.
- [x] Âncoras fechando as duas pontas do trilho, sem alterar slots, `next`/`prev` ou lógica de lista encadeada.
- [x] Nenhum critério de aceite das seções 11 e 12 regrediu (suíte completa passa, exceto o `widget_test.dart` de template — ver abaixo).

### Pendências conhecidas (fora do escopo deste módulo)

- `test/widget_test.dart` é o teste de contador do template padrão do Flutter e falha desde antes deste módulo: procura um `MaterialApp` com botão `+` que este projeto não tem. Deve ser apagado ou reescrito.
- Os halos de lanterna do fundo (Módulo 9, `lanternGlowDiameter`/`lanternGlowOpacity`) leem como discos pálidos chapados sobre a metade superior enevoada — o mesmo problema de headroom aditivo descrito em 13.2, mas na camada de cenário. Não foi tocado aqui.
- As correntes de suspensão desenhadas dentro dos frames de vagão sobem ≈37px e terminam no ar, já que o teto da caverna não está nessa camada. Convive com as correntes em catenária entre vagões, mas é uma ponta solta da arte nova.

---

## 14. Módulo 14 — Doca do Boss, arte caricata e combate jogável (concluído)

Três frentes, detalhadas em `modulo-14-redesign-e-combate-vagoneiro.md`. **Nada aqui altera a seção 2.3** (player 110px / vagão ≈45px / boss 176px / ápice ≈145px) **nem a máquina de estados do Vagão** (`spawning → idle → tremor → falling → removed`), e todos os critérios das seções 11, 12 e 13 continuam valendo — a suíte inteira passa (46 testes; a única falha remanescente é o `widget_test.dart` de template, pendência já registrada na seção 13).

Constantes visuais em `lib/game/fx/fx_config.dart` (bloco "Módulo 14"); as **regras** de combate (HP, bandas de fase, durações de janela, dano por fonte) ficam separadas em `lib/game/boss/boss_combat.dart`, sem nenhum import de Flame, para poderem ser testadas sem subir o jogo.

### 14.1 Doca do Boss (Frente 1)

`assets/boss/doca.png` (1536x1024, alfa real verificado: 79% do canvas em alpha 0, bbox opaco (209,73)-(1325,956) — sem o xadrez pintado que reprovou a primeira geração) entra como cenário estático, no mesmo tratamento dos vagões: tonalidade fria compartilhada + `contact-shadow.png`.

**Posicionada pela superfície do tampo, não pelo canvas** — mesmo princípio do `ChainAnchor` (que é posicionado pela ponta da corrente, seção 13.6). Um scan de largura por linha (alpha > 10) mostra as linhas 575–599 com só as correntes de sustentação (310–370px de largura) e um salto para 882 na linha **600**, onde começa o estrado. Essa linha é cravada em `boss.visibleFootY`.

> **`visibleFootY` — e por que o Boss não se move.** A arte nova tem 32.5px nativos de célula vazia sob as botas (`bossFrameBottomPadNative`, medido nas 6 colunas de idle: fundos em 265/265/269/266/267/267 dentro de células de 300px). Como o componente é ancorado em `bottomCenter` na coordenada do `slots_config.json`, o pé **visível** fica 32.5 × 0.7473 ≈ 24px acima de `position.y`. A regra da seção 2.3 é explícita — a ancoragem do pé é a base do bbox de conteúdo real do frame, não a borda do frame — então a doca e a sombra são registradas nessa linha derivada. O `position` do Boss continua sendo, bit a bit, o valor do config: **quem se move para encontrar o outro é a doca**.

Detalhes:

- **Escala.** O tampo tem 1054px nativos (linha 620, x 265..1318). Alvo de 150px de mundo → `bossDockRenderScale` = 150/1054 = 0.1423; o prop inteiro renderiza 218.6 x 145.7px. 150px cobre a silhueta idle do Boss (133 nativos ≈ 99px) e ainda para antes da arte do vagão do slot 0, que termina em x = 1499.5.
- **Espelhamento.** A arte tem a parede de rocha à esquerda e o estrado correndo para a direita; o Boss fica na ponta direita de um trilho que corre para a esquerda, então o prop é espelhado — a rocha encosta na borda direita da arena e o estrado volta na direção do slot 0. O componente é ancorado em `Anchor.center` **de propósito**: `flipHorizontallyAroundCenter` só deixa `position` intacto quando a âncora já é o centro (caso contrário compensa deslocando `transform.x`), e a aritmética de registro acima depende de `position.x ± size.x/2` continuar sendo a caixa real.
- **Prioridades.** `fxPriorityBossDock` = −4 (atrás das âncoras de corrente em −2, portanto atrás do vagão do slot 0 e da corrente boss→slot 0 que cruzam sua ponta) e `fxPriorityBossContactShadow` = −3 (acima da doca sobre a qual a sombra é projetada, abaixo do Boss que a projeta). Nenhuma prioridade pré-existente mudou. A sombra é **irmã** no mundo, não filha do Boss — Flame desenha os filhos *depois* do render do próprio componente, então uma sombra filha seria pintada por cima do personagem (mesmo motivo do `BossRimLight`, seção 13.3).

### 14.2 Arte caricata (Frente 2)

`assets/boss/sprite.png` foi substituído pelo maquinista caricato (casaco longo, quepe enorme, olho laranja brilhante, sorriso largo, corrente enrolada no antebraço). **A grade mudou; o mapeamento da seção 4.1 não.**

| | Antes | Depois |
|---|---|---|
| Canvas / célula | 1536x1024, 6x4 de **256px** | 1800x1200, 6x4 de **300px** |
| Altura opaca do idle | 232px (média) | **235.5px** (233/233/241/234/236/236) |
| `bossDisplayScale` | 176/232 | **176/235.5** = 0.7473 |
| Altura renderizada | 176px | **176px** (inalterada — a seção 2.3 é restrição, não resultado) |
| Olhos (`bossEyeFrameX/Y`) | (93.5, 55.5) | **(165.5, 108.5)** |

A folha continua **única, fatiada por posição de grade** (`SpriteSheet`/`srcSize`), nunca separada em arquivos por frame: a normalização entregue já deixou cada frame com âncora consistente dentro da própria célula, e separar jogaria isso fora obrigando a guardar um offset por frame (seção 3.7 do doc do módulo).

Fileira 3 continua com **apenas 4 colunas válidas** — reconferido na arte nova: as células (2,4) e (2,5) são totalmente transparentes, e há teste que falha se deixarem de ser. `observing` e `chainAttack` (fileira 2, colunas 1–4 e 5–6) saíram de "reservados" e passaram a ser tocados de verdade pelos ataques.

`debugPlayHit()` e `debugPlayExposed()` seguem existindo com a mesma assinatura e as mesmas teclas (`H`/`X`), mas agora chamam o **mesmo caminho** que o combate real usa (`_play(BossState.hit)` e `enterExposed`), em vez de um caminho paralelo — a tecla de debug passou a exercitar produção. `_sheet` virou anulável (era `late final`): estado de combate pode legitimamente ser dirigido antes do `onLoad` terminar — `occupySlot` já é chamado assim neste código — e uma troca de estado que chegue cedo tem que registrar o estado e pular o repaint, não estourar.

O collider do Boss (78x156, inalterado) foi **re-registrado** na mesma linha de pé visível: ancorado na borda do frame, ele penderia 24px abaixo do personagem na arte nova.

### 14.3 Combate e fases (Frente 3)

HP do Boss = 12, escolhido para as bandas da seção 4 caírem em número inteiro de acertos sem arredondamento: 12–8 é Fase 1 (5 acertos, 8/12 = 0.667 ≥ 0.66), 7–4 é Fase 2 (4 acertos, 4/12 = 0.333 ≥ 0.33), 3–0 é Fase 3. Player = 5 HP; toda fonte de dano custa exatamente 1.

**Janela de punição (item 8).** `boss.takeDamage()` retorna `false` e não faz nada fora de `isExposed` — a invulnerabilidade não é um teste espalhado pelos ataques, é a única porta de entrada de dano. Acertar dentro da janela a estende em `bossExposedAfterHit` (0.6s), então quem lê a abertura encadeia alguns golpes.

**Divisão de responsabilidade.** `AttackDirector` decide *quando*; `VagoneiroBoss` decide *o que acontece com a lista*. Toda mutação passa por `occupySlot`/`clearSlot`/`insertAtHead`/`createCycle`, e o director não tem outra forma de tocar num slot — a regra da seção 3.0 é sustentada pela estrutura, não por disciplina.

Os seis ataques, na adaptação linear (nenhuma geometria circular foi reintroduzida):

1. **Corrente Restritiva.** Origem escolhida uma vez, do slot onde o player está; telegraph de 1.2s com `effects/corrente-restritiva.png` (3x2 de 488px, alternando elo frio/incandescente) pendurado nas conexões até `next` e `prev`. Na execução, `|índiceDoPlayer − origem| > 1` é exatamente "acesso por índice": puxão de volta (tween), 1 de dano e a legenda **"Sem next, sem acesso."**. O parâmetro `origin` (`head`/`tail`) é o que faz a Fase 2 reusar este mesmo método em vez de duplicá-lo.
2. **Vagão-Fantasma.** A sequência `tremor → falling` é código dos Módulos 0–13, intocado. O que o Módulo 14 acrescenta é o `Player.onSupportLost`, disparado no frame exato em que `isSolid` vira `false`, cobrando dano de combate — e a queda subsequente cobra pelo `onDeath`, que era desde a seção 10.2 um ponto de extensão reservado para isto. Não há hitbox nova. A janela de invulnerabilidade de 1s impede que os dois sistemas cobrem duas vezes pelo mesmo erro (a queda de um vagão até a linha de morte leva ~0.62s).
3. **Empurrão de Cabeça.** Relabel puro: a ocupação alvo é calculada sobre um array e realizada **só nas diferenças** — conteúdo homogêneo, então derrubar e reconstruir oito vagões produziria um frame idêntico ao custo de oito tweens de spawn e oito correntes reiniciadas. O vagão da ponta oposta é destacado da lista **imediatamente** (`dropOffEndOfLine`, que separa `slot.vagao = null` da animação de queda) para que o relabel possa reocupar o slot no mesmo frame; `Vagao.playFall` foi extraído de `playVagaoFantasmaSequence` justamente para isso, e os dois caminhos rodam o mesmo código de queda. **Nenhum `Vagao` é reposicionado** — há teste que compara a posição de cada vagão com a coordenada fixa do seu slot depois do empurrão. Quem se move é só o player, por tween, para o topo do collider do slot de destino (lido do `platformHitbox`, o mesmo ponto em que um pulo o depositaria). Boss fica `exposed` 1.5s.
4. **Lista Dupla.** Ao entrar na Fase 2: `boss.trilhoReversivel = true`, `player.reverseAllowed = true`, correntes douradas. O dourado é `ColorFilter.mode(chainGoldTint, modulate)` sobre os mesmos elos — multiplica o ferro cinza pelo dourado preservando o sombreado da arte, sem segundo asset. Na Fase 1 o `prev` é uma **parede**, não dano: `next` corre para a esquerda neste trilho (slot 0 é a cabeça, no maior x), então andar para a direita é voltar pelo `prev`, e o movimento é limitado na fronteira do nó atual. Ensinar a restrição sem punir a curiosidade.
5. **Nó Órfão.** `NoOrfao extends Vagao` com `linked = false`, instanciado **em nenhum slot** — não é uma flag fingindo: ele não está em `track.slots`, logo não tem `next`/`prev` nem índice, `occupySlot`/`clearSlot` (que endereçam por índice) não têm como alcançá-lo, e nenhum observador do trilho o enxerga. É sólido (reusa o collider do vagão). O resolvedor de ataque checa `linked` **antes de tudo**, inclusive antes da janela `exposed`: miss garantido, sem dano e sem stun. Calibrado nos mesmos ≈45px (corpo em 409px nativos das linhas 130..538, o resto do canvas é poeira) — e a geometria resultante bate com a dos vagões (teto 55.5px vs 56.2px acima da âncora), então o collider padrão serve sem caso especial.
6. **Ciclo Corrompido.** Um ponteiro: `slot[7].next = slot[3]`. A geometria dos slots não muda — há teste que compara todas as coordenadas antes e depois. O arco roxo (`effects/ciclo-corrompido.png`, 3x2 fatiado com `floor` em 591x443, aceitando a sobra de 1–2px conforme a nota do asset) é desenhado *por cima* do trilho reto. O slot 3 é escolhido porque dá µ=3 e λ=5: os dois ponteiros se encontram **dentro** do laço num nó que visivelmente **não** é a entrada, que é o que faz a segunda metade da demonstração valer a pena. A demonstração é automática e percorre `slot.next` de verdade (inclusive o ponteiro corrompido): lento ciano 1 passo, rápido magenta 2 passos, encontro piscando branco, terceiro marcador dourado saindo da cabeça junto com o lento, segundo encontro = entrada, destacada 2s. O jogador só precisa **reconhecer e acertar**. Acerto → `next = null`, `exposed` por 3s. Erro → miss + stagger.

**HUD.** `CombatHud` (viewport, abaixo do `DebugHelpOverlay`) mostra a barra de HP do Boss com as duas linhas de limiar desenhadas sobre ela, os pips do player, e o ticker de **operação em execução** — alimentado por `boss.onOperation`, disparado por toda mutação real (`occupySlot(3)`, `slot[7].next = null`, `insertAtHead(novoVagao)`, `pop() em slot[7]`), de modo que o HUD não tem como divergir do que a lista fez. Legendas grandes ficam reservadas para as linhas de ensino ("Sem next, sem acesso.", "Nó órfão — sem next, sem prev.", "Ciclo rompido!"); o aviso de dano vai para o ticker, porque disparando um frame depois ele sobrescreveria a lição toda vez.

**Teclas novas:** `J` atacar, `K` forçar o próximo ataque da rotação, `P` −3 HP no Boss (para alcançar as fases sem jogar a luta inteira). As teclas antigas seguem idênticas.

### 14.4 Como isto foi validado

- **`test/boss_combat_test.dart`** (26 testes): a grade 6x4 de 300px e as células (2,4)/(2,5) vazias medidas no PNG real; as constantes de calibração reconferidas contra o arquivo e o alvo de 176px; a doca com o tampo em `visibleFootY` e a sombra sem gap; as bandas de fase nos limites exatos; invulnerabilidade fora da janela; **posição de cada vagão inalterada depois do empurrão**; o relabel com buraco no meio e a partir da cauda; Fase 2 ligando reversibilidade + dourado + órfão; o órfão como miss garantido mesmo com o Boss exposto; o algoritmo de Floyd achando o slot 3 no ponteiro que o trilho realmente tem; a Corrente Restritiva ponta a ponta (dano + puxão + legenda); e o ticker de operações.
- **`test/scene_snapshot_tool.dart`** ganhou `SNAPSHOT_PHASE=2|3` e `SNAPSHOT_CICLO=true`, que dirigem a luta pelo gatilho real de transição de fase antes do frame ser tirado — o que se revisa é o que o jogador veria.
- Conferido em render: Boss caricato apoiado no estrado com sombra de contato e sem gap; correntes douradas e Nó Órfão pairando acima do trecho entre os slots 4 e 5 na Fase 2; arco roxo do slot 7 ao slot 3 por cima do trilho reto, com o anel de destaque na entrada do ciclo.

### Critérios de aceite

- [x] Boss ancorado sobre a Doca do Boss, com sombra de contato e tonalidade fria como vagões/correntes.
- [x] Novo `sprite.png` caricato, grade 6x4 e mapeamento de estados da seção 4.1 preservados.
- [x] Corrente Restritiva com dano real e legenda "Sem next, sem acesso.".
- [x] Vagão-Fantasma contando como dano de combate.
- [x] Empurrão de Cabeça relabelando slots sem deslocar nenhum `Vagao`; quem se move é o player.
- [x] Lista Dupla com reversibilidade e corrente dourada na Fase 2, reaproveitando os mesmos ataques via `origin`.
- [x] Nó Órfão sempre em miss.
- [x] Ciclo Corrompido demonstrando Floyd automaticamente.
- [x] HP/fases, janela `exposed`/invulnerabilidade e HUD de operação em execução.
- [x] Nenhum critério das seções 11, 12 e 13 regrediu.

---

## 15. Módulo 15 — Upgrade do Player (concluído)

Quatro frentes sobre o Player já existente, **sem tocar na lógica interna do Boss** (HP/fases, janela `exposed`, ataques, HUD). O único ponto novo de contato com o combate é um caminho válido de dano — o golpe de espada — que termina no mesmo `AttackDirector.resolvePlayerAttack()` → `boss.takeDamage()` de antes.

Código novo em `lib/game/player/`: `player_animations.dart` (enum de estados + tabela de folhas, sem Flame), `dash_controller.dart` e `attack_controller.dart` (lógica pura, testável sem subir o jogo), `player_fx.dart` (efeitos pré-carregados), `sword_hitbox.dart` e `arena_wall.dart`.

### 15.1 Assets e estado de animação (Frente 1)

**A calibração da seção 2.3 teve de ser refeita, não só preservada.** Os `west.png`/`east.png` no disco foram regenerados junto com as folhas novas: o personagem ocupa 87px da célula de 256px (as constantes do Módulo 11 registravam 230px e padding de 9px). Mantidas as regras — 110px na tela, pé na base do bbox real — os números passam a ser:

| | Antes (Módulo 11) | Agora |
|---|---|---|
| Frame de referência | `walk` frame 0 | **`idle` frame 0** (a pose de repouso real) |
| Altura opaca nativa | 230px | **92px** (linhas 108..199) |
| Padding sob o pé | 9px | **56px** (pé na linha 199 em **todas** as folhas) |
| `playerDisplayScale` | 110/230 | **110/92** = 1.1957 |
| Altura renderizada | 110px | **110px** |

**Normalização por folha (`PlayerSheetSpec.artScale`).** As folhas compartilham célula e linha de base, mas **não** a escala de desenho — `jump_rise` desenha o personagem ~1.6x maior que `idle`. Renderizar tudo numa escala só faria o player "crescer" ao pular. Cada folha é dividida pelo próprio fator:

| Folha | `artScale` | Como foi medido |
|---|---|---|
| idle | 1.00 | referência |
| walk | 87/92 = 0.946 | razão das alturas opacas das poses em pé |
| dash | 1.10 | área de pele do rosto (única região com esse tom, escala com o quadrado do tamanho) + conferência visual da largura do capuz |
| jump_rise | 1.56 | idem |
| jump_fall | 1.17 | idem |
| double_jump | 1.23 | idem |
| attack1 | 1.10 | idem |
| attack2 | 1.16 | idem |

Nas folhas sem pose em pé, os valores são estimativas medidas (±5%), revisáveis em playtest — um número por folha, na tabela.

**Correção do offset do pé.** `playerVisualYOffset` tinha o sinal trocado desde o Módulo 11: com âncora `bottomCenter`, a borda inferior do frame fica em `position.y` e o pé visível fica `pad × scale` **acima** dela, então a arte precisa **descer** esse valor. O valor negativo subia a arte e deixava o pé `2 × pad × scale` acima do vagão — ~8px com o padding antigo (passou despercebido), ~134px com o novo. O offset agora é recalculado a cada troca de folha e durante o squash (`_applyVisualScale`), sempre sobre a escala atual.

**Idle real.** O congelamento do frame 0 de `walk` foi removido (há teste que falha se `paused = true`/`currentIndex = 0` voltarem ao `player.dart`). Um único `SpriteAnimationComponent` troca de animação conforme o estado; a pose avulsa `jump-double.png` e o `_DoubleJumpVisual` (que apontavam para um arquivo inexistente) saíram.

**Prioridade de resolução do estado** (a cada frame, depois da física): ataque → dash → `doubleJump` (enquanto a animação de 0.51s roda) → no ar: `jumpRise` se `vy < 0`, senão `jumpFall` → no chão: `walk` ou `idle`.

### 15.2 Dash (Frente 2)

- **Binding:** `C` (botão próprio). O duplo toque direcional foi descartado porque qualquer correção rápida esquerda-direita viraria dash. Direção = input horizontal segurado, ou a direção olhada.
- **Parâmetros** (`dash_controller.dart`): distância 2.1 × 110 = **231px**, duração nominal **0.15s**, cooldown de **0.6s** a partir do início. Sem stamina/mana.
- **Por distância, não por tempo:** cada frame anda no máximo 32px (`playerDashMaxStep`); um frame longo só atrasa o dash, nunca o encurta nem atravessa uma parede de 80px.
- **Sem input vertical:** pulo, ataque e movimento são ignorados durante o dash.
- **No chão × no ar.** Um dash iniciado no chão é cancelado ao perder o piso (`lostGround`), e a gravidade assume. Um dash iniciado no ar é puramente horizontal — a gravidade fica suspensa durante ele. *Decisão:* as plataformas desta arena têm 55px de largura, então um dash só no chão seria cancelado em ~50px e não teria uso.
- **Parede:** a arena não tinha paredes; `ArenaWall` fecha as duas bordas horizontais (fora do canvas, 80px de espessura). A colisão empurra o player para fora e cancela o dash (`wall`).
- **Rastro:** um `dash-trail-west/east.png` (conforme a direção) a cada 0.03s, 30px atrás e 45px acima do pé.
- **Reservado:** `playerDashGrantsInvulnerability = false` e `Player.isDashInvulnerable` (sempre `false`), sem lógica.

### 15.3 Duplo salto (Frente 3)

- A física do Módulo 11/Mudança 3 fica intocada na subida (g = 1160, v0 = −580 → ápice de **145px**). Na queda, a gravidade é multiplicada por **1.2** (`playerGravityFor`): leitura de peso mais clara, mesmo ápice, mesma altura alcançável. O pior degrau da arena (+120px em 180px) continua alcançável — há teste que simula o arco.
- O burst usa `double-jump-east.png` para as duas direções (efeito simétrico), com o centro do anel (48, 65 nativos) ancorado nos pés no momento da ativação, como irmão no mundo (fica onde o pulo aconteceu).
- **Reservados:** `playerCoyoteTime` e `playerJumpBufferTime` (= 0, nada os lê).

### 15.4 Ataque com espada (Frente 4)

- **`J`** deixou de ser atalho de debug: o `onKeyEvent` não resolve mais nada; o player lê `J` como tecla segurada (borda de subida) e inicia um golpe. Quem decide se o Boss é atingido é a hitbox.
- **`AttackController`** (separado da física): o golpe 2 só encadeia até **0.35s** depois de o golpe 1 terminar, ou com a tecla apertada durante a recuperação do golpe 1 (a partir do pico); fora disso, volta ao golpe 1; depois do golpe 2, também volta ao golpe 1. Só no chão — no ar a entrada é ignorada (`attackAir` reservado). Durante o golpe, movimento/pulo/dash ficam travados; perder o piso cancela o golpe.
- **Hitbox real** (`SwordHitbox`, entidade própria, não o collider do pé): retângulo de **154px** (1.4 × 110) à frente × 90px a partir do pé, `inactive` fora dos frames de pico — **frames 3-4 do golpe 1, frame 4 do golpe 2** (contando a partir de 1). No máximo um acerto por alvo por golpe.
- **Arco de corte:** `sword-slash-arc.png` (west) / `sword-slash-arc-east.png`, linha 1 para o golpe 1 e linha 2 para o golpe 2, como filho do player, surgindo no primeiro frame de pico. É posicionado pelo centro do conteúdo desenhado de cada linha (não pelo centro da célula), na altura da lâmina.
- **Dano:** `Player.onSwordContact` → a arena filtra `VagoneiroBoss` → `attackDirector.resolvePlayerAttack()` → `boss.takeDamage(playerAttackDamage)` (= 1). Fora da janela `exposed`, o golpe conecta e dá `missInvulnerable`, exatamente como antes. `resolvePlayerAttack` só deixou de chamar a antiga `playAttackSwing()` (removida — a animação agora é do `AttackController`).

### 15.5 Teclas

| Tecla | Antes | Agora |
|---|---|---|
| `J` | dano direto (debug) | golpe de espada real |
| `C` | — | dash |
| `N` / `S` | preview de direções verticais | removidas |
| `H`, `X`, `K`, `P`, `R`, `M`, `L`, `0-7` | — | inalteradas |

### 15.6 Como isto foi validado

- **`test/player_upgrade_test.dart`** (31 testes): grade e contagem de frames de cada folha e de cada efeito, medidas no PNG; linha de base do pé em todas as folhas; constantes de calibração re-medidas no `idle` frame 0; nenhuma direção vertical em assets, enum ou código; fim do congelamento, com `idle` animando na escala exata; dash com distância exata (inclusive com frame longo), cooldown, cancelamento por parede e por queda, sem movimento vertical e com rastro; ápice ≈145px (simulado e em jogo) e alcance do pior degrau; sequência `jumpRise → jumpFall → doubleJump → jumpFall → idle` com burst nos pés; hitbox ativa só nos frames de pico; combo dentro e fora da janela; dano via `J` real chegando a `boss.takeDamage()` só com `isExposed`; `H`/`X`/`P`/`K` como antes.
- **`test/wagon_and_player_fx_test.dart`:** a pré-condição do teste de squash foi ajustada — o player nasce no ar, agora em `jumpFall` (com a escala da própria folha); a asserção final, de voltar **exatamente** a `playerDisplayScale` em repouso, ficou intacta.
- **`test/boss_combat_test.dart`:** sem alterações; passa inteiro.
- Conferido em render headless: `idle` apoiado no vagão, arco sobre a lâmina, `jump_rise`/`jump_fall` no mesmo tamanho do `idle`, burst no ponto de ativação, rastro atrás do dash.

### Critérios de aceite

- [x] Player possui `idle` real (asset próprio), substituindo o congelamento de frame de `walk`.
- [x] `west`/`east` (walk) e as folhas `idle`, `dash`, `jump_rise`, `jump_fall`, `double_jump`, `attack1`, `attack2` (`west`/`east`) carregadas e integradas; o jogo é estritamente lateral.
- [x] Dash com distância e cooldown parametrizáveis, sem input vertical, cancelável por colisão, com rastro.
- [x] Duplo salto com animação granular e burst no segundo impulso, com o ápice de ≈145px inalterado.
- [x] Espada: combo de 2 golpes, hitbox só nos frames de pico, arco de corte, dano via `boss.takeDamage()` respeitando `isExposed`.
- [x] `J` dispara o ataque real.
- [x] Sem regressão na calibração (110px, ápice ≈145px, pé na base do bbox real — agora com o offset corrigido) nem no combate do Vagoneiro.
- [x] Assets com fundo transparente e grade uniforme (verificado por teste). O player continua **sem** a tonalidade fria aplicada (como antes deste módulo); as folhas novas não exigem nada para recebê-la.
- [x] `hit`/`damaged`/`pulled`/`attackAir`/`death` reservados no enum, sem asset.

### 15.7 Correção — troca de direção no ar

Sintoma: ao pular e inverter a direção horizontal no ar, o personagem parecia continuar no sentido anterior por um tempo antes de responder; no chão a troca era imediata. Causa: o deslocamento horizontal já mudava no mesmo frame, mas a direção olhada (`_setFacing`) só era atualizada com o player no chão — a arte ficava virada para o lado antigo até a aterrissagem, o que se lia como atraso. Correção: a direção passa a acompanhar o input também no ar; numa troca só de direção, o ticker da folha nova herda `currentIndex`/`clock`/`elapsed` da anterior (as folhas `west`/`east` têm o mesmo timing), para a virada não reiniciar `jumpRise`/`doubleJump`. Física, velocidade e alcance do pulo não mudaram. Teste: `player_upgrade_test.dart` → *reversing mid-air turns and moves on the same frame*.

### Pendências conhecidas

- O `artScale` das folhas sem pose em pé é uma estimativa medida (±5%) — revisar em playtest.
- `double-jump-west.png` existe, mas não é usado (o burst é simétrico).
- `test/widget_test.dart` de template continua falhando (pendência da seção 13).
