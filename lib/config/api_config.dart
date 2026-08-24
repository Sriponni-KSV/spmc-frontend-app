import 'package:flutter/foundation.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Enables localhost routing for USB cable debugging.
  static bool get useLocalhost => true;

  /// Your laptop's local Wi-Fi IP address on the network
  static const String backendIp = '192.168.1.58';

  /// Backend server port.
  static const String port = '3000';

  /// Production/API URL supplied through --dart-define.
  static const String environmentBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  /// Gets the active base URL dynamically.
  static String get baseUrl {
    // 1. --dart-define BASE_URL
    if (environmentBaseUrl.isNotEmpty) {
      return environmentBaseUrl.endsWith('/')
          ? environmentBaseUrl.substring(0, environmentBaseUrl.length - 1)
          : environmentBaseUrl;
    }

    // 2. Flutter Web local development
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty
          ? Uri.base.host
          : 'localhost';

      final scheme = Uri.base.scheme.startsWith('https')
          ? 'https'
          : 'http';

      return '$scheme://$host:$port/api';
    }

    // 3. Mobile local development using adb reverse
    if (useLocalhost) {
      return 'http://localhost:$port/api';
    }

    // 4. Mobile device over Wi-Fi
    return 'http://$backendIp:$port/api';
  }
}