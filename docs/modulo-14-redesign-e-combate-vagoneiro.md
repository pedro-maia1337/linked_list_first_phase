# Módulo 14 — Redesign do Vagoneiro, Prompts de Asset e Combate Jogável

**Stack:** Flutter + Flame
**Pré-requisito:** Módulos 0–13 (ver `boss-vagoneiro-design.md`) — slots fixos, máquina de estados do vagão, escala calibrada (player 110px / vagão ~45px / boss 176px), integração de cena.
**Este módulo resolve 3 problemas do pedido:** (1) boss solto sem apoio na arena, (2) arte do boss fora do tom caricato/8-bit do jogo, (3) os 6 ataques da fase estavam descritos assumindo trilho circular — aqui eles são reescritos para o trilho **linear** já implementado, simplificando o que ficava frágil na conversão.

---

## 1. Diagnóstico

### 1.1 Boss "flutuando"
O Módulo 13 integrou luz/sombra de **vagões e correntes** ao cenário, mas nunca deu ao Boss uma superfície própria — ele está parado sobre a rocha pintada no fundo, sem collider de chão, sem sombra de contato e sem nenhuma peça de cenário que o "ancore" no trilho. Visualmente ele lê como um sprite colado por cima da caverna (mesmo bug que o Módulo 13 já corrigiu para os vagões).

**Causa raiz:** não existe um asset de "doca do maquinista" — não é bug de física (o Boss não anda, não precisa de collider de gameplay), é ausência de um elemento de cenário + sombra de contato equivalentes ao que os vagões já têm.

### 1.2 Design fora do conceito do jogo
O `sprite.png` atual é um humanoide sombrio/realista (colete, quepe, correntes) — coerente com a *atmosfera* de Hollow Knight descrita na seção 5 do plano geral, mas o plano é explícito: **bosses são desenhados em tom cartoon/caricato, "vintage", estilo Cuphead**, contrastando com o mundo sério. O Vagoneiro atual não tem esse contraste — ele é só "mais um habitante sombrio da caverna", não uma personalidade cômica e ameaçadora ao mesmo tempo.

### 1.3 Ataques descritos para trilho circular
O pedido descreve telegraphs e execuções que presumem vagões dispostos em círculo (ex.: "corrente entre 2 vagões", "loop infinito no trilho", "coelho e tartaruga"). A implementação real é uma lista **linear** de slots fixos (Módulo 0–13, decisão deliberada para o player ter uma borda de queda no fim da linha — seção 10 do doc original). Refatoração necessária, ataque a ataque, na seção 4.

---

## 2. Redesign de Arte — Direção

**Conceito mantido:** o Vagoneiro continua sendo o "maquinista fantasma" que controla os vagões como nós de uma lista encadeada — ele não é substituído, é **recaricaturado**.

**Mudanças de direção:**
- Silhueta exagerada: cabeça grande, quepe desproporcional, mãos enormes (para vender o gesto de "puxar corrente" e "empurrar vagão"), tronco menor — proporção cartoon 2:1 cabeça:corpo, não humanoide realista.
- Expressão sempre legível a distância (sobrancelhas grossas, boca larga), trocando de pose para cada estado de combate — isso é o que falta hoje: `hit`/`exposed` no asset atual são sutis demais para "vender" o momento de punição ao jogador.
- Paleta consistente com a already-calibrada tonalidade fria do Módulo 13 (ameixa dessaturada H264–315) + olhos laranja-avermelhados como único ponto quente saturado, para o Boss continuar sendo o "farol" visual da cena.
- Resolução de pixel art idêntica ao pipeline existente (múltiplos de 256px por célula, sprite sheet em grade) — "8-bit/16-bit" aqui significa **pixel art legível e caricata**, não reduzir paleta de cor a ponto de quebrar a leitura do rosto a distância de gameplay.

### 2.1 Asset novo — Doca do Boss (resolve a seção 1.1)
Peça de cenário estática, sem collider de gameplay (Boss não se move), ancorada uma vez no setup, tratada com a mesma tonalidade fria + sombra de contato que os vagões já recebem.

---

