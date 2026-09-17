/// What the shared [Player] can stand on.
///
/// The player lands on any component that implements this (Flame passes the
/// hitbox's parent entity to `onCollision`, so the *entity* implements it,
/// not the hitbox). Each phase provides its own platforms — the linked_list
/// phase's `Vagao` is one — without the player knowing what they are.
abstract interface class PlayerPlatform {
  /// Whether the platform currently supports the player. When it turns
  /// false under a standing player, the player drops and
  /// `Player.onSupportLost` fires.
  bool get isSolid;

  /// World y of the surface the player's feet snap to.
  double get platformTopY;
}
