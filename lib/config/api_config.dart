import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Enables localhost routing for USB cable debugging or Desktop app.
  static bool get useLocalhost => false;

  /// Your laptop's local Wi-Fi IP address on the network for local testing
  static const String backendIp = '192.168.1.35';

  /// Backend server port for local development.
  static const String port = '3000';

  /// Production/API URL supplied through --dart-define.
  static const String environmentBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Gets the active base URL dynamically.
  static String get baseUrl {
    // 1. Explicit --dart-define BASE_URL takes highest precedence
    if (environmentBaseUrl.isNotEmpty) {
      return environmentBaseUrl.endsWith('/')
          ? environmentBaseUrl.substring(0, environmentBaseUrl.length - 1)
          : environmentBaseUrl;
    }

    // 2. Flutter Web Platform
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';

      // Local development on localhost/127.0.0.1
      if (host == 'localhost' || host == '127.0.0.1') {
        try {
          final envUrl = dotenv.maybeGet('BASE_URL');
          if (envUrl != null && envUrl.trim().isNotEmpty) {
            final trimmed = envUrl.trim();
            return trimmed.endsWith('/')
                ? trimmed.substring(0, trimmed.length - 1)
                : trimmed;
          }
        } catch (_) {}
        return '$scheme://$host:$port/api';
      }

      // Live deployment (e.g. hms.sriponnimedicalcentre.com or IP)
      // If deployed behind reverse proxy (port 80 / 443), use same-origin /api
      if (Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443) {
        return '$scheme://$host:${Uri.base.port}/api';
      }
      return '$scheme://$host/api';
    }

    // 3. Mobile / Desktop: Check flutter_dotenv configuration
    try {
      final envUrl = dotenv.maybeGet('BASE_URL');
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        final trimmed = envUrl.trim();
        return trimmed.endsWith('/')
            ? trimmed.substring(0, trimmed.length - 1)
            : trimmed;
      }
    } catch (_) {}

    // 4. Mobile local development using adb reverse (explicitly opted in)
    if (useLocalhost) {
      return 'http://localhost:$port/api';
    }

    // 5. Mobile device over Wi-Fi
    return 'http://$backendIp:$port/api';
  }
}
