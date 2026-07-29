import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Set to `true` when testing via USB Cable (with `adb reverse tcp:3000 tcp:3000`) or Web.
  /// Set to `false` for standalone APK connecting over Wi-Fi IP (`192.168.1.56`).
  static bool get useLocalhost => kIsWeb || true; 

  /// Your laptop's local Wi-Fi IP address on the network
  static const String backendIp = '192.168.1.56';

  /// Backend server port
  static const String port = '3000';

  /// Gets the active base URL dynamically for Web and Mobile
  static String get baseUrl {
    // 1. If useLocalhost is true (Web or USB Cable debugging via `adb reverse`)
    if (useLocalhost) {
      return 'http://localhost:$port/api';
    }

    // 2. Standalone APK over Wi-Fi IP
    final envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('localhost')) {
      return envUrl;
    }

    return 'http://$backendIp:$port/api';
  }
}
