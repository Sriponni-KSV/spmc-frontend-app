import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Production Backend API URL (HTTPS Domain)
  static const String productionBaseUrl =
      'https://hms.sriponnimedicalcentre.com/api';

  /// Default local backend port
  static const String defaultLocalPort = '3000';

  /// Optional compile-time environment override (--dart-define=BASE_URL=...)
  static const String environmentBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Gets the active base URL dynamically:
  /// - In Release mode (Production build / live deployment): ALWAYS uses the live Production backend.
  /// - In Debug / Local development mode: Automatically routes to the Local backend without manual editing.
  static String get baseUrl {
    // 1. Explicit compile-time override via --dart-define BASE_URL=...
    if (environmentBaseUrl.isNotEmpty) {
      return _normalizeUrl(environmentBaseUrl);
    }

    // 2. Production Release Mode: ALWAYS connect to the live backend domain
    if (kReleaseMode) {
      return productionBaseUrl;
    }

    // 3. Flutter Web Platform (Browser)
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';

      // Running locally in browser (localhost / 127.0.0.1) -> route to local backend
      if (host == 'localhost' || host == '127.0.0.1') {
        return '$scheme://$host:$defaultLocalPort/api';
      }

      // Hosted on live domain
      if (host.contains('sriponnimedicalcentre.com')) {
        return productionBaseUrl;
      }

      // Generic web hosting (reverse proxy /api on same host/port)
      if (Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443) {
        return '$scheme://$host:${Uri.base.port}/api';
      }
      return '$scheme://$host/api';
    }

    // 4. In Debug Mode on Mobile/Desktop: Check .env / assets/.env for local overrides
    try {
      final envUrl = dotenv.maybeGet('BASE_URL');
      if (envUrl != null && envUrl.trim().isNotEmpty) {
        return _normalizeUrl(envUrl);
      }
    } catch (_) {}

    // 5. Mobile & Desktop Local Debug Defaults:
    // - Android Emulator loopback: 10.0.2.2:3000
    // - Physical Android device (via `adb reverse tcp:3000 tcp:3000`), iOS Simulator & Desktop: localhost:3000
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$defaultLocalPort/api';
    }

    return 'http://localhost:$defaultLocalPort/api';
  }

  /// Removes trailing slashes for clean URL concatenations
  static String _normalizeUrl(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

