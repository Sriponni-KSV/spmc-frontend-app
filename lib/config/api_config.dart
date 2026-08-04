import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized API Endpoints Configuration
class ApiEndpoints {
  /// Enables localhost routing for USB cable debugging (`adb reverse tcp:3000 tcp:3000`) & Web.
  static bool get useLocalhost => true;

  /// Your laptop's local Wi-Fi IP address on the network
  static const String backendIp = '192.168.1.56';

  /// Backend server port
  static const String port = '3000';

  /// Gets the active base URL dynamically for Web and Mobile
  static String get baseUrl {
    if (useLocalhost) {
      // USB Cable Debugging (`adb reverse`) & Web
      return 'http://localhost:$port/api';
    }
    // Standalone APK over Wi-Fi
    return 'http://$backendIp:$port/api';
  }
}
