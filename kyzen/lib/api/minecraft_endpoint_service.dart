import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'environment_service.dart';

class MinecraftEndpoints {
  // i hope theres someone dumb enough to brute force this shit
  static const String _devSharedSecretHash = '360c6e3861b903dc889fac249e081c0e';

  static late bool _isDev;

  static void setEnvironment(EnvironmentConfig env) {
    final hash = md5.convert(utf8.encode(env.sharedSecret)).toString();
    _isDev = hash == _devSharedSecretHash;
  }

  static String get sessionStart => _isDev
      ? 'https://auth.dev-568eb875.franchise.minecraft-services.net/api/v1.0/session/start'
      : 'https://authorization.franchise.minecraft-services.net/api/v1.0/session/start';

  static String get inventory => _isDev
      ? 'https://entitlements.dev-593aa568.mktpl.minecraft-services.net/api/v1.0/player/inventory?includeReceipt=true'
      : 'https://entitlements.mktpl.minecraft-services.net/api/v1.0/player/inventory?includeReceipt=true';

  static String get virtualBalances => _isDev
      ? 'https://entitlements.dev-593aa568.mktpl.minecraft-services.net/api/v1.0/currencies/virtual/balances'
      : 'https://entitlements.mktpl.minecraft-services.net/api/v1.0/currencies/virtual/balances';

  static String get currencyId => _isDev
      ? '6c7001bb-03b3-44c4-8464-2e3c84014c3d'
      : 'ecd19d3c-7635-402c-a185-eb11cb6c6946';

  static String? profileHeadUrl(String? xuid) =>
      (xuid != null && xuid.isNotEmpty)
      ? 'https://persona-secondary.franchise.minecraft-services.net/api/v1.0/profile/xuid/$xuid/image/head'
      : null;

  static String? profileAvatarUrl(String? xuid) =>
      (xuid != null && xuid.isNotEmpty)
      ? 'https://persona-secondary.franchise.minecraft-services.net/api/v1.0/profile/xuid/$xuid/image/avatar'
      : null;
}
