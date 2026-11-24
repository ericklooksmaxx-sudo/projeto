// These class models are all used for personal account (for auth page)

class XboxLoginResultPersonaPlayer {
  final String sessionTicket;
  final String playFabId;
  final String? xboxUserId;
  final String? entityToken;
  final String? username;

  XboxLoginResultPersonaPlayer({
    required this.sessionTicket,
    required this.playFabId,
    this.xboxUserId,
    this.entityToken,
    this.username,
  });
}

class EntityTokenResult {
  final String entityToken;
  final DateTime tokenExpiration;
  final String entityId;

  EntityTokenResult({
    required this.entityToken,
    required this.tokenExpiration,
    required this.entityId,
  });
}

class PurchaseItemResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;

  PurchaseItemResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  bool get isAlreadyOwned =>
      errorCode == '400' && errorMessage?.contains('is not stackable') == true;

  bool get isInsufficientFunds =>
      errorCode == '422' ||
      errorMessage?.toLowerCase().contains('insufficient') == true;

  bool get isNotPurchasable =>
      errorCode == '400' &&
      (errorMessage?.contains('is not purchasable') == true ||
          errorMessage?.contains('NonPurchasableItem') == true);
}
