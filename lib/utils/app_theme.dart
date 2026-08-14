import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color backgroundColor = Color(
    0xFFF1F7FB,
  ); // Subtle blue-tinted background
  static const Color primaryColor = Color(0xFF065D96); // Logo Blue
  static const Color primaryLight = Color(0xFFEAF2F7);
  static const Color secondaryColor = Color(0xFF79B649); // Logo Green
  static const Color logoRed = Color(0xFFE53E3E); // Logo Red
  static const Color cardColor = Colors.white;

  static const Color textPrimaryColor = Color(
    0xFF1A202C,
  ); // Darker for better contrast
  static const Color textSecondaryColor = Color(0xFF718096);
  static const Color textMutedColor = Color(0xFFA0AEC0);

  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color iconColor = Color(0xFF94A3B8);

  static const Color successColor = Color(
    0xFF79B649,
  ); // Using Logo Green for success
  static const Color successBg = Color(0xFFF1F8EB);

  static const Color infoColor = Color(0xFF065D96); // Using Logo Blue for info
  static const Color infoBg = Color(0xFFEAF2F7);

  static const Color warningColor = Color(0xFFDD6B20);
  static const Color warningBg = Color(0xFFFFFAF0);

  static const Color dangerColor = Color(0xFFE53E3E);
  static const Color dangerBg = Color(0xFFFFF5F5);

  // Nurse specific color (purple)
  static const Color nurseColor = Color(0xFF6B46C1);

  // Aliases for backward compatibility
  static const Color alertBgColor = dangerBg;
  static const Color alertTextColor = dangerColor;
  static const Color infoBgColor = infoBg;
  static const Color labelColor = textSecondaryColor;

  static Color getStatusBgColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Scheduled':
      case 'In-Progress':
        return primaryLight;
      case 'Waiting':
        return const Color(0xFFFEF3C7);
      case 'In Consultation':
        return const Color(0xFFEDE9FE);
      case 'Completed':
      case 'Verified':
        return const Color(0xFFDCFCE7);
      case 'No Show':
      case 'No-Show':
        return const Color(0xFFF3F4F6);
      case 'Cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  static Color getStatusTextColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Scheduled':
      case 'In-Progress':
        return primaryColor;
      case 'Waiting':
        return const Color(0xFF92400E);
      case 'In Consultation':
        return const Color(0xFF5B21B6);
      case 'Completed':
      case 'Verified':
        return const Color(0xFF166534);
      case 'No Show':
      case 'No-Show':
        return const Color(0xFF374151);
      case 'Cancelled':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF374151);
    }
  }

  // ── Layout Constants ──────────────────────────────────────────────────────
  static const double borderRadius = 12.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double cardElevation =
      0.0; // Modern flat look with border/shadow

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static const String fontFamily = 'Inter';

  // ── Typography ────────────────────────────────────────────────────────────-
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

  static ButtonStyle get logoRedButton =>
      baseButtonStyle(backgroundColor: logoRed, foregroundColor: Colors.white);

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

  static ButtonStyle get cancelButton => OutlinedButton.styleFrom(
    foregroundColor: textSecondaryColor,
    side: const BorderSide(color: Color(0xFFB0BCC7), width: 1.2),
    backgroundColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    minimumSize: const Size(130, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );

  // ── Input Decoration ──────────────────────────────────────────────────────
  static InputDecoration standardInputDecoration({
    String? label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      suffixIcon: suffixIcon,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: dangerColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: dangerColor, width: 1.5),
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
      textTheme: GoogleFonts.interTextTheme(textTheme),
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
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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

  // ── Avatar Colors ─────────────────────────────────────────────────────────
  static const List<Map<String, Color>> avatarColorPalettes = [
    {'bg': Color(0xFFEBF8FF), 'text': Color(0xFF2B6CB0)}, // Blue
    {'bg': Color(0xFFF0FFF4), 'text': Color(0xFF2F855A)}, // Green
    {'bg': Color(0xFFFFF5F5), 'text': Color(0xFFC53030)}, // Red
    {'bg': Color(0xFFFEFCBF), 'text': Color(0xFFB7791F)}, // Yellow
    {'bg': Color(0xFFFAF5FF), 'text': Color(0xFF6B46C1)}, // Purple
    {'bg': Color(0xFFE6FFFA), 'text': Color(0xFF2C7A7B)}, // Teal
    {'bg': Color(0xFFFFEFFF), 'text': Color(0xFFB83280)}, // Pink
    {'bg': Color(0xFFF7FAFC), 'text': Color(0xFF2D3748)}, // Gray
  ];

  static Map<String, Color> getAvatarColors(String name) {
    if (name.isEmpty) return avatarColorPalettes[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % avatarColorPalettes.length;
    return avatarColorPalettes[index];
  }
}
