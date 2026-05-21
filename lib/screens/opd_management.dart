import 'package:flutter/material.dart';
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

class OPDManagementScreen extends StatefulWidget {
  final bool isMobile;
  const OPDManagementScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<OPDManagementScreen> createState() => _OPDManagementScreenState();
}

class _OPDManagementScreenState extends State<OPDManagementScreen> with SingleTickerProviderStateMixin {
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

  List<UserModel> _doctors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
    _loadDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        status: null, // Fetch all to filter locally by tabs
        doctor: _selectedDoctor == 'All' ? null : _selectedDoctor,
      );
      final consultationsData = await _appointmentController.fetchConsultations();
      if (mounted) {
        setState(() {
          _appointments = data;
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
      if (mounted) {
        staff.sort((a, b) => a.fullname.compareTo(b.fullname));
        setState(() {
          _doctors = staff;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    List<AppointmentModel> apps = List.from(_appointments);

    // 1. Search Query Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((a) {
        return a.patientName.toLowerCase().contains(query) ||
            (a.patientDisplayId?.toLowerCase().contains(query) ?? false) ||
            (a.patientPhone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 2. Sort Chronologically by Time
    apps.sort((a, b) {
      try {
        final timeA = DateFormat('hh:mm a').parse(a.appointmentTime);
        final timeB = DateFormat('hh:mm a').parse(b.appointmentTime);
        return timeA.compareTo(timeB);
      } catch (e) {
        return 0;
      }
    });

    return apps;
  }

  List<AppointmentModel> _getTabAppointments(int tabIndex) {
    final baseApps = _filteredAppointments;
    switch (tabIndex) {
      case 0: // Waiting (Confirmed / Checked-in / Waiting)
        return baseApps.where((a) => a.status == 'Confirmed' || a.status == 'Checked-in' || a.status == 'Waiting').toList();
      case 1: // In Consultation
        return baseApps.where((a) => a.status == 'In Consultation').toList();
      case 2: // Completed
        return baseApps.where((a) => a.status == 'Completed').toList();
      case 3: // Cancelled & No-Show
        return baseApps.where((a) => a.status == 'Cancelled' || a.status == 'No-Show').toList();
      default:
        return [];
    }
  }

  int _getCountForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _appointments.where((a) => a.status == 'Confirmed' || a.status == 'Checked-in' || a.status == 'Waiting').length;
      case 1:
        return _appointments.where((a) => a.status == 'In Consultation').length;
      case 2:
        return _appointments.where((a) => a.status == 'Completed').length;
      case 3:
        return _appointments.where((a) => a.status == 'Cancelled' || a.status == 'No-Show').length;
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
    return Container(
      margin: EdgeInsets.fromLTRB(widget.isMobile ? 16 : 24, 24, widget.isMobile ? 16 : 24, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.85)],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'OPD Queue Management',
                      style: TextStyle(
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
          ElevatedButton.icon(
            onPressed: () => _showWalkInDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(widget.isMobile ? 'Walk-in' : 'New Walk-in Entry', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 3,
              shadowColor: Colors.black26,
              minimumSize: const Size(120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      height: 90,
      margin: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            title: 'Total OPD Today',
            count: _appointments.length,
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
          Expanded(
            child: _buildSearchBar(),
          ),
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
          const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search patient name, ID, or phone...',
                hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
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
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: EdgeInsets.only(left: widget.isMobile ? 16 : 24, right: widget.isMobile ? 16 : 24, top: 12),
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
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
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
            Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppTheme.textMutedColor.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text(
              'No patients in this state currently.',
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
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
    final bool isTriaged = app.status == 'Checked-in' || app.status == 'Waiting';
    
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
            border: Border(
              left: BorderSide(color: statusColor, width: 6),
            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              app.appointmentTime,
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
                          app.patientName.isNotEmpty ? app.patientName[0].toUpperCase() : 'P',
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 14, color: AppTheme.textSecondaryColor),
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
                              const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textMutedColor),
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

                  // Triage / Vitals Pill Summary
                  if (tabIndex == 0)
                    _buildTriageBadge(isTriaged)
                  else
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
                        if (app.bloodPressureSystolic != null || app.temperature != null || app.sugarLevel != null) ...[
                          const Text(
                            'Patient Vitals:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
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
                        if (app.reasonForVisit != null && app.reasonForVisit!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
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
                        label: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showOverrideDialog(app),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Override Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                          foregroundColor: Colors.orange.shade800,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
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
    final label = (status == 'Checked-in' || status == 'Confirmed') ? 'Waiting' : status;

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
          Text(_error ?? 'An error occurred', style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
            _appointmentController.fetchConsultationsByPatient(app.patientId).then((consuls) {
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
            }).catchError((e) {
              if (mounted) {
                setDialogState(() {
                  isLoadingConsul = false;
                });
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: SizedBox(
              width: 800,
              height: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium Card Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                              child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.patientName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${app.patientDisplayId ?? 'N/A'} • Contact: ${app.patientPhone ?? 'N/A'}',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
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
                                const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      _detailItem('Assigned Doctor', app.doctorName),
                                      _detailItem('Department', app.department),
                                      _detailItem('Date / Time', '${app.appointmentDate} • ${app.appointmentTime}'),
                                      _detailItem('Session Status', app.status == 'Checked-in' ? 'Waiting' : app.status),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Vitals Card
                                if (app.bloodPressureSystolic != null || app.temperature != null || app.sugarLevel != null) ...[
                                  const Text('Patient Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
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
                                      if (app.bloodPressureSystolic != null && (app.temperature != null || app.sugarLevel != null))
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
                                      if (app.temperature != null && app.sugarLevel != null)
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

                                if (app.reasonForVisit != null && app.reasonForVisit!.isNotEmpty) ...[
                                  const Text('Reason for Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      border: Border.all(color: Colors.amber.shade100),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      app.reasonForVisit!,
                                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Vertical Divider
                          Container(width: 1, height: 480, color: Colors.grey.shade200),
                          const SizedBox(width: 24),

                          // Right Column: Clinical Consult findings / Status Timeline Log
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (app.status == 'Completed') ...[
                                  const Text('Clinical Consultation Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                  const SizedBox(height: 12),
                                  if (isLoadingConsul)
                                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                                  else if (consultation == null)
                                    const Text('No consultation details recorded yet.', style: TextStyle(fontSize: 13, color: Colors.grey))
                                  else ...[
                                    _buildConsultationSummary(consultation!),
                                  ],
                                  const SizedBox(height: 24),
                                ],

                                const Text('Status Timeline Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: app.changesLog != null
                                      ? _buildTimeline(app.changesLog)
                                      : const Text('No status changes recorded yet.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
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
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5A8E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildVitalPillCard(String label, String value, String unit, IconData icon, Color color) {
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
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(unit, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildConsultationSummary(Map<String, dynamic> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c['symptoms'] != null && c['symptoms'].toString().isNotEmpty) ...[
          const Text('Subjective Symptoms:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(c['symptoms'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['diagnosis'] != null && c['diagnosis'].toString().isNotEmpty) ...[
          const Text('Diagnosis / Impression:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(c['diagnosis'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['notes'] != null && c['notes'].toString().isNotEmpty) ...[
          const Text('Doctor\'s Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(c['notes'].toString(), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        if (c['medications'] != null) ...[
          const Text('Prescribed Medications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          _buildMedicationList(c['medications']),
        ],
        if (c['lab_tests'] != null) ...[
          const SizedBox(height: 8),
          const Text('Ordered Lab Tests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          _buildLabTestsList(c['lab_tests']),
        ],
        if (c['pharmacy_status'] != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Pharmacy Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
      return const Text('No lab tests ordered.', style: TextStyle(fontSize: 13, color: Colors.grey));
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
              Icon(Icons.science_outlined, size: 12, color: Colors.blue.shade800),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
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
      return const Text('No medications prescribed.', style: TextStyle(fontSize: 13, color: Colors.grey));
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
              const Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
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
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
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
          final from = change['status']['from'] == 'Checked-in' ? 'Waiting' : change['status']['from'];
          final to = change['status']['to'] == 'Checked-in' ? 'Waiting' : change['status']['to'];
          text = 'Status: $from → $to';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppTheme.primaryColor),
                  Container(width: 2, height: 20, color: AppTheme.borderColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dt != null)
                      Text(DateFormat('dd MMM, hh:mm a').format(dt.toLocal()), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
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
    final overrideStatuses = ['Confirmed', 'Checked-in', 'In Consultation', 'Completed', 'Cancelled', 'No-Show'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Admin Status Override', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: overrideStatuses.contains(newStatus) ? newStatus : overrideStatuses[0],
                decoration: const InputDecoration(labelText: 'New Status'),
                items: overrideStatuses.map((s) {
                  String display = s;
                  if (s == 'Confirmed') display = 'Waiting (Not Triaged)';
                  if (s == 'Checked-in') display = 'Waiting (Triage Complete)';
                  return DropdownMenuItem(value: s, child: Text(display));
                }).toList(),
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
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
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      } finally {
                        if (mounted) setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkInDialog() {
    PatientModel? selectedPatient;
    UserModel? selectedDoctor;
    String time = DateFormat('hh:mm a').format(DateTime.now());
    bool isSaving = false;
    bool isLoadingPatients = false;
    List<PatientModel> allPatients = [];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (allPatients.isEmpty && !isLoadingPatients) {
            setDialogState(() => isLoadingPatients = true);
            _patientController.fetchPatients().then((p) {
              if (mounted) {
                setDialogState(() {
                  allPatients = p;
                  isLoadingPatients = false;
                });
              }
            }).catchError((e) {
              if (mounted) setDialogState(() => isLoadingPatients = false);
            });
          }

          return AlertDialog(
            title: const Text('Quick Walk-in Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoadingPatients)
                        const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                      else
                        DropdownButtonFormField<PatientModel>(
                          value: selectedPatient,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Patient', prefixIcon: Icon(Icons.person_outline)),
                          items: allPatients.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.patientId ?? "N/A"})', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setDialogState(() => selectedPatient = val),
                          validator: (val) => val == null ? 'Please select patient' : null,
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserModel>(
                        value: selectedDoctor,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Assign Doctor', prefixIcon: Icon(Icons.medical_services_outlined)),
                        items: _doctors.map((d) => DropdownMenuItem(value: d, child: Text(d.fullname, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setDialogState(() => selectedDoctor = val),
                        validator: (val) => val == null ? 'Please select doctor' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (pickedTime != null) {
                            final now = DateTime.now();
                            final dt = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
                            setDialogState(() => time = DateFormat('hh:mm a').format(dt));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Text(time, style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
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
                        setDialogState(() => isSaving = true);
                        try {
                          final newApp = AppointmentModel(
                            patientId: selectedPatient!.id!,
                            patientName: selectedPatient!.name,
                            department: selectedDoctor!.specialization ?? 'General',
                            doctorName: selectedDoctor!.fullname,
                            appointmentDate: DateFormatter.toUi(DateTime.now()),
                            appointmentTime: time,
                            status: 'Confirmed', // Walk-ins go into queue in Confirmed state to be triaged
                            appointmentType: 'Walk-in',
                          );
                          await _appointmentController.bookAppointment(newApp);
                          Navigator.pop(ctx);
                          _loadData();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Walk-in registered successfully'), backgroundColor: Colors.green));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'),
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

          Widget _buildDialogVitalBadge(IconData icon, String label, String value, Color color) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
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
                      color: isActive ? stepColor.withOpacity(0.12) : Colors.transparent,
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
                      color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
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
                  buildStepIndicator(1, 'Diagnosis', Icons.health_and_safety_outlined),
                  _buildLine(),
                  buildStepIndicator(2, 'Prescriptions', Icons.medication_outlined),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
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
                          if (app.reasonForVisit != null && app.reasonForVisit!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.notes, size: 14, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Complaint: ${app.reasonForVisit}',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDialogVitalBadge(Icons.speed, 'BP', '${app.bloodPressureSystolic ?? "--"}/${app.bloodPressureDiastolic ?? "--"} mmHg', Colors.blue.shade700),
                              _buildDialogVitalBadge(Icons.thermostat_outlined, 'Temp', '${app.temperature ?? "--"} °F', Colors.orange.shade700),
                              _buildDialogVitalBadge(Icons.bloodtype_outlined, 'Sugar', '${app.sugarLevel ?? "--"} mg/dL', Colors.red.shade700),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Subjective Symptoms & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: symptomsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe clinical history, symptoms reported by patient...',
                        prefixIcon: const Icon(Icons.psychology_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                );

              case 1: // Step 2: Diagnosis Recorded
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clinical Diagnosis (Mandatory)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: diagnosisController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Acute Pharyngitis, Type 2 Diabetes Mellitus',
                        prefixIcon: const Icon(Icons.health_and_safety_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: recommendAdmission ? Colors.red.shade50.withOpacity(0.4) : Colors.grey.shade50,
                        border: Border.all(color: recommendAdmission ? Colors.red.shade200 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bed_outlined, color: recommendAdmission ? Colors.red.shade800 : Colors.grey.shade600, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recommend IPD Admission',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                                    ),
                                    Text(
                                      'Mark patient for clinical handover to Inpatient Department',
                                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor),
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
                                hintText: 'e.g. Severe respiratory distress requiring supplemental oxygen & constant monitoring',
                                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Clinical Recommendations & Advice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter clinical observations, advice, or review notes...',
                        prefixIcon: const Icon(Icons.comment_bank_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
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
                              const Icon(Icons.medication, color: AppTheme.primaryColor, size: 18),
                              const SizedBox(width: 8),
                              const Text('Add New Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedFrequency,
                                  decoration: InputDecoration(
                                    labelText: 'Frequency',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: ['1-0-1', '1-0-0', '0-0-1', '1-1-1', 'Once daily', 'Twice daily', 'Thrice daily', 'As needed (PRN)']
                                      .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setDialogState(() => selectedFrequency = v);
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
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  if (drugNameController.text.trim().isEmpty) return;
                                  setDialogState(() {
                                    medicationsList.add({
                                      'name': drugNameController.text.trim(),
                                      'dosage': dosageController.text.trim(),
                                      'frequency': selectedFrequency,
                                      'duration': durationController.text.trim(),
                                    });
                                    drugNameController.clear();
                                    dosageController.clear();
                                    durationController.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Prescribed Medications List:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
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
                                  Icon(Icons.medication_outlined, size: 28, color: Colors.grey.shade300),
                                  const SizedBox(height: 6),
                                  Text('No medications prescribed yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['name'] ?? '',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${m['dosage']} | ${m['frequency']} | ${m['duration']}',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          onPressed: () {
                                            setDialogState(() => medicationsList.removeAt(idx));
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
                    const Text('Select Standard Investigations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor)),
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
                              title: Text(test, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              value: standardLabs[test],
                              dense: true,
                              activeColor: AppTheme.primaryColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (customLabController.text.trim().isEmpty) return;
                            setDialogState(() {
                              customLabsList.add(customLabController.text.trim());
                              customLabController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            label: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            backgroundColor: AppTheme.primaryLight,
                            deleteIcon: const Icon(Icons.close, size: 12, color: AppTheme.primaryColor),
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
                      child: const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF0D9488)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to Complete Consultation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D9488)),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'This will save the clinical logs, record the diagnosis, order lab tests, and dispatch prescriptions to the pharmacy dispensing dashboard automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, height: 1.4),
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
                              const Icon(Icons.local_pharmacy_outlined, color: Color(0xFF065F46), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                medicationsList.isEmpty
                                    ? 'No Medications Prescribed'
                                    : 'Prescription Status: Ready to Dispatch',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                          standardLabs.values.contains(true) || customLabsList.isNotEmpty ? const Divider(color: Color(0xFFA7F3D0), height: 20) : const SizedBox.shrink(),
                          if (standardLabs.values.contains(true) || customLabsList.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.science_outlined, color: Color(0xFF065F46), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Lab Orders: Ready to Order',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
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

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 10,
            child: Container(
              width: 580,
              height: 580,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        const Icon(Icons.healing_outlined, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Clinical Consultation Findings',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Patient: ${app.patientName} (${app.patientDisplayId ?? "No ID"})',
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                            onPressed: isSaving ? null : () => setDialogState(() => activeStep--),
                            icon: const Icon(Icons.arrow_back, size: 14),
                            label: const Text('Back'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondaryColor,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    if (activeStep == 1 && diagnosisController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a diagnosis to proceed.')),
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
                                        'symptoms': symptomsController.text.trim(),
                                        'diagnosis': diagnosisController.text.trim(),
                                        'notes': notesController.text.trim(),
                                        'medications': medicationsList,
                                        'lab_tests': finalLabs,
                                        'pharmacy_status': medicationsList.isNotEmpty ? 'Notified' : 'Pending',
                                        'recommend_admission': recommendAdmission,
                                        'reason_for_admission': reasonForAdmissionController.text.trim(),
                                      };

                                      await _appointmentController.saveConsultation(consultationData);
                                      Navigator.pop(ctx);
                                      _loadData();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Consultation completed successfully!'), backgroundColor: Colors.green),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox.shrink()
                              : Icon(activeStep == 4 ? Icons.check : Icons.arrow_forward, size: 14),
                          label: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(activeStep == 4 ? 'Complete Consultation' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        child: Text('No prescriptions generated today.', style: TextStyle(color: Colors.grey)),
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
                    Text(c['patient_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(c['created_at'] ?? DateTime.now().toString())), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Divider(height: 24),
                const Text('Prescribed Medications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Column(
                  children: meds.map<Widget>((m) {
                    String display = m.toString();
                    if (m is Map) {
                      display = '${m['name']} - ${m['dosage']} (${m['frequency']})';
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
                          const Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(display, style: const TextStyle(fontSize: 12))),
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
        child: Text('No lab tests ordered today.', style: TextStyle(color: Colors.grey)),
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
                    Text(c['patient_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(c['created_at'] ?? DateTime.now().toString())), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Divider(height: 24),
                const Text('Ordered Tests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: labs.map<Widget>((l) {
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
                          Icon(Icons.science_outlined, size: 12, color: Colors.blue.shade800),
                          const SizedBox(width: 4),
                          Text(
                            l.toString(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
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
        child: Text('No pharmacy notifications today.', style: TextStyle(color: Colors.grey)),
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
                    Text(c['patient_name'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    _buildPharmacyStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ID: ${c['patient_display_id'] ?? 'N/A'} • Doctor: ${c['doctor_name'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const Divider(height: 24),
                const Text('Medications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Column(
                  children: meds.map<Widget>((m) {
                    String display = m.toString();
                    if (m is Map) {
                      display = '${m['name']} - ${m['dosage']} (${m['frequency']})';
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
                          const Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(display, style: const TextStyle(fontSize: 12))),
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
                            await _appointmentController.updateConsultation(c['id'], {
                              'symptoms': c['symptoms'],
                              'diagnosis': c['diagnosis'],
                              'medications': c['medications'],
                              'notes': c['notes'],
                              'lab_tests': c['lab_tests'],
                              'pharmacy_status': 'Dispensed',
                            });
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Medications dispensed successfully!'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error dispensing: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Dispense Medications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5A8E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

