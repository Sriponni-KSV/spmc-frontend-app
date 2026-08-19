import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_dropdown_search.dart';
import '../widgets/appointment_details_dialog.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/patient_controller.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../utils/date_formatter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/unsaved_changes_helper.dart';

class OPDManagementScreen extends StatefulWidget {
  final bool isMobile;
  final String title;
  const OPDManagementScreen({
    Key? key,
    required this.isMobile,
    this.title = 'OPD Management',
  }) : super(key: key);

  @override
  State<OPDManagementScreen> createState() => _OPDManagementScreenState();
}

class _OPDManagementScreenState extends State<OPDManagementScreen>
    with SingleTickerProviderStateMixin {
  final AppointmentController _appointmentController = AppointmentController();
  final AdminController _adminController = AdminController();
  final PatientController _patientController = PatientController();

  late TabController _tabController;
  List<AppointmentModel> _appointments = [];
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  final DateTime _selectedDate = DateTime.now(); // Locked to today for OPD
  String _selectedDoctor = 'All';
  String _searchQuery = '';
  bool _isFilterVisible = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<UserModel> _doctors = [];

  @override
  void initState() {
    super.initState();
    UnsavedChangesHelper.setUnsavedChanges(true);
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
    _loadDoctors();
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await _appointmentController.fetchAdminAppointments(
        date: dateStr,
        status: null,
        doctor: _selectedDoctor == 'All' ? null : _selectedDoctor,
      );
      final consultationsData = await _appointmentController
          .fetchConsultations();

      if (mounted) {
        setState(() {
          _appointments =
              data; // include all appointment types (walk-in + pre-booked)
          _consultations = consultationsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final staff = await _adminController.fetchStaff(role: 'Doctor');
      final activeWithTimings = staff.where((d) {
        if (d.status.toLowerCase() != 'active') return false;
        final dp = d.doctorProfile;
        if (dp == null) return false;
        if (dp.slotStartTime == null || dp.slotStartTime!.trim().isEmpty) return false;
        if (dp.slotEndTime == null || dp.slotEndTime!.trim().isEmpty) return false;
        if (dp.slotDuration == null || dp.slotDuration!.trim().isEmpty) return false;
        if (dp.availableDays == null || dp.availableDays!.isEmpty) return false;
        return true;
      }).toList();
      if (mounted) {
        activeWithTimings.sort((a, b) => a.fullname.compareTo(b.fullname));
        setState(() {
          _doctors = activeWithTimings;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    }
  }

  bool _isWalkIn(AppointmentModel appointment) {
    final normalized = appointment.appointmentType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '');
    return normalized == 'walkin';
  }

  DateTime _sortDate(AppointmentModel appointment) {
    return DateTime.tryParse(
          appointment.createdAt ?? appointment.updatedAt ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _newestFirst(AppointmentModel a, AppointmentModel b) {
    final dateCompare = _sortDate(b).compareTo(_sortDate(a));
    if (dateCompare != 0) return dateCompare;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  // All today's appointments (both walk-in and pre-booked)
  List<AppointmentModel> get _walkInAppointments =>
      List<AppointmentModel>.from(_appointments);

  List<AppointmentModel> get _filteredAppointments {
    List<AppointmentModel> apps = List<AppointmentModel>.from(
      _walkInAppointments,
    );

    // 1. Search Query Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((a) {
        return a.patientName.toLowerCase().contains(query) ||
            (a.patientDisplayId?.toLowerCase().contains(query) ?? false) ||
            (a.patientPhone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    apps.sort(_newestFirst);

    return apps;
  }

  List<AppointmentModel> _getTabAppointments(int tabIndex) {
    final baseApps = _filteredAppointments;
    switch (tabIndex) {
      case 0: // Waiting (Confirmed / Checked-in / Waiting)
        return baseApps
            .where(
              (a) =>
                  a.status == 'Confirmed' ||
                  a.status == 'Checked-in' ||
                  a.status == 'Waiting',
            )
            .toList();
      case 1: // In Consultation
        return baseApps.where((a) => a.status == 'In Consultation').toList();
      case 2: // Completed – driven by consultations (all dates, not date-filtered)
        return _consultations.map((c) {
          return AppointmentModel(
            id: c['appointment_id'] is int
                ? c['appointment_id']
                : int.tryParse(c['appointment_id']?.toString() ?? ''),
            patientId: c['patient_id'] is int
                ? c['patient_id']
                : int.tryParse(c['patient_id']?.toString() ?? '') ?? 0,
            patientName: c['patient_name'] as String? ?? 'Unknown',
            doctorName: c['doctor_name'] as String? ?? '',
            appointmentDate: c['appointment_date'] as String? ?? '',
            appointmentTime: c['appointment_time'] as String? ?? '',
            department: c['department'] as String? ?? '',
            appointmentType: c['appointment_type'] as String? ?? 'Walk-in',
            status: 'Completed',
            patientDisplayId: c['patient_display_id'] as String?,
            patientPhone: c['patient_phone'] as String?,
            changesLog: c['changes_log'],
            createdAt: c['created_at'] as String?,
            updatedAt: c['updated_at'] as String?,
          );
        }).toList();
      case 3: // Cancelled & No-Show
        return baseApps
            .where((a) => a.status == 'Cancelled' || a.status == 'No-Show')
            .toList();
      default:
        return [];
    }
  }

  int _getCountForTab(int tabIndex) {
    final walkins = _walkInAppointments;
    switch (tabIndex) {
      case 0:
        return walkins
            .where(
              (a) =>
                  a.status == 'Confirmed' ||
                  a.status == 'Checked-in' ||
                  a.status == 'Waiting',
            )
            .length;
      case 1:
        return walkins.where((a) => a.status == 'In Consultation').length;
      case 2:
        return _consultations.length;
      case 3:
        return walkins
            .where((a) => a.status == 'Cancelled' || a.status == 'No-Show')
            .length;
      default:
        return 0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Waiting':
      case 'Checked-in':
        return const Color(0xFF0D9488); // Teal
      case 'In Consultation':
        return const Color(0xFFF59E0B); // Amber
      case 'Completed':
        return const Color(0xFF22C55E); // Green
      case 'Cancelled':
        return const Color(0xFFEF4444); // Red
      case 'No-Show':
        return const Color(0xFFF97316); // Orange
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchAndFilterRow(),
          if (_isFilterVisible) _buildFilterPanel(),
          const SizedBox(height: 16),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorView()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabQueueList(0),
                      _buildTabQueueList(1),
                      _buildTabQueueList(2),
                      _buildTabQueueList(3),
                      _buildPrescriptionsTab(),
                      _buildLabTestsTab(),
                      _buildPharmacyTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = Provider.of<AuthProvider>(context).user;
    final isNurse = user?.role == 'Nurse';

    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.isMobile ? 16 : 24,
        24,
        widget.isMobile ? 16 : 24,
        8,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: widget.isMobile ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Today\'s OPD Pipeline: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (isNurse)
                  ElevatedButton.icon(
                    onPressed: () => _showWalkInDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Walk-in',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 3,
                      shadowColor: Colors.black26,
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_hospital_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Today\'s OPD Pipeline: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNurse)
                  ElevatedButton.icon(
                    onPressed: () => _showWalkInDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      widget.isMobile ? 'Walk-in' : 'New Walk-in Entry',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 3,
                      shadowColor: Colors.black26,
                      minimumSize: const Size(120, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      height: 90,
      margin: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 16 : 24,
        vertical: 8,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            title: 'Total OPD Today',
            count: _walkInAppointments.length,
            color: Colors.blue.shade700,
            icon: Icons.people_outline,
            onTap: null,
          ),
          _buildStatCard(
            title: 'Waiting Queue',
            count: _getCountForTab(0),
            color: const Color(0xFF0D9488),
            icon: Icons.hourglass_empty,
            onTap: () => _tabController.animateTo(0),
          ),
          _buildStatCard(
            title: 'In Consultation',
            count: _getCountForTab(1),
            color: const Color(0xFFF59E0B),
            icon: Icons.medical_services_outlined,
            onTap: () => _tabController.animateTo(1),
          ),
          _buildStatCard(
            title: 'Completed',
            count: _getCountForTab(2),
            color: const Color(0xFF22C55E),
            icon: Icons.check_circle_outline,
            onTap: () => _tabController.animateTo(2),
          ),
          _buildStatCard(
            title: 'Cancelled',
            count: _getCountForTab(3),
            color: const Color(0xFFEF4444),
            icon: Icons.cancel_outlined,
            onTap: () => _tabController.animateTo(3),
          ),
          _buildStatCard(
            title: 'Prescriptions',
            count: _getPrescriptionsCount(),
            color: Colors.indigo,
            icon: Icons.description_outlined,
            onTap: () => _tabController.animateTo(4),
          ),
          _buildStatCard(
            title: 'Lab Orders',
            count: _getLabTestsCount(),
            color: Colors.teal.shade700,
            icon: Icons.science_outlined,
            onTap: () => _tabController.animateTo(5),
          ),
          _buildStatCard(
            title: 'Pharmacy Status',
            count: _getPharmacyCount(),
            color: Colors.purple.shade700,
            icon: Icons.local_pharmacy_outlined,
            onTap: () => _tabController.animateTo(6),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: color.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withOpacity(0.02),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildSearchAndFilterRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 12),
          _buildFilterToggle(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 18,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search patient name, ID, or phone...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return InkWell(
      onTap: () => setState(() => _isFilterVisible = !_isFilterVisible),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
              size: 18,
              color: AppTheme.textPrimaryColor,
            ),
            const SizedBox(width: 8),
            const Text(
              'Filters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: EdgeInsets.only(
        left: widget.isMobile ? 16 : 24,
        right: widget.isMobile ? 16 : 24,
        top: 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              'Doctor Availability Filter',
              _selectedDoctor,
              ['All', ..._doctors.map((d) => d.fullname)],
              (v) {
                if (v != null) {
                  setState(() => _selectedDoctor = v);
                  _loadData();
                }
              },
            ),
          ),
          if (_selectedDoctor != 'All') ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {
                setState(() => _selectedDoctor = 'All');
                _loadData();
              },
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
              tooltip: 'Reset Filters',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 6),
        CustomDropdownSearch(
          label: '',
          value: value,
          dropdownItems: items,
          height: 48,
          onChanged: onChanged,
        ),
      ],
    );
  }

  int _getPrescriptionsCount() {
    return _consultations.where((c) {
      final medsRaw = c['medications'];
      List<dynamic> meds = [];
      if (medsRaw is List) {
        meds = medsRaw;
      } else if (medsRaw is String) {
        try {
          final decoded = jsonDecode(medsRaw);
          if (decoded is List) meds = decoded;
        } catch (_) {}
      }
      return meds.isNotEmpty;
    }).length;
  }

  int _getLabTestsCount() {
    return _consultations.where((c) {
      final labsRaw = c['lab_tests'];
      List<dynamic> labs = [];
      if (labsRaw is List) {
        labs = labsRaw;
      } else if (labsRaw is String) {
        try {
          final decoded = jsonDecode(labsRaw);
          if (decoded is List) labs = decoded;
        } catch (_) {}
      }
      return labs.isNotEmpty;
    }).length;
  }

  int _getPharmacyCount() {
    return _consultations.where((c) {
      final status = c['pharmacy_status']?.toString();
      if (status == null || status.isEmpty) return false;
      final medsRaw = c['medications'];
      List<dynamic> meds = [];
      if (medsRaw is List) {
        meds = medsRaw;
      } else if (medsRaw is String) {
        try {
          final decoded = jsonDecode(medsRaw);
          if (decoded is List) meds = decoded;
        } catch (_) {}
      }
      return meds.isNotEmpty;
    }).length;
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_empty, size: 16),
                const SizedBox(width: 4),
                Text('Waiting (${_getCountForTab(0)})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.medical_services_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Consulting (${_getCountForTab(1)})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 16),
                const SizedBox(width: 4),
                Text('Completed (${_getCountForTab(2)})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Cancelled (${_getCountForTab(3)})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Prescriptions (${_getPrescriptionsCount()})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.science_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Lab Orders (${_getLabTestsCount()})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_pharmacy_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Pharmacy Status (${_getPharmacyCount()})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabQueueList(int tabIndex) {
    final list = _getTabAppointments(tabIndex);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 48,
              color: AppTheme.textMutedColor.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No patients in this state currently.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final app = list[index];
        return _buildAppointmentItemCard(app, tabIndex);
      },
    );
  }

  Widget _buildAppointmentItemCard(AppointmentModel app, int tabIndex) {
    final avatarColor = AppTheme.getAvatarColors(app.patientName);
    final bool isTriaged =
        app.status == 'Checked-in' || app.status == 'Waiting';

    // Status colors
    Color statusColor;
    switch (app.status) {
      case 'Waiting':
      case 'Checked-in':
        statusColor = const Color(0xFF0D9488); // Teal
        break;
      case 'In Consultation':
        statusColor = const Color(0xFFF59E0B); // Amber
        break;
      case 'Completed':
        statusColor = const Color(0xFF22C55E); // Green
        break;
      case 'Cancelled':
      case 'No-Show':
        statusColor = const Color(0xFFEF4444); // Red
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timing & Avatar
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              app.status == 'Completed'
                                  ? Icons.calendar_today
                                  : Icons.access_time,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              app.status == 'Completed'
                                  ? '${app.appointmentDate}  ${app.appointmentTime}'
                                  : app.appointmentTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColor['bg'],
                        child: Text(
                          app.patientName.isNotEmpty
                              ? app.patientName[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: avatarColor['text'],
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Patient / Doctor Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              app.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            if (app.patientDisplayId != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  app.patientDisplayId!,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                            // Appointment type badge
                            const SizedBox(width: 6),
                            Builder(
                              builder: (_) {
                                final normalized = app.appointmentType
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[\s-]+'), '');
                                final isWalkIn = normalized == 'walkin';
                                final badgeColor = isWalkIn
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFF6366F1);
                                final label = isWalkIn
                                    ? 'Walk-in'
                                    : app.appointmentType;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: badgeColor.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Dr. ${app.doctorName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${app.department}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMutedColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (app.patientPhone != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: AppTheme.textMutedColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                app.patientPhone!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMutedColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Status Pill Summary
                  _buildStatusBadge(app.status),
                ],
              ),
              const Divider(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show Vitals values if they exist (BP, Temp, Sugar)
                        if (app.bloodPressureSystolic != null ||
                            app.temperature != null ||
                            app.sugarLevel != null) ...[
                          const Text(
                            'Patient Vitals:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (app.bloodPressureSystolic != null)
                                _buildVitalPill(
                                  Icons.speed,
                                  'BP: ${app.bloodPressureSystolic}/${app.bloodPressureDiastolic ?? "--"} mmHg',
                                  Colors.blue.shade700,
                                ),
                              if (app.temperature != null)
                                _buildVitalPill(
                                  Icons.thermostat_outlined,
                                  'Temp: ${app.temperature} °F',
                                  Colors.orange.shade700,
                                ),
                              if (app.sugarLevel != null)
                                _buildVitalPill(
                                  Icons.bloodtype_outlined,
                                  'Sugar: ${app.sugarLevel} mg/dL',
                                  Colors.red.shade700,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (app.reasonForVisit != null &&
                            app.reasonForVisit!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notes,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Complaint: ${app.reasonForVisit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Actions Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showVisitDetails(app),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (app.status == 'Confirmed') ...[
                        if (!_hasVitals(app)) ...[
                          ElevatedButton.icon(
                            onPressed: () => _openVitalsDialog(app),
                            icon: const Icon(
                              Icons.monitor_heart,
                              size: 14,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Add Vitals',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],

                        ElevatedButton.icon(
                          onPressed: () => _showCancelAppointmentDialog(app),
                          icon: const Icon(Icons.cancel_outlined, size: 14),
                          label: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageBadge(bool isTriaged) {
    final color = isTriaged ? const Color(0xFF0D9488) : Colors.grey;
    final label = isTriaged ? 'Triage Complete' : 'Waiting Triage';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  bool _hasVitals(AppointmentModel app) {
    return app.bloodPressureSystolic != null && app.temperature != null;
  }

  void _openVitalsDialog(AppointmentModel app) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppointmentDetailsDialog(
        appointment: app,
        editVitalsOnly: true,
        onRefresh: _loadData,
      ),
    );
  }

  Future<void> _showVitalsMissingDialog(
    BuildContext context,
    AppointmentModel appt,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Vitals Required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Vitals must be recorded before changing the appointment status to "Waiting". Would you like to enter them now?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close alert
                _openVitalsDialog(appt);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Enter Vitals Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleMarkWaiting(AppointmentModel app) async {
    if (!_hasVitals(app)) {
      await _showVitalsMissingDialog(context, app);
    } else {
      await _markWaiting(app);
    }
  }

  Future<void> _markWaiting(AppointmentModel app) async {
    try {
      await _appointmentController.updateStatus(app.id!, 'Waiting');
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.patientName} marked as Waiting ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCancelAppointmentDialog(AppointmentModel app) async {
    final cancelReasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: TextField(
          controller: cancelReasonController,
          decoration: const InputDecoration(
            hintText: 'Enter cancellation reason (required)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (cancelReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason is required')),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                await _appointmentController.updateStatus(
                  app.id!,
                  'Cancelled',
                  cancellationReason: cancelReasonController.text.trim(),
                );
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${app.patientName} cancelled ✓'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showVisitDetails(AppointmentModel app) {
    Map<String, dynamic>? consultation;
    bool isLoadingConsul = app.status == 'Completed';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoadingConsul) {
            _appointmentController
                .fetchConsultationsByPatient(app.patientId)
                .then((consuls) {
                  if (mounted) {
                    final match = consuls.firstWhere(
                      (c) => c['appointment_id'] == app.id,
                      orElse: () => <String, dynamic>{},
                    );
                    setDialogState(() {
                      if (match.isNotEmpty) {
                        consultation = match;
                      }
                      isLoadingConsul = false;
                    });
                  }
                })
                .catchError((e) {
                  if (mounted) {
                    setDialogState(() {
                      isLoadingConsul = false;
                    });
                  }
                });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium Card Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F5A8E), Color(0xFF063A60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.patientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${app.patientDisplayId ?? 'N/A'} • Contact: ${app.patientPhone ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Patient & Appointment details + vitals
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Appointment Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _detailItem(
                                        'Assigned Doctor',
                                        app.doctorName,
                                      ),
                                      _detailItem('Department', app.department),
                                      _detailItem(
                                        'Date / Time',
                                        '${app.appointmentDate} • ${app.appointmentTime}',
                                      ),
                                      _detailItem(
                                        'Session Status',
                                        app.status,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Vitals Card
                                if (app.bloodPressureSystolic != null ||
                                    app.temperature != null ||
                                    app.sugarLevel != null) ...[
                                  const Text(
                                    'Patient Vitals',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (app.bloodPressureSystolic != null)
                                        Expanded(
                                          child: _buildVitalPillCard(
                                            'Blood Pressure',
                                            '${app.bloodPressureSystolic}/${app.bloodPressureDiastolic}',
                                            'mmHg',
                                            Icons.favorite,
                                            Colors.red,
                                          ),
                                        ),
                                      if (app.bloodPressureSystolic != null &&
                                          (app.temperature != null ||
                                              app.sugarLevel != null))
                                        const SizedBox(width: 8),
                                      if (app.temperature != null)
                                        Expanded(
                                          child: _buildVitalPillCard(
                                            'Temperature',
                                            '${app.temperature}',
                                            '°F',
                                            Icons.thermostat,
                                            Colors.orange,
                                          ),
                                        ),
                                      if (app.temperature != null &&
                                          app.sugarLevel != null)
                                        const SizedBox(width: 8),
                                      if (app.sugarLevel != null)
                                        Expanded(
                                          child: _buildVitalPillCard(
                                            'Blood Sugar',
                                            '${app.sugarLevel}',
                                            'mg/dL',
                                            Icons.water_drop,
                                            Colors.blue,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                if (app.reasonForVisit != null &&
                                    app.reasonForVisit!.isNotEmpty) ...[
                                  const Text(
                                    'Reason for Visit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      border: Border.all(
                                        color: Colors.amber.shade100,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      app.reasonForVisit!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.amber.shade900,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Vertical Divider
                          Container(
                            width: 1,
                            height: 480,
                            color: Colors.grey.shade200,
                          ),
                          const SizedBox(width: 24),

                          // Right Column: Clinical Consult findings / Status Timeline Log
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (app.status == 'Completed') ...[
                                  const Text(
                                    'Clinical Consultation Findings',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (isLoadingConsul)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (consultation == null)
                                    const Text(
                                      'No consultation details recorded yet.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else ...[
                                    _buildConsultationSummary(consultation!),
                                  ],
                                  const SizedBox(height: 24),
                                ],

                                const Text(
                                  'Status Timeline Log',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Builder(
                                    builder: (_) {
                                      // Prefer the freshly-fetched consultation's
                                      // changes_log; fall back to app.changesLog
                                      final timelineData =
                                          (consultation != null &&
                                              consultation!['changes_log'] !=
                                                  null)
                                          ? consultation!['changes_log']
                                          : app.changesLog;
                                      return timelineData != null
                                          ? _buildTimeline(timelineData)
                                          : const Text(
                                              'No status changes recorded yet.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                            );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Button Panel
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.logoRed,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close Details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVitalPillCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalDetailPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildConsultationSummary(Map<String, dynamic> c) {
    List? docsList;
    final docs = c['documents'];
    if (docs is List) {
      docsList = docs;
    } else if (docs is String && docs.isNotEmpty) {
      try {
        final decoded = jsonDecode(docs);
        if (decoded is List) docsList = decoded;
      } catch (_) {}
    }

    final ref = c['referral'];
    Map? refMap;
    if (ref is Map) {
      refMap = ref;
    } else if (ref is String && ref.isNotEmpty) {
      try {
        final decoded = jsonDecode(ref);
        if (decoded is Map) refMap = decoded;
      } catch (_) {}
    }

    List medsList = [];
    if (c['medications'] != null) {
      if (c['medications'] is String) {
        try {
          final decoded = jsonDecode(c['medications']);
          if (decoded is List) medsList = decoded;
        } catch (_) {}
      } else if (c['medications'] is List) {
        medsList = c['medications'];
      }
    }

    List labsList = [];
    if (c['lab_tests'] != null) {
      if (c['lab_tests'] is String) {
        try {
          final decoded = jsonDecode(c['lab_tests']);
          if (decoded is List) labsList = decoded;
        } catch (_) {}
      } else if (c['lab_tests'] is List) {
        labsList = c['lab_tests'];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c['doctor_name'] != null &&
            c['doctor_name'].toString().isNotEmpty) ...[
          const Text(
            'Doctor:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            c['doctor_name'].toString(),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        if (c['symptoms'] != null && c['symptoms'].toString().isNotEmpty) ...[
          const Text(
            'Subjective Symptoms:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['symptoms'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['leading_questions'] != null &&
            c['leading_questions'].toString().isNotEmpty) ...[
          const Text(
            'Leading Questions:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            c['leading_questions'].toString(),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        if (c['diagnosis'] != null && c['diagnosis'].toString().isNotEmpty) ...[
          const Text(
            'Diagnosis / Impression:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['diagnosis'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['history'] != null && c['history'].toString().isNotEmpty) ...[
          const Text(
            'Clinical History:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['history'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['examination'] != null &&
            c['examination'].toString().isNotEmpty) ...[
          const Text(
            'Physical Examination:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            c['examination'].toString(),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        if (c['family_history'] != null &&
            c['family_history'].toString().isNotEmpty) ...[
          const Text(
            'Family History:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            c['family_history'].toString(),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        if (c['social'] != null && c['social'].toString().isNotEmpty) ...[
          const Text(
            'Social History:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['social'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['allergy'] != null && c['allergy'].toString().isNotEmpty) ...[
          const Text(
            'Allergies:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            c['allergy'].toString(),
            style: const TextStyle(fontSize: 13, color: Colors.red),
          ),
          const SizedBox(height: 8),
        ],
        if (c['procedure'] != null && c['procedure'].toString().isNotEmpty) ...[
          const Text(
            'Procedures:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['procedure'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['plan'] != null && c['plan'].toString().isNotEmpty) ...[
          const Text(
            'Plan:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['plan'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (refMap != null &&
            ((refMap['referred_doctor']?.toString().isNotEmpty ?? false) ||
                (refMap['referred_department']?.toString().isNotEmpty ??
                    false))) ...[
          const Text(
            'Referral Details:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            'To Doctor: ${refMap['referred_doctor'] ?? 'N/A'} • Dept: ${refMap['referred_department'] ?? 'N/A'}\nNotes: ${refMap['referral_notes'] ?? ''}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        if (docsList != null && docsList.isNotEmpty) ...[
          const Text(
            'Attached Documents:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...docsList.map((d) {
            if (d is Map) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${d['title']} (${d['file_name']})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }).toList(),
          const SizedBox(height: 8),
        ],
        if (medsList.isNotEmpty) ...[
          const Text(
            'Prescribed Medications:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildMedicationList(c['medications']),
        ],
        if (labsList.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Ordered Lab Tests:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildLabTestsList(c['lab_tests']),
        ],
        if (c['comment'] != null && c['comment'].toString().isNotEmpty) ...[
          const Text(
            'Comments / General Remarks:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['comment'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['notes'] != null && c['notes'].toString().isNotEmpty) ...[
          const Text(
            'Doctor\'s Advice / Follow-up Notes:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(c['notes'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['pharmacy_status'] != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Pharmacy Status: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              _buildPharmacyStatusBadge(c['pharmacy_status'].toString()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLabTestsList(dynamic labTests) {
    List labs = [];
    if (labTests is List) {
      labs = labTests;
    } else if (labTests is String) {
      try {
        final decoded = jsonDecode(labTests);
        if (decoded is List) {
          labs = decoded;
        }
      } catch (_) {}
    }

    if (labs.isEmpty) {
      return const Text(
        'No lab tests ordered.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labs.map((l) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 12,
                color: Colors.blue.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                l.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPharmacyStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color text = Colors.grey.shade700;
    if (status == 'Notified') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF047857);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildMedicationList(dynamic medications) {
    List meds = [];
    if (medications is List) {
      meds = medications;
    } else if (medications is String) {
      try {
        final decoded = jsonDecode(medications);
        if (decoded is List) {
          meds = decoded;
        }
      } catch (_) {}
    }

    if (meds.isEmpty) {
      return const Text(
        'No medications prescribed.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    return Column(
      children: meds.map((m) {
        String display = m.toString();
        if (m is Map) {
          display = '${m['name']} - ${m['dosage']} (${m['frequency']})';
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.medication,
                size: 14,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  display,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(dynamic log) {
    if (log is! Map) return const SizedBox.shrink();
    final sortedKeys = log.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedKeys.map((key) {
        final change = log[key];
        DateTime? dt;
        try {
          dt = DateTime.parse(key);
        } catch (_) {}
        String text = 'Updated';
        if (change is Map && change.containsKey('status')) {
          final from = change['status']['from'];
          final to = change['status']['to'];
          if (from == null ||
              from == 'null' ||
              from.toString().trim().isEmpty) {
            text = 'Initial Status: $to';
          } else {
            text = 'Status: $from → $to';
          }
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 10,
                    color: AppTheme.primaryColor,
                  ),
                  Container(width: 2, height: 20, color: AppTheme.borderColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dt != null)
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(dt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    Text(text, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showOverrideDialog(AppointmentModel app) {
    final reasonController = TextEditingController();
    String newStatus = app.status;
    bool isSaving = false;

    // Remove All from status selections
    final overrideStatuses = [
      'Confirmed',
      'Checked-in',
      'In Consultation',
      'Completed',
      'Cancelled',
      'No-Show',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Admin Status Override',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomDropdownSearch(
                label: 'New Status',
                value: overrideStatuses.contains(newStatus)
                    ? newStatus
                    : overrideStatuses[0],
                dropdownMap: const {
                  'Confirmed': 'Confirmed',
                  'Checked-in': 'Checked-in',
                  'Waiting': 'Waiting',
                  'In Consultation': 'In Consultation',
                  'Completed': 'Completed',
                  'Cancelled': 'Cancelled',
                  'No-Show': 'No-Show',
                },
                onChanged: (val) {
                  if (val != null) setDialogState(() => newStatus = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Override Reason (Mandatory)',
                  hintText: 'Explain why you are changing the status...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please provide a reason'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await _appointmentController.adminOverrideAppointment(
                          id: app.id!,
                          status: newStatus,
                          overrideReason: reasonController.text.trim(),
                        );
                        Navigator.pop(ctx);
                        _loadData();
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Status updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                      } finally {
                        if (mounted) setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _parseTime(String timeStr) {
    final timeParts = timeStr.split(' ');
    final hms = timeParts[0].split(':');
    int hour = int.parse(hms[0]);
    int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
    if (timeParts.length > 1) {
      if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(2026, 1, 1, hour, minute);
  }

  List<String> _generateSlotsForDoctor(UserModel doctor) {
    if (doctor.slotStartTime == null || doctor.slotEndTime == null) {
      List<String> slots = [];
      DateTime start = DateTime(2026, 1, 1, 9, 0);
      DateTime end = DateTime(2026, 1, 1, 13, 0);
      while (start.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(start));
        start = start.add(const Duration(minutes: 30));
      }
      return slots;
    }

    int duration = 30;
    if (doctor.slotDuration != null) {
      duration = int.tryParse(doctor.slotDuration!.split(' ')[0]) ?? 30;
    }

    try {
      DateTime start = _parseTime(doctor.slotStartTime!);
      DateTime end = _parseTime(doctor.slotEndTime!);

      List<String> slots = [];
      DateTime current = start;
      while (current.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(Duration(minutes: duration));
      }
      return slots;
    } catch (e) {
      return [];
    }
  }

  void _showWalkInDialog() {
    PatientModel? selectedPatient;
    UserModel? selectedDoctor;
    String? selectedTime;
    List<String> availableSlots = [];
    bool isSaving = false;
    bool isLoadingPatients = false;
    List<PatientModel> allPatients = [];
    final bpSysCtrl = TextEditingController();
    final bpDiaCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final complaintCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (allPatients.isEmpty && !isLoadingPatients) {
            setDialogState(() => isLoadingPatients = true);
            _patientController
                .fetchPatients()
                .then((p) {
                  if (mounted) {
                    setDialogState(() {
                      allPatients = p;
                      isLoadingPatients = false;
                    });
                  }
                })
                .catchError((e) {
                  if (mounted) setDialogState(() => isLoadingPatients = false);
                });
          }

          return AlertDialog(
            title: const Text(
              'Quick Walk-in Entry',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoadingPatients)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        const Text(
                          'Select Patient',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),

                      const SizedBox(height: 10),

                      CustomDropdownSearch(
                        label: '',
                        hint: 'Search or select patient...',
                        value: selectedPatient?.id?.toString(),
                        dropdownMap: {
                          for (var p in allPatients)
                            p.id.toString():
                                '${p.name} (${p.patientId ?? "N/A"})',
                        },
                        onChanged: (val) {
                          if (val != null) {
                            final id = int.tryParse(val);
                            setDialogState(() {
                              selectedPatient = allPatients.firstWhere(
                                (p) => p.id == id,
                              );
                            });
                          }
                        },
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please select patient'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Assign Doctor',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 10),

                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select doctor...',
                        value: selectedDoctor?.id.toString(),
                        dropdownMap: {
                          for (var d in _doctors)
                            d.id.toString():
                                d.staffUniqueId != null &&
                                    d.staffUniqueId!.isNotEmpty
                                ? '${d.fullname} (${d.staffUniqueId})'
                                : d.fullname,
                        },
                        onChanged: (val) {
                          if (val != null) {
                            final id = int.tryParse(val);
                            final doctor = _doctors.firstWhere(
                              (d) => d.id == id,
                            );
                            setDialogState(() {
                              selectedDoctor = doctor;
                              selectedTime = null;
                              DateTime now = DateTime.now();
                              final weekDays = [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ];
                              final dayName = weekDays[now.weekday - 1];
                              final dateStr = DateFormat(
                                'dd/MM/yyyy',
                              ).format(now);

                              bool isAvailable = false;
                              if (doctor.availableDays != null &&
                                  doctor.availableDays!.contains(dayName)) {
                                isAvailable = true;
                              }
                              if (doctor.weeklyOffDays != null &&
                                  doctor.weeklyOffDays!.contains(dayName)) {
                                isAvailable = false;
                              }
                              if (doctor.specificLeaveDates != null &&
                                  doctor.specificLeaveDates!.contains(
                                    dateStr,
                                  )) {
                                isAvailable = false;
                              }

                              if (!isAvailable) {
                                availableSlots = [];
                              } else {
                                availableSlots = _generateSlotsForDoctor(
                                  doctor,
                                );
                                availableSlots = availableSlots.where((slot) {
                                  bool isBooked = _appointments.any(
                                    (a) =>
                                        a.doctorName == doctor.fullname &&
                                        a.appointmentTime == slot &&
                                        a.status != 'Cancelled' &&
                                        a.status != 'No-Show',
                                  );
                                  if (isBooked) return false;
                                  try {
                                    DateTime slotTime = _parseTime(slot);
                                    DateTime fullSlotTime = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      slotTime.hour,
                                      slotTime.minute,
                                    );
                                    return fullSlotTime.isAfter(now);
                                  } catch (e) {
                                    return true;
                                  }
                                }).toList();
                              }
                            });
                          }
                        },
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please select doctor'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      if (selectedDoctor != null) ...[
                        const Text(
                          'Available Time Slots (Today)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (availableSlots.isEmpty)
                          const Text(
                            'No slots available for this doctor today.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = availableSlots[index];
                              final isSelected = selectedTime == slot;
                              return InkWell(
                                onTap: () =>
                                    setDialogState(() => selectedTime = slot),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.borderColor,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    slot,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimaryColor,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (selectedTime == null && availableSlots.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Please select a time slot',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Patient Intake Vitals',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: 'BP Systolic',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: ' *',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: bpSysCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '120',
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Please enter BP systolic';
                                    }
                                    final num = int.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 90 || num > 300)
                                      return 'Must be 90 to 300';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: 'BP Diastolic',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: ' *',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: bpDiaCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '80',
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Please enter BP diastolic';
                                    }
                                    final num = int.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 50 || num > 180)
                                      return 'Must be 50 to 180';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: 'Sugar Level',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: ' *',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: sugarCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '95.5 mg/dL',
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Please enter sugar level';
                                    }
                                    final num = double.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 30 || num > 600)
                                      return 'Must be 30 to 600';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text: 'Temperature',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: ' *',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: tempCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  maxLength: 5,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '98.6 °F',
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (val) {
                                    final text = val?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Please enter temperature';
                                    }
                                    final num = double.tryParse(text);
                                    if (num == null) return 'Enter a number';
                                    if (num == 0) return 'Cannot be 0';
                                    if (num < 90 || num > 115)
                                      return 'Must be 90 to 115';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: complaintCtrl,
                        maxLines: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                          LengthLimitingTextInputFormatter(100),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Describe symptoms or reason for visit...',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a time slot'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final vitalsData = <String, dynamic>{
                            'blood_pressure_systolic': int.parse(
                              bpSysCtrl.text.trim(),
                            ),
                            'blood_pressure_diastolic': int.parse(
                              bpDiaCtrl.text.trim(),
                            ),
                            'sugar_level': double.parse(sugarCtrl.text.trim()),
                            'temperature': double.parse(tempCtrl.text.trim()),
                            'reason_for_visit': complaintCtrl.text.trim(),
                          };
                          final newApp = AppointmentModel(
                            patientId: selectedPatient!.id!,
                            patientName: selectedPatient!.name,
                            department:
                                selectedDoctor!.specialization ?? 'General',
                            doctorName: selectedDoctor!.fullname,
                            appointmentDate: DateFormatter.toUi(DateTime.now()),
                            appointmentTime: selectedTime!,
                            bloodPressureSystolic:
                                vitalsData['blood_pressure_systolic'] as int,
                            bloodPressureDiastolic:
                                vitalsData['blood_pressure_diastolic'] as int?,
                            sugarLevel: vitalsData['sugar_level'] as double?,
                            temperature: vitalsData['temperature'] as double,
                            reasonForVisit: complaintCtrl.text.trim(),
                            status: 'Waiting',
                            appointmentType: 'Walk-in',
                          );
                          final created = await _appointmentController
                              .bookAppointment(newApp);
                          await _appointmentController.updateVitals(
                            created.id!,
                            vitalsData,
                          );
                          await _appointmentController.updateStatus(
                            created.id!,
                            'Waiting',
                          );
                          Navigator.pop(ctx);
                          _loadData();
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Walk-in registered and added to waiting',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.logoRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Register'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConsultationWorkflowDialog(AppointmentModel app) {
    int activeStep = 0;
    bool isSaving = false;

    // Persist controllers across dialog states
    final symptomsController = TextEditingController();
    final diagnosisController = TextEditingController();
    final notesController = TextEditingController();

    // Rx step state
    final drugNameController = TextEditingController();
    final dosageController = TextEditingController();
    final durationController = TextEditingController();
    String selectedFrequency = '1-0-1';
    final List<Map<String, String>> medicationsList = [];

    // Labs step state
    final Map<String, bool> standardLabs = {
      'Complete Blood Count (CBC)': false,
      'Basic Metabolic Panel (BMP)': false,
      'Lipid Panel': false,
      'Thyroid Panel (TSH)': false,
      'Urinalysis': false,
      'Chest X-Ray': false,
      'ECG/EKG': false,
    };
    final List<String> customLabsList = [];
    final customLabController = TextEditingController();

    // Admission state
    bool recommendAdmission = false;
    final reasonForAdmissionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget _buildLine() {
            return Container(width: 24, height: 2, color: Colors.grey.shade300);
          }

          Widget _buildDialogVitalBadge(
            IconData icon,
            String label,
            String value,
            Color color,
          ) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          Widget buildStepIndicator(int step, String label, IconData icon) {
            bool isCompleted = activeStep > step;
            bool isActive = activeStep == step;
            Color stepColor = isCompleted
                ? const Color(0xFF0D9488)
                : (isActive ? AppTheme.primaryColor : Colors.grey.shade400);

            return Tooltip(
              message: label,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? stepColor.withOpacity(0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: stepColor,
                        width: isActive ? 2.5 : 1.5,
                      ),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : icon,
                      size: 16,
                      color: stepColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildProgressHeader() {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildStepIndicator(0, 'Intake', Icons.notes),
                  _buildLine(),
                  buildStepIndicator(
                    1,
                    'Diagnosis',
                    Icons.health_and_safety_outlined,
                  ),
                  _buildLine(),
                  buildStepIndicator(
                    2,
                    'Prescriptions',
                    Icons.medication_outlined,
                  ),
                  _buildLine(),
                  buildStepIndicator(3, 'Lab Orders', Icons.science_outlined),
                  _buildLine(),
                  buildStepIndicator(4, 'Complete', Icons.done_all),
                ],
              ),
            );
          }

          // Step renders
          Widget renderStepContent() {
            switch (activeStep) {
              case 0: // Step 1: Consultation Entry
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient Intake Vitals',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (app.reasonForVisit != null &&
                              app.reasonForVisit!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.notes,
                                  size: 14,
                                  color: Colors.blueGrey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Complaint: ${app.reasonForVisit}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDialogVitalBadge(
                                Icons.speed,
                                'BP',
                                '${app.bloodPressureSystolic ?? "--"}/${app.bloodPressureDiastolic ?? "--"} mmHg',
                                Colors.blue.shade700,
                              ),
                              _buildDialogVitalBadge(
                                Icons.thermostat_outlined,
                                'Temp',
                                '${app.temperature ?? "--"} °F',
                                Colors.orange.shade700,
                              ),
                              _buildDialogVitalBadge(
                                Icons.bloodtype_outlined,
                                'Sugar',
                                '${app.sugarLevel ?? "--"} mg/dL',
                                Colors.red.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Subjective Symptoms & History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: symptomsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Describe clinical history, symptoms reported by patient...',
                        prefixIcon: const Icon(Icons.psychology_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );

              case 1: // Step 2: Diagnosis Recorded
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinical Diagnosis (Mandatory)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: diagnosisController,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Acute Pharyngitis, Type 2 Diabetes Mellitus',
                        prefixIcon: const Icon(
                          Icons.health_and_safety_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: recommendAdmission
                            ? Colors.red.shade50.withOpacity(0.4)
                            : Colors.grey.shade50,
                        border: Border.all(
                          color: recommendAdmission
                              ? Colors.red.shade200
                              : Colors.grey.shade200,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bed_outlined,
                                color: recommendAdmission
                                    ? Colors.red.shade800
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recommend IPD Admission',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Mark patient for clinical handover to Inpatient Department',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: recommendAdmission,
                                activeColor: Colors.red.shade700,
                                onChanged: (val) {
                                  setDialogState(() {
                                    recommendAdmission = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (recommendAdmission) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: reasonForAdmissionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Reason for Admission',
                                hintText:
                                    'e.g. Severe respiratory distress requiring supplemental oxygen & constant monitoring',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Clinical Recommendations & Advice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Enter clinical observations, advice, or review notes...',
                        prefixIcon: const Icon(Icons.comment_bank_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );

              case 2: // Step 3: Prescription Generated
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.medication,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Add New Medication',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: drugNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Drug Name',
                                    hintText: 'Paracetamol',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: dosageController,
                                  decoration: InputDecoration(
                                    labelText: 'Dosage',
                                    hintText: '500 mg',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CustomDropdownSearch(
                                  label: 'Frequency',
                                  value: selectedFrequency,
                                  dropdownItems: const [
                                    '1-0-1',
                                    '1-0-0',
                                    '0-0-1',
                                    '1-1-1',
                                    'Once daily',
                                    'Twice daily',
                                    'Thrice daily',
                                    'As needed (PRN)',
                                  ],
                                  onChanged: (v) {
                                    if (v != null)
                                      setDialogState(
                                        () => selectedFrequency = v,
                                      );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: durationController,
                                  decoration: InputDecoration(
                                    labelText: 'Duration',
                                    hintText: '5 days',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  if (drugNameController.text.trim().isEmpty)
                                    return;
                                  setDialogState(() {
                                    medicationsList.add({
                                      'name': drugNameController.text.trim(),
                                      'dosage': dosageController.text.trim(),
                                      'frequency': selectedFrequency,
                                      'duration': durationController.text
                                          .trim(),
                                    });
                                    drugNameController.clear();
                                    dosageController.clear();
                                    durationController.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Prescribed Medications List:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: medicationsList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medication_outlined,
                                    size: 28,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No medications prescribed yet.',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: medicationsList.length,
                                itemBuilder: (c, idx) {
                                  final m = medicationsList[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.01),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.medication,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppTheme.textPrimaryColor,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${m['dosage']} | ${m['frequency']} | ${m['duration']}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme
                                                      .textSecondaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            setDialogState(
                                              () =>
                                                  medicationsList.removeAt(idx),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );

              case 3: // Step 4: Lab Tests Ordered
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Standard Investigations:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Scrollbar(
                        child: ListView(
                          children: standardLabs.keys.map((test) {
                            return CheckboxListTile(
                              title: Text(
                                test,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              value: standardLabs[test],
                              dense: true,
                              activeColor: AppTheme.primaryColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() => standardLabs[test] = v);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: customLabController,
                            decoration: InputDecoration(
                              labelText: 'Other Custom Lab Test',
                              hintText: 'e.g. Vitamin D3',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (customLabController.text.trim().isEmpty) return;
                            setDialogState(() {
                              customLabsList.add(
                                customLabController.text.trim(),
                              );
                              customLabController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (customLabsList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: customLabsList.map((l) {
                          return Chip(
                            label: Text(
                              l,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            backgroundColor: AppTheme.primaryLight,
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 12,
                              color: AppTheme.primaryColor,
                            ),
                            onDeleted: () {
                              setDialogState(() => customLabsList.remove(l));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );

              case 4: // Step 5: Pharmacy Notified
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to Complete Consultation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'This will save the clinical logs, record the diagnosis, order lab tests, and dispatch prescriptions to the pharmacy dispensing dashboard automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.local_pharmacy_outlined,
                                color: Color(0xFF065F46),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                medicationsList.isEmpty
                                    ? 'No Medications Prescribed'
                                    : 'Prescription Status: Ready to Dispatch',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                          standardLabs.values.contains(true) ||
                                  customLabsList.isNotEmpty
                              ? const Divider(
                                  color: Color(0xFFA7F3D0),
                                  height: 20,
                                )
                              : const SizedBox.shrink(),
                          if (standardLabs.values.contains(true) ||
                              customLabsList.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  color: Color(0xFF065F46),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Lab Orders: Ready to Order',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );

              default:
                return const SizedBox.shrink();
            }
          }

          // Gather final list of lab tests
          List<String> getFinalOrderedLabs() {
            final List<String> result = [];
            standardLabs.forEach((key, val) {
              if (val) result.add(key);
            });
            result.addAll(customLabsList);
            return result;
          }

          final screenWidth = MediaQuery.of(ctx).size.width;
          final screenHeight = MediaQuery.of(ctx).size.height;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 10,
            child: Container(
              width: screenWidth < 620 ? screenWidth * 0.95 : 580,
              height: screenHeight < 620 ? screenHeight * 0.95 : 580,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, Color(0xFF0F766E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.healing_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Clinical Consultation Findings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Patient: ${app.patientName} (${app.patientDisplayId ?? "No ID"})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Progress Header
                  buildProgressHeader(),

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: renderStepContent(),
                    ),
                  ),

                  // Footer/Actions Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (activeStep > 0) ...[
                          OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () => setDialogState(() => activeStep--),
                            icon: const Icon(Icons.arrow_back, size: 14),
                            label: const Text('Back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondaryColor,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (activeStep == 0) ...[
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondaryColor,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (activeStep < 4) {
                                    // Validation for Step 2
                                    if (activeStep == 1 &&
                                        diagnosisController.text
                                            .trim()
                                            .isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enter a diagnosis to proceed.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => activeStep++);
                                  } else {
                                    // Complete consultation action
                                    setDialogState(() => isSaving = true);
                                    try {
                                      final finalLabs = getFinalOrderedLabs();
                                      final consultationData = {
                                        'appointment_id': app.id,
                                        'patient_id': app.patientId,
                                        'symptoms': symptomsController.text
                                            .trim(),
                                        'diagnosis': diagnosisController.text
                                            .trim(),
                                        'notes': notesController.text.trim(),
                                        'medications': medicationsList,
                                        'lab_tests': finalLabs,
                                        'pharmacy_status':
                                            medicationsList.isNotEmpty
                                            ? 'Notified'
                                            : 'Pending',
                                        'recommend_admission':
                                            recommendAdmission,
                                        'reason_for_admission':
                                            reasonForAdmissionController.text
                                                .trim(),
                                      };

                                      await _appointmentController
                                          .saveConsultation(consultationData);
                                      await _appointmentController.updateStatus(
                                        app.id!,
                                        'Completed',
                                      );
                                      Navigator.pop(ctx);
                                      _loadData();
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Consultation completed successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted)
                                        setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox.shrink()
                              : Icon(
                                  activeStep == 4
                                      ? Icons.check
                                      : Icons.arrow_forward,
                                  size: 14,
                                ),
                          label: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  activeStep == 4
                                      ? 'Complete Consultation'
                                      : 'Next',
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrescriptionsTab() {
    final prescriptions = _consultations.where((c) {
      final medsRaw = c['medications'];
      List<dynamic> meds = [];
      if (medsRaw is List) {
        meds = medsRaw;
      } else if (medsRaw is String) {
        try {
          final decoded = jsonDecode(medsRaw);
          if (decoded is List) meds = decoded;
        } catch (_) {}
      }
      return meds.isNotEmpty;
    }).toList();

    if (prescriptions.isEmpty) {
      return const Center(
        child: Text(
          'No prescriptions generated today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final c = prescriptions[index];
        final medsRaw = c['medications'];
        List<dynamic> meds = [];
        if (medsRaw is List) {
          meds = medsRaw;
        } else if (medsRaw is String) {
          try {
            final decoded = jsonDecode(medsRaw);
            if (decoded is List) meds = decoded;
          } catch (_) {}
        }
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['patient_name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(
                        DateTime.parse(
                          c['created_at'] ?? DateTime.now().toString(),
                        ),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 24),
                const Text(
                  'Prescribed Medications:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Column(
                  children: meds.map<Widget>((m) {
                    String display = m.toString();
                    if (m is Map) {
                      display =
                          '${m['name']} - ${m['dosage']} (${m['frequency']})';
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.medication,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              display,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabTestsTab() {
    final labOrders = _consultations.where((c) {
      final labsRaw = c['lab_tests'];
      List<dynamic> labs = [];
      if (labsRaw is List) {
        labs = labsRaw;
      } else if (labsRaw is String) {
        try {
          final decoded = jsonDecode(labsRaw);
          if (decoded is List) labs = decoded;
        } catch (_) {}
      }
      return labs.isNotEmpty;
    }).toList();

    if (labOrders.isEmpty) {
      return const Center(
        child: Text(
          'No lab tests ordered today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: labOrders.length,
      itemBuilder: (context, index) {
        final c = labOrders[index];
        final labsRaw = c['lab_tests'];
        List<dynamic> labs = [];
        if (labsRaw is List) {
          labs = labsRaw;
        } else if (labsRaw is String) {
          try {
            final decoded = jsonDecode(labsRaw);
            if (decoded is List) labs = decoded;
          } catch (_) {}
        }
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['patient_name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(
                        DateTime.parse(
                          c['created_at'] ?? DateTime.now().toString(),
                        ),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 24),
                const Text(
                  'Ordered Tests:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: labs.map<Widget>((l) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade100),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 12,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPharmacyTab() {
    final pharmacyNotifications = _consultations.where((c) {
      final status = c['pharmacy_status']?.toString();
      if (status == null || status.isEmpty) return false;
      final medsRaw = c['medications'];
      List<dynamic> meds = [];
      if (medsRaw is List) {
        meds = medsRaw;
      } else if (medsRaw is String) {
        try {
          final decoded = jsonDecode(medsRaw);
          if (decoded is List) meds = decoded;
        } catch (_) {}
      }
      return meds.isNotEmpty;
    }).toList();

    if (pharmacyNotifications.isEmpty) {
      return const Center(
        child: Text(
          'No pharmacy notifications today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: pharmacyNotifications.length,
      itemBuilder: (context, index) {
        final c = pharmacyNotifications[index];
        final medsRaw = c['medications'];
        List<dynamic> meds = [];
        if (medsRaw is List) {
          meds = medsRaw;
        } else if (medsRaw is String) {
          try {
            final decoded = jsonDecode(medsRaw);
            if (decoded is List) meds = decoded;
          } catch (_) {}
        }
        final status = c['pharmacy_status']?.toString() ?? 'Pending';
        final isDispensed = status == 'Dispensed';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['patient_name'] ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    _buildPharmacyStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 24),
                const Text(
                  'Medications:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Column(
                  children: meds.map<Widget>((m) {
                    String display = m.toString();
                    if (m is Map) {
                      display =
                          '${m['name']} - ${m['dosage']} (${m['frequency']})';
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.medication,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              display,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (!isDispensed) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _appointmentController
                                .updateConsultation(c['id'], {
                                  'symptoms': c['symptoms'],
                                  'diagnosis': c['diagnosis'],
                                  'medications': c['medications'],
                                  'notes': c['notes'],
                                  'lab_tests': c['lab_tests'],
                                  'pharmacy_status': 'Dispensed',
                                });
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Medications dispensed successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error dispensing: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Dispense Medications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5A8E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
