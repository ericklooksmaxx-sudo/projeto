class DownloadedFile {
  final String name;
  final String? path; // For regular files
  final String? uri; // For SAF content URIs
  final int size;
  final DateTime lastModified;

  DownloadedFile({
    required this.name,
    this.path,
    this.uri,
    required this.size,
    required this.lastModified,
  });

  String get displayPath => path ?? uri ?? '';

  bool get isContentUri => uri != null;
}
