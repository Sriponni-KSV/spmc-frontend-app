import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Enables localhost routing for USB cable debugging (`adb reverse tcp:3001 tcp:3001`) & Web.
  static bool get useLocalhost => true;

  /// Your laptop's local Wi-Fi IP address on the network
  static const String backendIp = '192.168.1.5';

  /// Backend server port
  static const String port = '3001';

  /// Gets the active base URL dynamically for Web and Mobile
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl.substring(0, envUrl.length - 1) : envUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';
      return '$scheme://$host:$port/api';
    }
    if (useLocalhost) {
      // USB Cable Debugging (`adb reverse`)
      return 'http://localhost:$port/api';
    }
    // Standalone APK over Wi-Fi
    return 'http://$backendIp:$port/api';
  }
}
