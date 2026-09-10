# Skill: Flutter + Flame GameDev — Validação de GDD e Implementação

## 1. Objetivo

Atuar como um desenvolvedor GameDev especializado em **Flutter + Flame**, responsável por transformar documentos de design técnico/GDD em implementação consistente, modular, testável e compatível com a arquitetura do projeto.

Esta skill deve ser usada sempre que um documento de design, especificação de boss, mecânica, animação, entidade, cenário ou sistema do jogo for fornecido para implementação.

O agente deve tratar o documento como **fonte de verdade do escopo solicitado**, sem inventar requisitos ausentes.

---

## 2. Stack e princípios

### Stack principal

- Flutter
- Dart
- Flame
- SpriteAnimation / SpriteAnimationComponent
- Component / PositionComponent / Collidable quando necessário
- Assets organizados por domínio
- Testes unitários e testes de componentes quando aplicável

### Princípios

1. **Separação de responsabilidades**
   - Entidades não devem concentrar toda a lógica do jogo.
   - Boss, player, vagões, trilhos, animações e efeitos devem possuir responsabilidades claras.

2. **Estado explícito**
   - Estados de entidades devem ser representados por enums ou abstrações equivalentes.
   - Transições devem ser previsíveis e testáveis.

3. **Data-driven quando possível**
   - Configurações de animação, velocidades, duração e posições devem evitar hard-code espalhado.
   - **Neste projeto**, as coordenadas de arena (posições de slots do trilho, posição do boss, limite de morte/`deathZone`, âncoras decorativas) são exportadas por um motor gráfico externo em um arquivo `slots_config.json` (ver seção 11.1). Esse JSON é a **fonte de verdade das coordenadas** — nenhuma posição de slot, boss ou death zone deve ser hard-coded no código Dart; tudo deve ser lido do config no `onLoad` da arena.

4. **Assets desacoplados da lógica**
   - O código deve referenciar assets por caminhos centralizados/configurados.
   - Não misturar carregamento de sprites com regras de gameplay sem necessidade.

5. **Composição sobre acoplamento**
   - Preferir componentes pequenos e reutilizáveis.

6. **Preparar extensibilidade sem implementar escopo futuro**
   - Criar pontos de extensão quando o documento explicitamente pedir.
   - Não implementar mecânicas futuras apenas porque aparecem como contexto.

---

# 3. Regra fundamental: validar o documento antes de implementar

Antes de escrever código, faça uma **validação do documento**.

A validação deve responder:

- O que está dentro do escopo atual?
- O que está explicitamente fora do escopo?
- Quais entidades precisam existir?
- Quais estados existem?
- Quais animações existem?
- Quais transições são exigidas?
- Existem dependências entre entidades?
- Existem requisitos conflitantes?
- Existem requisitos incompletos ou ambíguos?
- O critério de aceite pode ser testado?

Nunca trate uma seção de contexto como requisito de implementação se o documento disser que ela está fora de escopo.

---

# 4. Matriz de requisitos

Antes da implementação, transformar o documento em uma matriz:

| ID | Requisito | Tipo | Escopo | Implementável? | Testável? |
|---|---|---|---|---|---|
| R01 | Entidade principal deve existir | funcional | atual | sim | sim |
| R02 | Animação idle | visual | atual | sim | sim |
| R03 | Sistema de dano | gameplay | futuro | não | não nesta etapa |

### Classificação

Cada requisito deve ser classificado como:

- `functional`
- `visual`
- `animation`
- `architecture`
- `gameplay`
- `asset`
- `integration`
- `future`
- `out_of_scope`

Se houver dúvida, marcar como:

`AMBIGUOUS — NEEDS DECISION`

Não inventar uma interpretação silenciosamente.

---

# 5. Validação de escopo

Sempre procurar explicitamente no documento:

- "fora de escopo"
- "não implementar"
- "etapa atual"
- "futuramente"
- "contexto"
- "opcional"
- "recomendável"
- "critério de aceite"

### Regra de prioridade

Use esta ordem:

1. Requisito explícito da etapa atual
2. Critério de aceite
3. Estados/animações explicitamente necessários
4. Arquitetura sugerida
5. Contexto conceitual
6. Itens futuros/opcionais

Itens futuros não devem virar implementação obrigatória.

---

# 6. Validação de consistência

Procurar conflitos como:

### Exemplo

O documento diz:

> Boss fica parado.

E posteriormente diz:

> Boss se move livremente pela arena.

Isso deve ser reportado como conflito.

Não escolher uma das versões sem informar.

### Checklist

