import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/app_theme.dart';
import '../route_constants.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.user != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
            decoration: AppTheme.cardDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Medical / Error themed graphic icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade100, width: 2),
                  ),
                  child: Icon(
                    Icons.healing_outlined,
                    size: 64,
                    color: AppTheme.logoRed,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '404',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Page Not Found',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The medical system route you are trying to access does not exist or has been relocated. Please check the address or return back.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    if (isLoggedIn) {
                      context.go(AppRoutes.dashboard);
                    } else {
                      context.go(AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: Text(
                    isLoggedIn ? 'Go to Dashboard' : 'Go to Login',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: AppTheme.primaryButton.copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(double.infinity, 56)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      if (isLoggedIn) {
                        context.go(AppRoutes.dashboard);
                      } else {
                        context.go(AppRoutes.login);
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryColor,
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Back to Previous Page'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
