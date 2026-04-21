import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AccessDeniedWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onBack;

  const AccessDeniedWidget({
    Key? key,
    this.message = "Access Denied – You do not have permission to perform this action.",
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.alertBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_outlined,
                size: 64,
                color: AppTheme.alertTextColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Access Restricted",
              style: AppTheme.lightTheme.textTheme.displayLarge?.copyWith(
                fontSize: 24,
                color: AppTheme.alertTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 32),
            if (onBack != null)
              ElevatedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Go Back"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
