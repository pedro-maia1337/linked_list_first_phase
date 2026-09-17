# FightCodex: Codex das Estruturas

Jogo Flutter + Flame em que cada fase ensina uma estrutura de dados (lista encadeada, pilha, fila, árvore, tabela hash, grafo…), com bioma e boss próprios, acessíveis a partir de um hub central ("O Repositório").

Fases implementadas:

| id | Estrutura | Boss |
|---|---|---|
| `linked_list` | Lista Encadeada | O Vagoneiro |

## Estrutura

- `lib/shared/` e `assets/shared/`: o que vale para todas as fases (Player, HUD, efeitos, física, debug, contrato de fase).
- `lib/phases/<id>/` e `assets/phases/<id>/`: o que é de uma fase só.
- `lib/phases/phase_registry.dart`: lista de fases.

Guia completo, incluindo o passo a passo para adicionar uma fase: **[docs/ESTRUTURA.md](docs/ESTRUTURA.md)**.
Design da fase 1: [docs/phases/linked_list/boss-vagoneiro-design.md](docs/phases/linked_list/boss-vagoneiro-design.md).

## Rodando

```
flutter pub get
flutter run -d windows        # abre a primeira fase do registro
flutter test                  # suíte completa (test/shared + test/phases/<id>)
```

Render sem janela da fase 1:

```
flutter test test/phases/linked_list/scene_snapshot_tool.dart --dart-define=SNAPSHOT_OUT=<arquivo.png>
```