## 3. Prompts de Geração de Assets

Todos os prompts assumem o mesmo pipeline: **pixel art 2D, vista lateral, fundo transparente, grade de células quadradas, estilo caricato/cartoon "vilão de trem" com contraste tenebroso-cômico**, para bater com a paleta já calibrada (ameixa dessaturada H264–315 + acentos laranja-avermelhados quentes).

**Duas exigências valem para TODOS os prompts abaixo e não podem ser removidas ao adaptar/gerar variações:**

1. **Transparência real (alpha), não fundo verde/branco/xadrez.** É `PNG` com canal alfa de verdade — nenhum pixel de "fundo" deve sobrar nas bordas do personagem (sem halo/matte residual), porque o Módulo 13 aplica `ColorFilter` e luz aditiva diretamente sobre o alfa do sprite (seção 13.2 do doc base); um fundo mal recortado vaza tonalidade errada por trás da silhueta. Sempre reforçar no prompt: `true alpha transparency, no background color, no checkerboard, no matte/fringe around edges` e, no negativo, `solid background color, green screen, white background, background halo, semi-opaque edges`.
2. **Espaçamento (padding) dentro de cada célula — é sprite de jogo, não ilustração a sangrar.** O conteúdo opaco de cada frame precisa ter **margem de respiro** dentro da célula/canvas declarada (não pode tocar as bordas), por dois motivos técnicos já documentados: (a) o collider e a ancoragem são medidos pelo bounding box opaco real do frame, não pelo canvas (seção 2.3 e 13.5 do doc base) — sprite sem padding distorce essa medição; (b) frames com poses distintas (soco, corrente puxando) tendem a esticar membros para fora do quadro se não houver margem reservada de antemão. Sempre reforçar no prompt: `character contained within the frame with clear padding/margin on all sides, not touching or bleeding off the canvas edges, room for outstretched limbs during action poses`.

### 3.1 Sprite principal do Boss (substitui `boss/sprite.png`)
```
Pixel art character sheet, side-view, 2D game sprite, caricatured cartoon villain
train conductor, exaggerated proportions (oversized head and gloved hands, small
torso), long dark coat with brass buttons, huge tilted conductor cap, thick
comic eyebrows, wide expressive mouth, glowing orange-red cartoon eyes,
coiled iron chain wrapped around one forearm, gothic dark-fantasy palette
(desaturated plum/violet shadows, warm amber highlights), flat clean pixel
shading, thick dark outline for readability at distance, transparent
background, sprite sheet grid 6 columns x 4 rows, 256x256 px cells,
row 1 = idle breathing loop (6 frames), row 2 = observing with spyglass (4
frames) + chain-attack wind-up (2 frames), row 3 = comic stunned reaction
with spinning eyes/stars (4 frames, columns 5-6 empty), row 4 = exposed
vulnerable pose arms down mouth open (3 frames) + recovering shake-it-off
pose (3 frames). Consistent character proportions and palette across all
frames. True alpha transparency, no background color, no checkerboard, no
matte/fringe around edges. Character contained within each 256x256 cell
with clear padding/margin on all sides, not touching or bleeding off the
cell edges — leave room for outstretched arms during wind-up poses. No
background elements, no watermark, no text.
```
Negative prompt: `realistic proportions, photorealistic, horror gore, blur, 3D render, soft painterly shading, extra limbs, inconsistent palette between frames, solid background color, green screen, white background, background halo, semi-opaque edges, character touching frame border, cropped limbs`

### 3.2 Ataque de impacto (substitui/gera `boss/soco.png`)
```
Pixel art sprite sheet, same caricatured train-conductor boss character as
reference, side view, exaggerated wind-up punch/train-horn-blow animation,
4x4 grid, 256x256 px cells, 16 frames total: frames 1-4 anticipation (leaning
back, chain coiling on arm), frames 5-8 whistle blast (cheeks puffed, steam
cloud, comic sound-effect lines), frames 9-12 forward lunge attack, frames
13-16 recovery/overextended stumble. Same palette and outline weight as the
idle sheet. True alpha transparency, no background color, no checkerboard,
no matte/fringe around edges. Character contained within each 256x256 cell
with clear padding/margin on all sides — reserve extra margin specifically
for the lunge frames (9-12), where the arm and chain extend furthest, so
nothing is cropped by the cell border. No text.
```
Negative prompt: `solid background color, green screen, white background, background halo, semi-opaque edges, limbs or chain cropped by frame border, character touching cell edge`

