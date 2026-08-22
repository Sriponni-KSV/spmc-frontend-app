import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Top-level Overlay notification banner that displays above all modals, dialogs, and popups.
class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show an error/validation notification banner above all popups and dialogs.
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.error_outline_rounded,
      iconColor: AppTheme.dangerColor,
      borderColor: AppTheme.dangerColor.withValues(alpha: 0.5),
      backgroundColor: const Color(0xFFFEF2F2),
      textColor: const Color(0xFF991B1B),
      duration: duration,
    );
  }

  /// Show a success notification banner above all popups and dialogs.
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppTheme.secondaryColor,
      borderColor: AppTheme.secondaryColor.withValues(alpha: 0.5),
      backgroundColor: const Color(0xFFF0FDF4),
      textColor: const Color(0xFF166534),
      duration: duration,
    );
  }

  /// Show a warning notification banner above all popups and dialogs.
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFD97706),
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
      backgroundColor: const Color(0xFFFFFBEB),
      textColor: const Color(0xFF92400E),
      duration: duration,
    );
  }

  /// Show an informational notification banner above all popups and dialogs.
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.info_outline_rounded,
      iconColor: AppTheme.primaryColor,
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      backgroundColor: const Color(0xFFF0F9FF),
      textColor: const Color(0xFF075985),
      duration: duration,
    );
  }

  /// Core method to render a floating notification card in the root Overlay.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = AppTheme.primaryColor,
    Color borderColor = const Color(0xFFE2E8F0),
    Color backgroundColor = Colors.white,
    Color textColor = const Color(0xFF1E293B),
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing active notification
    dismiss();

    try {
      final overlay = Overlay.of(context, rootOverlay: true);

      _currentEntry = OverlayEntry(
        builder: (ctx) => _NotificationBannerWidget(
          message: message,
          title: title,
          icon: icon,
          iconColor: iconColor,
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          textColor: textColor,
          onDismiss: dismiss,
        ),
      );

      overlay.insert(_currentEntry!);

      _dismissTimer = Timer(duration, () {
        dismiss();
      });
    } catch (_) {
      // Fallback to standard ScaffoldMessenger if overlay is unavailable
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: iconColor,
            duration: duration,
          ),
        );
      } catch (_) {}
    }
  }

  /// Dismiss the active overlay notification.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.message,
    this.title,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _animCtrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    return Positioned(
      top: mediaQuery.padding.top + 16,
      left: isMobile ? 12 : (mediaQuery.size.width - 480) / 2,
      right: isMobile ? 12 : null,
      width: isMobile ? null : 480,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 20, color: widget.iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null &&
                            widget.title!.trim().isNotEmpty) ...[
                          Text(
                            widget.title!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.textColor,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.textColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleDismiss,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: widget.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
