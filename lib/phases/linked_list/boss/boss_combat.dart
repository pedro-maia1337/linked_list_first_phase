/// Módulo 14/15 — the numeric model behind the fight (HP, phases, cadence).
///
/// Kept as plain data + pure functions in its own file, deliberately free
/// of Flame imports, so the rules the design doc pins down (the 100-66 /
/// 65-33 / 32-0 phase bands, the exposed windows, what each attack costs
/// the player) can be unit-tested without booting a game, and so the
/// components below only ever *consume* them.
///
/// **Módulo 15 (playtest correction pass)** cut the attack roster down to
/// two primitives — `RemoverNo` and `InserirNo` — so everything here that
/// described Corrente Restritiva, Lista Dupla, Nó Órfão or Ciclo
/// Corrompido is gone with it. The phases survive unchanged in *meaning*
/// (three bands, same HP thresholds); what differs between them now is
/// only cadence and combination, never mechanics.
///
/// Nothing here touches the section 2.3 scale calibration or the wagon
/// state machine.
library;

/// The three phases of the fight.
///
/// Bands are expressed as fractions of [bossMaxHp] exactly as the design
/// doc writes them in percentages:
///  * `fase1` — 100%..66%
///  * `fase2` — 65%..33%
///  * `fase3` — 32%..0%
///
/// Módulo 15: the labels no longer promise a new *mechanic* per phase,
/// because there isn't one. They name the cadence, which is the only
/// thing that actually changes.
enum BossPhase {
  fase1,
  fase2,
  fase3;

  /// Human-readable label used by the HUD.
  String get label => switch (this) {
        BossPhase.fase1 => 'FASE 1 — um nó por vez',
        BossPhase.fase2 => 'FASE 2 — cadência acelerada',
        BossPhase.fase3 => 'FASE 3 — remove e insere em sequência',
      };
}

/// Lower bound (inclusive) of the phase-1 band, as a fraction of max HP.
const double bossPhase1LowerBound = 0.66;

/// Lower bound (inclusive) of the phase-2 band, as a fraction of max HP.
const double bossPhase2LowerBound = 0.33;

/// Which phase a boss at [hpFraction] (0..1) is in.
BossPhase phaseForHpFraction(double hpFraction) {
  if (hpFraction >= bossPhase1LowerBound) {
    return BossPhase.fase1;
  }
  if (hpFraction >= bossPhase2LowerBound) {
    return BossPhase.fase2;
  }
  return BossPhase.fase3;
}

/// Boss hit points.
///
/// 12 is chosen so the three bands land on whole numbers of hits without
/// rounding drift: 12..8 is phase 1 (5 hits), 7..4 is phase 2 (4 hits),
/// 3..0 is phase 3 (4 hits) — check: 8/12 = 0.667 >= 0.66, 7/12 = 0.583,
/// 4/12 = 0.333 >= 0.33, 3/12 = 0.25.
const int bossMaxHp = 12;

// The player's own numbers (`playerMaxHp`, `playerAttackDamage`,
// `playerInvulnerabilityDuration`, the stagger) live in
// `shared/player/player_combat_config.dart` — they describe the player,
// not this boss. Every source of damage below costs exactly 1.

/// Damage for standing on the wagon `RemoverNo` drops, charged the instant
/// the floor stops being solid (`Player.onSupportLost`). This is the
/// pre-existing fall hook, not a new hitbox — Mudança 1 (a) is explicit
/// that the removal must reuse it.
const int removerNoDamage = 1;

/// Damage for actually falling out of the arena. Routed through the
/// pre-existing `Player.onDeath` extension hook rather than a second death
/// path (design doc section 10.2, item 3).
const int quedaDamage = 1;

/// Damage `InserirNo` deals to a player who was standing on the wagon that
/// fell off the far end of the line.
const int inserirNoDamage = 1;

/// How long the boss stays vulnerable after the push (Mudança 1 (b):
/// "Boss fica `exposed` 1.5s no slot 0 novo" — the rule the module keeps
/// verbatim from Módulo 14).
const double bossExposedAfterInsercao = 1.5;

/// How long the boss stays vulnerable after being hit while already
/// exposed — the stagger that lets a player chain a couple of hits inside
/// one window instead of one hit ending it.
const double bossExposedAfterHit = 0.6;

// ---------------------------------------------------------------------------
// Cadence — the *only* thing that separates the three phases (Mudança 1).
//
// Every field below is a number, not a capability: no phase unlocks an
// attack, a direction, a node or a pointer that another phase lacks. A
// reader comparing two [PhaseCadence]s should be able to say "faster, and
// more of the same" and nothing else.
// ---------------------------------------------------------------------------

