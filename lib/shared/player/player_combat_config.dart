/// The player's combat numbers, shared by every phase.
///
/// Moved out of the linked_list phase's `boss_combat.dart` unchanged: they
/// describe the player (how much damage it can take, how long it is immune
/// after a hit, how hard its sword hits), not any particular boss. Each
/// phase still decides how much each of *its* hazards costs.
library;

/// Player hit points. Every source of combat damage in the linked_list
/// phase costs exactly 1, so this is also "how many mistakes the fight
/// forgives".
const int playerMaxHp = 5;

/// How long the player is immune after taking a hit, so one mistake can't
/// be charged twice by two systems noticing it in the same second.
const double playerInvulnerabilityDuration = 1.0;

/// A small, non-damaging recoil: a brief loss of control plus a shove.
const double playerStaggerDuration = 0.45;
const double playerStaggerPushback = 34;

/// Damage of one sword swing on a boss (Módulo 15). Same 1 as every other
/// damage source until a balancing decision says otherwise.
const int playerAttackDamage = 1;
