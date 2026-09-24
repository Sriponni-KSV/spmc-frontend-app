import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import 'app_settings_dialog.dart';

class AppTopBarActions extends StatelessWidget {
  final bool showClock;
  final Widget? liveClockWidget;
  final bool showThemeSelector;

  const AppTopBarActions({
    super.key,
    this.showClock = false,
    this.liveClockWidget,
    this.showThemeSelector = false,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = AppTheme.isDark(context);

    final iconColor = isDark ? AppTheme.darkTextSecondaryColor : const Color(0xFF4A5568);
    final buttonBg = isDark ? AppTheme.darkCardColor : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorderColor : const Color(0xFFCBD5E1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Language Quick Toggle Pill
        InkWell(
          onTap: () => languageProvider.toggleLanguage(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

        if (showThemeSelector) ...[
          const SizedBox(width: 10),

          // Theme Mode Selector Menu (Light, Dark, System Default)
          PopupMenuButton<ThemeMode>(
            tooltip: context.tr('theme'),
            initialValue: themeProvider.themeMode,
            onSelected: (ThemeMode mode) {
              themeProvider.setThemeMode(mode);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor),
            ),
            color: buttonBg,
            offset: const Offset(0, 44),
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
                child: _buildThemeIcon(themeProvider.themeMode, isDark),
              ),
            ),
            itemBuilder: (context) => [
              _buildThemeMenuItem(
                context: context,
                mode: ThemeMode.light,
                icon: Icons.light_mode_outlined,
                label: context.tr('light_mode'),
                isSelected: themeProvider.themeMode == ThemeMode.light,
              ),
              _buildThemeMenuItem(
                context: context,
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_outlined,
                label: context.tr('dark_mode'),
                isSelected: themeProvider.themeMode == ThemeMode.dark,
              ),
              _buildThemeMenuItem(
                context: context,
                mode: ThemeMode.system,
                icon: Icons.brightness_auto_outlined,
                label: context.tr('system_default'),
                isSelected: themeProvider.themeMode == ThemeMode.system,
              ),
            ],
          ),
        ],

        const SizedBox(width: 10),

        // Settings Button
        InkWell(
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

        // Optional Live Clock
        if (showClock && liveClockWidget != null) ...[
          const SizedBox(width: 12),
          liveClockWidget!,
        ],
      ],
    );
  }

  Widget _buildThemeIcon(ThemeMode mode, bool isDark) {
    switch (mode) {
      case ThemeMode.light:
        return const Icon(
          Icons.wb_sunny_rounded,
          size: 18,
          color: Color(0xFFF59E0B), // Warm amber
        );
      case ThemeMode.dark:
        return const Icon(
          Icons.nightlight_round,
          size: 18,
          color: Color(0xFF818CF8), // Indigo moon
        );
      case ThemeMode.system:
        return Icon(
          Icons.brightness_auto_rounded,
          size: 18,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4A5568),
        );
    }
  }

  PopupMenuItem<ThemeMode> _buildThemeMenuItem({
    required BuildContext context,
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : null,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }
}
