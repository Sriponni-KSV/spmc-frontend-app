import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../screens/login_page.dart';
import 'app_theme.dart';

class LogoutHelper {
  static void showLogoutConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                auth.logout();
                Navigator.pushAndRemoveUntil(
                  context, // Use outer context for navigation
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.logoRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(130, 48),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }
}
