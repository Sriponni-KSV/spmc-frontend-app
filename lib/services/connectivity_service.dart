import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Why the app is currently offline.
enum OfflineReason {
  /// Everything is fine.
  none,

  /// The device has no network interface at all (Wi-Fi/mobile data off).
  noInternet,

  /// The device has internet but the backend server is unreachable / stopped.
  serverDown,
}

/// Monitors connectivity by both listening to network-adapter changes
/// (via connectivity_plus) and periodically pinging the actual backend.
///
/// The heartbeat ping is the authoritative signal: any HTTP response (even
/// 4xx/5xx) means the backend is reachable; an exception means it is not.
/// This correctly handles:
///  - Backend stopped while running locally (localhost still "online" on Wi-Fi)
///  - Wi-Fi turned off when backend is on a remote host
///  - Production backend going down with internet still connected
class ConnectivityService extends ChangeNotifier {
  final String _backendUrl;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _heartbeatTimer;

  OfflineReason _reason = OfflineReason.none;

  /// Whether the app is currently unable to reach the backend.
  bool get isOffline => _reason != OfflineReason.none;

  /// The specific reason we are offline (noInternet or serverDown).
  OfflineReason get offlineReason => _reason;

  ConnectivityService(this._backendUrl) {
    _init();
  }

  Future<void> _init() async {
    // 1. Immediate ping on startup to know current state right away
    await _pingBackend();

    // 2. Listen for network-adapter changes (fast signal, works well on mobile)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.every((r) => r == ConnectivityResult.none)) {
          // No network interface at all — go offline immediately without waiting
          _setReason(OfflineReason.noInternet);
        } else {
          // Adapter came back — confirm with a real ping before clearing banner
          _pingBackend();
        }
      },
    );

    // 3. Heartbeat: verify backend reachability every 5 seconds.
    //    This is the key piece that makes it work on Flutter Web / localhost.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pingBackend();
    });
  }

  Future<void> _pingBackend() async {
    if (_backendUrl.isEmpty) return;

    // First check: does the device have any network at all?
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.every((r) => r == ConnectivityResult.none)) {
      _setReason(OfflineReason.noInternet);
      return;
    }

    // Second check: can we actually reach the backend?
    try {
      // Any HTTP response (200, 404, 401 …) means the backend is reachable.
      // Only a socket/network exception means we're truly offline.
      await http
          .get(Uri.parse(_backendUrl))
          .timeout(const Duration(seconds: 4));
      _setReason(OfflineReason.none);
    } catch (_) {
      // Internet is up (we checked above) but the backend is not responding.
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
