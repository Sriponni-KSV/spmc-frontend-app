import 'package:flutter/material.dart';

class AppTheme {
  // Main Colors based on the UI design provided
  static const Color backgroundColor = Color(0xFFF4F7FA);
  static const Color primaryColor = Color(0xFF0F5A8E);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF2D3748);
  static const Color textSecondaryColor = Color(0xFF718096);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color iconColor = Color(0xFFA0AEC0);
  static const Color labelColor = Color(0xFF4A5568);
  static const Color successColor = Color(0xFF7fb547);
  static const Color infoColor = Color(0xFF4299E1);
  static const Color warningColor = Color(0xFFED8936);
  static const Color alertBgColor = Color(0xFFFFF5F5);
  static const Color alertTextColor = Color(0xFFC53030);
  static const Color infoBgColor = Color(0xFFEBF8FF);

  // Premium Card Shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // App-wide Font Family
  static const String fontFamily = 'Inter';

  // Centralized Theme Data
  // Changing any property in this getter updates it app-wide!
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        background: backgroundColor,
        surface: cardColor,
      ),

      // Default AppBar Styling
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),

      // Uniform Button Sizes and Colors
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(
            double.infinity,
            56,
          ), // consistent global height
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),

      // Text Field Design (used globally in all forms)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: iconColor, fontFamily: fontFamily),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
        prefixIconColor: iconColor,
        suffixIconColor: iconColor,
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),

      // Typography scaling
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          color: textPrimaryColor,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: textPrimaryColor,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: textSecondaryColor,
        ),
      ),

      // Bottom Navigation Bar Styling
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}
