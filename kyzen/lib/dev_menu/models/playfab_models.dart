enum PlayFabEndpoint {
  catalogSearch(
    label: 'Search',
    category: 'Catalog',
    endpoint: '/Catalog/Search',
    method: 'POST',
    description:
        'Search catalog items with OData filters, order by, and paging',
  ),
  catalogGetPublishedItem(
    label: 'Get Published Item',
    category: 'Catalog',
    endpoint: '/Catalog/GetPublishedItem',
    method: 'POST',
    description: 'Fetch item by UUID',
  ),
  catalogGetItemContainers(
    label: 'Get Item Containers',
    category: 'Catalog',
    endpoint: '/Catalog/GetItemContainers',
    method: 'POST',
    description:
        'Get bundle containers referencing an item by FriendlyId or ItemId',
  ),
  clientGetTitlePublicKey(
    label: 'Get Title Public Key',
    category: 'Client',
    endpoint: '/Client/GetTitlePublicKey',
    method: 'POST',
    description: 'Retrieve Mojang CSP RSA public key for player encryption',
  ),
  authenticationGetEntityToken(
    label: 'Get Entity Token',
    category: 'Authentication',
    endpoint: '/Authentication/GetEntityToken',
    method: 'POST',
    description: 'Get PlayFab entity token for authentication',
  ),
  clientLoginWithCustomId(
    label: 'Login With Custom ID',
    category: 'Client',
    endpoint: '/Client/LoginWithCustomID',
    method: 'POST',
    description: 'Login or create guest player account with custom ID',
  ),
  custom(
    label: 'Custom Endpoint',
    category: 'Custom',
    endpoint: '',
    method: 'POST',
    description: 'Call custom endpoint with a custom JSON payload',
  );

  final String label;
  final String category;
  final String endpoint;
  final String method;
  final String description;

  const PlayFabEndpoint({
    required this.label,
    required this.category,
    required this.endpoint,
    required this.method,
    required this.description,
  });
}

class FilterPreset {
  final String title;
  final String category;
  final String filter;
  final String? tooltip;

  const FilterPreset({
    required this.title,
    required this.category,
    required this.filter,
    this.tooltip,
  });
}

