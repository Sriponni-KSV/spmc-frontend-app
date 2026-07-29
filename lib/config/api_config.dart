import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Automatically `true` when running on Web (Browser),
  /// and `false` when running on Mobile App (Android/iOS)!
  static bool get useLocalhost => kIsWeb;

  /// Your laptop's local Wi-Fi IP address on the network
  static const String backendIp = '192.168.1.56';

  /// Backend server port
  static const String port = '3000';

  /// Gets the active base URL dynamically for Web and Mobile
  static String get baseUrl {
    // 1. Running on WEB (kIsWeb = true) -> Automatically uses localhost
    if (useLocalhost) {
      return 'http://localhost:$port/api';
    }

    // 2. Running on MOBILE (kIsWeb = false) -> Check if .env has custom IP
    final envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('localhost')) {
      return envUrl;
    }

    // 3. Running on MOBILE -> Uses direct laptop Wi-Fi IP
    return 'http://$backendIp:$port/api';
  }
}
