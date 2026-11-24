import 'content_variant.dart';

typedef FaqEntry = ({String heading, String content});
typedef HowToEntry = ({String? heading, String? content, List<String>? images});

class SearchResult {
  final String title;
  final String creator;
  final String? creatorId;
  final String? imageUrl;
  final String description;
  final double? avgStars;
  final int? totalStars;
  final List<String> downloadUrls;
  final List<ContentVariant> downloadVariants;
  final String dlcId;
  final String packType;
  final List<String> extraImages;
  final String? imagePanorama;
  final String? packIconUrl;
  final String? videoUrl;
  final String? changelog;
  final bool isOwned;
  final dynamic price; // Can be int, double, or null
  final bool hasVibrantVisuals;
  final String creationDate;
  final String lastModifiedDate;
  final String? version;
  final bool isEmote;
  final bool isPersonaPiece;
  final String? skinBinaryUrl;
  final String? personaBinaryUrl;
  final List<FaqEntry>? faqEntries;
  final String? howToTitle;
  final List<HowToEntry>? howToEntries;

  SearchResult({
    required this.title,
    required this.creator,
    this.creatorId,
    this.imageUrl,
    required this.description,
    this.avgStars,
    this.totalStars,
    required this.downloadUrls,
    this.downloadVariants = const [],
    required this.dlcId,
    required this.packType,
    required this.extraImages,
    this.imagePanorama,
    this.packIconUrl,
    this.videoUrl,
    this.changelog,
    required this.isOwned,
    this.price,
    required this.hasVibrantVisuals,
    required this.creationDate,
    required this.lastModifiedDate,
    this.version,
    this.isEmote = false,
    this.isPersonaPiece = false,
    this.skinBinaryUrl,
    this.personaBinaryUrl,
    this.faqEntries,
    this.howToTitle,
    this.howToEntries,
  });
}

class CreatorResult {
  final String filterId;
  final String filterName;

  CreatorResult({required this.filterId, required this.filterName});

  factory CreatorResult.fromMap(Map<String, dynamic> map) {
    return CreatorResult(
      filterId: map['filterId'] ?? '',
      filterName: map['filterName'] ?? '',
    );
  }
}
