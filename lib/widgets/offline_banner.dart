import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

/// Wraps the entire app with a bottom-sliding connectivity status banner.
///
/// - Offline  → red banner slides up, stays until reconnected
/// - Back online → switches to green banner for 3 seconds, then slides back down
class OfflineAwareWrapper extends StatefulWidget {
  final Widget child;
  const OfflineAwareWrapper({super.key, required this.child});

  @override
  State<OfflineAwareWrapper> createState() => _OfflineAwareWrapperState();
}

class _OfflineAwareWrapperState extends State<OfflineAwareWrapper> {
  ConnectivityService? _service;
  bool _showBanner = false;
  bool _isBackOnline = false;
  Timer? _onlineTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<ConnectivityService>();
    if (_service != service) {
      _service?.removeListener(_onChanged);
      _service = service;
      service.addListener(_onChanged);
      // Reflect current state immediately on first attach
      if (service.isOffline) {
        _showBanner = true;
        _isBackOnline = false;
      }
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final isOffline = _service?.isOffline ?? false;

    if (isOffline) {
      // Went offline → red banner, cancel any pending "back online" dismiss
      _onlineTimer?.cancel();
      setState(() {
        _showBanner = true;
        _isBackOnline = false;
      });
    } else if (_showBanner) {
      // Came back online after being offline → green for 3 s then hide
      _onlineTimer?.cancel();
      setState(() => _isBackOnline = true);
      _onlineTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() { _showBanner = false; _isBackOnline = false; });
      });
    }
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _service?.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          bottom: _showBanner ? 0 : -120,
          left: 0,
          right: 0,
          child: _OfflineBanner(isBackOnline: _isBackOnline),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatefulWidget {
  final bool isBackOnline;
  const _OfflineBanner({required this.isBackOnline});

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        // Red when offline, green when back online
        color: widget.isBackOnline
            ? const Color(0xFF2E7D32) // green
            : const Color(0xFFD32F2F), // red
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: widget.isBackOnline
                ? _OnlineContent()
                : _OfflineContent(pulseAnim: _pulseAnim),
          ),
        ),
      ),
    );
  }
}

// ── Offline row ───────────────────────────────────────────────────────────────

class _OfflineContent extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _OfflineContent({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pulsing dot
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (context, _) => Opacity(
            opacity: pulseAnim.value,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 19),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No Internet Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Something went wrong. Waiting to reconnect\u2026',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 15, height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Back-online row ───────────────────────────────────────────────────────────

class _OnlineContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.wifi_rounded, color: Colors.white, size: 19),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Back Online',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Your connection has been restored.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
      ],
    );
  }
}
