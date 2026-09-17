import 'dart:convert';
import '../linked_list_assets.dart';

import 'package:flutter/services.dart' show rootBundle;

/// Path to the arena layout exported by the external graphics engine.
///
/// Source of truth for all slot/boss/deathZone coordinates — see
/// skill/flutter_flame_gamedev_skill.md, section 9 ("Config JSON de arena").
const String arenaConfigAssetPath = linkedListLevelConfigPath;

class CanvasConfig {
  final double width;
  final double height;
  final String source;

  const CanvasConfig({
    required this.width,
    required this.height,
    required this.source,
  });

  factory CanvasConfig.fromJson(Map<String, dynamic> json) {
    return CanvasConfig(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      source: json['source'] as String,
    );
  }
}

class TrackConfig {
  final String type;
  final String orientation;
  final int slotCount;
  final double startX;
  final double endX;

  const TrackConfig({
    required this.type,
    required this.orientation,
    required this.slotCount,
    required this.startX,
    required this.endX,
  });

  factory TrackConfig.fromJson(Map<String, dynamic> json) {
    return TrackConfig(
      type: json['type'] as String,
      orientation: json['orientation'] as String,
      slotCount: json['slotCount'] as int,
      startX: (json['startX'] as num).toDouble(),
      endX: (json['endX'] as num).toDouble(),
    );
  }
}

/// A fixed, pre-calculated position on the linear track.
///
/// `next`/`prev` are slot indices, not Slot references — the track is
/// linear, not circular (see boss-vagoneiro-design.md, section 3.0):
/// the tail slot has `next == null` and the head slot has `prev == null`.
class SlotConfig {
  final int index;
  final double x;
  final double y;
  final int? next;
  final int? prev;

  const SlotConfig({
    required this.index,
    required this.x,
    required this.y,
    required this.next,
    required this.prev,
  });

  factory SlotConfig.fromJson(Map<String, dynamic> json) {
    return SlotConfig(
      index: json['index'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      next: json['next'] as int?,
      prev: json['prev'] as int?,
    );
  }
}

class BossConfig {
  final double x;
  final double y;
  final String anchor;
  final String facing;

  const BossConfig({
    required this.x,
    required this.y,
    required this.anchor,
    required this.facing,
  });

  factory BossConfig.fromJson(Map<String, dynamic> json) {
    return BossConfig(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      anchor: json['anchor'] as String,
      facing: json['facing'] as String,
    );
  }
}

class DeathZoneConfig {
  final String type;
  final double y;

  const DeathZoneConfig({required this.type, required this.y});

  factory DeathZoneConfig.fromJson(Map<String, dynamic> json) {
    return DeathZoneConfig(
      type: json['type'] as String,
      y: (json['y'] as num).toDouble(),
    );
  }
}

class DecorativeAnchor {
  final double x;
  final double y;

  const DecorativeAnchor({required this.x, required this.y});

