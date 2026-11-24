import 'package:http/http.dart' as http;

// single instance
class AppHttpClient {
  AppHttpClient._();
  static final http.Client instance = http.Client();
}
