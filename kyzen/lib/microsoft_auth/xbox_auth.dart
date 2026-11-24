import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/impl.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_generators/ec_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:uuid/uuid.dart';
import 'live_auth.dart';

// Encode BigInt to a Uint8List (big-endian).
// This is needed for correctly formatting the ECDSA signature.
Uint8List _bigIntToBytes(BigInt number, {int outLen = 32}) {
  final bytes = (number.bitLength + 7) ~/ 8;
  final data = ByteData(bytes);
  var x = number;
  for (var i = bytes - 1; i >= 0; i--) {
    data.setUint8(i, x.toUnsigned(8).toInt());
    x = x >> 8;
  }

  if (bytes < outLen) {
    final paddedData = Uint8List(outLen)
      ..setRange(outLen - bytes, outLen, data.buffer.asUint8List());
    return paddedData;
  }

  return data.buffer.asUint8List().sublist(bytes - outLen);
}

/// Represents the final Xbox Live token required for authentication.
class XBLToken {
  final String token;
  final String userHash;
  final String? gamertag;
  final String? xuid;

  XBLToken._({
    required this.token,
    required this.userHash,
    this.gamertag,
    this.xuid,
  });

  factory XBLToken.fromJson(Map<String, dynamic> json) {
    final authorizationToken = json['AuthorizationToken'];
    if (authorizationToken == null) {
      throw const FormatException("JSON response missing 'AuthorizationToken'");
    }

    final displayClaims = authorizationToken['DisplayClaims'];
    final userInfoList = displayClaims?['xui'] as List?;

    if (userInfoList == null || userInfoList.isEmpty) {
      throw const FormatException("JSON response missing 'xui' claims");
    }

    final userInfo = userInfoList[0];
    return XBLToken._(
      token: authorizationToken['Token'],
      userHash: userInfo['uhs'],
      gamertag: userInfo['gtg'],
      xuid: userInfo['xid'],
    );
  }

  /// Returns the value for the 'Authorization' header for Minecraft services.
  String get authorizationHeader => 'XBL3.0 x=$userHash;$token';
}

/// Represents the intermediate device token.
class DeviceToken {
  final String token;
  DeviceToken.fromJson(Map<String, dynamic> json) : token = json['Token'];
}

/// A service to handle the Xbox Live authentication flow.
class XboxAuthService {
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  XboxAuthService() : _client = _createHttpClient();

  static http.Client _createHttpClient() {
    return http.Client();
  }

  /// Request an XBL token using a Microsoft OAuth2 token.
  Future<XBLToken> requestXBLToken(OAuth2Token liveToken) async {
    if (liveToken.isExpired) {
      throw Exception('Microsoft OAuth2 token is expired.');
    }

    try {
      // 1. Generate an ECDSA key pair for Proof-of-Possession.
      final keyPair = _generateEcdsaKeyPair();

      // 2. Obtain a device token.
      final deviceToken = await _obtainDeviceToken(keyPair);

      // 3. Use the device token and live token to get the final XBL token.
      final xblToken = await _obtainXBLToken(liveToken, deviceToken, keyPair);

      return xblToken;
    } finally {
      _client.close();
    }
  }

