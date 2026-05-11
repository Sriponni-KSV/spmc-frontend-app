import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color backgroundColor = Color(0xFFF8FAFC); // Lighter, modern bg
  static const Color primaryColor = Color(0xFF0F5A8E);
  static const Color primaryLight = Color(0xFFEBF4FF);
  static const Color secondaryColor = Color(0xFF4A5568);
  static const Color cardColor = Colors.white;
  
  static const Color textPrimaryColor = Color(0xFF1A202C); // Darker for better contrast
  static const Color textSecondaryColor = Color(0xFF718096);
  static const Color textMutedColor = Color(0xFFA0AEC0);
  
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color iconColor = Color(0xFF94A3B8);
  
  static const Color successColor = Color(0xFF38A169);
  static const Color successBg = Color(0xFFF0FFF4);
  
  static const Color infoColor = Color(0xFF3182CE);
  static const Color infoBg = Color(0xFFEBF8FF);
  
  static const Color warningColor = Color(0xFFDD6B20);
  static const Color warningBg = Color(0xFFFFFAF0);
  
  static const Color dangerColor = Color(0xFFE53E3E);
  static const Color dangerBg = Color(0xFFFFF5F5);

  // Aliases for backward compatibility
  static const Color alertBgColor = dangerBg;
  static const Color alertTextColor = dangerColor;
  static const Color infoBgColor = infoBg;
  static const Color labelColor = textSecondaryColor;

  // ── Layout Constants ──────────────────────────────────────────────────────
  static const double borderRadius = 12.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double cardElevation = 0.0; // Modern flat look with border/shadow
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static const String fontFamily = 'Inter';

  // ── Typography ────────────────────────────────────────────────────────────
  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: textPrimaryColor,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: textPrimaryColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textPrimaryColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimaryColor,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textSecondaryColor,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
  );

  // ── Button Styles ─────────────────────────────────────────────────────────
  static ButtonStyle baseButtonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
    double? elevation,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation ?? 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle get primaryButton => baseButtonStyle(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
  );

  static ButtonStyle get secondaryButton => baseButtonStyle(
    backgroundColor: secondaryColor,
    foregroundColor: Colors.white,
  );

  static ButtonStyle get successButton => baseButtonStyle(
    backgroundColor: successColor,
    foregroundColor: Colors.white,
  );

  static ButtonStyle get dangerButton => baseButtonStyle(
    backgroundColor: dangerColor,
    foregroundColor: Colors.white,
  );

  static ButtonStyle get warningButton => baseButtonStyle(
    backgroundColor: warningColor,
    foregroundColor: Colors.white,
  );

  static ButtonStyle get outlinedButton => OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: borderColor),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    textStyle: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  // ── Input Decoration ──────────────────────────────────────────────────────
  static InputDecoration standardInputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(paddingMedium),
      labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: dangerColor),
      ),
    );
  }

  // ── Card Decoration ───────────────────────────────────────────────────────
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: cardShadow,
    border: Border.all(color: borderColor.withOpacity(0.5)),
  );

  // ── Theme Data ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: fontFamily,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        background: backgroundColor,
        error: dangerColor,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineMedium?.copyWith(fontSize: 18),
        iconTheme: const IconThemeData(color: primaryColor),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: borderColor),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButton),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(paddingMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
      ),

      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(backgroundColor),
        headingTextStyle: textTheme.labelLarge?.copyWith(color: secondaryColor),
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
        horizontalMargin: paddingMedium,
      ),
    );
  }
}

