import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_localizations.dart';
import '../utils/tamil_transliteration_helper.dart';

class AdminModuleItem {
  final String title;
  final String category;
  final String route;
  final int index;
  final IconData icon;
  final List<String> keywords;
  final String description;

  const AdminModuleItem({
    required this.title,
    required this.category,
    required this.route,
    required this.index,
    required this.icon,
    required this.keywords,
    required this.description,
  });
}

class AdminGlobalSearchOverlay extends StatefulWidget {
  final List<PatientModel> patients;
  final List<UserModel> staff;
  final Function(String route, int index) onNavigate;

  const AdminGlobalSearchOverlay({
    Key? key,
    required this.patients,
    required this.staff,
    required this.onNavigate,
  }) : super(key: key);

  @override
  State<AdminGlobalSearchOverlay> createState() => _AdminGlobalSearchOverlayState();
}

class _AdminGlobalSearchOverlayState extends State<AdminGlobalSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<AdminModuleItem> _allModules = [
    AdminModuleItem(
      title: 'IPD Beds Master Catalog',
      category: 'Master Catalog',
      route: AppRoutes.adminIpdBeds,
      index: 16,
      icon: Icons.hotel_outlined,
      keywords: [
        'ipd beds',
        'ipd',
        'bed',
        'beds',
        'ward',
        'wards',
        'room',
        'catalog',
        'admission',
        'availability',
        'occupancy',
        'icu bed',
        'general ward'
      ],
      description: 'Configure hospital beds, wards, statuses and admission availability',
    ),
    AdminModuleItem(
      title: 'Food Stock Management',
      category: 'Master Catalog',
      route: AppRoutes.adminInventory,
      index: 11,
      icon: Icons.restaurant_outlined,
      keywords: [
        'food stock',
        'food',
        'stock',
        'grocery',
        'groceries',
        'pantry',
        'kitchen',
        'rice',
        'milk',
        'dal',
        'replenishment',
        'dietary',
        'inventory'
      ],
      description: 'Kitchen groceries, pantry stock levels, expiration alerts, replenishments',
    ),
    AdminModuleItem(
      title: 'Medicine Catalog',
      category: 'Master Catalog',
      route: AppRoutes.adminMedicationCatalog,
      index: 13,
      icon: Icons.medication_outlined,
      keywords: [
        'medicine',
        'medication',
        'drugs',
        'pharma',
        'pharmacy',
        'catalog',
        'prescription',
        'tablets',
        'paracetamol',
        'aspirin',
        'antibiotics',
        'syrup',
        'capsules',
        'injections'
      ],
      description: 'Hospital medication catalog, formulations, and drug pricing',
    ),
    AdminModuleItem(
      title: 'Home Visit Consumables',
      category: 'Master Catalog',
      route: AppRoutes.adminHomeVisitConsumables,
      index: 14,
      icon: Icons.home_repair_service_outlined,
      keywords: ['consumables', 'home visit consumables', 'kit', 'supplies'],
      description: 'Consumable supplies allocated for nurse home visit care',
    ),
    AdminModuleItem(
      title: 'Carried Kit Items',
      category: 'Master Catalog',
      route: AppRoutes.adminCarriedKitItems,
      index: 15,
      icon: Icons.inventory_outlined,
      keywords: ['carried kit', 'kit items', 'equipment', 'instruments'],
      description: 'Medical instruments & diagnostics kit items for home visits',
    ),
    AdminModuleItem(
      title: 'Staff Management',
      category: 'Administration',
      route: AppRoutes.adminUsers,
      index: 1,
      icon: Icons.people_outline,
      keywords: ['staff', 'doctor', 'nurse', 'pharmacist', 'employees', 'users', 'doctors', 'nurses', 'admin'],
      description: 'Register staff, update profiles, specialization, and credentials',
    ),
    AdminModuleItem(
      title: 'Patients Registry',
      category: 'Patients',
      route: AppRoutes.adminPatients,
      index: 2,
      icon: Icons.sick_outlined,
      keywords: ['patient', 'patients', 'directory', 'registry', 'uhid', 'registration', 'medical records'],
      description: 'Patient directory, UHID lookup, registration, and history',
    ),
    AdminModuleItem(
      title: 'Access Control (RBAC)',
      category: 'Administration',
      route: AppRoutes.adminSettings,
      index: 3,
      icon: Icons.security_outlined,
      keywords: ['rbac', 'access control', 'roles', 'permissions', 'security', 'role'],
      description: 'Department permissions, role configurations, and system security',
    ),
    AdminModuleItem(
      title: 'Appointments Management',
      category: 'Clinical',
      route: AppRoutes.adminAppointments,
      index: 4,
      icon: Icons.calendar_month_outlined,
      keywords: ['appointment', 'appointments', 'booking', 'schedule', 'doctor calendar', 'consultation'],
      description: 'Hospital appointment calendar, slot allocation, and doctor queues',
    ),
    AdminModuleItem(
      title: 'OPD Management',
      category: 'Clinical',
      route: AppRoutes.adminOpd,
      index: 5,
      icon: Icons.monitor_heart_outlined,
      keywords: ['opd', 'outpatient', 'clinic', 'consultations', 'vitals', 'doctor opd'],
      description: 'Outpatient department queues, doctor calls, vitals recording',
    ),
    AdminModuleItem(
      title: 'IPD Management',
      category: 'Inpatient',
      route: AppRoutes.adminIpd,
      index: 6,
      icon: Icons.single_bed_outlined,
      keywords: ['ipd', 'inpatient', 'admission', 'discharge', 'rounds', 'mar', 'discharge summary'],
      description: 'Inpatient admissions, ward assignments, MAR records, discharge',
    ),
    AdminModuleItem(
      title: 'OT Management',
      category: 'Surgical',
      route: AppRoutes.adminOt,
      index: 7,
      icon: Icons.healing_outlined,
      keywords: ['ot', 'operation', 'theatre', 'surgery', 'surgeon', 'pac assessment', 'anesthesia'],
      description: 'Operation theatre scheduling, surgical teams, PAC evaluations',
    ),
    AdminModuleItem(
      title: 'Shift Allocation & Roster',
      category: 'Nursing',
      route: AppRoutes.adminShifts,
      index: 8,
      icon: Icons.schedule_outlined,
      keywords: ['shift', 'shifts', 'roster', 'nurse schedule', 'allocation', 'duty roster'],
      description: 'Nurse shift duty roster, ward assignments, weekly schedules',
    ),
    AdminModuleItem(
      title: 'Billing & Invoices',
      category: 'Finance',
      route: AppRoutes.adminBilling,
      index: 10,
      icon: Icons.receipt_long_outlined,
      keywords: ['billing', 'bill', 'bills', 'invoice', 'invoices', 'payment', 'receipt', 'accounts'],
      description: 'Patient bills, payment collection, discounts, and revenue receipts',
    ),
    AdminModuleItem(
      title: 'Home Visit Care',
      category: 'Services',
      route: AppRoutes.adminHomeVisits,
      index: 12,
      icon: Icons.home_work_outlined,
      keywords: ['home visit', 'homecare', 'visits', 'nurse home care'],
      description: 'Schedule, dispatch and monitor nurse home visit patient visits',
    ),
    AdminModuleItem(
      title: 'Admin Control Panel',
      category: 'Overview',
      route: AppRoutes.adminDashboard,
      index: 0,
      icon: Icons.admin_panel_settings_outlined,
      keywords: ['dashboard', 'control panel', 'overview', 'stats', 'analytics', 'home'],
      description: 'Hospital overview stats, weekly appointments, active shifts overview',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _focusNode.requestFocus());
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<AdminModuleItem> _getMatchingModules(String query) {
    if (query.isEmpty) {
      return _allModules
          .where((m) =>
              m.index == 16 || // IPD Beds
              m.index == 11 || // Food Stock
              m.index == 1 || // Staff
              m.index == 2 || // Patients
              m.index == 4 || // Appointments
              m.index == 3) // RBAC
          .toList();
    }
    final q = query.toLowerCase().trim();
    return _allModules.where((m) {
      if (m.title.toLowerCase().contains(q)) return true;
      if (m.category.toLowerCase().contains(q)) return true;
      if (m.description.toLowerCase().contains(q)) return true;
      for (final kw in m.keywords) {
        if (kw.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  List<UserModel> _getMatchingStaff(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase().trim();
    return widget.staff.where((s) {
      final name = (s.rawFullname ?? s.fullname).toLowerCase();
      final email = s.email.toLowerCase();
      final role = s.role.toLowerCase();
      final mobile = (s.mobile ?? '').toLowerCase();
      final spec = (s.specialization ?? '').toLowerCase();
      return name.contains(q) ||
          email.contains(q) ||
          role.contains(q) ||
          mobile.contains(q) ||
          spec.contains(q);
    }).take(4).toList();
  }

  List<PatientModel> _getMatchingPatients(String query) {
    if (query.isEmpty) {
      return widget.patients.take(3).toList();
    }
    final q = query.toLowerCase().trim();
    return widget.patients.where((p) {
      final name = p.name.toLowerCase();
      final transliterated =
          TamilTransliterationHelper.transliterate(p.name).toLowerCase();
      final pid = (p.patientId ?? '').toLowerCase();
      final phone = p.phone.toLowerCase();
      return name.contains(q) ||
          transliterated.contains(q) ||
          pid.contains(q) ||
          phone.contains(q);
    }).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final matchingModules = _getMatchingModules(query);
    final matchingStaff = _getMatchingStaff(query);
    final matchingPatients = _getMatchingPatients(query);

    final bool hasResults = matchingModules.isNotEmpty ||
        matchingStaff.isNotEmpty ||
        matchingPatients.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 680,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Input Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppTheme.fontFamily,
                          ),
                          decoration: InputDecoration(
                            hintText: context.tr(
                              'search_admin_global_placeholder',
                              fallback:
                                  'Search modules, IPD beds, staff, patients (e.g. IPD Beds, Rice, Doctor)...',
                            ),
                            hintStyle: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20, color: AppTheme.textSecondaryColor),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22, color: AppTheme.iconColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),

                // Content Area
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasResults && query.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No results found for "$query"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Try searching for IPD Beds, Food Stock, Staff, Doctor, or a Patient Name.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Section 1: Modules & Pages
                        if (matchingModules.isNotEmpty) ...[
                          _buildSectionHeader(
                            query.isEmpty ? 'QUICK NAVIGATION' : 'MODULES & PAGES (${matchingModules.length})',
                            Icons.dashboard_customize_outlined,
                          ),
                          const SizedBox(height: 10),
                          ...matchingModules.map((m) => _buildModuleTile(m)),
                          const SizedBox(height: 18),
                        ],

                        // Section 2: Staff Members (when matching)
                        if (matchingStaff.isNotEmpty) ...[
                          _buildSectionHeader(
                            'STAFF & PRACTITIONERS (${matchingStaff.length})',
                            Icons.people_outline,
                          ),
                          const SizedBox(height: 10),
                          ...matchingStaff.map((s) => _buildStaffTile(s)),
                          const SizedBox(height: 18),
                        ],

                        // Section 3: Patients
                        if (matchingPatients.isNotEmpty) ...[
                          _buildSectionHeader(
                            query.isEmpty ? 'RECENT PATIENTS' : 'PATIENTS (${matchingPatients.length})',
                            Icons.sick_outlined,
                          ),
                          const SizedBox(height: 10),
                          ...matchingPatients.map((p) => _buildPatientTile(p)),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(top: BorderSide(color: AppTheme.borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: const Text('Esc', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                          ),
                          const SizedBox(width: 6),
                          const Text('to close', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                      const Text(
                        'Click any result to jump directly to that module',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleTile(AdminModuleItem module) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(module.icon, color: AppTheme.primaryColor, size: 20),
          ),
          title: Row(
            children: [
              Text(
                module.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  module.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              module.description,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.primaryColor),
          onTap: () {
            widget.onNavigate(module.route, module.index);
          },
        ),
      ),
    );
  }

  Widget _buildStaffTile(UserModel staff) {
    final name = staff.rawFullname ?? staff.fullname;
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 13),
            ),
          ),
          title: Row(
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  staff.role,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                ),
              ),
            ],
          ),
          subtitle: Text(
            staff.email,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textSecondaryColor),
          onTap: () {
            widget.onNavigate(AppRoutes.adminUsers, 1);
          },
        ),
      ),
    );
  }

  Widget _buildPatientTile(PatientModel patient) {
    final pInitials = patient.name.trim().isNotEmpty
        ? patient.name.trim()[0].toUpperCase()
        : 'P';
    final pid = patient.patientId ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              pInitials,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
            ),
          ),
          title: Row(
            children: [
              Text(
                patient.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
              ),
              if (pid.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    pid,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            'Phone: ${patient.phone} • Age: ${patient.age}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textSecondaryColor),
          onTap: () {
            widget.onNavigate(AppRoutes.adminPatients, 2);
          },
        ),
      ),
    );
  }
}