- Nomes das entidades são consistentes?
- Nomes dos estados são consistentes?
- Enum e tabela possuem os mesmos estados?
- Animações mencionadas possuem estados correspondentes?
- Critérios de aceite correspondem ao escopo?
- Estrutura de arquivos corresponde às entidades?
- Há referências para arquivos/classes que não foram definidas?
- Uma mecânica depende de outra que está fora de escopo?
- Um estado possui transição definida?
- Existe estado final/removido?
- Assets necessários foram especificados?

---

# 7. Validação de máquinas de estado

Para cada entidade com estados, produzir mentalmente ou documentar:

```text
INITIAL
  ↓
SPAWNING
  ↓
IDLE
```

> **Nota (modelo de slots fixos):** neste projeto, entidades como `Vagao` **não possuem estado `WALKING`**. Um vagão não se desloca de um ponto A a um ponto B — ele aparece (`spawning`, fade-in/pop) diretamente na coordenada fixa do slot que ocupa (ver seção 11.1) e transiciona para `idle`. Se um documento de design mencionar `walking` para vagões, isso deve ser reportado como possível resquício de uma versão anterior do design (ver seção 6, validação de consistência), e não implementado silenciosamente. O estado de caminhada (`walk`) continua existindo normalmente para o `Player`, que se move livremente pelo cenário — a restrição acima é específica de entidades atreladas a slots fixos (vagões).

Para estados temporários:

```text
IDLE
  ↓
TELEGRAPH
  ↓
ACTION
  ↓
IDLE
```

Para remoção:

```text
IDLE
  ↓
TREMOR
  ↓
FALLING
  ↓
REMOVED
```

Validar:

- estado inicial;
- estados possíveis;
- transições;
- duração quando especificada;
- animação associada;
- evento que dispara a transição;
- estado final;
- comportamento quando a animação termina.

Nunca deixar uma animação temporária sem definir o próximo estado quando o documento exigir essa transição.

---

# 8. Validação específica de animações

Para cada animação, validar:

- nome;
- entidade;
- quantidade aproximada de frames, se especificada;
- loop ou não;
- duração;
- gatilho;
- estado correspondente;
- próximo estado;
- asset necessário;
- comportamento ao finalizar.

Exemplo:

```text
Vagao
  tremor
    duração: ~1.2s
    loop: sim durante telegraph
    próximo estado: falling

  falling
    loop: não
    próximo estado: removed
```

Não adicionar frames, efeitos ou comportamentos não solicitados como requisitos obrigatórios.

---

# 9. Validação de assets

Criar uma lista de assets esperados:

```text
assets/
  boss/
  wagons/
  player/
```

Para cada asset:

- verificar se existe;
- verificar nome;
- verificar formato;
- verificar transparência quando necessário;
- verificar resolução;
- verificar consistência visual;
- verificar se pode ser usado como sprite sheet;
- verificar alinhamento entre frames.

### Sprite sheets

Validar:

- tamanho uniforme dos frames;
- espaçamento;
- ausência de sobreposição;
- mesma escala;
- mesma orientação;
- mesma origem visual;
- ausência de anti-aliasing quando o estilo exigir pixel art.

### Config JSON de arena (`slots_config.json`)

Quando o projeto usar um arquivo de configuração exportado por um motor gráfico externo (posições de slots, boss, death zone, âncoras decorativas), validar antes de consumi-lo:

- `canvas.width`/`canvas.height` batem com as dimensões reais do background carregado;
- a quantidade de slots (`slots.length`) bate com o `slotCount` esperado pelo documento de design;
- os pares `next`/`prev` de cada slot formam um ciclo fechado e consistente (percorrer `next` a partir de qualquer slot deve retornar ao ponto de partida após `slotCount` passos);
- todas as coordenadas (`slots[i].x/y`, `boss.x/y`, `deathZone.y`) estão dentro dos limites do canvas;
- o índice do slot mais próximo do boss (tipicamente `slot 0`) corresponde ao que o documento de design descreve como ponto de spawn inicial;
- o JSON não é editado manualmente no código — qualquer mudança de layout deve vir de uma nova exportação do motor gráfico, não de um patch direto nos valores dentro do Dart.

Se qualquer uma dessas verificações falhar, reportar como `AMBIGUOUS — NEEDS DECISION` em vez de ajustar silenciosamente os valores no código.

---

# 10. Arquitetura Flutter + Flame

Uma arquitetura inicial recomendada:

```text
lib/
  game/
    boss/
    wagon/
    player/
    track/
    components/
    effects/
    config/
```

Exemplo:

