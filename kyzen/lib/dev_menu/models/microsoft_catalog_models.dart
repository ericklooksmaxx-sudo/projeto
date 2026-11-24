import 'dart:convert';
import 'package:flutter/foundation.dart';

enum MicrosoftCatalogMode {
  lookup(
    label: 'Catalog Lookup',
    description: 'Lookup sellable products & add-ons for a title (SellableBy)',
    endpoint: '/v7/products/lookup',
  ),
  singleProduct(
    label: 'Single Product',
    description: 'Fetch detailed product data by Product ID',
    endpoint: '/v7/products/{id}',
  ),
  scraper(
    label: 'Scrape All Pages',
    description:
        'Scrape all related products across all pages and auto-save JSON',
    endpoint: '/v7/products/lookup?all',
  ),
  custom(
    label: 'Custom Endpoint',
    description: 'Call Microsoft Display Catalog URL',
    endpoint: '',
  );

  final String label;
  final String description;
  final String endpoint;

  const MicrosoftCatalogMode({
    required this.label,
    required this.description,
    required this.endpoint,
  });
}

enum MicrosoftPlatform {
  windows(label: 'Windows'),
  xbox(label: 'Xbox');

  final String label;
  const MicrosoftPlatform({required this.label});
}

class MicrosoftCatalogPreset {
  final String productId;
  final String name;
  final String packageIdentifier;
  final MicrosoftPlatform platform;
  final String description;

  const MicrosoftCatalogPreset({
    required this.productId,
    required this.name,
    required this.packageIdentifier,
    required this.platform,
    required this.description,
  });
}

const List<MicrosoftCatalogPreset> microsoftCatalogPresets = [
  // Windows
  MicrosoftCatalogPreset(
    productId: '9NBLGGH2JHXJ',
    name: 'Minecraft (Windows UWP)',
    packageIdentifier: 'Microsoft.MinecraftUWP',
    platform: MicrosoftPlatform.windows,
    description: 'Minecraft Bedrock Edition for Windows 10/11',
  ),
  MicrosoftCatalogPreset(
    productId: '9P5X4QVLC2XR',
    name: 'Minecraft Windows Beta',
    packageIdentifier: 'Microsoft.MinecraftWindowsBeta',
    platform: MicrosoftPlatform.windows,
    description: 'Minecraft Preview / Beta for Windows',
  ),
  MicrosoftCatalogPreset(
    productId: '9PGW18NPBZV5',
    name: 'Minecraft Launcher',
    packageIdentifier: 'Microsoft.4297127D64EC6',
    platform: MicrosoftPlatform.windows,
    description: 'Official unified Minecraft Launcher for Windows',
  ),
  MicrosoftCatalogPreset(
    productId: '9P8MK4NC0LJB',
    name: 'Minecraft Dungeons (Win)',
    packageIdentifier: 'Microsoft.Lovika',
    platform: MicrosoftPlatform.windows,
    description: 'Minecraft Dungeons action RPG for Windows',
  ),
  MicrosoftCatalogPreset(
    productId: '9P5786PJB9RP',
    name: 'Minecraft Dungeons 2 (Win)',
    packageIdentifier: 'Microsoft.MinecraftDungeons2',
    platform: MicrosoftPlatform.windows,
    description: 'Minecraft Dungeons II for Windows',
  ),
  MicrosoftCatalogPreset(
    productId: '9N98Z825TNFW',
    name: 'Minecraft Legends (Win)',
    packageIdentifier: 'Microsoft.BadgerWin10',
    platform: MicrosoftPlatform.windows,
    description: 'Minecraft Legends action strategy for Windows',
  ),

  // Xbox
  MicrosoftCatalogPreset(
    productId: '9NBLGGH537BL',
    name: 'Minecraft Xbox (APPX)',
    packageIdentifier: 'Microsoft.MinecraftUWPConsole',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft Bedrock for Xbox One / Series X|S (APPX package)',
  ),
  MicrosoftCatalogPreset(
    productId: '9MTK992XRFL2',
    name: 'Minecraft Preview Xbox (APPX)',
    packageIdentifier: 'Microsoft.MinecraftUWPBeta',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft Preview for Xbox (APPX package)',
  ),
  MicrosoftCatalogPreset(
    productId: '9MVXMVT8ZKWC',
    name: 'Minecraft Xbox (XVC)',
    packageIdentifier: 'Microsoft.186805A1E9E',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft for Xbox console (XVC package)',
  ),
  MicrosoftCatalogPreset(
    productId: '9NQ19C36R0VD',
    name: 'Minecraft Preview Xbox (XVC)',
    packageIdentifier: 'Microsoft.MinecraftBeta',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft Preview for Xbox console (XVC package)',
  ),
  MicrosoftCatalogPreset(
    productId: '9N8NJ74FZTG9',
    name: 'Minecraft Dungeons (Xbox)',
    packageIdentifier: 'Microsoft.LovikaX1',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft Dungeons for Xbox console',
  ),
  MicrosoftCatalogPreset(
    productId: '9NF0D13RPX5L',
    name: 'Minecraft Legends (Xbox)',
    packageIdentifier: 'Microsoft.296897AFE3FDD',
    platform: MicrosoftPlatform.xbox,
    description: 'Minecraft Legends for Xbox console',
  ),
];