### 3.3 Telegraph — Corrente Restritiva (chains piscando)
```
Pixel art VFX sprite sheet, glowing chain link, side view, loop animation,
6 frames of 64x64 px, alternating warm red pulse and neutral iron color,
sharp pixel-art glow (no soft blur). True alpha transparency, no background
color, no checkerboard, no matte/fringe around the glow edges. Chain link
and glow contained within each 64x64 cell with clear padding on all
sides — the glow's outer falloff must fully fade to transparent before
reaching the cell border, not get clipped by it. Matches art style of an
existing gothic dark-fantasy pixel game with iron chain decorations. No
text.
```
Negative prompt: `solid background color, green screen, checkerboard background, glow clipped at frame edge, hard-edged glow cutoff, semi-opaque background haze`

### 3.4 Doca do Boss (cenário)

> ⚠️ **Regenerar — falha confirmada.** A versão recebida (`doca.png`) veio em **RGB sem canal alfa**: o "xadrez de transparência" foi pintado como textura real dentro da própria imagem (inclusive por cima do metal da plataforma), não é transparência de verdade. Como o xadrez se mistura com a textura enferrujada do objeto, não dá pra separar isso depois por script sem destruir parte da arte (testado: um flood-fill de fundo apagou pedaços do tampo da doca). É um problema de origem — a ferramenta usada não exportou alfa real — então precisa gerar de novo.

```
Pixel art background prop, small iron dock/platform for a train conductor
to stand on, riveted metal plate with two support chains anchoring into
rock wall, gothic dark-fantasy cave palette (desaturated plum shadows, warm
amber rim light), side view, static single image (not animated), sized to
match an existing 176px-tall character standing on it. Export as PNG with a
REAL alpha channel (RGBA) — do not paint a checkerboard pattern as part of
the artwork to represent transparency, the background must be actual
alpha=0 pixels, verifiable in image metadata. No background color, no
matte/fringe around edges — this asset will be layered directly over
painted cave background art, so any residual background pixel or fake
checker texture will show as a visible artifact. Prop contained within the
canvas with clear padding/margin on all sides, not touching or bleeding off
the canvas edges. Matches the style of existing wagon-track chain anchor
props. No text, no characters standing on it.
```
Negative prompt: `solid background color, green screen, white background, painted checkerboard pattern, fake transparency texture, checker pattern on the metal surface, background halo, semi-opaque edges, drop shadow baked into image, prop touching canvas border`

### 3.5 Nó Órfão (vagão desconectado, fase 2)
```
Pixel art sprite, single lonely train wagon, side view, static idle pose,
subtly desaturated and slightly transparent/ghosted (60% opacity look)
compared to a normal wagon, no chain links attached on either side (chain
stubs broken/dangling), faint drifting dust particles around it, same
palette and proportions as an existing wagon sprite (~45px display height
reference). True alpha transparency, no background color, no checkerboard,
no matte/fringe around edges (including around the drifting dust
particles). Wagon and dust particles contained within the canvas with
clear padding/margin on all sides, not bleeding off the edges. No text.
```
Negative prompt: `solid background color, green screen, checkerboard background, dust particles cropped at edge, wagon touching canvas border`

### 3.6 Loop/Ciclo Corrompido (arco de corrente entre slots não-adjacentes)

> ⚠️ **Regenerar — falha confirmada.** A versão recebida (`ciclo_corrompido.png`) tem canal alfa presente, mas a maior parte do brilho roxo está com alfa parcial cobrindo uma textura de xadrez pintada dentro do próprio brilho (não é só a borda suave esperada de um glow — o corpo inteiro do efeito tem o quadriculado "por dentro"). É o mesmo problema de origem do item 3.4: a ferramenta simulou transparência visualmente em vez de exportar alfa real e limpo.

