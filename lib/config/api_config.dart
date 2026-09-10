import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Enables localhost routing for USB cable debugging or Desktop app.
  static bool get useLocalhost => false;

  /// Your laptop's local Wi-Fi IP address on the network for local testing
  static const String backendIp = '192.168.1.6';

  /// Backend server port for local development.
  static const String port = '3001';

  /// Production/API URL supplied through --dart-define.
  static const String environmentBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Gets the active base URL dynamically.
  static String get baseUrl {
    // 1. Check flutter_dotenv configuration (if explicitly set in .env)
    try {
      final envUrl = dotenv.maybeGet('BASE_URL');
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        final trimmed = envUrl.trim();
        return trimmed.endsWith('/')
            ? trimmed.substring(0, trimmed.length - 1)
            : trimmed;
      }
    } catch (_) {}

    // 2. --dart-define BASE_URL
    if (environmentBaseUrl.isNotEmpty) {
      return environmentBaseUrl.endsWith('/')
          ? environmentBaseUrl.substring(0, environmentBaseUrl.length - 1)
          : environmentBaseUrl;
    }

    // 3. Flutter Web
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';

      // Local development on localhost/127.0.0.1
      if (host == 'localhost' || host == '127.0.0.1') {
        return '$scheme://$host:$port/api';
      }

      // Live deployment (e.g. 32.194.16.162 or domain): Nginx reverse-proxies /api on the same web port
      if (Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443) {
        return '$scheme://$host:${Uri.base.port}/api';
      }
      return '$scheme://$host/api';
    }

    // 4. Mobile local development using adb reverse (explicitly opted in)
    if (useLocalhost) {
      return 'http://localhost:$port/api';
    }

    // 5. Mobile device over Wi-Fi
    return 'http://$backendIp:$port/api';
  }
}
