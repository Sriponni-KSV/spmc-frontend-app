import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Why the app is currently offline.
enum OfflineReason {
  /// Everything is fine.
  none,

  /// The device has no network interface at all (Wi-Fi/mobile data off).
  noInternet,

  /// The device has internet but the backend server is unreachable / stopped.
  serverDown,
}

/// Monitors connectivity by dynamically pinging the configured backend API endpoint.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _heartbeatTimer;

  OfflineReason _reason = OfflineReason.none;

  /// Whether the app is currently unable to reach the backend.
  bool get isOffline => _reason != OfflineReason.none;

  /// The specific reason we are offline (noInternet or serverDown).
  OfflineReason get offlineReason => _reason;

  ConnectivityService([String? backendUrl]) {
    _init();
  }

  Future<void> _init() async {
    // 1. Immediate ping on startup
    await _pingBackend();

    // 2. Listen for network adapter changes on native platforms
    if (!kIsWeb) {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          if (results.every((r) => r == ConnectivityResult.none)) {
            _setReason(OfflineReason.noInternet);
          } else {
            _pingBackend();
          }
        },
      );
    }

    // 3. Heartbeat: verify backend reachability every 5 seconds.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pingBackend();
    });
  }

  Future<void> _pingBackend() async {
    final baseUrl = ApiEndpoints.baseUrl;
    if (baseUrl.isEmpty) return;

    try {
      // Any HTTP response (200, 404, 401 …) means the backend is reachable.
      await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 4));
      _setReason(OfflineReason.none);
    } catch (_) {
      // If HTTP call threw, check if network interface is completely disconnected
      if (!kIsWeb) {
        try {
          final connectivityResults = await _connectivity.checkConnectivity();
          if (connectivityResults.every((r) => r == ConnectivityResult.none)) {
            _setReason(OfflineReason.noInternet);
            return;
          }
        } catch (_) {}
      }
      _setReason(OfflineReason.serverDown);
    }
  }

  void _setReason(OfflineReason reason) {
    if (_reason != reason) {
      _reason = reason;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
