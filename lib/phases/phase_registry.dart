import '../shared/phases/phase_definition.dart';
import 'linked_list/linked_list_phase.dart';

/// Every playable phase, in the order the game presents them.
///
/// Adding a phase = adding its `PhaseDefinition` here (see
/// `docs/ESTRUTURA.md`). Nothing under `lib/shared/` changes.
const List<PhaseDefinition> phaseRegistry = [
  linkedListPhase,
];

/// Looks a phase up by [PhaseDefinition.id].
PhaseDefinition phaseById(String id) =>
    phaseRegistry.firstWhere((phase) => phase.id == id);