  factory DecorativeAnchor.fromJson(Map<String, dynamic> json) {
    return DecorativeAnchor(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

/// A single absolute (x, y) point in canvas space.
class AnchorPoint {
  final double x;
  final double y;

  const AnchorPoint({required this.x, required this.y});

  factory AnchorPoint.fromJson(Map<String, dynamic> json) {
    return AnchorPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

/// One decorative chain segment's pre-calculated attachment points (see
/// module prompt: `slots_config.json`'s `chainConnections.connections`).
/// `from`/`to` are either the literal string `"boss"` or a slot index —
/// kept as raw JSON values (`Object`) since the two are never compared to
/// each other, only used to identify which segment this is.
class ChainConnectionConfig {
  final Object from; // "boss" or an int slot index.
  final int to; // always a slot index — nothing chains *into* the boss.
  final AnchorPoint fromAnchor;
  final AnchorPoint toAnchor;
  final double distance;

  const ChainConnectionConfig({
    required this.from,
    required this.to,
    required this.fromAnchor,
    required this.toAnchor,
    required this.distance,
  });

  factory ChainConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ChainConnectionConfig(
      from: json['from'] as Object,
      to: json['to'] as int,
      fromAnchor:
          AnchorPoint.fromJson(json['fromAnchor'] as Map<String, dynamic>),
      toAnchor: AnchorPoint.fromJson(json['toAnchor'] as Map<String, dynamic>),
      distance: (json['distance'] as num).toDouble(),
    );
  }
}

/// One decorative end-of-track chain anchor (Módulo 13, tarefa 6): the wall
/// fitting that stops the wagon at either end of the track from looking
/// like it hangs from nothing.
///
/// [sprite] selects which of the two mirrored art files to use — `"left"`
/// for the plate bolted on the left with its chain running right,
/// `"right"` for the mirror image. [tip] is where that art's **free chain
/// end** must land in canvas coordinates; the plate's position follows from
/// it and from the render scale, so the config never has to restate art
/// geometry.
///
/// [chainToSlot] is the slot a [ChainSegment] should run to from [tip]
/// (with [toAnchor] as its far end and [distance] as its span), or `null`
/// for an anchor whose own baked-in chain is the whole decoration. Purely
/// visual: nothing here participates in the linked list.
class EndAnchorConfig {
  final String id;
  final String sprite;
  final AnchorPoint tip;
  final int? chainToSlot;
  final AnchorPoint? toAnchor;
  final double? distance;

  const EndAnchorConfig({
    required this.id,
    required this.sprite,
    required this.tip,
    required this.chainToSlot,
    required this.toAnchor,
    required this.distance,
  });

  factory EndAnchorConfig.fromJson(Map<String, dynamic> json) {
    final toAnchorJson = json['toAnchor'] as Map<String, dynamic>?;
    return EndAnchorConfig(
      id: json['id'] as String,
      sprite: json['sprite'] as String,
      tip: AnchorPoint.fromJson(json['tip'] as Map<String, dynamic>),
      chainToSlot: json['chainToSlot'] as int?,
      toAnchor: toAnchorJson == null ? null : AnchorPoint.fromJson(toAnchorJson),
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }
}

/// Pre-calculated chain-decoration attachment points (see module prompt):
/// each connection's `fromAnchor`/`toAnchor` are absolute canvas points
/// where the chain should visually touch the top of the wagon/boss art —
/// `attachHeightAboveGround` above the slot/boss's own (ground-level,
/// bottom_center) `x`/`y` — already computed on the config side, so
/// nothing in the Flutter code re-derives them from `slot.y`/`boss.y`.
class ChainConnectionsConfig {
  final double attachHeightAboveGround;
  final List<ChainConnectionConfig> connections;

  /// Módulo 13, tarefa 6 — the two end-of-track wall fittings. Optional so
  /// an older config without the key still parses.
  final List<EndAnchorConfig> endAnchors;

  const ChainConnectionsConfig({
    required this.attachHeightAboveGround,
    required this.connections,
    required this.endAnchors,
  });

  factory ChainConnectionsConfig.fromJson(Map<String, dynamic> json) {
    return ChainConnectionsConfig(
      attachHeightAboveGround:
          (json['attachHeightAboveGround'] as num).toDouble(),
      connections: (json['connections'] as List)
          .map((e) => ChainConnectionConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      endAnchors: ((json['endAnchors'] as List?) ?? const [])
          .map((e) => EndAnchorConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Typed, parsed contents of `slots_config.json` (see [arenaConfigAssetPath]).
class ArenaConfig {
  final CanvasConfig canvas;
  final TrackConfig track;
  final List<SlotConfig> slots;
  final BossConfig boss;
  final DeathZoneConfig deathZone;
  final Map<String, List<DecorativeAnchor>> decorativeAnchors;
  final ChainConnectionsConfig chainConnections;

  const ArenaConfig({
    required this.canvas,
    required this.track,
    required this.slots,
    required this.boss,
    required this.deathZone,
    required this.decorativeAnchors,
    required this.chainConnections,
  });

  factory ArenaConfig.fromJson(Map<String, dynamic> json) {
    final anchorsJson =
        (json['decorativeAnchors'] as Map<String, dynamic>? ?? {});
    final anchors = anchorsJson.map(
      (key, value) => MapEntry(
        key,
        (value as List)
            .map((e) => DecorativeAnchor.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );

    return ArenaConfig(
      canvas: CanvasConfig.fromJson(json['canvas'] as Map<String, dynamic>),
      track: TrackConfig.fromJson(json['track'] as Map<String, dynamic>),
      slots: (json['slots'] as List)
          .map((e) => SlotConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      boss: BossConfig.fromJson(json['boss'] as Map<String, dynamic>),
      deathZone:
          DeathZoneConfig.fromJson(json['deathZone'] as Map<String, dynamic>),
      decorativeAnchors: anchors,
      chainConnections: ChainConnectionsConfig.fromJson(
        json['chainConnections'] as Map<String, dynamic>,
      ),
    );
  }

  /// Loads and parses [arenaConfigAssetPath] from the asset bundle.
  static Future<ArenaConfig> load() async {
    final raw = await rootBundle.loadString(arenaConfigAssetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ArenaConfig.fromJson(json);
  }
}
