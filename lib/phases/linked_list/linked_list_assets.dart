/// Root of the linked_list phase's assets, relative to
/// `Flame.images.prefix` ('assets/'). Every asset path in this phase is
/// built from it, so the whole phase can be relocated by changing one line.
const String linkedListAssetRoot = 'phases/linked_list/';

/// The phase's level layout (slot positions, boss spot, death line, chain
/// anchors), loaded from the asset bundle — full bundle key.
const String linkedListLevelConfigPath =
    'assets/${linkedListAssetRoot}level/slots_config.json';