```
Pixel art VFX, long curved chain arc glowing purple, pulsing loop animation,
6 frames, sized to arc over a horizontal train track connecting two
non-adjacent points, sharp pixel glow, dark-fantasy palette accented with
saturated violet/magenta, tileable/stretchable along its curve. Export as
PNG with a REAL alpha channel (RGBA) — do not paint a checkerboard pattern
as part of the artwork to represent transparency; the glow's soft falloff
must be true graduated alpha (verifiable in image metadata), not a
checker-textured purple shape. No background color, no matte/fringe around
the glow edges. Arc and glow contained within the canvas with clear padding
on all sides — the glow's outer falloff must fully fade to transparent
before reaching the canvas border. No text.
```
Negative prompt: `solid background color, green screen, painted checkerboard pattern inside the glow, fake transparency texture, checkerboard visible through the effect, glow clipped at frame edge, hard-edged glow cutoff`

---

### 3.7 Mapa de Slicing dos Spritesheets Entregues

**Decisão de entrega: os 6 assets ficam como folhas únicas (spritesheet), não separados em um arquivo por frame.** Depois da normalização de grade feita no tratamento (recorte por blob + recentralização com padding uniforme), cada frame de uma mesma animação passou a ocupar uma célula de **tamanho fixo idêntico**, com a personagem sempre no mesmo ponto de ancoragem relativo à célula. Separar em arquivos individuais agora jogaria fora esse ganho — cada recorte teria bounding box diferente (poses maiores vs. menores) e o agente precisaria guardar um offset de âncora por frame para o pé não "flutuar" entre animações. Mantendo a folha única, o Boss usa **uma textura carregada uma vez** e cada frame é obtido por posição de grade fixa (`SpriteSheet` do Flame ou equivalente `srcPosition`/`srcSize`), que é o padrão nesse tipo de engine e o mesmo modelo já usado nos Módulos 0–13 para os vagões.

O agente implementador **não precisa adivinhar nem recalcular** nada disso — a tabela abaixo é o mapa exato de cada arquivo entregue:

| Arquivo | Canvas | Grade (col×lin) | Célula | Células válidas por linha | Uso |
|---|---|---|---|---|---|
| `boss_tratado.png` | 1800×1200 | 6×4 | 300×300 | linha0: 0–5 (idle) · linha1: 0–3 observando + 4–5 corrente-pronta · linha2: **0–3 apenas** (stunned; colunas 4–5 vazias/transparentes) · linha3: 0–5 (exposed/recovering) | `sprite.png` principal — idle/observing/chainAttack/hit-stunned/exposed/recovering (seção 4.1 do doc base) |
| `boss_soco_tratado.png` | 1504×1504 | 4×4 | 376×376 | todas as 16 células preenchidas | animação de ataque de impacto (anticipation → whistle → lunge → recovery, 4 por fase) |
| `corrente-restritiva_tratado.png` | 1464×976 | 3×2 | 488×488 | todas as 6 preenchidas | loop de telegraph da corrente (alterna cor neutra/vermelha) |
| `ciclo_corrompido_ok.png` | 1774×887 | 3×2 | **~591×443 (não perfeitamente inteiro — ver nota)** | todas as 6 preenchidas | loop do arco roxo pulsante (Ciclo Corrompido) |
| `doca_ok.png` | 1536×1024 | — (imagem única, sem grade) | — | — | prop estático de cenário, ancorar uma vez sob os pés do Boss |
| `no_orfao_tratado.png` | 864×634 | — (imagem única, sem grade) | — | — | vagão órfão já com efeito fantasma (dessaturado + ~60% opacidade) aplicado |

**Nota sobre `ciclo_corrompido_ok.png`:** essa folha não passou pelo mesmo script de renormalização das outras (foi aceita direto após a regeneração, pois já tinha padding seguro e transparência real — seção anterior desta conversa). A divisão 1774/3 e 887/2 não fecha em número inteiro; ao fatiar, arredonde para baixo (`floor`) e aceite ~1-2px de sobra na borda direita/inferior da última coluna/linha — irrelevante para um efeito de brilho (sem íris de personagem para desalinhar) e não vale o custo de renormalizar de novo.