```text
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
  circular_track.dart
  slot.dart

config/
  arena_config.dart          # carrega e tipa o slots_config.json
```

> Os diretórios permanecem os mesmos independentemente do modelo de movimentação adotado (slots fixos ou path livre) — o que muda é o conteúdo de `track/` e a existência de `config/arena_config.dart`, responsável por ler o JSON exportado pelo motor gráfico (ver seção 9, "Config JSON de arena") e expor os dados tipados (`slots`, `boss`, `deathZone`, `decorativeAnchors`) para o resto do jogo.

### Responsabilidades

`VagoneiroBoss`
- controlar os vagões (ocupar/limpar slots — ver seção 11.1);
- solicitar spawn;
- solicitar remoção;
- controlar estado próprio;
- expor pontos de extensão.

`Vagao`
- controlar estado próprio;
- executar animações;
- existir em uma posição **fixa**, herdada do `Slot` que ocupa (sem deslocamento próprio — ver seção 11.1 e 12);
- informar término de animação;
- não mantém `next`/`prev` diretamente — essas referências pertencem ao `Slot` (ver seção 11.1), não ao `Vagao`.

`Slot`
- representar uma posição fixa e pré-calculada do trilho (coordenada vinda do config JSON);
- manter as referências `next`/`prev` para o slot vizinho (a lista encadeada real vive aqui);
- manter uma referência opcional (`Vagao?`) para o vagão que o ocupa no momento, se houver.

`Player`
- controlar locomoção;
- controlar animações;
- responder a estados definidos pelo documento.

`CircularTrack`
- carregar a lista de `Slot` a partir do `arena_config.dart`/JSON;
- expor a lista encadeada de slots (percurso via `next`/`prev`);
- **não é responsável por mover vagões ao longo de uma curva** neste modelo — essa responsabilidade só reaparece se um documento de design futuro exigir movimentação livre (ver seção 12).

---

# 11. Lista encadeada: validação arquitetural

Quando o documento exigir uma lista encadeada real, não substituir silenciosamente por:

```dart
List<Vagao>
```

## 11.1 Modelo de slots fixos (padrão adotado neste projeto)

Neste projeto, a lista encadeada **não é formada pelos `Vagao`** — é formada pelos **`Slot`** (posições fixas e pré-calculadas do trilho, tipicamente exportadas de `slots_config.json` por um motor gráfico externo). Cada `Slot` é um nó permanente da estrutura; o `Vagao` é apenas um conteúdo opcional (`Vagao?`) que um slot pode ou não ter no momento.

```text
Boss
  ↓
head (Slot 0)
  ↓ next
Slot (vagao: Vagao?)
  ↓ next
Slot (vagao: null)   ← "buraco"
  ↓ next
Slot (vagao: Vagao?)
  ↓ next
... (fecha o ciclo de volta ao Slot 0)
```

Isso significa:

- Inserir um vagão = `slot.vagao = Vagao(...)` (ou `boss.occupySlot(index)`), **nunca** criar um novo nó na lista nem mover um vagão existente até aquela posição.
- Remover um vagão = `slot.vagao = null` (ou `boss.clearSlot(index)`); o `Slot` em si **permanece** na lista (`next`/`prev` continuam apontando para ele) — o que desaparece é o conteúdo, não o nó.
- A quantidade de `Slot`s é fixa e definida no setup da arena (a partir do JSON); não crescem nem encolhem dinamicamente.

Para lista dupla (Fase 2 do design, "Lista Dupla/Reversão" — fora de escopo até ser explicitamente pedido):

```text
prev ← Slot → next
```

Nesse caso, a "reversão" pode ser resolvida trocando qual referência (`next` ou `prev`) é usada para determinar "próximo" durante a varredura, sem necessidade de mover nenhum `Slot` ou `Vagao` fisicamente — ver seção 12 para a justificativa arquitetural completa.

### Invariantes

Validar:

- `head` aponta para o primeiro `Slot` (tipicamente o slot mais próximo do boss no config JSON);
- `slot.next`/`slot.prev` nunca é `null` (a lista de slots é circular por construção — diferente do conteúdo `Vagao?`, que pode ser `null`);
- `prev.next == current` quando aplicável;
- `next.prev == current` quando aplicável;
- remoção de um **vagão** (`clearSlot`) não deve alterar `next`/`prev` de nenhum `Slot` — apenas o campo `vagao` do slot afetado;
- inserção de um **vagão** (`occupySlot`) idem — não deve recriar nem realocar `Slot`s;
- não existem referências de `Vagao` órfãs (um `Vagao` sem `Slot` correspondente não deveria existir na cena).

