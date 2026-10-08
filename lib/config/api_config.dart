import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Production Backend API URL (HTTPS Domain)
  static const String productionBaseUrl =
      'https://hms.sriponnimedicalcentre.com/api';

  /// Testing Backend API URL for Vercel Deployments (Hosted on Render)
  static const String testingVercelBaseUrl =
      'https://spmc-backend.onrender.com/api';

  /// Default local backend port
  static const String defaultLocalPort = '3000';

  /// Optional compile-time environment override (--dart-define=BASE_URL=...)
  static const String environmentBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Gets the active base URL dynamically:
  /// - On Localhost (Web/Desktop/Mobile): Routes to Local backend (http://localhost:3000/api).
  /// - On Vercel (*.vercel.app): Routes to Testing backend (https://spmc-backend.onrender.com/api).
  /// - On Live Domain (*.sriponnimedicalcentre.com) & Production APK: Routes to Production backend (https://hms.sriponnimedicalcentre.com/api).
  static String get baseUrl {
    // 1. Explicit compile-time override via --dart-define BASE_URL=...
    if (environmentBaseUrl.isNotEmpty) {
      return _normalizeUrl(environmentBaseUrl);
    }

    // 2. Flutter Web Platform (Browser Domain Auto-Detection)
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';

      // A. Running locally in browser (localhost / 127.0.0.1) -> route to local backend
      if (host == 'localhost' || host == '127.0.0.1') {
        return '$scheme://$host:$defaultLocalPort/api';
      }

      // B. Testing server on Vercel (*.vercel.app) -> route to Render test backend
      if (host.contains('vercel.app')) {
        return testingVercelBaseUrl;
      }

      // C. Live Production Domain (*.sriponnimedicalcentre.com)
      if (host.contains('sriponnimedicalcentre.com')) {
        return productionBaseUrl;
      }

      // D. Generic web hosting fallback (reverse proxy on same host/port)
      if (Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443) {
        return '$scheme://$host:${Uri.base.port}/api';
      }
      return '$scheme://$host/api';
    }

    // 3. Mobile & Desktop Production Release Mode (Release APK / AppBundle)
    if (kReleaseMode) {
      return productionBaseUrl;
    }

    // 4. In Debug Mode on Mobile/Desktop: Check .env / assets/.env for custom local overrides
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