**Como o agente deve fatiar (Flame):**
```dart
final bossSheet = SpriteSheet(image: bossImage, srcSize: Vector2(300, 300));
final idleFrames = List.generate(6, (i) => bossSheet.getSprite(0, i));
final stunnedFrames = List.generate(4, (i) => bossSheet.getSprite(2, i)); // só 0-3, não iterar até 5
```
Mesma lógica para `boss_soco_tratado.png` (`Vector2(376,376)`, 4×4 cheio) e `corrente-restritiva_tratado.png`/`ciclo_corrompido_ok.png` (`Vector2(488,488)` e `Vector2(591,443)`, 3×2 cheio). `doca_ok.png` e `no_orfao_tratado.png` são carregados como sprite único, sem `SpriteSheet`.

---

## 4. Refatoração dos Ataques (circular → linear, simplificados)

Princípio geral: **nenhuma geometria muda** (trilho continua linear, seção 3.0 do doc original preservada). Onde o design pedia comportamento "circular", a adaptação é sempre uma de duas saídas: (a) o comportamento já funciona igual ou melhor em linha reta, ou (b) o efeito é recriado como um **overlay visual/lógico** sobre a lista linear, sem mexer na física do trilho.

### 4.1 Fase 1 (100–66%)

**① Corrente Restritiva**
- *Original (pedia "entre 2 vagões" sem especificar layout):* já funciona 1:1 em linha — não precisa de círculo.
- **Regra:** o Boss escolhe um slot `origem` (onde o player está ou deveria estar) e telegrafa (pisca vermelho 1.2s) a corrente até o(s) slot(s) **adjacente(s)** (`next`/`prev` imediatos). Se o player pular para um slot com `|índiceDestino − índiceOrigem| > 1` (tentando "acesso por índice"), a corrente o puxa de volta ao slot de origem e aplica dano.
- **Simplificação real:** em vez de calcular a corrente mais próxima do player a cada frame, o Boss só arma esse ataque quando o player está parado num vagão específico — telegraph nasce ali, não precisa rastrear todas as correntes do trilho.
- **Feedback:** legenda "Sem `next`, sem acesso." (fade in/out 1.5s) no momento do puxão.

**② Vagão-Fantasma**
- Já implementado visualmente (Módulo 0–13). Único trabalho deste módulo é **ligar dano real**: se o player está sobre o slot quando ele entra em `falling`, perde suporte (já ocorre) e o dano vem do `FallDeath` já existente — não precisa de hitbox nova, é reaproveitar o gatilho de queda como dano de combate (ver seção 5.4).

**③ Empurrão de Cabeça (`insertAtHead`)**
- *Original:* "empurra todos, incluindo o jogador, para trás" — presume vagões deslizando fisicamente, o que o modelo de slots fixos proíbe (nada se desloca de um slot para outro, seção 3.0 do doc original).
- **Adaptação (sem violar slots fixos):** o Boss ocupa o slot 0 com um vagão novo; todo o conteúdo lógico dos slots 0..N-2 é **relabelado** para 1..N-1 (troca de conteúdo via `occupySlot`/`clearSlot`, não movimento de componente — exatamente como o sistema já funciona). O último slot, se cheio, "cai do fim da linha" (dispara sua própria sequência de `falling`, ensinando que a lista tem tamanho finito). Se o player estiver sobre um vagão afetado, ele é deslocado suavemente (tween de posição, não física) para a posição do **novo** slot que aquele conteúdo ocupa — vendido como "empurrão" mesmo sem o vagão físico se mover, porque quem se move é só o player, sincronizado com a troca.
- **Telegraph:** apito + luz na cabeça do trilho (já previsto).
- **Janela de punição:** Boss fica `exposed` 1.5s no slot 0 novo (já previsto, sem mudança).

### 4.2 Fase 2 (65–33%)