Para ciclos intencionais entre slots (ex.: mecânica futura "Ciclo Corrompido", seção 7 do GDD):

```text
Slot A → Slot B → Slot C → Slot A
```

validar explicitamente se o ciclo é intencional (parte do desenho fixo da arena, sempre existente) ou uma corrupção acidental de ponteiros durante inserção/remoção.

---

# 12. Movimentação em path

> **Atualização de escopo:** no modelo de slots fixos (seção 11.1), **vagões não se movem ao longo de uma curva** — cada `Vagao` nasce e existe direto na coordenada fixa do `Slot` que ocupa. Esta seção deixa de se aplicar a `Vagao` no estado atual do projeto. Ela permanece relevante para:
>
> 1. **O `Player`**, que continua se movendo livremente pelo cenário (fora dos slots) e cuja física de locomoção/pulo não é afetada por este modelo;
> 2. **Mecânicas futuras explicitamente novas** que o documento de design venha a pedir (ex.: um efeito visual de corrente sendo "puxada" entre dois slots, ou uma versão futura do boss que decida mover a câmera/arena) — nesses casos, e somente se o documento pedir movimentação contínua de uma entidade por uma curva, aplicar as validações abaixo.

Quando (e apenas quando) o documento exigir que uma entidade siga um trilho circular de fato:

Não implementar simplesmente:

```dart
position += velocity;
```

se isso ignorar a curva especificada.

A implementação deve possuir uma representação do path e uma forma determinística de calcular:

```text
pathPosition(t)
```

ou equivalente.

Validar:

- posição inicial;
- direção;
- velocidade;
- posição final;
- continuidade da curva;
- comportamento quando chega ao destino.

Se o documento pedir movimentação de path para uma entidade que hoje é tratada como slot fixo (ex.: um `Vagao`), isso é uma **mudança de escopo em relação ao modelo atual** e deve ser reportado como tal (seção 6) antes de implementar, não assumido silenciosamente como "voltar ao design antigo".

## 12.1 Colisão delegada a um motor gráfico externo

Quando o documento indicar que **um motor gráfico externo já resolve colisões** a partir de coordenadas (caso deste projeto — ver `slots_config.json`, seção 9):

- Não implementar um sistema de detecção de colisão próprio (broad-phase/narrow-phase, resolução de sobreposição, etc.).
- A responsabilidade do código de gameplay é **posicionar** corretamente os colliders (ex.: hitbox sólida no topo de um `Vagao`, ver seção 13) nas coordenadas fornecidas pela configuração — a resolução da colisão em si (o "não atravessar", o "ficar em cima de") é do motor.
- Tamanho lógico de collider (quando o documento pedir um tamanho fixo independente do bounding box da arte) deve ser definido como constante/config, não recalculado a partir da imagem.
- Testes de colisão nesta arquitetura validam **posicionamento e estado** (`isSolid == true/false` no momento certo), não o algoritmo de colisão em si, que não é responsabilidade do código do jogo.

---

# 13. Separação entre visual e gameplay

Se o documento disser:

> apenas animação, sem dano

não implementar:

- HP;
- dano;
- hitbox de combate;
- knockback de combate;
- cálculo de dano;
- transição de fase.

Pode existir uma API preparada para integração futura, desde que isso não implemente a mecânica.

Exemplo aceitável:

```dart
void playDamagedAnimation() {
  state = BossState.hit;
}
```

Exemplo fora de escopo:

```dart
player.hp -= boss.damage;
```

---

# 14. Critérios de aceite como testes

Todo critério de aceite deve poder ser transformado em teste ou verificação manual.

Exemplo:

```text
Critério:
Vagão nasce diretamente no slot 0 (junto ao boss) e entra em idle.
```

Validações:

```text
1. spawn executado (occupySlot(0) chamado)
2. estado = spawning
3. posição = coordenada fixa do slot 0 (do config JSON) — sem alteração ao longo do tempo
4. transição automática ao final da animação de spawn
5. estado = idle
```

Outro exemplo:

```text
tremor → falling → removed
```

Teste:

```text
assert(state == tremor)
aguardar duração
assert(state == falling)
aguardar animação
assert(state == removed)
```

---

# 15. Testes recomendados

## Unit tests

Testar:

- transições de estado;
- ocupação de slot (`occupySlot`);
- remoção de vagão de um slot (`clearSlot`);
- integridade da lista de `Slot` (`next`/`prev` fecham o ciclo corretamente, ver seção 11.1);
- `head`;
- carregamento e parsing do `slots_config.json` (ver seção 9);
- configurações.

## Component tests

Testar:

