import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  bool _isOffline = false;
  bool get isOffline => _isOffline;

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
          _setOffline(true);
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
    try {
      // Any HTTP response (200, 404, 401 …) means the backend is reachable.
      // Only a socket/network exception means we're truly offline.
      await http
          .get(Uri.parse(_backendUrl))
          .timeout(const Duration(seconds: 4));
      _setOffline(false);
    } catch (_) {
      _setOffline(true);
    }
  }

  void _setOffline(bool offline) {
    if (_isOffline != offline) {
      _isOffline = offline;
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

