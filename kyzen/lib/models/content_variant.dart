// DLCs can have multiple variant like "optimized-1.26.40"

class ContentVariant {
  final String label;
  final List<String> tags;
  final List<String> urls;

  const ContentVariant({
    required this.label,
    required this.tags,
    required this.urls,
  });

  // Whether this is the default variant (no tags).
  bool get isDefault => tags.isEmpty;

  @override
  String toString() => 'ContentVariant(label: $label, urls: ${urls.length})';
}