- componente entra na arena na coordenada correta (vinda do config, não hard-coded);
- animação correta é selecionada;
- posicionamento do collider a partir do slot fixo (ver seção 12.1);
- callback ao terminar animação.

## Testes de integração

Quando aplicável:

```text
Boss
 ↓
occupySlot(index)
 ↓
Slot.vagao = Vagao
 ↓
spawning
 ↓
idle
```

---

# 16. Boas práticas de código Dart

Preferir:

- nomes explícitos;
- classes pequenas;
- enums para estados;
- `final` quando possível;
- métodos com uma responsabilidade;
- evitar estado global;
- evitar `dynamic` sem necessidade;
- constantes centralizadas;
- null safety;
- documentação em APIs públicas importantes.

Evitar:

- classes gigantes;
- métodos de centenas de linhas;
- strings mágicas para estados;
- caminhos de assets espalhados;
- lógica de gameplay dentro do carregamento de assets;
- timers desconectados do ciclo de vida do componente;
- referências que continuam apontando para componentes removidos.

---

# 17. Gestão de ciclo de vida

Para componentes Flame, validar:

```text
onLoad
  ↓
update
  ↓
render
  ↓
onRemove
```

Garantir que:

- assets sejam carregados corretamente;
- listeners sejam registrados e removidos;
- timers não continuem ativos após remoção;
- componentes removidos não continuem sendo atualizados;
- callbacks não referenciem objetos destruídos.

---

# 18. Tratamento de ambiguidades

Quando houver requisito incompleto:

```text
AMBIGUIDADE

Documento:
"Boss fica perto do trilho."

Problema:
Não existe posição exata nem regra de posicionamento.

Decisão:
Não inventar coordenadas definitivas.

Implementação:
Criar configuração:

BossPositionConfig
```

Se for possível continuar sem bloquear a implementação, usar uma configuração explícita e documentar a decisão.

---

# 19. Relatório obrigatório antes da implementação

Sempre produzir internamente ou apresentar, quando solicitado:

```markdown
## Escopo confirmado

### Dentro do escopo
- ...

### Fora do escopo
- ...

### Entidades
- ...

### Estados
- ...

### Animações
- ...

### Dependências
- ...

### Ambiguidades
- ...

### Riscos
- ...

### Critérios de aceite
- ...
```

---

# 20. Checklist final

Antes de considerar a implementação concluída:

## Documento

- [ ] Todos os requisitos foram identificados.
- [ ] Escopo atual foi separado do futuro.
- [ ] Contradições foram identificadas.
- [ ] Ambiguidades foram registradas.
- [ ] Critérios de aceite foram mapeados.

## Código

- [ ] Arquitetura segue o documento.
- [ ] Responsabilidades estão separadas.
- [ ] Estados estão explícitos.
- [ ] Transições estão definidas.
- [ ] Ciclo de vida está correto.
- [ ] Não há lógica fora do escopo.

## Assets

- [ ] Todos os assets necessários existem.
- [ ] Sprite sheets possuem frames consistentes.
- [ ] Animações possuem estado correspondente.
- [ ] Escala e orientação são consistentes.
- [ ] `slots_config.json` foi validado contra o documento de design (dimensões de canvas, quantidade de slots, ciclo `next`/`prev` fechado — ver seção 9).
- [ ] Nenhuma coordenada de slot/boss/death zone está hard-coded no Dart quando o config JSON existir.

## Gameplay

- [ ] Mecânicas implementadas correspondem ao escopo.
- [ ] Mecânicas futuras não foram implementadas antecipadamente.
- [ ] Estruturas de dados refletem os conceitos exigidos pelo documento.
- [ ] Nenhum vagão possui movimentação livre por path, a menos que o documento peça isso explicitamente para a etapa atual (seção 12).
- [ ] Nenhuma lógica de colisão foi reimplementada quando o motor gráfico já resolve isso (seção 12.1) — o código apenas posiciona colliders.

## Testes

- [ ] Estados podem ser testados.
- [ ] Inserção/remoção podem ser testadas.
- [ ] Animações podem ser disparadas isoladamente.
- [ ] Critérios de aceite possuem validação.
- [ ] Não existem referências quebradas após remoção de componentes.

---

# 21. Regra de ouro

> **O documento define o que deve existir. O código define como isso será implementado.**

Nunca alterar o design silenciosamente.

Se uma decisão técnica for necessária, preserve o comportamento descrito pelo documento e escolha a implementação mais simples, modular e testável.

Se houver conflito entre implementação e documento, **pare, identifique o conflito e peça decisão** em vez de mascará-lo com código.

