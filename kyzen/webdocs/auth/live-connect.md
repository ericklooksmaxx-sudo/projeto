# LiveConnectAuth

Microsoft Live Connect OAuth2 authentication to authorize the client to act on behalf of a user's personal Xbox Live account.

## Class Properties

- `clientId`: Xbox App Client ID (`0000000048183522`).
- `scope`: Target scope requesting Xbox Live access (`service::user.auth.xboxlive.com::MBI_SSL`).
- `redirectUri`: Same protocol scheme as Minecraft (`ms-xal-0000000048183522://auth`).

## Primary Methods

### `getAuthorizationUrl()` → `String`

Constructs the Microsoft OAuth2 login URL redirecting users to sign in. Includes the custom application Client ID, scope, and the registered redirect URI.

### `exchangeCodeForToken({required String code})` → `Future<OAuth2Token>`

Exchanges the deep-linked authorization code for access and refresh tokens. Saves tokens locally to `personal_token.json`. (Maybe they should be encrypted)

### `getToken()` → `Future<OAuth2Token>`

Loads token from cache/storage. If the token is expired, automatically calls the token refresh endpoint using the refresh token before returning.

## Code Example

```dart
// Example OAuth Flow
final auth = LiveConnectAuth();

// Generate Browser URL
final url = auth.getAuthorizationUrl();
// Open url in browser...

// Receive Code from Redirect
final token = await auth.exchangeCodeForToken(
  code: "M.R3_XYZ..."
);
print("Token: ${token.accessToken}");
```