**④ Lista Dupla (Reversão)**
- *Original:* presumia movimento bidirecional novo — em trilho linear isso é natural, não exige círculo.
- **Regra:** flag `boss.trilhoReversivel = true`; correntes ficam douradas; o Vagoneiro passa a poder disparar Corrente Restritiva e Empurrão a partir de **qualquer ponta** (antes só fazia sentido a partir da cabeça). O player ganha a opção de recuar pelo `prev`, mas a regra de adjacência da Corrente Restritiva (①) não muda — o ensinamento é "2 ponteiros, navegação nos dois sentidos", não "regras diferentes".
- **Simplificação:** não é necessário duplicar toda a lógica de ataque — Corrente Restritiva e Empurrão de Cabeça recebem um parâmetro `origem` que agora pode ser `head` ou `tail`; o resto do código é reutilizado.

**⑤ Nó Órfão**
- *Original:* já funciona sem depender de topologia circular.
- **Regra:** um `Vagao` extra é instanciado numa posição **fora da sequência de slots numerados** (ex.: um pouco acima do trilho, entre dois slots), com flag `linked = false`. Ele é sólido (bloqueia caminho/pulo), mas **não está no `LinkedList` de slots** — não tem `next`/`prev`, não pode ser `occupySlot`/`clearSlot`'d pelo Boss.
- **Erro conceitual:** se o player ataca esse nó, o resolvedor de combate (seção 5) checa `linked == false` → sempre `miss` (sem dano, sem stun, com VFX de "clang" vazio) — ensina que nós fora da cadeia estão inacessíveis mesmo estando fisicamente visíveis.

### 4.3 Fase 3 (32–0%) — Ciclo Corrompido

Este é o ataque que mais dependia de topologia circular real ("o último vagão se conecta de volta a um do meio, criando loop"). Adaptado para não exigir geometria circular:

- **O "loop" é lógico, não físico.** O trilho continua reto; o que muda é o ponteiro lógico: `slot[N-1].next = slot[k]` (um índice do meio) em vez de `null`. Visualmente isso é representado por um **arco de corrente roxa** desenhado por cima do trilho, ligando o fim ao slot `k` (asset da seção 3.6) — sem mover nenhum vagão.
- **Simplificação do "coelho e tartaruga":** pedir ao jogador para executar mentalmente o algoritmo de Floyd em tempo real durante uma luta de boss é pouco divertido e pouco legível. Em vez disso, o jogo **demonstra o algoritmo visualmente e automaticamente**, e o jogador só precisa **reconhecer e atacar o resultado**:
  1. Dois marcadores de luz percorrem a cadeia a partir da cabeça, no ritmo do "passo" do Boss: um **lento** (ciano, avança 1 slot por passo) e um **rápido** (magenta, avança 2 slots por passo, entrando no loop antes).
  2. Quando se encontram dentro do loop, os dois piscam branco (telegraph de "achei o loop").
  3. Um terceiro marcador (dourado) nasce na cabeça e anda 1 slot por passo **junto** com o marcador lento (que continua do ponto de encontro); o slot onde os dois se encontram de novo é o **nó de entrada do ciclo** — ele pisca roxo forte e fica destacado por 2s.
  4. O player tem essa janela para atacar exatamente aquele slot. Acerto → corrente do loop se rompe (`slot[N-1].next` volta a `null`), Boss fica `exposed` total por 3s (já previsto). Erro (ataca outro slot) → miss, sem dano ao Boss, pequeno stagger no player como custo de erro.
- Isso preserva o ensinamento real do algoritmo (o jogador vê os dois ponteiros e por que o segundo encontro marca a entrada do ciclo) sem exigir que ele calcule nada sob pressão de combate — a dificuldade fica na **observação e timing do ataque**, que é o que a diretriz "importante é ficar interativo e divertido" pede.

---

## 5. Prompt para o Agente Implementador

Este prompt consolida tudo (diagnóstico, redesign, refatoração dos ataques) numa única instrução autocontida, pronta para ser repassada a um agente de codificação (ex.: Claude Code) que tenha acesso ao repositório Flutter/Flame do projeto e aos documentos `boss-vagoneiro-design.md` e `plano-jogo-estruturas-dados.md`.