  /// Step 1: Generates an ECDSA key pair on the P-256 curve.
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _generateEcdsaKeyPair() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    final curve = ECCurve_secp256r1();
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(curve), secureRandom),
      );

    return generator.generateKeyPair();
  }

  /// Step 2: Obtains a device token from the Xbox Live device auth endpoint.
  Future<DeviceToken> _obtainDeviceToken(
    AsymmetricKeyPair<ECPublicKey, ECPrivateKey> keyPair,
  ) async {
    const url = 'https://device.auth.xboxlive.com/device/authenticate';
    final publicKey = keyPair.publicKey;

    final body = {
      'RelyingParty': 'http://auth.xboxlive.com',
      'TokenType': 'JWT',
      'Properties': {
        'AuthMethod': 'ProofOfPossession',
        'Id': '{${_uuid.v4()}}',
        'DeviceType': 'Android',
        'Version': '10',
        'ProofKey': {
          'crv': 'P-256',
          'alg': 'ES256',
          'use': 'sig',
          'kty': 'EC',
          'x': base64Url
              .encode(_bigIntToBytes(publicKey.Q!.x!.toBigInteger()!))
              .replaceAll('=', ''),
          'y': base64Url
              .encode(_bigIntToBytes(publicKey.Q!.y!.toBigInteger()!))
              .replaceAll('=', ''),
        },
      },
    };

    final bodyBytes = utf8.encode(json.encode(body));
    final request = http.Request('POST', Uri.parse(url))
      ..headers['x-xbl-contract-version'] = '1'
      ..headers['Content-Type'] = 'application/json'
      ..bodyBytes = bodyBytes;

    _signRequest(request, bodyBytes, keyPair.privateKey);

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to obtain device token: ${response.statusCode} $responseBody',
      );
    }

    return DeviceToken.fromJson(json.decode(responseBody));
  }

  /// Step 3: Obtains the final XBL token from the Sisu authorization endpoint.
  Future<XBLToken> _obtainXBLToken(
    OAuth2Token liveToken,
    DeviceToken deviceToken,
    AsymmetricKeyPair<ECPublicKey, ECPrivateKey> keyPair,
  ) async {
    const url = 'https://sisu.xboxlive.com/authorize';
    final publicKey = keyPair.publicKey;

    final body = {
      'AccessToken': 't=${liveToken.accessToken}',
      'AppId': '0000000048183522',
      'deviceToken': deviceToken.token,
      'Sandbox': 'RETAIL',
      'UseModernGamertag': true,
      'SiteName': 'user.auth.xboxlive.com',
      'RelyingParty': 'https://b980a380.minecraft.playfabapi.com/',
      'ProofKey': {
        'crv': 'P-256',
        'alg': 'ES256',
        'use': 'sig',
        'kty': 'EC',
        'x': base64Url
            .encode(_bigIntToBytes(publicKey.Q!.x!.toBigInteger()!))
            .replaceAll('=', ''),
        'y': base64Url
            .encode(_bigIntToBytes(publicKey.Q!.y!.toBigInteger()!))
            .replaceAll('=', ''),
      },
    };

    final bodyBytes = utf8.encode(json.encode(body));
    final request = http.Request('POST', Uri.parse(url))
      ..headers['x-xbl-contract-version'] = '1'
      ..headers['Content-Type'] = 'application/json'
      ..bodyBytes = bodyBytes;

    _signRequest(request, bodyBytes, keyPair.privateKey);

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      final errorCode = response.headers['x-err'];
      if (errorCode != null) {
        throw Exception(
          'Failed to obtain XBL token: ${_parseXboxErrorCode(errorCode)}',
        );
      }
      throw Exception(
        'Failed to obtain XBL token: ${response.statusCode} $responseBody',
      );
    }

    return XBLToken.fromJson(json.decode(responseBody));
  }

  /// Signs HTTP request with an ECDSA signature
  void _signRequest(
    http.Request request,
    Uint8List bodyBytes,
    ECPrivateKey privateKey,
  ) {
    final windowsTimestamp =
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 11644473600) *
        10000000;

    final hash = SHA256Digest();

    // Signature policy version (1) and null terminator.
    final policyBytes = Uint8List.fromList([0, 0, 0, 1, 0]);

    // Timestamp (Big Endian) and null terminator.
    final timestampBytes = ByteData(8)
      ..setUint64(0, windowsTimestamp, Endian.big);
    final timestampWithNull = Uint8List.fromList(
      timestampBytes.buffer.asUint8List() + [0],
    );

    // HTTP method and null terminator.
    final methodBytes = utf8.encode('${request.method}\x00');

    // Request path and query and null terminator.
    final pathBytes = utf8.encode(
      '${request.url.path}${request.url.query}\x00',
    );

    // Authorization header (empty for these requests) and null terminator.
    final authBytes = utf8.encode('\x00');

    // Body and null terminator.
    final bodyWithNull = Uint8List.fromList(bodyBytes + [0]);

    // Build the full payload to be hashed.
    final toSign = Uint8List.fromList(
      policyBytes +
          timestampWithNull +
          methodBytes +
          pathBytes +
          authBytes +
          bodyWithNull,
    );

    // Hash the payload.
    final digest = hash.process(toSign);

    // Sign the hash.
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter(privateKey));
    final ecSignature = signer.generateSignature(digest) as ECSignature;

    // The signature is r and s values concatenated.
    final signatureBytes = Uint8List.fromList(
      _bigIntToBytes(ecSignature.r) + _bigIntToBytes(ecSignature.s),
    );

    // Prepend the signature policy version (1) and the timestamp again.
    final headerBytes = Uint8List.fromList(
      [0, 0, 0, 1] + timestampBytes.buffer.asUint8List() + signatureBytes,
    );

    request.headers['Signature'] = base64.encode(headerBytes);
  }

  String _parseXboxErrorCode(String code) {
    switch (code) {
      case '2148916227':
        return '($code) Your account was banned by Xbox for violating one or more Community Standards for Xbox and is unable to be used.';
      case '2148916229':
        return '($code) Your account is currently restricted and your guardian has not given you permission to play online. Login to https://account.microsoft.com/family/ and have your guardian change your permissions.';
      case '2148916233':
        return '($code) Your account currently does not have an Xbox profile. Please create one at https://signup.live.com/signup';
      case '2148916234':
        return '($code) Your account has not accepted Xbox\'s Terms of Service. Please login and accept them.';
      case '2148916235':
        return '($code) Your account resides in a region that Xbox has not authorized use from. Xbox has blocked your attempt at logging in.';
      case '2148916236':
        return '($code) Your account requires proof of age. Please login to https://login.live.com/login.srf and provide proof of age.';
      case '2148916237':
        return '($code) Your account has reached its limit for playtime. Your account has been blocked from logging in.';
      case '2148916238':
        return '($code) The account date of birth is under 18 years and cannot proceed unless the account is added to a family by an adult.';
      default:
        return 'Unknown Xbox error code: $code';
    }
  }
}
