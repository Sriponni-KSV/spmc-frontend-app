import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import 'app_settings_dialog.dart';

/// Top-bar action buttons.
///
/// Contains two clearly distinct controls:
///  1. **Translate pill** — instantly toggles the UI language between English
///     and Tamil (EN ↔ தமிழ்).
///  2. **Settings (gear) button** — opens the Appearance / Theme dialog where
///     the user can pick Light, Dark, or System theme mode.
class AppTopBarActions extends StatelessWidget {
  final bool showClock;
  final Widget? liveClockWidget;
  /// Whether to display the Settings (Appearance / Theme) button.
  /// Hidden for now per requirement; can be enabled in the future by passing true or changing default.
  final bool showSettings;
  /// Whether to display the Language (Translate) quick-toggle pill.
  final bool showLanguageToggle;

  const AppTopBarActions({
    super.key,
    this.showClock = false,
    this.liveClockWidget,
    this.showSettings = true,
    this.showLanguageToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = AppTheme.isDark(context);

    final iconColor =
        isDark ? AppTheme.darkTextSecondaryColor : const Color(0xFF4A5568);
    final buttonBg = isDark ? AppTheme.darkCardColor : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorderColor : const Color(0xFFCBD5E1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. Language Quick-Toggle Pill ─────────────────────────────────
        // Tapping this pill immediately switches the entire UI between
        // English and Tamil. It is NOT a settings panel — it is a one-tap
        // language toggle, the same action as "Translate".
        if (showLanguageToggle) ...[
          Tooltip(
            message: languageProvider.isTamil
                ? 'Switch to English'
                : 'தமிழிற்கு மாறு (Switch to Tamil)',
            child: InkWell(
              onTap: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                languageProvider.toggleLanguage(userId: auth.user?.id);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 34,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      size: 15,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      languageProvider.isTamil ? 'தமிழ்' : 'EN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 14,
                      color: iconColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── 2. Settings (Appearance / Theme) Button ───────────────────────
        // Opens the AppSettingsDialog which lets the user select the app's
        // theme mode: Light, Dark, or System Default, as well as application language.
        if (showSettings) ...[
          if (showLanguageToggle) const SizedBox(width: 10),
          Tooltip(
            message: context.tr(
              'settings',
              fallback: 'Settings',
            ),
            child: InkWell(
              onTap: () => AppSettingsDialog.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: buttonBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.settings_outlined,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Optional Live Clock ───────────────────────────────────────────
        if (showClock && liveClockWidget != null) ...[
          const SizedBox(width: 12),
          liveClockWidget!,
        ],
      ],
    );
  }
}