const List<FilterPreset> filterPresets = [
  FilterPreset(
    title: 'Add-ons',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq 'addon')",
    tooltip: 'Bedrock Add-ons',
  ),
  FilterPreset(
    title: 'Sounds dlc',
    category: 'Piece & Tags',
    filter:
        "(contentType eq 'MarketplaceDurableCatalog_V1.2') and tags/any(t: t eq 'tag.category.audio')",
    tooltip: 'Audio',
  ),
  FilterPreset(
    title: 'Auger Internal Cache',
    category: 'Content Type',
    filter: "(contentType eq 'AugerInternalCache_V1.0.0')",
    tooltip: 'Marketplace recommendation cache manifests',
  ),
  FilterPreset(
    title: 'Banner Manifest V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'BannerManifest_V1.0')",
    tooltip: 'Featured store carousel promotional banners',
  ),
  FilterPreset(
    title: 'Bundle Offers V2.0',
    category: 'Content Type',
    filter: "(contentType eq 'BundleOffer_V2.0')",
    tooltip: 'Multi-pack and coin bundle offers',
  ),
  FilterPreset(
    title: 'Coin Screen Manifest',
    category: 'Content Type',
    filter: "(contentType eq 'CoinScreenManifest_V1.0')",
    tooltip: 'Minecoin purchasing screen layout',
  ),
  FilterPreset(
    title: 'Content Card Config',
    category: 'Content Type',
    filter: "(contentType eq 'ContentCardConfig_V1.0')",
    tooltip: 'Content card visual configuration',
  ),
  FilterPreset(
    title: 'Created >= 2025',
    category: 'Date & Combos',
    filter: "(CreationDate ge 2025-01-22T23:32:36.943Z)",
    tooltip: 'Items created since Jan 2025',
  ),
  FilterPreset(
    title: 'Created >= 2026',
    category: 'Date & Combos',
    filter: "(CreationDate ge 2026-01-01T00:00:00Z)",
    tooltip: 'Items created in 2026 or later',
  ),
  FilterPreset(
    title: 'Creator Page Manifest',
    category: 'Content Type',
    filter: "(contentType eq 'CreatorPageManifest_V1.0.0')",
    tooltip: 'Creator marketplace profile landing pages',
  ),
  FilterPreset(
    title: 'Custom Prices Document',
    category: 'Content Type',
    filter: "(contentType eq 'CustomPricesDocument_V1.0')",
    tooltip: 'Regional and promotional price overrides',
  ),
  FilterPreset(
    title: 'Debug Subscription',
    category: 'Content Type',
    filter: "(contentType eq 'DebugSubscription')",
    tooltip: 'QA and test subscription manifests',
  ),
  FilterPreset(
    title: 'Free Items',
    category: 'Store & Pricing',
    filter: "(displayProperties/price eq 0)",
    tooltip: 'Items with price 0 (free)',
  ),
  FilterPreset(
    title: 'Friendly ID Tag',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq '{id}')",
    tooltip: "Search items by Friendly ID tag (tags/any(t: t eq '{id}'))",
  ),
  FilterPreset(
    title: 'FriendlyId AlternateId',
    category: 'Piece & Tags',
    filter: "AlternateIds/any(a: a/Type eq 'FriendlyId' and a/Value eq '{id}')",
    tooltip:
        "Search items having AlternateId FriendlyId (AlternateIds/any(a: a/Type eq 'FriendlyId' and a/Value eq '{id}'))",
  ),
  FilterPreset(
    title: 'Hidden Offers',
    category: 'Piece & Tags',
    filter:
        "(contentType eq 'MarketplaceDurableCatalog_V1.2') and tags/any(t: t eq 'hidden_offer')",
    tooltip: 'Hidden marketplace offers',
  ),
  FilterPreset(
    title: 'Item Redemption Offer V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'ItemRedemptionOffer_V1.0')",
    tooltip: 'Codes and item redemption offers',
  ),
  FilterPreset(
    title: 'Marketplace (No Skins, >= 2026)',
    category: 'Date & Combos',
    filter:
        "(contentType eq 'MarketplaceDurableCatalog_V1.2') and (CreationDate ge 2026-07-28T19:27:56Z) and (not tags/any(t: t eq 'skinpack'))",
    tooltip: 'Marketplace DLCs from specific date without skinpacks',
  ),
  FilterPreset(
    title: 'Marketplace Durable V1.2',
    category: 'Content Type',
    filter: "(contentType eq 'MarketplaceDurableCatalog_V1.2')",
    tooltip: 'Standard Minecraft Marketplace DLC items',
  ),
  FilterPreset(
    title: 'Marketplace Pass Free Trial',
    category: 'Content Type',
    filter: "(contentType eq 'MarketplacePass_Free_V1.0')",
    tooltip: 'Free trial Marketplace Pass offers',
  ),
  FilterPreset(
    title: 'Mash-ups',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq 'mashup')",
    tooltip: 'Mash-up packs',
  ),
  FilterPreset(
    title: 'Microsoft Store Alt ID',
    category: 'Store & Pricing',
    filter: "(AlternateIds/any(a: a/Type eq 'MicrosoftStore'))",
    tooltip: 'Items linked to Microsoft Store',
  ),
  FilterPreset(
    title: 'Minecoin Config V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'MinecoinConfig_V1.0')",
    tooltip: 'Minecoin currency configurations',
  ),
  FilterPreset(
    title: 'Navigation Manifest V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'NavManifest_V1.0')",
    tooltip: 'In-game marketplace navigation sidebar categories',
  ),
  FilterPreset(
    title: 'Not Skinpack',
    category: 'Piece & Tags',
    filter: "(not tags/any(t: t eq 'skinpack'))",
    tooltip: 'Exclude all skinpacks',
  ),
  FilterPreset(
    title: 'Offer Collections V3.0',
    category: 'Content Type',
    filter: "(contentType eq 'OfferCollectionQueries_V3.0')",
    tooltip: 'Offer collections',
  ),
  FilterPreset(
    title: 'Payout Multiplier Override',
    category: 'Content Type',
    filter: "(contentType eq 'PayoutMultiplierOverrideDocument_V1.0')",
    tooltip: 'Creator payout multiplier rules',
  ),
  FilterPreset(
    title: 'Persona',
    category: 'Content Type',
    filter: "(contentType eq 'PersonaDurable')",
    tooltip: 'Character creator and dressing room items',
  ),
  FilterPreset(
    title: 'Persona Capes',
    category: 'Piece & Tags',
    filter: "(displayProperties/pieceType eq 'persona_capes')",
    tooltip: 'Capes',
  ),
  FilterPreset(
    title: 'Persona Emotes',
    category: 'Piece & Tags',
    filter: "(displayProperties/pieceType eq 'persona_emote')",
    tooltip: 'Character creator persona emotes',
  ),
  FilterPreset(
    title: 'Persona Query Manifest',
    category: 'Content Type',
    filter: "(contentType eq 'PersonaQueryManifest_V1.0')",
    tooltip: 'Dressing room query categories',
  ),
  FilterPreset(
    title: 'Query Manifest V2.1.0',
    category: 'Content Type',
    filter: "(contentType eq 'QueryManifest_V2.1.0')",
  ),
  FilterPreset(
    title: 'Realms Subscriptions',
    category: 'Content Type',
    filter: "(contentType eq 'realm')",
  ),
  FilterPreset(
    title: 'Resource Pack Treatment',
    category: 'Content Type',
    filter: "(contentType eq 'ResourcePackTreatment_V1.2')",
    tooltip: 'Resource pack treatments and features',
  ),
  FilterPreset(
    title: 'Resource Packs',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq 'resourcepack')",
    tooltip: 'Texture and resource packs',
  ),
  FilterPreset(
    title: 'Scary / Spooky',
    category: 'Piece & Tags',
    filter:
        "(contentType eq 'MarketplaceDurableCatalog_V1.2') and not tags/any(t: t eq 'skinpack') and not tags/any(t: t eq 'resourcepack') and (tags/any(t: t eq 'tag.horror') or tags/any(t: t eq 'tag.halloween') or tags/any(t: t eq 'tag.haunted') or tags/any(t: t eq 'tag.scary_mobs') or tags/any(t: t eq 'tag.spooky'))",
    tooltip: 'Horror',
  ),
  FilterPreset(
    title: 'Server Offer List V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'ServerOfferList_V1.0')",
    tooltip: 'Featured server storefront offer lists',
  ),
  FilterPreset(
    title: 'Skinpacks',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq 'skinpack')",
    tooltip: 'Only skinpacks',
  ),
  FilterPreset(
    title: 'Store Config V1.1',
    category: 'Content Type',
    filter: "(contentType eq 'StoreConfig_V1.1')",
    tooltip: 'Marketplace store configuration and creator list',
  ),
  FilterPreset(
    title: 'Third Party Server Content',
    category: 'Content Type',
    filter: "(contentType eq '3PServerContent_V1.2')",
  ),
  FilterPreset(
    title: 'Token Config V1.0',
    category: 'Content Type',
    filter: "(contentType eq 'TokenConfig_V1.0')",
  ),
  FilterPreset(
    title: 'Vibrant Visuals',
    category: 'Piece & Tags',
    filter:
        "(contentType eq 'MarketplaceDurableCatalog_V1.2') and tags/any(t: t eq 'tag.vibrantvisuals')",
    tooltip: 'Items with vibrant visuals tag',
  ),
  FilterPreset(
    title: 'World Seeds',
    category: 'Content Type',
    filter: "(contentType eq 'WorldSeed')",
    tooltip: 'World creation seed picker templates',
  ),
  FilterPreset(
    title: 'World Templates',
    category: 'Piece & Tags',
    filter: "tags/any(t: t eq 'worldtemplate')",
  ),
];
