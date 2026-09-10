import 'dart:developer' as developer;

import '../config/arena_config.dart';
import 'slot.dart';

/// Builds and holds the linked list of [Slot]s for the arena track.
///
/// Named `LinearTrack` (previously `CircularTrack`) because the topology is
/// **linear**, not circular: both `slots_config.json` (`slots[7].next ==
/// null`, `slots[0].prev == null`, `track.note`: "SEQUENCIA LINEAR...nao
/// fecha em circulo/elipse") and boss-vagoneiro-design.md section 3.0 are
/// explicit and consistent that the track does not close into a loop
/// ("sem fechar em círculo/elipse ... o último slot é o fim da lista/tail,
/// sem voltar a apontar para o slot 0").
///
/// Divergence to flag (not corrected here, per instructions — reported to
/// the user instead): skill/flutter_flame_gamedev_skill.md section 11.1
/// still describes a closed-ring model as "padrão adotado neste projeto"
/// and its invariants checklist (section 9) asks to validate that
/// `next`/`prev` "formam um ciclo fechado". That generic template
/// contradicts this project's own config/design docs, which take
/// precedence and were confirmed with the user in an earlier module.
class LinearTrack {
  final List<Slot> slots;
  final Slot head;

  LinearTrack._(this.slots, this.head);

  factory LinearTrack.fromConfig(List<SlotConfig> slotConfigs) {
    final byIndex = <int, Slot>{
      for (final c in slotConfigs) c.index: Slot(index: c.index, x: c.x, y: c.y),
    };

    for (final c in slotConfigs) {
      final slot = byIndex[c.index]!;
      // Faithful to the JSON: slot[0].prev stays null (head, next to the
      // boss) and slot[7].next stays null (tail) — never forced into a
      // cycle.
      slot.next = c.next != null ? byIndex[c.next] : null;
      slot.prev = c.prev != null ? byIndex[c.prev] : null;
    }

    final orderedSlots = List<Slot>.generate(
      slotConfigs.length,
      (i) => byIndex[i]!,
    );

    return LinearTrack._(orderedSlots, orderedSlots.first);
  }

  Slot slotAt(int index) => slots[index];

  /// Walks `slot.next` starting at [head] (slot 0), returning the visited
  /// indices in order. For this project's data this always ends with
  /// `next == null` at slot 7 — it never loops back to slot 0.
  List<int> traverseFromHead() {
    final visited = <int>[];
    Slot? current = head;
    // Safety cap against a genuine data bug (e.g. a corrupted config
    // accidentally introducing a real cycle) — not expected to ever bind
    // for this project's linear slots_config.json.
    while (current != null && visited.length <= slots.length) {
      visited.add(current.index);
      current = current.next;
    }
    return visited;
  }

  /// Debug validation: walk from slot 0 and report the exact index sequence
  /// plus the terminal condition (`next == null`), so a circular regression
  /// would be visible immediately (repeated indices / index 0 recurring).
  void debugLogTraversal() {
    final visited = traverseFromHead();
    final isLinear = visited.toSet().length == visited.length;
    final buffer = StringBuffer()
      ..writeln('=== LinearTrack.debugLogTraversal ===')
      ..writeln('visited order: ${visited.join(' -> ')} -> null')
      ..writeln('slots visited: ${visited.length} (expected ${slots.length})')
      ..writeln('head.prev == null: ${head.prev == null}')
      ..writeln(
        isLinear
            ? 'no repeated index — track is linear, ends at null (matches slots_config.json)'
            : 'WARNING: repeated index detected — track is unexpectedly circular',
      )
      ..write('=== end of traversal ===');

    developer.log(buffer.toString(), name: 'LinearTrack');
    // ignore: avoid_print
    print(buffer.toString());
  }
}
