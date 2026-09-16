import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Navigation item definition for Admin Dashboard.
class AdminNavItem {
  final int index;
  final IconData icon;
  final String label;
  final String? requiredRole;
  final bool isVisible;

  const AdminNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.requiredRole,
    this.isVisible = true,
  });
}

/// Catalog Sub-Item definition for Master Catalog
class AdminCatalogSubItem {
  final int index;
  final IconData icon;
  final String label;
  final bool isVisible;

  const AdminCatalogSubItem({
    required this.index,
    required this.icon,
    required this.label,
    this.isVisible = true,
  });
}

/// Centralized Navigation Configuration for Admin Dashboard.
/// 
/// To show or hide any section/menu in the Admin Dashboard, simply toggle its boolean flag
/// below (`true` to show, `false` to hide).
class AdminNavConfig {
  // =========================================================================
  // MAIN MENU VISIBILITY TOGGLES
  // =========================================================================

  /// Dashboard Overview (Visible)
  static const bool showDashboard = true;

  /// Staff Management (Visible)
  static const bool showStaffManagement = true;

  /// Patients Directory (Visible)
  static const bool showPatients = true;

  /// Home Visit Care & Services (Visible)
  static const bool showHomeVisitCare = true;

  /// Master Catalog Parent Menu (Visible)
  static const bool showMasterCatalog = true;

  // -------------------------------------------------------------------------
  // Hidden Menus (Change to `true` whenever you want to display them)
  // -------------------------------------------------------------------------

  /// Access Control / RBAC (Hidden - Change to true to display)
  static const bool showAccessControl = false;

  /// Appointments (Visible)
  static const bool showAppointments = true;

  /// OPD Management (Visible)
  static const bool showOpdManagement = true;

  /// IPD Management (Hidden - Change to true to display)
  static const bool showIpdManagement = false;

  /// OT Management (Hidden - Change to true to display)
  static const bool showOtManagement = false;

  /// Shift Allocation (Visible)
  static const bool showShiftAllocation = true;

  /// ICU & Emergency (Hidden - Change to true to display)
  static const bool showIcuEmergency = false;

  /// Billing & Invoices (Hidden - Change to true to display)
  static const bool showBillingInvoices = false;

  /// Inventory Management (Hidden - Change to true to display)
  static const bool showInventoryManagement = false;

  // =========================================================================
  // CATALOG SUB-ITEM VISIBILITY TOGGLES
  // =========================================================================
  static const bool showMedicineCatalog = true;
  static const bool showHomeVisitConsumables = true;
  static const bool showCarriedKitItems = true;

  // =========================================================================
  // HELPER METHODS TO FILTER AND RETURN ACTIVE MENU ITEMS
  // =========================================================================

  /// Returns the list of visible top-level navigation items
  static List<AdminNavItem> getVisibleNavItems(UserModel? user) {
    final List<AdminNavItem> allItems = [
      const AdminNavItem(
        index: 0,
        icon: Icons.admin_panel_settings_outlined,
        label: 'Dashboard',
        isVisible: showDashboard,
      ),
      const AdminNavItem(
        index: 1,
        icon: Icons.people_outline,
        label: 'Staff Management',
        isVisible: showStaffManagement,
      ),
      const AdminNavItem(
        index: 2,
        icon: Icons.sick_outlined,
        label: 'Patients',
        isVisible: showPatients,
      ),
      const AdminNavItem(
        index: 3,
        icon: Icons.security_outlined,
        label: 'Access Control (RBAC)',
        requiredRole: 'Super Admin',
        isVisible: showAccessControl,
      ),
      const AdminNavItem(
        index: 4,
        icon: Icons.calendar_month_outlined,
        label: 'Appointments',
        isVisible: showAppointments,
      ),
      const AdminNavItem(
        index: 5,
        icon: Icons.monitor_heart_outlined,
        label: 'OPD Management',
        isVisible: showOpdManagement,
      ),
      const AdminNavItem(
        index: 6,
        icon: Icons.hotel_outlined,
        label: 'IPD Management',
        isVisible: showIpdManagement,
      ),
      const AdminNavItem(
        index: 7,
        icon: Icons.healing_outlined,
        label: 'OT Management',
        isVisible: showOtManagement,
      ),
      const AdminNavItem(
        index: 8,
        icon: Icons.schedule_outlined,
        label: 'Shift Allocation',
        isVisible: showShiftAllocation,
      ),
      const AdminNavItem(
        index: 9,
        icon: Icons.emergency_outlined,
        label: 'ICU & Emergency',
        isVisible: showIcuEmergency,
      ),
      const AdminNavItem(
        index: 10,
        icon: Icons.receipt_long_outlined,
        label: 'Billing & Invoices',
        isVisible: showBillingInvoices,
      ),
      const AdminNavItem(
        index: 11,
        icon: Icons.inventory_2_outlined,
        label: 'Inventory Management',
        isVisible: showInventoryManagement,
      ),
      const AdminNavItem(
        index: 12,
        icon: Icons.home_work_outlined,
        label: 'Home Visit Care',
        isVisible: showHomeVisitCare,
      ),
    ];

    return allItems.where((item) {
      if (!item.isVisible) return false;
      if (item.requiredRole != null && user?.role != item.requiredRole) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Returns the list of visible catalog sub-items
  static List<AdminCatalogSubItem> getVisibleCatalogSubItems() {
    final List<AdminCatalogSubItem> subItems = [
      const AdminCatalogSubItem(
        index: 13,
        icon: Icons.medication_outlined,
        label: 'Medicine Catalog',
        isVisible: showMedicineCatalog,
      ),
      const AdminCatalogSubItem(
        index: 14,
        icon: Icons.home_repair_service_outlined,
        label: 'Home Visit Consumables',
        isVisible: showHomeVisitConsumables,
      ),
      const AdminCatalogSubItem(
        index: 15,
        icon: Icons.inventory_outlined,
        label: 'Carried Kit Items',
        isVisible: showCarriedKitItems,
      ),
    ];

    return subItems.where((item) => item.isVisible).toList();
  }
}