```
Contexto: você está trabalhando no boss "O Vagoneiro" (fase Lista Encadeada) do
jogo DataQuest: Codex das Estruturas (Flutter + Flame). Os Módulos 0–13 já
implementaram estrutura, movimentação, animações, escala e integração visual
de cena (ver boss-vagoneiro-design.md, seções 1–13). Este trabalho NÃO deve
regredir nada disso: todos os critérios de aceite das seções 11, 12 e 13
daquele documento continuam valendo e a suíte de testes existente
(test/scene_integration_test.dart etc.) precisa continuar passando.

Sua tarefa tem três frentes, todas necessárias para tornar a fase jogável de
verdade (hoje o boss não causa nem recebe dano real):

FRENTE 1 — Corrigir o boss "solto" na arena
O Vagoneiro está posicionado sobre o fundo pintado da caverna sem nenhuma
peça de cenário sob ele, sem sombra de contato e sem a tonalidade
fria/iluminação que já foi aplicada a vagões e correntes no Módulo 13. Crie
um asset de cenário "doca do boss" (plataforma/base de metal ancorada na
parede, no mesmo estilo dos anchors de corrente já existentes em
wagons/spritesheets/sprite_anchor_left.png e sprite_anchor_right.png) e
integre-o exatamente como os vagões: contact-shadow.png escalado para os
176px de altura do boss, sem gap; camada de tonalidade fria (mesma cor e
opacidade usadas em vagões/correntes, seção 13.2); nenhuma mudança de
posição, escala ou colisão do boss em si — é acabamento visual, igual ao
Módulo 13.

FRENTE 2 — Substituir a arte do boss por uma versão caricata
O sprite.png atual é um humanoide sombrio/realista, o que contraria o
pilar de arte do jogo (seção 5 do plano-jogo-estruturas-dados.md): bosses
devem ser caricatos/cartoon, tipo Cuphead, em contraste cômico com a
atmosfera séria do mundo. Os 6 assets já foram gerados, tratados (fundo
transparente real verificado, grade renormalizada com padding uniforme por
frame) e aprovados — use-os como estão, EXATAMENTE conforme o mapa de
slicing da seção 3.7 (arquivo, tamanho de célula, colunas/linhas, células
vazias por linha). Não separe as folhas em arquivos individuais por frame:
fatie por posição de grade em runtime (SpriteSheet/srcSize), porque a
normalização já deixou cada frame com âncora consistente dentro da própria
célula — separar em arquivos jogaria isso fora e obrigaria a guardar um
offset de âncora por frame. Preserve o mapeamento de estados (idle/
observing/chainAttack/hit-stunned/exposed/recovering) descrito na seção
4.1 do doc base ao ligar cada célula da grade ao enum BossState — troque a
arte, não a estrutura do enum nem os pontos de disparo (debugPlayHit(),
debugPlayExposed()) já existentes.

FRENTE 3 — Implementar combate e fases real (hoje é só visual)
Hoje o boss não tem HP, não causa dano real e o player não pode feri-lo.
Implemente, seguindo a refatoração dos 6 ataques descrita na seção 4 deste
documento (adaptada do design original de trilho circular para o trilho
LINEAR de slots fixos já existente — NÃO reintroduza geometria circular em
lugar nenhum):

1. Sistema de HP e fases do boss com os limiares 100–66% / 65–33% / 32–0%
   (Fase 1/2/3), disparando eventos de transição de fase.
2. Corrente Restritiva: telegraph de 1.2s piscando a corrente entre um
   slot de origem e seus vizinhos imediatos (next/prev); se o player estiver
   fora do slot adjacente quando o ataque executa, puxe-o de volta ao slot
   de origem, aplique dano, e mostre a legenda "Sem next, sem acesso."
3. Vagão-Fantasma: a sequência tremor->falling já existe — apenas conecte
   a perda de suporte físico a dano real de combate (não só o
   onPlayerDeath() cosmético que já existe para queda).
4. Empurrão de Cabeça: insira um vagão novo no slot 0 relabelando o
   conteúdo lógico dos slots existentes um índice adiante via
   occupySlot/clearSlot (SEM mover fisicamente nenhum componente Vagao —
   essa regra do doc base seção 3.0 é inviolável); se o player estiver
   sobre um slot afetado, reposicione só o player (tween) para acompanhar
   a nova posição lógica do conteúdo; se o último slot já estava ocupado,
   dispare a queda dele em vez de estourar o trilho; deixe o boss exposto
   por 1.5s no slot 0 recém-criado.
5. Lista Dupla: ao entrar na Fase 2, ative uma flag de reversibilidade que
   permite os ataques 2 e 4 se originarem de qualquer ponta do trilho e
   permite o player se mover para trás (prev); troque a cor visual das
   correntes para dourado. Não duplique a lógica dos ataques — parametrize
   a origem (head/tail) e reaproveite.
6. Nó Órfão: instancie um vagão fora da sequência numerada de slots
   (sem next/prev, flag linked=false), sólido para colisão mas nunca
   afetável por occupySlot/clearSlot; qualquer ataque do player contra ele
   deve resultar em miss garantido (sem dano, sem stun), com feedback
   visual de "clang vazio".
7. Ciclo Corrompido: implemente como ponteiro lógico (slot[N-1].next
   apontando para um slot do meio) mais um arco de corrente roxa desenhado
   por CIMA do trilho linear existente — não altere a geometria física dos
   slots. Em vez de exigir que o jogador calcule o algoritmo de Floyd em
   tempo real, rode uma demonstração visual automática (dois marcadores,
   lento e rápido, percorrendo a cadeia; ao se encontrarem, um terceiro
   marcador nasce na cabeça e anda junto ao lento até se reencontrarem —
   esse ponto final é o nó de entrada do ciclo) e então destaque esse slot
   por ~2s para o jogador atacar. Acerto: rompe o loop (next = null),
   expõe o boss totalmente por 3s. Erro: miss, pequeno stagger no player.
8. Ataques do player só causam dano real quando o boss está na janela
   "exposed"; fora dela, o boss é invulnerável (telegraph -> execução ->
   punição, no mesmo espírito de Cuphead descrito no plano geral).

Restrições que valem para as três frentes:
- Não altere nenhum valor da seção 2.3 do doc base (110px player / ~45px
  vagão / 176px boss / ~145px ápice de pulo) nem a máquina de estados do
  Vagão (spawning->idle->tremor->falling->removed).
- Reaproveite nomes e assinaturas já existentes sempre que possível
  (occupySlot, clearSlot, boss.debugPlayHit(), boss.debugPlayExposed(),
  onPlayerDeath()) em vez de recriar equivalentes.
- Ao final, verifique cada item da seção 6 (Critérios de Aceite) deste
  documento antes de considerar a entrega concluída.
```

