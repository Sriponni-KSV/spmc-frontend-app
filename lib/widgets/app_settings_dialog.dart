import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// Application & Language Settings dialog.
///
/// Allows configuring:
/// 1. Language (English ↔ Tamil) — with a confirmation step before applying.
/// 2. Appearance & Theme (Light, Dark, System Default)
/// 3. A Close button to dismiss the dialog.
class AppSettingsDialog extends StatefulWidget {
  final bool showThemeSelection;

  const AppSettingsDialog({
    super.key,
    this.showThemeSelection = false,
  });

  static void show(BuildContext context, {bool showThemeSelection = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AppSettingsDialog(showThemeSelection: showThemeSelection),
    );
  }

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  /// Asks the user to confirm a language change and, if confirmed, applies it.
  Future<void> _confirmLanguageChange(
    BuildContext context,
    String newCode,
  ) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Already selected — nothing to do.
    if ((newCode == 'ta') == languageProvider.isTamil) return;

    final isDark = AppTheme.isDark(context);
    final bool isSwitchingToTamil = newCode == 'ta';

    final String titleText = isSwitchingToTamil
        ? 'Switch to Tamil? / தமிழுக்கு மாற்றவா?'
        : 'Switch to English?';

    final String bodyText = isSwitchingToTamil
        ? 'Home Visit Care section will be displayed in Tamil.\n'
            'மற்ற அனைத்து பகுதிகளும் ஆங்கிலத்தில் இருக்கும்.'
        : 'Home Visit Care section will switch back to English.\n'
            'All other sections remain in English.';

    final String confirmLabel = isSwitchingToTamil ? 'Switch / மாற்று' : 'Switch';
    final String cancelLabel = isSwitchingToTamil ? 'Cancel / ரத்து' : 'Cancel';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.translate_rounded,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
        title: Text(
          titleText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor,
          ),
        ),
        content: Text(
          bodyText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isDark ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: AppTheme.cancelButton,
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: AppTheme.primaryButton,
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      languageProvider.setLanguageCode(newCode, userId: auth.user?.id);
      try {
        auth.updatePreferredLanguage(newCode);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = AppTheme.isDark(context);

    final cardBg = isDark ? AppTheme.darkCardColor : Colors.white;
    final borderColor =
        isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textPrimary =
        isDark ? AppTheme.darkTextPrimaryColor : AppTheme.textPrimaryColor;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondaryColor : AppTheme.textSecondaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: cardBg,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ── Dialog Header ─────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('app_settings', fallback: 'Application Settings'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.showThemeSelection
                            ? (languageProvider.isTamil
                                ? 'மொழி மற்றும் தோற்ற அமைப்புகள்'
                                : 'Language and appearance settings')
                            : (languageProvider.isTamil
                                ? 'மொழி அமைப்புகள்'
                                : 'Language settings'),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: context.tr('close', fallback: 'Close'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: borderColor),
            const SizedBox(height: 20),

            // ── Section 1: Language Selection ─────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.translate_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('language', fallback: 'Language'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'language_subtitle',
                fallback: 'Select application display language',
              ),
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 4),
            // Scope note — always in English since non-home-visit UI is English
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tamil applies to Home Visit Care only. All other sections stay in English.',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Language Options (English and Tamil)
            Column(
              children: [
                _buildLanguageCard(
                  context: context,
                  code: 'en',
                  title: 'English',
                  subtitle: 'Default language',
                  badge: 'EN',
                  isSelected: !languageProvider.isTamil,
                  onTap: () => _confirmLanguageChange(context, 'en'),
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 10),
                _buildLanguageCard(
                  context: context,
                  code: 'ta',
                  title: 'தமிழ்',
                  subtitle: 'தமிழ் மொழி',
                  badge: 'தமிழ்',
                  isSelected: languageProvider.isTamil,
                  onTap: () => _confirmLanguageChange(context, 'ta'),
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),

            // ── Section 2: Theme Mode Selection ───────────────────────────────
            if (widget.showThemeSelection) ...[
              const SizedBox(height: 24),
              Divider(height: 1, thickness: 1, color: borderColor),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(
                    Icons.palette_outlined,
                    size: 20,
                    color: AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('theme', fallback: 'Theme'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'theme_subtitle',
                  fallback: 'Adjust appearance according to your preference',
                ),
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 14),

              // Theme Options
              Row(
                children: [
                  Expanded(
                    child: _buildThemeCard(
                      context: context,
                      mode: ThemeMode.light,
                      icon: Icons.wb_sunny_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: context.tr('light_mode', fallback: 'Light Mode'),
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeCard(
                      context: context,
                      mode: ThemeMode.dark,
                      icon: Icons.nightlight_round,
                      iconColor: const Color(0xFF818CF8),
                      label: context.tr('dark_mode', fallback: 'Dark Mode'),
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeCard(
                      context: context,
                      mode: ThemeMode.system,
                      icon: Icons.brightness_auto_rounded,
                      iconColor: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF4A5568),
                      label: context.tr('system_default', fallback: 'System Default'),
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // ── Close Button ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSecondary,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.tr('close', fallback: 'Close'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required ThemeMode mode,
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isSelected ? AppTheme.primaryColor : iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : textPrimary,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 15,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
