import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Root-level Overlay bar notification (styled like a standard bottom SnackBar)
/// that always displays in front of all dialogs, modals, and popups.
class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show an error notification bar (solid danger red with white text).
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: AppTheme.dangerColor,
      textColor: Colors.white,
      duration: duration,
    );
  }

  /// Show a success notification bar (solid green with white text).
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: AppTheme.secondaryColor,
      textColor: Colors.white,
      duration: duration,
    );
  }

  /// Show a warning notification bar (solid orange with white text).
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFD97706),
      textColor: Colors.white,
      duration: duration,
    );
  }

  /// Show an informational notification bar (solid brand blue with white text).
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppTheme.primaryColor,
      textColor: Colors.white,
      duration: duration,
    );
  }

  /// Localizes standard notification messages into Tamil if active locale is Tamil.
  static String localizeMessage(BuildContext context, String message) {
    if (message.trim().isEmpty) return message;
    bool isTamil = false;
    try {
      isTamil = Localizations.localeOf(context).languageCode == 'ta';
    } catch (_) {}
    if (!isTamil) return message;

    final trimmed = message.trim();

    const directMap = <String, String>{
      'Home visit care plan cancelled successfully':
          'வீட்டு வருகை பராமரிப்புத் திட்டம் வெற்றிகரமாக ரத்து செய்யப்பட்டது',
      'Procedure record deleted successfully':
          'செயல்முறை பதிவு வெற்றிகரமாக நீக்கப்பட்டது',
      'Medicine record deleted successfully':
          'மருந்து பதிவு வெற்றிகரமாக நீக்கப்பட்டது',
      'Procedure recorded successfully':
          'செயல்முறை வெற்றிகரமாக பதிவு செய்யப்பட்டது',
      'Procedure updated successfully':
          'செயல்முறை வெற்றிகரமாக புதுப்பிக்கப்பட்டது',
      'Medicine recorded successfully':
          'மருந்து வெற்றிகரமாக பதிவு செய்யப்பட்டது',
      'Medicine updated successfully':
          'மருந்து வெற்றிகரமாக புதுப்பிக்கப்பட்டது',
      'Failed to save procedure': 'செயல்முறையை சேமிக்க முடியவில்லை',
      'Failed to update procedure': 'செயல்முறையை புதுப்பிக்க முடியவில்லை',
      'Failed to delete procedure': 'செயல்முறையை நீக்க முடியவில்லை',
      'Failed to save medicine': 'மருந்தை சேமிக்க முடியவில்லை',
      'Failed to update medicine': 'மருந்தை புதுப்பிக்க முடியவில்லை',
      'Failed to delete medicine': 'மருந்தை நீக்க முடியவில்லை',
      'Nursing care saved successfully':
          'செவிலியர் பராமரிப்பு வெற்றிகரமாக சேமிக்கப்பட்டது',
      'Failed to save nursing care':
          'செவிலியர் பராமரிப்பை சேமிக்க முடியவில்லை',
      'Dressing details contains invalid special characters':
          'கட்டுப்போடும் விவரங்களில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Nursing notes contains invalid special characters':
          'செவிலியர் குறிப்புகளில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Personal care details contains invalid special characters':
          'தனிநபர் பராமரிப்பு விவரங்களில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Medicine name contains invalid special characters':
          'மருந்து பெயரில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Consumable name contains invalid special characters':
          'உபயோகப் பொருள் பெயரில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Procedure name contains invalid special characters':
          'செயல்முறை பெயரில் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன',
      'Please enter at least one nursing note, dressing procedure, or personal care activity':
          'தயவுசெய்து ஒரு செவிலியர் குறிப்பு, கட்டுப்போடுதல் அல்லது பராமரிப்புப் பணியை உள்ளிடவும்',
      'Dressing details must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols':
          'கட்டுப்போடும் விவரங்களில் எழுத்துகள் இருக்க வேண்டும்; எண்கள் அல்லது குறியீடுகள் மட்டுமே இருக்கக்கூடாது',
      'Nursing notes must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols':
          'செவிலியர் குறிப்புகளில் எழுத்துகள் இருக்க வேண்டும்; எண்கள் அல்லது குறியீடுகள் மட்டுமே இருக்கக்கூடாது',
      'Personal care details must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols':
          'தனிநபர் பராமரிப்பு விவரங்களில் எழுத்துகள் இருக்க வேண்டும்; எண்கள் அல்லது குறியீடுகள் மட்டுமே இருக்கக்கூடாது',
    };

    if (directMap.containsKey(trimmed)) {
      return directMap[trimmed]!;
    }

    // Dynamic pattern for Home visit cancellation:
    final cancelMatch = RegExp(
      r'^Home visit care plan \(([^)]+)\) for (.+?) stopped and cancelled successfully\.?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (cancelMatch != null) {
      final visitNum = cancelMatch.group(1);
      final patient = cancelMatch.group(2);
      return '$patient-க்கான வீட்டு வருகை பராமரிப்புத் திட்டம் ($visitNum) நிறுத்தப்பட்டு வெற்றிகரமாக ரத்து செய்யப்பட்டது.';
    }

    // Dynamic pattern: "... contains invalid special characters"
    if (trimmed.toLowerCase().endsWith('contains invalid special characters')) {
      final subject = trimmed
          .substring(0, trimmed.length - 'contains invalid special characters'.length)
          .trim();
      return '$subject-ல் செல்லாத சிறப்பு எழுத்துக்கள் உள்ளன';
    }

    return message;
  }

  /// Core method to render a bottom SnackBar-style bar in the root Overlay.
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color backgroundColor = const Color(0xFF334155),
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismiss();

    final localizedMessage = localizeMessage(context, message);

    try {
      final overlay = Overlay.of(context, rootOverlay: true);

      _currentEntry = OverlayEntry(
        builder: (ctx) => _NotificationBarWidget(
          message: localizedMessage,
          icon: icon,
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
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizedMessage),
            backgroundColor: backgroundColor,
            duration: duration,
          ),
        );
      } catch (_) {}
    }
  }

  /// Dismiss the active overlay notification bar.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }
}

class _NotificationBarWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _NotificationBarWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_NotificationBarWidget> createState() => _NotificationBarWidgetState();
}

class _NotificationBarWidgetState extends State<_NotificationBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
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
      bottom: mediaQuery.padding.bottom + 16,
      left: isMobile ? 16 : (mediaQuery.size.width - 560) / 2,
      right: isMobile ? 16 : null,
      width: isMobile ? null : 560,
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: widget.textColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleDismiss,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white70,
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
