import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Navigation item definition for Doctor Dashboard.
class DoctorNavItem {
  final int index;
  final IconData icon;
  final String label;
  final String? permissionRequired;
  final bool isVisible;

  const DoctorNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.permissionRequired,
    this.isVisible = true,
  });
}

/// Centralized Navigation Configuration for Doctor Dashboard.
///
/// To show or hide any menu item, simply change the boolean flags below
/// to `true` (visible) or `false` (hidden).
class DoctorNavConfig {
  // =========================================================================
  // MENU VISIBILITY TOGGLES
  // =========================================================================

  /// Dashboard Overview (Visible)
  static const bool showDashboard = true;

  /// My Consultations (Visible)
  static const bool showMyConsultations = true;

  /// Lab Reports (Visible)
  static const bool showLabReports = true;

  /// AI Dictation (Moved inside OT Management)
  static const bool showAiDictation = false;

  /// IPD Management (Visible)
  static const bool showIpdManagement = true;

  /// OT Management (Visible)
  static const bool showOtManagement = true;

  /// My Profile (Visible)
  static const bool showProfile = true;

  // =========================================================================
  // HELPER METHOD TO FILTER AND RETURN ACTIVE MENU ITEMS
  // =========================================================================
  static List<DoctorNavItem> getVisibleNavItems(UserModel? user) {
    final isAnaesthetist = user?.role == 'Anaesthetist';

    if (isAnaesthetist) {
      final List<DoctorNavItem> anaesthetistItems = [
        const DoctorNavItem(
          index: 0,
          icon: Icons.grid_view_outlined,
          label: 'Dashboard',
          isVisible: showDashboard,
        ),
        const DoctorNavItem(
          index: 3,
          icon: Icons.local_hospital_outlined,
          label: 'IPD Management',
          permissionRequired: 'ipd_doctor_rounds',
          isVisible: showIpdManagement,
        ),
        const DoctorNavItem(
          index: 5,
          icon: Icons.mic_none_outlined,
          label: 'Speech-to-Text (OT)',
          permissionRequired: 'ot_anaesthesia_pac',
          isVisible: showAiDictation,
        ),
        const DoctorNavItem(
          index: 4,
          icon: Icons.healing_outlined,
          label: 'OT Management',
          permissionRequired: 'ot_anaesthesia_pac',
          isVisible: true,
        ),
        const DoctorNavItem(
          index: 7,
          icon: Icons.people_outline,
          label: 'Patients',
          permissionRequired: 'view_patients',
          isVisible: true,
        ),
        const DoctorNavItem(
          index: 8,
          icon: Icons.calendar_today_outlined,
          label: 'Appointments',
          permissionRequired: 'book_appointment',
          isVisible: true,
        ),
        const DoctorNavItem(
          index: 2,
          icon: Icons.person_outline,
          label: 'My Profile',
          isVisible: showProfile,
        ),
      ];

      return anaesthetistItems.where((item) {
        if (!item.isVisible) return false;
        if (user?.role == 'Super Admin') return true;
        if (item.permissionRequired != null) {
          if (item.permissionRequired == 'ot_anaesthesia_pac') {
            return (user?.hasPermission('ot_anaesthesia_pac') ?? false) ||
                   (user?.hasPermission('ot_who_checklist') ?? false) ||
                   (user?.hasPermission('ot_surgeries') ?? false);
          }
          return user?.hasPermission(item.permissionRequired!) ?? false;
        }
        return true;
      }).toList();
    }

    final List<DoctorNavItem> allItems = [
      const DoctorNavItem(
        index: 0,
        icon: Icons.grid_view_outlined,
        label: 'Dashboard',
        isVisible: showDashboard,
      ),
      const DoctorNavItem(
        index: 1,
        icon: Icons.history_edu_outlined,
        label: 'My Consultations',
        permissionRequired: 'conduct_consultations',
        isVisible: showMyConsultations,
      ),
      const DoctorNavItem(
        index: 6,
        icon: Icons.science_outlined,
        label: 'Lab Reports',
        permissionRequired: 'view_lab_reports',
        isVisible: showLabReports,
      ),
      const DoctorNavItem(
        index: 3,
        icon: Icons.local_hospital_outlined,
        label: 'IPD Management',
        permissionRequired: 'ipd_doctor_rounds',
        isVisible: showIpdManagement,
      ),
      const DoctorNavItem(
        index: 5,
        icon: Icons.mic_none_outlined,
        label: 'Speech-to-Text (OT)',
        permissionRequired: 'ot_surgeries',
        isVisible: showAiDictation,
      ),
      const DoctorNavItem(
        index: 4,
        icon: Icons.healing_outlined,
        label: 'OT Management',
        permissionRequired: 'ot_surgeries',
        isVisible: showOtManagement,
      ),
      const DoctorNavItem(
        index: 7,
        icon: Icons.people_outline,
        label: 'Patients',
        permissionRequired: 'view_patients',
        isVisible: true,
      ),
      const DoctorNavItem(
        index: 8,
        icon: Icons.calendar_today_outlined,
        label: 'Appointments',
        permissionRequired: 'book_appointment',
        isVisible: true,
      ),
      const DoctorNavItem(
        index: 2,
        icon: Icons.person_outline,
        label: 'My Profile',
        isVisible: showProfile,
      ),
    ];

    return allItems.where((item) {
      if (!item.isVisible) return false;
      if (user?.role == 'Super Admin') return true;
      if (item.permissionRequired != null) {
        return user?.hasPermission(item.permissionRequired!) ?? false;
      }
      return true;
    }).toList();
  }
}