/// How one phase paces the two primitives.
class PhaseCadence {
  /// Seconds of telegraph before an attack executes. Phase 1 is the
  /// 1.2-1.5s window the brief asks for; later phases compress it by their
  /// speed factor.
  final double telegraphMin;
  final double telegraphMax;

  /// Seconds between the end of one attack and the start of the next.
  final double interval;

  /// How many holes `RemoverNo` may leave open at once. Never lets two of
  /// them be adjacent — that rule lives in the slot selection and is not
  /// a function of the phase (Mudança 1 (a): "sob nenhuma circunstância,
  /// em nenhuma fase").
  final int maxSimultaneousHoles;

  /// How many `InserirNo`s the boss may chain back to back.
  final int maxChainedInsertions;

  /// Whether the boss may follow a `RemoverNo` immediately with an
  /// `InserirNo`. Still only the two primitives — this is a combination,
  /// not a third attack.
  final bool canChainRemoveThenInsert;

  const PhaseCadence({
    required this.telegraphMin,
    required this.telegraphMax,
    required this.interval,
    required this.maxSimultaneousHoles,
    required this.maxChainedInsertions,
    required this.canChainRemoveThenInsert,
  });

  /// Seconds between the beats of a chained sequence — deliberately much
  /// shorter than [interval], because a chain is meant to read as one
  /// attack with two halves, not as two attacks that happened to be close.
  double get chainGap => 0.35;
}

/// Phase 1 — one attack at a time, 1.2-1.5s telegraph.
const PhaseCadence cadenceFase1 = PhaseCadence(
  telegraphMin: 1.2,
  telegraphMax: 1.5,
  interval: 4.2,
  maxSimultaneousHoles: 1,
  maxChainedInsertions: 1,
  canChainRemoveThenInsert: false,
);

/// Phase 2 — "~30% mais rápido", up to two (non-adjacent) holes, and
/// insertions chained twice in a row.
///
/// 0.7x is that 30%, applied uniformly to both the telegraph and the
/// interval so the *shape* of the beat is preserved and only its tempo
/// moves: 1.2 -> 0.84, 1.5 -> 1.05, 4.2 -> 2.94.
const double phase2SpeedFactor = 0.7;
const PhaseCadence cadenceFase2 = PhaseCadence(
  telegraphMin: 1.2 * phase2SpeedFactor,
  telegraphMax: 1.5 * phase2SpeedFactor,
  interval: 4.2 * phase2SpeedFactor,
  maxSimultaneousHoles: 2,
  maxChainedInsertions: 2,
  canChainRemoveThenInsert: false,
);

/// Phase 3 — maximum cadence, and `RemoverNo -> InserirNo` back to back.
///
/// 0.55x of the phase-1 numbers: 1.2 -> 0.66, 1.5 -> 0.825, 4.2 -> 2.31.
/// The telegraph stays above the ~0.5s floor below which a wind-up stops
/// being readable at all, which is the point past which "faster" would
/// become "unfair" rather than "harder".
const double phase3SpeedFactor = 0.55;
const PhaseCadence cadenceFase3 = PhaseCadence(
  telegraphMin: 1.2 * phase3SpeedFactor,
  telegraphMax: 1.5 * phase3SpeedFactor,
  interval: 4.2 * phase3SpeedFactor,
  maxSimultaneousHoles: 2,
  maxChainedInsertions: 2,
  canChainRemoveThenInsert: true,
);

PhaseCadence cadenceFor(BossPhase phase) => switch (phase) {
      BossPhase.fase1 => cadenceFase1,
      BossPhase.fase2 => cadenceFase2,
      BossPhase.fase3 => cadenceFase3,
    };

/// Beat between the boss's attacks, for callers that only want the number.
double attackIntervalFor(BossPhase phase) => cadenceFor(phase).interval;

/// The two primitives the boss has. There is no third one, and Mudança 1
/// says there must never be: this enum is the enforcement point — an
/// attack that does not fit one of these two names has nowhere to live.
enum BossAttack {
  removerNo,
  inserirNo;

  String get label =>
      this == BossAttack.removerNo ? 'RemoverNo' : 'InserirNo';
}

/// Outcome of a player attack, resolved by the combat controller.
enum AttackOutcome {
  /// Real damage landed — the boss was inside its `exposed` window.
  hit,

  /// The boss was not exposed. Cuphead rule: outside the punish window the
  /// boss simply does not take damage.
  missInvulnerable,
}