class MicrosoftCatalogProduct {
  final String productId;
  final String title;
  final String? shortDescription;
  final String? description;
  final String? publisherName;
  final String? originalReleaseDate;
  final String? productKind;
  final String? productFamily;
  final String? packageFamilyName;
  final String? category;
  final String? imageUrl;
  final String? priceFormatted;
  final Map<String, dynamic> rawJson;

  const MicrosoftCatalogProduct({
    required this.productId,
    required this.title,
    this.shortDescription,
    this.description,
    this.publisherName,
    this.originalReleaseDate,
    this.productKind,
    this.productFamily,
    this.packageFamilyName,
    this.category,
    this.imageUrl,
    this.priceFormatted,
    required this.rawJson,
  });

  factory MicrosoftCatalogProduct.fromJson(Map<String, dynamic> json) {
    final productId = json['ProductId']?.toString() ?? 'Unknown ID';

    String title = 'Unknown Title';
    String? shortDesc;
    String? desc;
    String? publisher;
    String? imgUrl;

    final localized = json['LocalizedProperties'];
    if (localized is List && localized.isNotEmpty && localized.first is Map) {
      final loc = localized.first as Map<String, dynamic>;
      title = loc['ProductTitle']?.toString() ?? title;
      shortDesc = loc['ShortDescription']?.toString();
      desc = loc['ProductDescription']?.toString();
      publisher = loc['PublisherName']?.toString();

      final images = loc['Images'];
      if (images is List && images.isNotEmpty) {
        imgUrl = _extractBestImageUrl(images);
      }
    }

    // Market properties
    String? releaseDate;
    final market = json['MarketProperties'];
    if (market is List && market.isNotEmpty && market.first is Map) {
      final m = market.first as Map<String, dynamic>;
      releaseDate = m['OriginalReleaseDate']?.toString();
    }

    // Properties
    String? pfn;
    String? cat;
    final props = json['Properties'];
    if (props is Map) {
      pfn = props['PackageFamilyName']?.toString();
      cat = props['Category']?.toString();
    }

    final productKind = json['ProductKind']?.toString();
    final productFamily = json['ProductFamily']?.toString();

    // Price
    String? price;
    final skus = json['DisplaySkuAvailabilities'];
    if (skus is List && skus.isNotEmpty) {
      price = _extractPrice(skus);
    }

    return MicrosoftCatalogProduct(
      productId: productId,
      title: title,
      shortDescription: shortDesc,
      description: desc,
      publisherName: publisher,
      originalReleaseDate: releaseDate,
      productKind: productKind,
      productFamily: productFamily,
      packageFamilyName: pfn,
      category: cat,
      imageUrl: imgUrl,
      priceFormatted: price,
      rawJson: json,
    );
  }

  static String? _extractBestImageUrl(List<dynamic> images) {
    const preferredPurposes = [
      'BoxArt',
      'Poster',
      'Logo',
      'Tile',
      'TitledHeroArt',
      'Hero',
      'FeaturePromotionalArtwork',
    ];

    for (final purpose in preferredPurposes) {
      for (final item in images) {
        if (item is Map && item['ImagePurpose'] == purpose) {
          final uri = item['Uri']?.toString();
          if (uri != null && uri.isNotEmpty) {
            return uri.startsWith('//') ? 'https:$uri' : uri;
          }
        }
      }
    }

    for (final item in images) {
      if (item is Map) {
        final uri = item['Uri']?.toString();
        if (uri != null && uri.isNotEmpty) {
          return uri.startsWith('//') ? 'https:$uri' : uri;
        }
      }
    }
    return null;
  }

