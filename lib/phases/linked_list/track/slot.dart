import '../wagon/vagao.dart';

/// A fixed, pre-calculated position on the track.
///
/// Per the skill's architecture (section 11.1), the linked list lives here —
/// `next`/`prev` point to neighboring [Slot]s — not on [Vagao]. A [Vagao]
/// never owns `next`/`prev` references.
class Slot {
  final int index;
  final double x;
  final double y;

  Slot? next;
  Slot? prev;
  Vagao? vagao;

  Slot({
    required this.index,
    required this.x,
    required this.y,
    this.next,
    this.prev,
    this.vagao,
  });
}
