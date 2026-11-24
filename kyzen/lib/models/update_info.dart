class PlatformDownload {
  final String downloadUrl;
  final bool isDirectDownload;
  final String fileName;
  final String? zipPassword;

  const PlatformDownload({
    required this.downloadUrl,
    required this.isDirectDownload,
    required this.fileName,
    this.zipPassword,
  });

  factory PlatformDownload.fromJson(Map<String, dynamic> json) {
    return PlatformDownload(
      downloadUrl: json['download_url'] as String,
      isDirectDownload: json['is_direct_download'] as bool? ?? false,
      fileName: json['file_name'] as String,
      zipPassword: json['zip_password'] as String?,
    );
  }
}

class UpdateInfo {
  final String latestVersion;
  final String changelog;
  final Map<String, PlatformDownload> platforms;

  const UpdateInfo({
    required this.latestVersion,
    required this.changelog,
    required this.platforms,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final platformsJson = json['platforms'] as Map<String, dynamic>;
    final platforms = platformsJson.map(
      (key, value) => MapEntry(
        key,
        PlatformDownload.fromJson(value as Map<String, dynamic>),
      ),
    );

    return UpdateInfo(
      latestVersion: json['latest_version'] as String,
      changelog: json['changelog'] as String,
      platforms: platforms,
    );
  }
}

class UpdateResult {
  final bool updateAvailable;
  final String? latestVersion;
  final String? changelog;
  final PlatformDownload? platformDownload;

  const UpdateResult({
    required this.updateAvailable,
    this.latestVersion,
    this.changelog,
    this.platformDownload,
  });

  // No update available or check failed.
  const UpdateResult.none() : this(updateAvailable: false);
}