  static String? _extractPrice(List<dynamic> skus) {
    for (final sku in skus) {
      if (sku is Map) {
        final availabilities = sku['Availabilities'];
        if (availabilities is List && availabilities.isNotEmpty) {
          for (final av in availabilities) {
            if (av is Map) {
              final orderData = av['OrderManagementData'];
              if (orderData is Map) {
                final priceData = orderData['Price'];
                if (priceData is Map) {
                  final currency =
                      priceData['CurrencyCode']?.toString() ?? 'USD';
                  final listPrice = priceData['ListPrice'];
                  final msrp = priceData['MSRP'];
                  final price = listPrice ?? msrp;
                  if (price != null) {
                    final numVal = num.tryParse(price.toString()) ?? 0;
                    if (numVal == 0) return 'Free';
                    return '$currency ${numVal.toStringAsFixed(2)}';
                  }
                }
              }
            }
          }
        }
      }
    }
    return null;
  }
}

class MicrosoftCatalogResponse {
  final int statusCode;
  final int durationMs;
  final int sizeBytes;
  final String url;
  final dynamic json;
  final String rawString;
  final bool isSuccess;
  final String? errorMessage;
  final List<MicrosoftCatalogProduct> products;
  final int? totalResultCount;
  final bool? hasMorePages;
  final List<String> bigIds;
  final DateTime timestamp;

  const MicrosoftCatalogResponse({
    required this.statusCode,
    required this.durationMs,
    required this.sizeBytes,
    required this.url,
    required this.json,
    required this.rawString,
    required this.isSuccess,
    this.errorMessage,
    required this.products,
    this.totalResultCount,
    this.hasMorePages,
    required this.bigIds,
    required this.timestamp,
  });

  String get prettyString {
    if (json != null) {
      try {
        return const JsonEncoder.withIndent('  ').convert(json);
      } catch (_) {
        return rawString;
      }
    }
    return rawString;
  }

  factory MicrosoftCatalogResponse.fromHttp({
    required int statusCode,
    required int durationMs,
    required String url,
    required String rawString,
    String? errorMessage,
  }) {
    dynamic decodedJson;
    final products = <MicrosoftCatalogProduct>[];
    int? totalCount;
    bool? hasMore;
    final bigIds = <String>[];

    try {
      decodedJson = jsonDecodeSafe(rawString);
      if (decodedJson is Map<String, dynamic>) {
        totalCount = decodedJson['TotalResultCount'] as int?;
        hasMore = decodedJson['HasMorePages'] as bool?;

        if (decodedJson['BigIds'] is List) {
          for (final id in decodedJson['BigIds']) {
            if (id != null) bigIds.add(id.toString());
          }
        }

        // Single product response format: {"Product": {...}}
        if (decodedJson.containsKey('Product') &&
            decodedJson['Product'] is Map) {
          final prodMap = decodedJson['Product'] as Map<String, dynamic>;
          products.add(MicrosoftCatalogProduct.fromJson(prodMap));
        }
        // Lookup response format: {"Products": [{...}, ...]}
        else if (decodedJson.containsKey('Products') &&
            decodedJson['Products'] is List) {
          for (final item in decodedJson['Products']) {
            if (item is Map<String, dynamic>) {
              products.add(MicrosoftCatalogProduct.fromJson(item));
            }
          }
        }
        // Direct product format if someone passes bare product JSON
        else if (decodedJson.containsKey('ProductId')) {
          products.add(MicrosoftCatalogProduct.fromJson(decodedJson));
        }
      } else if (decodedJson is List) {
        for (final item in decodedJson) {
          if (item is Map<String, dynamic>) {
            products.add(MicrosoftCatalogProduct.fromJson(item));
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing Microsoft Catalog JSON: $e');
    }

    final isSuccess =
        statusCode >= 200 && statusCode < 300 && errorMessage == null;

    return MicrosoftCatalogResponse(
      statusCode: statusCode,
      durationMs: durationMs,
      sizeBytes: rawString.length,
      url: url,
      json: decodedJson,
      rawString: rawString,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
      products: products,
      totalResultCount: totalCount ?? products.length,
      hasMorePages: hasMore,
      bigIds: bigIds,
      timestamp: DateTime.now(),
    );
  }
}

dynamic jsonDecodeSafe(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}
