abstract final class AppVersion {
  static const int major = 1;
  static const int minor = 6;
  static const int ultraminor = 2;

  // '1.6.2'
  static const String string = '$major.$minor.$ultraminor';

  // 'v1.6.2'
  static const String display = 'v$string';

  // 'kyzen/1.6.2'
  static const String userAgent = 'kyzen/$string';
}
