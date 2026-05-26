import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../core/routes/route_constants.dart';
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
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                await auth.logout();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
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
