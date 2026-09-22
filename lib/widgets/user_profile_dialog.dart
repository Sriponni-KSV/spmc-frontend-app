import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import '../core/routes/route_constants.dart';
import 'app_settings_dialog.dart';

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
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorderColor(context)),
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
                  decoration: BoxDecoration(
                    color: AppTheme.isDark(context)
                        ? AppTheme.darkBorderColor.withValues(alpha: 0.5)
                        : AppTheme.primaryLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.close, color: AppTheme.getTextSecondaryColor(context)),
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
                          border: Border.all(
                            color: AppTheme.getCardColor(context),
                            width: 4,
                          ),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
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
            Divider(height: 1, thickness: 1, color: AppTheme.getBorderColor(context)),
            // Detailed fields
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.badge_outlined,
                    label: context.tr('staff_id', fallback: 'Staff Unique ID'),
                    value: user.staffUniqueId ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.email_outlined,
                    label: context.tr('email_address', fallback: 'Email Address'),
                    value: user.email,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.phone_android_outlined,
                    label: context.tr('mobile_number', fallback: 'Mobile Number'),
                    value: user.mobile ?? 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: context.tr('onboarded_date', fallback: 'Onboarded Date'),
                    value: user.createdAt != null && user.createdAt!.isNotEmpty
                        ? user.createdAt!
                        : 'N/A',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.info_outline,
                    label: context.tr('status', fallback: 'Status'),
                    value: user.status,
                    isStatus: true,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: AppTheme.getBorderColor(context)),
            // Actions Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(
                builder: (context) {
                  final profileRoute = _getProfileRoute(user.role);
                  return Row(
                    children: [
                      // Settings Button
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AppSettingsDialog.show(context);
                        },
                        icon: const Icon(Icons.settings_outlined),
                        color: AppTheme.primaryColor,
                        tooltip: context.tr('settings'),
                      ),
                      const SizedBox(width: 8),
                      // Close Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.getTextSecondaryColor(context),
                            side: BorderSide(color: AppTheme.getBorderColor(context)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            context.tr('close'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (profileRoute != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go(profileRoute);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  context.tr('profile'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
    return Builder(
      builder: (context) {
        final textPrimary = AppTheme.getTextPrimaryColor(context);
        final textSecondary = AppTheme.getTextSecondaryColor(context);

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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  valueWidget,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
