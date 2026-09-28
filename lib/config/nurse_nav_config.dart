import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Navigation item definition for Nurse Dashboard.
class NurseNavItem {
  final int index;
  final IconData icon;
  final String label;
  final String? permissionRequired;
  final bool isVisible;

  const NurseNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.permissionRequired,
    this.isVisible = true,
  });
}

/// Centralized Navigation Configuration for Nurse Dashboard.
///
/// To show or hide any menu item, simply change the boolean flags below
/// to `true` (visible) or `false` (hidden).
class NurseNavConfig {
  // =========================================================================
  // MENU VISIBILITY TOGGLES
  // =========================================================================

  /// Dashboard Overview (Visible)
  static const bool showDashboard = true;

  /// Patients Directory (Visible)
  static const bool showPatients = true;

  /// Home Visit Care & Services (Visible)
  static const bool showHomeVisitCare = true;

  /// Appointments (Hidden)
  static const bool showAppointments = false;

  /// Doctors Directory (Hidden - Change to true to display)
  static const bool showDoctors = false;

  /// OPD Assistance (Hidden)
  static const bool showOpdAssistance = false;

  /// IPD Management (Hidden)
  static const bool showIpdManagement = false;

  /// OT Management (Hidden)
  static const bool showOtManagement = false;

  /// Profile Screen (Hidden - Change to true to display)
  static const bool showProfile = true;

  // =========================================================================
  // HELPER METHOD TO FILTER AND RETURN ACTIVE MENU ITEMS
  // =========================================================================
  static List<NurseNavItem> getVisibleNavItems(UserModel? user) {
    final List<NurseNavItem> allItems = [
      const NurseNavItem(
        index: 0,
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        isVisible: showDashboard,
      ),
      NurseNavItem(
        index: 1,
        icon: Icons.people_outline,
        label: 'Patients',
        permissionRequired: 'view_patients',
        isVisible: showPatients,
      ),
      NurseNavItem(
        index: 2,
        icon: Icons.calendar_today_outlined,
        label: 'Appointments',
        permissionRequired: 'book_appointment',
        isVisible: showAppointments,
      ),
      const NurseNavItem(
        index: 3,
        icon: Icons.medical_services_outlined,
        label: 'Doctors',
        isVisible: showDoctors,
      ),
      const NurseNavItem(
        index: 5,
        icon: Icons.local_hospital_outlined,
        label: 'OPD Assistance',
        isVisible: showOpdAssistance,
      ),
      const NurseNavItem(
        index: 6,
        icon: Icons.bedroom_child_outlined,
        label: 'IPD Management',
        isVisible: showIpdManagement,
      ),
      const NurseNavItem(
        index: 7,
        icon: Icons.healing_outlined,
        label: 'OT Management',
        isVisible: showOtManagement,
      ),
      const NurseNavItem(
        index: 9,
        icon: Icons.home_work_outlined,
        label: 'Home Visit Care',
        isVisible: showHomeVisitCare,
      ),
      const NurseNavItem(
        index: 4,
        icon: Icons.person_outline,
        label: 'Profile',
        isVisible: showProfile,
      ),
    ];

    return allItems.where((item) {
      if (!item.isVisible) return false;
      if (item.permissionRequired != null) {
        return user?.hasPermission(item.permissionRequired!) ?? false;
      }
      return true;
    }).toList();
  }
}
