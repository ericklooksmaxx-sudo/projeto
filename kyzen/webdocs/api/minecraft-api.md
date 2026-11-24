# MinecraftApi

Communicates directly with Minecraft service endpoints to fetch balances and get user item entitlement.

## Configured Endpoints

| Name | Method | Production Endpoint |
|---|---|---|
| Session Start | `POST` | `https://authorization.franchise.minecraft-services.net/api/v1.0/session/start` |
| Player Inventory | `GET` | `https://entitlements.mktpl.minecraft-services.net/api/v1.0/player/inventory?includeReceipt=true` |
| Virtual Balance | `GET` | `https://entitlements.mktpl.minecraft-services.net/api/v1.0/currencies/virtual/balances` |

## Primary Methods

### `startMinecraftSession(String sessionTicket)` → `Future<Map>`

Exchanges the PlayFab session ticket for a short-lived `MCToken` (Minecraft Service Authorization Header) used in subsequent inventory requests.

### `getMinecoinBalance()` → `Future<int>`

Returns the balance of the virtual currency `Minecoin` associated with the active player session.

## Session Request Payload Example

```json
{
  "device": {
    "applicationType": "MinecraftPE",
    "gameVersion": "1.26.0",
    "platform": "Windows10",
    "storePlatform": "uwp.store",
    "type": "Windows10"
  },
  "user": {
    "language": "en",
    "languageCode": "en-US",
    "regionCode": "US",
    "token": "ST-12345...",
    "tokenType": "PlayFab"
  }
}
```