---

## 6. Critérios de Aceite deste Módulo

- [x] Boss ancorado sobre a "Doca do Boss" (seção 2.1/3.4), com sombra de contato e tonalidade fria como vagões/correntes — sem mais leitura de "colado no fundo".
- [x] Novo `sprite.png` caricato substituindo o humanoide sombrio, mantendo grade 6x4 e mapeamento de estados da seção 4.1 do doc base.
- [x] Corrente Restritiva aplica dano real e legenda "Sem next, sem acesso." ao punir acesso por índice.
- [x] Vagão-Fantasma conta como dano de combate, não só queda cosmética.
- [x] Empurrão de Cabeça relabela slots sem violar a regra de "vagão nunca se desloca fisicamente"; player é reposicionado, não os vagões.
- [x] Lista Dupla ativa reversibilidade e corrente dourada ao entrar na Fase 2, reaproveitando os mesmos ataques com flag `bidirecional`.
- [x] Nó Órfão sempre resulta em miss (sem next/prev, fora do `LinkedList`).
- [x] Ciclo Corrompido demonstra o algoritmo de Floyd automaticamente e só exige do jogador reconhecer e atacar o slot final destacado — sem cálculo manual sob pressão.
- [x] HP/fases do Boss, janela `exposed`/invulnerabilidade fora dela e HUD de "operação em execução" (`occupySlot`, `next = null`, etc., conforme seção 4.2 do plano geral) implementados.
