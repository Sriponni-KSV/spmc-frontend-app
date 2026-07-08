import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../core/routes/route_constants.dart';

class UserProfileDialog extends StatelessWidget {
  final UserModel user;

  const UserProfileDialog({super.key, required this.user});

  static void show(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UserProfileDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColors = AppTheme.getAvatarColors(user.rawFullname ?? user.fullname);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Avatar and Basic Info
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: avatarColors['bg'],
                          child: Text(
                            (user.rawFullname ?? user.fullname).isNotEmpty
                                ? (user.rawFullname ?? user.fullname)[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: avatarColors['text'],
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // User Name and Role
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    user.rawFullname ?? user.fullname,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
            // Detailed fields
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Staff Unique ID',
                    value: user.staffUniqueId ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    value: user.email,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.phone_android_outlined,
                    label: 'Mobile Number',
                    value: user.mobile ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: user.status,
                    isStatus: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
            // Actions Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(
                builder: (context) {
                  final profileRoute = _getProfileRoute(user.role);
                  if (profileRoute == null) {
                    return ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondaryColor,
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // dismiss dialog
                            context.go(profileRoute); // navigate to profile
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Profile',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getProfileRoute(String role) {
    final lowerRole = role.toLowerCase();
    if (lowerRole == 'doctor' || lowerRole == 'anaesthetist') {
      return AppRoutes.doctorProfile;
    } else if (lowerRole == 'nurse' || lowerRole == 'head nurse') {
      return AppRoutes.nurseProfile;
    } else if (lowerRole == 'front desk' || lowerRole == 'receptionist' || lowerRole == 'reception') {
      return AppRoutes.frontDeskProfile;
    } else if (lowerRole == 'lab') {
      return AppRoutes.labProfile;
    } else if (lowerRole == 'pharmacy') {
      return AppRoutes.pharmacyProfile;
    }
    return null;
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isStatus = false,
  }) {
    Widget valueWidget;
    if (isStatus) {
      final isSuccess = value.toLowerCase() == 'active';
      valueWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSuccess ? AppTheme.successBg : AppTheme.dangerBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSuccess
                ? AppTheme.successColor.withValues(alpha: 0.3)
                : AppTheme.dangerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          value.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSuccess ? AppTheme.successColor : AppTheme.dangerColor,
          ),
        ),
      );
    } else {
      valueWidget = Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              valueWidget,
            ],
          ),
        ),
      ],
    );
  }
}
