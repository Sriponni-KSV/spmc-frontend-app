import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/appointment_controller.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/access_denied_widget.dart';
import '../models/appointment_model.dart';
import 'new_consultation.dart';
import '../utils/date_formatter.dart';

class PatientsView extends StatefulWidget {
  final List<PatientModel> patients;
  final bool isLoading;
  final String? error;
  final VoidCallback onRegisterPatient;
  final Function(PatientModel) onCompleteProfile;
  final VoidCallback onBookAppointment;
  final VoidCallback? onRefresh;

  const PatientsView({
    Key? key,
    required this.patients,
    required this.isLoading,
    this.error,
    required this.onRegisterPatient,
    required this.onCompleteProfile,
    required this.onBookAppointment,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<PatientsView> createState() => _PatientsViewState();
}

class _PatientsViewState extends State<PatientsView> {
  String _searchQuery = '';
  PatientModel? _selectedPatient;
  bool _isFilterVisible = false;

  // Filter values
  String _selectedAgeRange = 'All Ages';
  String _selectedGender = 'All Genders';
  String _selectedLastVisit = 'Any Time';
  String _selectedStatus = 'All Status';

  List<String> _departments = [];
  bool _isLoadingDepartments = true;
  final AdminController _adminController = AdminController();

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final specializations = await _adminController.fetchSpecializations();
      if (mounted) {
        setState(() {
          _departments = specializations
              .map((e) => e['name'].toString())
              .toList();
          _isLoadingDepartments = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments in patients_view: $e');
      if (mounted) {
        setState(() {
          _departments = [
            'General Medicine',
            'Cardiology',
            'Pediatrics',
            'Orthopedics',
          ];
          _isLoadingDepartments = false;
        });
      }
    }
  }

  List<PatientModel> get _filteredPatients {
    List<PatientModel> filtered = widget.patients;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.phone.toLowerCase().contains(q) ||
            p.department.toLowerCase().contains(q);
      }).toList();
    }

    // Age Range filter
    if (_selectedAgeRange != 'All Ages') {
      filtered = filtered.where((p) {
        if (_selectedAgeRange == 'Under 18') return p.age < 18;
        if (_selectedAgeRange == '18-35') return p.age >= 18 && p.age <= 35;
        if (_selectedAgeRange == '36-60') return p.age >= 36 && p.age <= 60;
        if (_selectedAgeRange == 'Over 60') return p.age > 60;
        return true;
      }).toList();
    }

    // Gender filter
    if (_selectedGender != 'All Genders') {
      filtered = filtered
          .where((p) => p.gender.toLowerCase() == _selectedGender.toLowerCase())
          .toList();
    }

    // Status filter
    if (_selectedStatus != 'All Status') {
      if (_selectedStatus == 'Active') {
        // Assuming all currently fetched patients are active for now
        return filtered;
      } else if (_selectedStatus == 'Inactive') {
        return []; // No inactive patients in the current dataset
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Show patient detail when a patient is selected
    if (_selectedPatient != null) {
      return PatientDetailView(
        patient: _selectedPatient!,
        onBack: () => setState(() => _selectedPatient = null),
        onCompleteProfile: widget.onCompleteProfile,
      );
    }

    final Size screenSize = MediaQuery.of(context).size;
    final bool isMobile = screenSize.width < 850;
    final bool isSmallMobile = screenSize.width < 400;
    final bool isTablet = screenSize.width >= 850 && screenSize.width < 1200;

    EdgeInsets padding;
    if (isMobile) {
      padding = EdgeInsets.all(isSmallMobile ? 10.0 : 12.0);
    } else if (isTablet) {
      padding = const EdgeInsets.all(16.0);
    } else {
      padding = const EdgeInsets.all(24.0);
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final bool hideRecentAndQuick = [
      'Admin',
      'Super Admin',
    ].contains(user?.role);

    if (widget.error == 'Exception: Access Denied' ||
        (user != null && !user.hasPermission('view_patients'))) {
      return const AccessDeniedWidget(
        message:
            'Access Denied: You do not have permission to view patient records.',
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientsHeader(isMobile, isTablet),
            const SizedBox(height: 16),
            _buildPatientsSearch(isMobile, isTablet),
            if (_isFilterVisible) ...[
              const SizedBox(height: 16),
              _buildFilterPanel(isMobile, isTablet),
            ],
            if (!hideRecentAndQuick) ...[
              const SizedBox(height: 24),
              _buildRecentPatientsHeader(isMobile),
              const SizedBox(height: 12),
              _buildRecentPatientsRow(isMobile, isTablet),
            ],
            const SizedBox(height: 24),
            _buildTableHeading(isMobile),
            const SizedBox(height: 12),
            _buildPatientsTable(isMobile, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPatientsHeader(bool isMobile) {
    return Text(
      'Recent Patients',
      style: TextStyle(
        fontSize: isMobile ? 18 : 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildTableHeading(bool isMobile) {
    return Text(
      'Patient Records',
      style: TextStyle(
        fontSize: isMobile ? 18 : 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildPatientsHeader(bool isMobile, bool isTablet) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final double fontSize = isMobile ? 20 : (isTablet ? 24 : 28);
    final double subtitleSize = isMobile ? 11 : (isTablet ? 12 : 14);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patients',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Manage patient records and hospital information',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (user?.hasPermission('add_patient') ?? false)
            ElevatedButton.icon(
              onPressed: widget.onRegisterPatient,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'New Patient Registration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patients',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Manage patient records and information',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: subtitleSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (user?.hasPermission('add_patient') ?? false)
          ElevatedButton.icon(
            onPressed: widget.onRegisterPatient,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              minimumSize: Size(isTablet ? 100 : 120, 48),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPatientsSearch(bool isMobile, bool isTablet) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final bool hideRecentAndQuick = [
      'Admin',
      'Super Admin',
    ].contains(user?.role);
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search patients by name or phone...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!hideRecentAndQuick &&
                  (user?.hasPermission('add_patient') ?? false))
                SizedBox(
                  width: MediaQuery.of(context).size.width < 450
                      ? double.infinity
                      : (MediaQuery.of(context).size.width - 34) / 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _showQuickRegisterDialog(context),
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text(
                      'Quick Register',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5D9A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              SizedBox(
                width: MediaQuery.of(context).size.width < 450
                    ? double.infinity
                    : (MediaQuery.of(context).size.width - 34) / 2,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _isFilterVisible = !_isFilterVisible),
                  icon: Icon(
                    _isFilterVisible
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    size: 16,
                  ),
                  label: const Text('Filter', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.textPrimaryColor,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppTheme.textSecondaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText:
                                'Search by name, mobile number, department...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!hideRecentAndQuick &&
                  (user?.hasPermission('add_patient') ?? false))
                ElevatedButton.icon(
                  onPressed: () => _showQuickRegisterDialog(context),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text(
                    'Quick Register',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5D9A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(130, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _isFilterVisible = !_isFilterVisible),
                icon: Icon(
                  _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
                  size: 16,
                ),
                label: const Text('Filter', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textPrimaryColor,
                  minimumSize: const Size(100, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppTheme.textSecondaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText:
                          'Search by name, mobile number, or department...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (!hideRecentAndQuick &&
            (user?.hasPermission('add_patient') ?? false))
          ElevatedButton.icon(
            onPressed: () => _showQuickRegisterDialog(context),
            icon: const Icon(Icons.flash_on, size: 18),
            label: const Text(
              'Quick Register',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5D9A),
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isFilterVisible = !_isFilterVisible),
          icon: Icon(
            _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
            size: 18,
          ),
          label: const Text(
            'Filter',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textPrimaryColor,
            minimumSize: const Size(120, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPatientsRow(bool isMobile, bool isTablet) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.patients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('No recent patients found.'),
      );
    }

    final recentPatients = widget.patients.take(3).toList();
    List<Widget> cards = [];

    for (int i = 0; i < recentPatients.length; i++) {
      final patient = recentPatients[i];
      final String name = patient.name;
      final String age = patient.age.toString();
      final String gender = patient.gender;

      String initials = '?';
      if (name.trim().isNotEmpty) {
        final parts = name
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .toList();
        if (parts.isNotEmpty) {
          initials = parts.map((p) => p[0].toUpperCase()).join('');
        }
      }

      cards.add(
        isMobile
            ? SizedBox(
                width: 240,
                child: PatientInfoCard(
                  name: name,
                  info: '${age}y • $gender',
                  initials: initials,
                  tags: patient.isQuickRegister ? ['Quick'] : [],
                  onView: () => setState(() => _selectedPatient = patient),
                  onBook: widget.onBookAppointment,
                ),
              )
            : isTablet
            ? SizedBox(
                width: 280,
                child: PatientInfoCard(
                  name: name,
                  info: '${age}y • $gender',
                  initials: initials,
                  tags: patient.isQuickRegister ? ['Quick'] : [],
                  onView: () => setState(() => _selectedPatient = patient),
                  onBook: widget.onBookAppointment,
                ),
              )
            : PatientInfoCard(
                name: name,
                info: '${age}y • $gender',
                initials: initials,
                tags: patient.isQuickRegister ? ['Quick'] : [],
                onView: () => setState(() => _selectedPatient = patient),
                onBook: widget.onBookAppointment,
              ),
      );

      if (i < recentPatients.length - 1) {
        cards.add(SizedBox(width: isMobile ? 12 : 16));
      }
    }

    if (isMobile || isTablet) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(child: Row(children: cards)),
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards
            .map((c) => c is SizedBox ? c : Expanded(child: c))
            .toList(),
      ),
    );
  }

  Widget _buildPatientsTable(bool isMobile, bool isTablet) {
    final patients = _filteredPatients;

    if (isMobile || isTablet) {
      if (widget.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (patients.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('No patients found')),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: patients.length,
        separatorBuilder: (_, __) => SizedBox(height: isMobile ? 10 : 12),
        itemBuilder: (context, index) {
          return _buildPatientCardMobile(patients[index]);
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFEDF2F7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildTableHeaderText('Patient ID')),
                Expanded(flex: 3, child: _buildTableHeaderText('Name')),
                Expanded(child: _buildTableHeaderText('Age')),
                if (!isMobile) Expanded(child: _buildTableHeaderText('Gender')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Mobile No')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Email')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Department')),
                Expanded(child: _buildTableHeaderText('Status')),
                Expanded(flex: 2, child: _buildTableHeaderText('Actions')),
              ],
            ),
          ),
          // Table Rows
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No patients found')),
            )
          else
            ...patients.map((patient) {
              final String name = patient.name;
              final parts = name
                  .trim()
                  .split(' ')
                  .where((p) => p.isNotEmpty)
                  .take(2)
                  .toList();
              final String initials = parts.isNotEmpty
                  ? parts.map((p) => p[0].toUpperCase()).join('')
                  : '?';

              return Column(
                children: [
                  _buildPatientTableRow(
                    patient,
                    name,
                    patient.age == 0 ? 'Not Provided' : '${patient.age}y',
                    patient.gender,
                    patient.phone,
                    patient.email,
                    patient.department,
                    'Active',
                    initials,
                    patient.isQuickRegister ? ['Quick'] : [],
                    isMobile,
                  ),

                  const Divider(height: 1),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildPatientCardMobile(PatientModel patient) {
    final String name = patient.name;
    final String ageStr = patient.age == 0 ? 'Not Prov.' : '${patient.age}y';
    final bool isQuick = patient.isQuickRegister;

    final parts = name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    final String initials = parts.isNotEmpty
        ? parts.map((p) => p[0].toUpperCase()).join('')
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPatient = patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isQuick
                        ? const Color(0xFFF3E8FF)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: isQuick
                            ? const Color(0xFF7C3AED)
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isQuick) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => widget.onCompleteProfile(patient),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7C3AED,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.edit_note,
                                        size: 14,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Complete Profile',
                                        style: TextStyle(
                                          color: Color(0xFF7C3AED),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$ageStr • ID: ${patient.id ?? "---"}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: 'Active'),
                  if (Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).user?.hasPermission('delete_patient') ??
                      false)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      padding: const EdgeInsets.only(left: 8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDeletePatientConfirmation(patient),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      patient.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      patient.department,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _selectedPatient = patient),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                      ),
                    ),
                  ),
                  if (!['Admin', 'Super Admin'].contains(
                    Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user?.role,
                  )) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onBookAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Book Appt.'),
                      ),
                    ),
                  ],
                  if (Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).user?.hasPermission('add_patient') ??
                      false) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onCompleteProfile(patient),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6AD55),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(isQuick ? 'Complete' : 'Edit'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color(0xFF4A5568),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPatientTableRow(
    PatientModel patient,
    String name,
    String age,
    String gender,
    String contact,
    String email,
    String department,
    String status,
    String initials,
    List<String> tags,
    bool isMobile,
  ) {
    bool isQuick = patient.isQuickRegister;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isQuick ? const Color(0xFFF9F5FF) : Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              patient.patientId ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isQuick
                      ? const Color(0xFF805AD5)
                      : const Color(0xFF0D5D9A),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isQuick
                                    ? const Color(0xFF553C9A)
                                    : const Color(0xFF2D3748),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: tags.map((t) {
                              if (isQuick && t == 'Quick') {
                                return InkWell(
                                  onTap: () =>
                                      widget.onCompleteProfile(patient),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF7C3AED,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.edit_note,
                                          size: 14,
                                          color: Color(0xFF7C3AED),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Complete Profile',
                                          style: TextStyle(
                                            color: Color(0xFF7C3AED),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return HealthTag(label: t);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              age,
              style: TextStyle(
                fontSize: 13,
                color: isQuick
                    ? const Color(0xFF553C9A)
                    : const Color(0xFF4A5568),
                fontWeight: isQuick ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (!isMobile)
            Expanded(
              child: Text(
                gender.isNotEmpty ? gender : 'Not Provided',
                style: TextStyle(
                  fontSize: 13,
                  color: isQuick
                      ? const Color(0xFF553C9A)
                      : const Color(0xFF4A5568),
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              contact.isNotEmpty ? contact : 'Not Provided',
              style: TextStyle(
                fontSize: 13,
                color: isQuick
                    ? const Color(0xFF553C9A)
                    : const Color(0xFF4A5568),
              ),
            ),
          ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                email.isNotEmpty ? email : 'Not Provided',
                style: TextStyle(
                  fontSize: 13,
                  color: isQuick
                      ? const Color(0xFF553C9A)
                      : const Color(0xFF4A5568),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                department.isNotEmpty ? department : 'Not Provided',
                style: TextStyle(
                  fontSize: 13,
                  color: isQuick
                      ? const Color(0xFF553C9A)
                      : const Color(0xFF4A5568),
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(status: status),
            ),
          ),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildActionLabel(
                  Icons.visibility_outlined,
                  'View',
                  isQuick ? const Color(0xFF805AD5) : const Color(0xFF3182CE),
                  onTap: () => setState(() => _selectedPatient = patient),
                ),
                if (!['Admin', 'Super Admin'].contains(
                  Provider.of<AuthProvider>(context, listen: false).user?.role,
                ))
                  _buildActionLabel(
                    Icons.calendar_month_outlined,
                    'Book',
                    const Color(0xFF38A169),
                    onTap: widget.onBookAppointment,
                  ),
                _buildActionLabel(
                  Icons.edit_outlined,
                  'Edit',
                  const Color(0xFFF6AD55),
                  onTap: () => widget.onCompleteProfile(patient),
                ),
                if (Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user?.hasPermission('delete_patient') ??
                    false)
                  _buildActionLabel(
                    Icons.delete_outline,
                    'Delete',
                    Colors.redAccent,
                    onTap: () => _showDeletePatientConfirmation(patient),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeletePatientConfirmation(PatientModel patient) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text(
              'Delete Patient',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: patient.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '? This action cannot be undone.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await PatientController().deletePatient(patient.id!);
                          if (mounted) {
                            Navigator.pop(ctx);
                            widget.onRefresh?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${patient.name} deleted.'),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isDeleting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionLabel(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                _buildFilterDropdown(
                  'Age Range',
                  _selectedAgeRange,
                  ['All Ages', 'Under 18', '18-35', '36-60', 'Over 60'],
                  (val) => setState(() => _selectedAgeRange = val!),
                ),
                const SizedBox(height: 14),
                _buildFilterDropdown(
                  'Gender',
                  _selectedGender,
                  ['All Genders', 'Male', 'Female', 'Other'],
                  (val) => setState(() => _selectedGender = val!),
                ),
                const SizedBox(height: 14),
                _buildFilterDropdown(
                  'Last Visit',
                  _selectedLastVisit,
                  ['Any Time', 'Last 7 Days', 'Last 30 Days', 'This Year'],
                  (val) => setState(() => _selectedLastVisit = val!),
                ),
                const SizedBox(height: 14),
                _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  ['All Status', 'Active', 'Inactive'],
                  (val) => setState(() => _selectedStatus = val!),
                ),
              ],
            )
          : isTablet
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Age Range',
                        _selectedAgeRange,
                        ['All Ages', 'Under 18', '18-35', '36-60', 'Over 60'],
                        (val) => setState(() => _selectedAgeRange = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Gender',
                        _selectedGender,
                        ['All Genders', 'Male', 'Female', 'Other'],
                        (val) => setState(() => _selectedGender = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Last Visit',
                        _selectedLastVisit,
                        [
                          'Any Time',
                          'Last 7 Days',
                          'Last 30 Days',
                          'This Year',
                        ],
                        (val) => setState(() => _selectedLastVisit = val!),
                      ),
                    ),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Status',
                        _selectedStatus,
                        ['All Status', 'Active', 'Inactive'],
                        (val) => setState(() => _selectedStatus = val!),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Age Range',
                    _selectedAgeRange,
                    ['All Ages', 'Under 18', '18-35', '36-60', 'Over 60'],
                    (val) => setState(() => _selectedAgeRange = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Gender',
                    _selectedGender,
                    ['All Genders', 'Male', 'Female', 'Other'],
                    (val) => setState(() => _selectedGender = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Last Visit',
                    _selectedLastVisit,
                    ['Any Time', 'Last 7 Days', 'Last 30 Days', 'This Year'],
                    (val) => setState(() => _selectedLastVisit = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Status',
                    _selectedStatus,
                    ['All Status', 'Active', 'Inactive'],
                    (val) => setState(() => _selectedStatus = val!),
                  ),
                ),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 14,
              ),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.textSecondaryColor,
          ),
        ],
      ),
    );
  }

  void _showQuickRegisterDialog(BuildContext context) {
    final PatientController patientController = PatientController();
    String? selectedGender;
    String? _selectedDeptQuick;
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController dobCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController reasonCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool isSaving = false;
    // For dropdown validation errors (shown only after submit attempt)
    String? genderError;
    String? deptError;
    // Live phone error (updates on each keystroke)
    String? phoneError;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Container(
                  width: MediaQuery.of(context).size.width > 500
                      ? 450
                      : MediaQuery.of(context).size.width * 0.95,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  padding: const EdgeInsets.all(0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Patient Registration',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fast check-in with minimal details',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.borderColor),
                        // Form body
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (MediaQuery.of(context).size.width < 500) ...[
                                _buildQuickFieldLabel('Full Name'),
                                _buildQuickTextField(
                                  controller: nameCtrl,
                                  hint: 'Enter patient\'s full name',
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Name is required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildQuickFieldLabel('Email Address'),
                                _buildQuickTextField(
                                  controller: emailCtrl,
                                  hint: 'patient@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) {
                                    if (val == null || val.isEmpty)
                                      return 'Email is required';
                                    if (!val.contains('@'))
                                      return 'Invalid email';
                                    return null;
                                  },
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel('Full Name'),
                                          _buildQuickTextField(
                                            controller: nameCtrl,
                                            hint: 'Enter patient\'s full name',
                                            validator: (val) =>
                                                val == null || val.isEmpty
                                                ? 'Name is required'
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel(
                                            'Email Address',
                                          ),
                                          _buildQuickTextField(
                                            controller: emailCtrl,
                                            hint: 'patient@example.com',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            validator: (val) {
                                              if (val == null || val.isEmpty)
                                                return 'Email is required';
                                              if (!val.contains('@'))
                                                return 'Invalid email';
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              if (MediaQuery.of(context).size.width < 500) ...[
                                _buildQuickFieldLabel('Date of Birth'),
                                _buildQuickTextField(
                                  controller: dobCtrl,
                                  hint: 'dd/mm/yyyy',
                                  icon: Icons.calendar_today_outlined,
                                  readOnly: true,
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'DOB required'
                                      : null,
                                  onTap: () async {
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().subtract(
                                        const Duration(days: 365 * 30),
                                      ),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime.now(),
                                    );
                                    if (pickedDate != null) {
                                      setState(() {
                                        dobCtrl.text = DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(pickedDate);
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildQuickFieldLabel('Mobile Number'),
                                _buildQuickTextField(
                                  controller: phoneCtrl,
                                  hint: '98765 43210',
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      if (val.isEmpty) {
                                        phoneError = 'Phone number is required';
                                      } else if (val.length < 10) {
                                        phoneError =
                                            'Enter 10-digit number (${val.length}/10)';
                                      } else {
                                        phoneError = null;
                                      }
                                    });
                                  },
                                  errorText: phoneError,
                                  validator: (val) =>
                                      val == null || val.length != 10
                                      ? 'Enter 10-digit number'
                                      : null,
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel(
                                            'Date of Birth',
                                          ),
                                          _buildQuickTextField(
                                            controller: dobCtrl,
                                            hint: 'dd/mm/yyyy',
                                            icon: Icons.calendar_today_outlined,
                                            readOnly: true,
                                            validator: (val) =>
                                                val == null || val.isEmpty
                                                ? 'Required'
                                                : null,
                                            onTap: () async {
                                              DateTime? pickedDate =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: DateTime.now()
                                                        .subtract(
                                                          const Duration(
                                                            days: 365 * 30,
                                                          ),
                                                        ),
                                                    firstDate: DateTime(1900),
                                                    lastDate: DateTime.now(),
                                                  );
                                              if (pickedDate != null) {
                                                setState(() {
                                                  dobCtrl.text = DateFormat(
                                                    'dd/MM/yyyy',
                                                  ).format(pickedDate);
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel(
                                            'Mobile Number',
                                          ),
                                          _buildQuickTextField(
                                            controller: phoneCtrl,
                                            hint: '98765 43210',
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                            ],
                                            onChanged: (val) {
                                              setState(() {
                                                if (val.isEmpty) {
                                                  phoneError =
                                                      'Phone number is required';
                                                } else if (val.length < 10) {
                                                  phoneError =
                                                      'Enter 10-digit number (${val.length}/10)';
                                                } else {
                                                  phoneError = null;
                                                }
                                              });
                                            },
                                            errorText: phoneError,
                                            validator: (val) =>
                                                val == null || val.length != 10
                                                ? 'Enter 10-digit number'
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 16),
                              if (MediaQuery.of(context).size.width < 500) ...[
                                _buildQuickFieldLabel('Department'),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: deptError != null
                                              ? const Color(0xFFE53E3E)
                                              : AppTheme.borderColor,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _selectedDeptQuick,
                                          hint: Text(
                                            _isLoadingDepartments
                                                ? 'Loading...'
                                                : 'Select Department',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          items: _departments.map((
                                            String value,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedDeptQuick = val;
                                              deptError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (deptError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          left: 4,
                                        ),
                                        child: Text(
                                          deptError!,
                                          style: const TextStyle(
                                            color: Color(0xFFE53E3E),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildQuickFieldLabel('Gender'),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: genderError != null
                                              ? const Color(0xFFE53E3E)
                                              : AppTheme.borderColor,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: selectedGender,
                                          hint: const Text(
                                            'Select',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Male',
                                              child: Text(
                                                'Male',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Female',
                                              child: Text(
                                                'Female',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Other',
                                              child: Text(
                                                'Other',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              selectedGender = val;
                                              genderError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (genderError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          left: 4,
                                        ),
                                        child: Text(
                                          genderError!,
                                          style: const TextStyle(
                                            color: Color(0xFFE53E3E),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ] else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel('Department'),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                height: 48,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: deptError != null
                                                        ? const Color(
                                                            0xFFE53E3E,
                                                          )
                                                        : AppTheme.borderColor,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    isExpanded: true,
                                                    value: _selectedDeptQuick,
                                                    hint: Text(
                                                      _isLoadingDepartments
                                                          ? 'Loading...'
                                                          : 'Select',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    items: _departments.map((
                                                      String value,
                                                    ) {
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: value,
                                                        child: Text(
                                                          value,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _selectedDeptQuick =
                                                            val;
                                                        deptError = null;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                              if (deptError != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                        left: 4,
                                                      ),
                                                  child: Text(
                                                    deptError!,
                                                    style: const TextStyle(
                                                      color: Color(0xFFE53E3E),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildQuickFieldLabel('Gender'),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                height: 48,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: genderError != null
                                                        ? const Color(
                                                            0xFFE53E3E,
                                                          )
                                                        : AppTheme.borderColor,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    isExpanded: true,
                                                    value: selectedGender,
                                                    hint: const Text(
                                                      'Select',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value: 'Male',
                                                        child: Text(
                                                          'Male',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: 'Female',
                                                        child: Text(
                                                          'Female',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: 'Other',
                                                        child: Text(
                                                          'Other',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (val) {
                                                      setState(() {
                                                        selectedGender = val;
                                                        genderError = null;
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                              if (genderError != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                        left: 4,
                                                      ),
                                                  child: Text(
                                                    genderError!,
                                                    style: const TextStyle(
                                                      color: Color(0xFFE53E3E),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              _buildQuickFieldLabel(
                                'Reason for Visit (Optional)',
                                isRequired: false,
                              ),
                              _buildQuickTextField(
                                controller: reasonCtrl,
                                hint:
                                    'Brief description of symptoms or reason...',
                                maxLines: 3,
                              ),

                              const SizedBox(height: 24),
                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          side: const BorderSide(
                                            color: AppTheme.borderColor,
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: AppTheme.textPrimaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: isSaving
                                            ? null
                                            : () async {
                                                // Validate text fields
                                                if (!_formKey.currentState!
                                                    .validate()) {
                                                  // Also set dropdown errors
                                                  setState(() {
                                                    if (selectedGender == null)
                                                      genderError =
                                                          'Please select gender';
                                                    if (_selectedDeptQuick ==
                                                        null)
                                                      deptError =
                                                          'Please select department';
                                                  });
                                                  return;
                                                }
                                                // Validate dropdowns
                                                if (selectedGender == null ||
                                                    _selectedDeptQuick ==
                                                        null) {
                                                  setState(() {
                                                    if (selectedGender == null)
                                                      genderError =
                                                          'Please select gender';
                                                    if (_selectedDeptQuick ==
                                                        null)
                                                      deptError =
                                                          'Please select department';
                                                  });
                                                  return;
                                                }

                                                setState(() => isSaving = true);

                                                try {
                                                  int calculatedAge = 0;
                                                  if (dobCtrl.text.isNotEmpty) {
                                                    try {
                                                      // Use DateFormat to parse precisely
                                                      final dob = DateFormat(
                                                        'dd/MM/yyyy',
                                                      ).parse(dobCtrl.text);
                                                      final now =
                                                          DateTime.now();
                                                      calculatedAge =
                                                          now.year - dob.year;
                                                      if (now.month <
                                                              dob.month ||
                                                          (now.month ==
                                                                  dob.month &&
                                                              now.day <
                                                                  dob.day)) {
                                                        calculatedAge--;
                                                      }
                                                    } catch (e) {
                                                      debugPrint(
                                                        'Error parsing DOB for age: $e',
                                                      );
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Invalid Date Format: ${dobCtrl.text}',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      setState(
                                                        () => isSaving = false,
                                                      );
                                                      return;
                                                    }
                                                  }

                                                  final newPatient =
                                                      PatientModel(
                                                        name: nameCtrl.text
                                                            .trim(),
                                                        dob: dobCtrl.text
                                                            .trim(),
                                                        age: calculatedAge,
                                                        gender:
                                                            selectedGender ??
                                                            'Other',
                                                        phone: phoneCtrl.text
                                                            .trim(),
                                                        email: emailCtrl.text
                                                            .trim(),
                                                        department:
                                                            _selectedDeptQuick ??
                                                            'General',
                                                        address: '',
                                                        height: 0.0,
                                                        weight: 0.0,
                                                        bpSystolic: 0,
                                                        bpDiastolic: 0,
                                                        sugar: 0.0,
                                                        temp: 0.0,
                                                        complaints: reasonCtrl
                                                            .text
                                                            .trim(),
                                                        history: '',
                                                        smokingStatus: 'Never',
                                                        alcoholStatus: 'Never',
                                                        occupation: '',
                                                        hobbies: '',
                                                        foodHabits: '',
                                                        physicalActivity: '',
                                                        isQuickRegister: true,
                                                      );

                                                  await patientController
                                                      .registerPatient(
                                                        newPatient,
                                                      );

                                                  setState(
                                                    () => isSaving = false,
                                                  );
                                                  Navigator.pop(context);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Patient Registered Successfully!',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                  if (widget.onRefresh !=
                                                      null) {
                                                    widget.onRefresh!();
                                                  }
                                                } catch (e) {
                                                  setState(
                                                    () => isSaving = false,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.redAccent,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0D5D9A,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text(
                                                'Register',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Footer link moved inside the scroll view or as a separate column item
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColor.withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onRegisterPatient();
                              },
                              child: const Text(
                                'Need full registration with complete details?',
                                style: TextStyle(
                                  color: Color(0xFF3182CE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFieldLabel(String text, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimaryColor,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFE53E3E)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 14,
        ),
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        errorStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        suffixIcon: icon != null
            ? Icon(icon, size: 18, color: AppTheme.textSecondaryColor)
            : null,
        isDense: true,
      ),
    );
  }
}

class PatientDetailView extends StatefulWidget {
  final PatientModel patient;
  final VoidCallback onBack;
  final Function(PatientModel) onCompleteProfile;

  const PatientDetailView({
    Key? key,
    required this.patient,
    required this.onBack,
    required this.onCompleteProfile,
  }) : super(key: key);

  @override
  State<PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<PatientDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppointmentController _appointmentController = AppointmentController();
  List<Map<String, dynamic>> _consultations = [];
  List<AppointmentModel> _patientAppointments = [];
  bool _isLoadingConsultations = true;
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchConsultations(), _fetchPatientAppointments()]);
  }

  Future<void> _fetchPatientAppointments() async {
    if (widget.patient.id == null) return;
    setState(() => _isLoadingAppointments = true);
    try {
      final appts = await _appointmentController.fetchAppointments();
      if (mounted) {
        setState(() {
          _patientAppointments = appts
              .where((a) => a.patientId == widget.patient.id)
              .toList();
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching patient appointments: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _fetchConsultations() async {
    try {
      if (widget.patient.id == null) {
        setState(() => _isLoadingConsultations = false);
        return;
      }
      final consultations = await _appointmentController
          .fetchConsultationsByPatient(widget.patient.id!);
      if (mounted) {
        setState(() {
          _consultations = consultations;
          _isLoadingConsultations = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching consultations: $e');
      if (mounted) {
        setState(() => _isLoadingConsultations = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.patient.name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    return parts.isNotEmpty
        ? parts.map((p) => p[0].toUpperCase()).join('')
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 850;
    final bool isTablet = screenWidth >= 850 && screenWidth < 1200;
    final p = widget.patient;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12.0 : (isTablet ? 16.0 : 24.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Back to Patients',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isMobile ? 14 : 20),

            // Patient Header Card
            _buildHeaderCard(p, isMobile, isTablet),
            SizedBox(height: isMobile ? 14 : 20),

            // Current Vitals
            _buildVitalsCard(p, isMobile),
            SizedBox(height: isMobile ? 14 : 20),

            // Tabs Section
            _buildTabsSection(p, isMobile),

            // Start Consultation Button (Only for Doctors with pending appts)
            _buildStartConsultationButton(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildStartConsultationButton(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.role.toLowerCase() != 'doctor') return const SizedBox.shrink();

    // Find a confirmed appointment for today or pending consultation
    final pendingAppt = _patientAppointments.firstWhere(
      (a) => a.status == 'Confirmed' || a.status == 'Pending',
      orElse: () => AppointmentModel(
        patientId: 0,
        patientName: '',
        department: '',
        doctorName: '',
        appointmentDate: '',
        appointmentTime: '',
        status: '',
      ),
    );

    if (pendingAppt.patientId == 0) return const SizedBox.shrink();

    final existingConsul = _consultations.firstWhere(
      (c) => c['appointment_id'] == pendingAppt.id,
      orElse: () => {},
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          _showConsultationDialog(pendingAppt);
        },
        icon: const Icon(Icons.medical_services_outlined, color: Colors.white),
        label: Text(
          existingConsul.isNotEmpty
              ? 'Edit Consultation'
              : 'Start New Consultation',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF38A169),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showConsultationDialog(AppointmentModel appt) {
    final existingConsul = _consultations.firstWhere(
      (c) => c['appointment_id'] == appt.id,
      orElse: () => {},
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          body: NewConsultationView(
            appointment: appt,
            initialConsultation: existingConsul.isNotEmpty
                ? existingConsul
                : null,
            onBack: () {
              Navigator.pop(context);
              _fetchData(); // REFRESH DATA when coming back
            },
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(PatientModel p, bool isMobile, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 28)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D5D9A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isMobile
          ? _buildHeaderMobile(p)
          : _buildHeaderDesktop(p, isTablet),
    );
  }

  Widget _buildHeaderDesktop(PatientModel p, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: isTablet ? 36 : 42,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: isTablet ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 18 : 24),
            // Name + Info + Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: isTablet ? 26 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.age} years • ${p.gender} • Blood Group: O+', // Placeholder blood group
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isTablet ? 14 : 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildHealthTags(p),
                  ),
                ],
              ),
            ),
            // Buttons
            Row(
              children: [
                if (p.isQuickRegister) ...[
                  _buildHeaderButton(
                    Icons.edit_note_outlined,
                    'Complete Profile',
                    onTap: () => widget.onCompleteProfile(p),
                    isPrimary: true,
                  ),
                  const SizedBox(width: 12),
                ],
                _buildHeaderButton(
                  Icons.calendar_today_outlined,
                  'Book Appointment',
                  isPrimary: true,
                ),
                const SizedBox(width: 12),
                _buildHeaderButton(
                  Icons.description_outlined,
                  'Add Notes',
                  isPrimary: false,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 16),
        // Contact Row
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildContactIconItem(
              Icons.phone_outlined,
              p.phone.isNotEmpty ? p.phone : '+1 555-0101',
            ),
            const SizedBox(width: 40),
            _buildContactIconItem(
              Icons.mail_outline,
              p.email.isNotEmpty ? p.email : 'patient@email.com',
            ),
            const SizedBox(width: 40),
            Flexible(
              child: _buildContactIconItem(
                Icons.location_on_outlined,
                p.address.isNotEmpty ? p.address : '123 Main St, New York, NY',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactIconItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeaderMobile(PatientModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.age} years • ${p.gender}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: _buildHealthTags(p)),
        const SizedBox(height: 16),
        Row(
          children: [
            if (p.isQuickRegister) ...[
              Expanded(
                child: _buildHeaderButton(
                  Icons.edit_note_outlined,
                  'Complete Profile',
                  onTap: () => widget.onCompleteProfile(p),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _buildHeaderButton(
                Icons.calendar_month_outlined,
                p.age < 18 ? 'Book Pediatric' : 'Book Appt.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHeaderButton(Icons.note_add_outlined, 'Notes'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),
        if (p.phone.isNotEmpty)
          _buildContactItem(Icons.phone_outlined, p.phone),
        if (p.address.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildContactItem(Icons.location_on_outlined, p.address),
        ],
      ],
    );
  }

  List<Widget> _buildHealthTags(PatientModel p) {
    final tags = <Widget>[];
    if (p.smokingStatus.toLowerCase() != 'never' &&
        p.smokingStatus.isNotEmpty &&
        p.smokingStatus.toLowerCase() != 'no') {
      tags.add(_buildTag('Smoker'));
    }
    if (p.alcoholStatus.toLowerCase() == 'regular') {
      tags.add(_buildTag('Alcohol'));
    }
    if (p.history.toLowerCase().contains('diabet')) {
      tags.add(_buildTag('Diabetic'));
    }
    if (p.complaints.isNotEmpty) {
      tags.add(_buildTag('Active Complaints'));
    }
    if (tags.isEmpty) {
      tags.add(_buildTag(p.department.isNotEmpty ? p.department : 'General'));
    }
    return tags;
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isPrimary = true,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? const Color(0xFF3182CE) : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF3182CE) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsCard(PatientModel p, bool isMobile) {
    final bool isTablet =
        MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1000;
    final vitals = [
      _VitalItem(
        label: 'Blood Pressure',
        value: (p.bpSystolic == 0 && p.bpDiastolic == 0)
            ? 'Not Provided'
            : '${p.bpSystolic}/${p.bpDiastolic}',
        color: const Color(0xFFEDF2F7), // Light blueish grey
        textColor: const Color(0xFF2D3748),
      ),
      _VitalItem(
        label: 'Sugar Level',
        value: p.sugar == 0.0 ? 'Not Provided' : '${p.sugar} mg/dL',
        color: const Color(0xFFFFF5F5), // Light pink
        textColor: const Color(0xFFC53030),
      ),
      _VitalItem(
        label: 'Temperature',
        value: p.temp == 0.0 ? 'Not Provided' : '${p.temp}°F',
        color: const Color(0xFFFFF5EB), // Light orange
        textColor: const Color(0xFFC05621),
      ),
      _VitalItem(
        label: 'Weight',
        value: p.weight == 0.0 ? 'Not Provided' : '${p.weight} lbs',
        color: const Color(0xFFF0FFF4), // Light green
        textColor: const Color(0xFF2F855A),
      ),
      _VitalItem(
        label: 'Height',
        value: p.height == 0.0 ? 'Not Provided' : '${p.height} cm',
        color: const Color(0xFFFAF5FF), // Light purple
        textColor: const Color(0xFF6B46C1),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Vitals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isMobile ? 14 : 20),
          if (isMobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: vitals
                      .map(
                        (v) => SizedBox(
                          width: itemWidth.floorToDouble(),
                          child: _buildVitalBox(v),
                        ),
                      )
                      .toList(),
                );
              },
            )
          else if (isTablet)
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: vitals
                      .map(
                        (v) => SizedBox(
                          width: itemWidth.floorToDouble(),
                          child: _buildVitalBox(v),
                        ),
                      )
                      .toList(),
                );
              },
            )
          else
            Row(
              children: vitals
                  .map(
                    (v) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildVitalBox(v),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVitalBox(_VitalItem vital) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vital.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vital.label,
            style: TextStyle(
              fontSize: 11,
              color: vital.textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vital.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: vital.textColor,
            ),
          ),
          if (vital.unit != null) ...[
            const SizedBox(height: 4),
            Text(
              vital.unit!,
              style: TextStyle(
                fontSize: 10,
                color: vital.textColor.withOpacity(0.55),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabsSection(PatientModel p, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Medical History'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Visits Timeline'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.self_improvement_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Lifestyle Data'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200, maxHeight: 500),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMedicalHistoryTab(p),
                _buildVisitsTimelineTab(p),
                _buildLifestyleTab(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab(PatientModel p) {
    final hasHistory = p.history.isNotEmpty;
    final hasComplaints = p.complaints.isNotEmpty;

    if (!hasHistory && !hasComplaints) {
      return const Center(
        child: Text(
          'No medical history recorded.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasComplaints) ...[
            const Text(
              'Chief Complaints',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildHistoryItem(
              icon: Icons.error_outline,
              iconColor: const Color(0xFFE53E3E),
              title: p.complaints,
              subtitle: 'Current',
              status: 'Active',
              statusColor: const Color(0xFFE53E3E),
              statusBg: const Color(0xFFFFF5F5),
            ),
            const SizedBox(height: 20),
          ],
          if (hasHistory) ...[
            const Text(
              'Past Medical History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ...p.history
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildHistoryItem(
                      icon: Icons.info_outline,
                      iconColor: const Color(0xFFE53E3E),
                      title: line.trim(),
                      subtitle: 'Past record',
                      status: 'Managed',
                      statusColor: const Color(0xFF38A169),
                      statusBg: const Color(0xFFF0FFF4),
                    ),
                  ),
                )
                .toList(),
            if (p.history
                        .split('\n')
                        .where((l) => l.trim().isNotEmpty)
                        .length ==
                    1 &&
                !p.history.contains('\n'))
              _buildHistoryItem(
                icon: Icons.info_outline,
                iconColor: const Color(0xFFE53E3E),
                title: p.history,
                subtitle: 'Past record',
                status: 'Managed',
                statusColor: const Color(0xFF38A169),
                statusBg: const Color(0xFFF0FFF4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsTimelineTab(PatientModel p) {
    if (_isLoadingConsultations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_consultations.length + 1} Total Records',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                onPressed: _fetchData,
                tooltip: 'Refresh Timeline',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Consultations
                ..._consultations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final c = entry.value;

                  // Safe parsing of medications
                  List medsList = [];
                  if (c['medications'] != null) {
                    if (c['medications'] is String) {
                      try {
                        medsList = jsonDecode(c['medications']);
                      } catch (e) {
                        medsList = [];
                      }
                    } else if (c['medications'] is List) {
                      medsList = c['medications'];
                    }
                  }

                  final meds = medsList.isNotEmpty
                      ? medsList
                            .map((m) => '${m['name']} (${m['dosage']})')
                            .join(', ')
                      : 'No medications';

                  final doctor = c['doctor_name'] ?? 'Doctor';
                  final symptoms = c['symptoms'] ?? 'None';
                  final diagnosis = c['diagnosis'] ?? 'None';

                  return _buildTimelineItem(
                    date: c['appointment_date'] ?? 'Consultation',
                    time: c['appointment_time'] ?? '—',
                    dept: c['department'] ?? 'General',
                    doctor: doctor,
                    complaint: symptoms,
                    diagnosis: diagnosis,
                    prescription: meds,
                    isFirst: index == 0,
                  );
                }).toList(),

                // Registration Visit (Always show at the end)
                _buildTimelineItem(
                  date: p.createdAt ?? 'Registration Visit',
                  time: 'Initial Entry',
                  dept: p.department,
                  doctor: 'Staff',
                  complaint: p.complaints.isNotEmpty
                      ? p.complaints
                      : 'Initial registration',
                  diagnosis: 'General Health Check',
                  prescription: 'N/A',
                  isFirst: _consultations.isEmpty,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String date,
    required String time,
    required String dept,
    String? doctor,
    String? complaint,
    String? diagnosis,
    String? prescription,
    bool isFirst = false,
    bool isLast = false,
  }) {
    String formattedDate = date;
    final dt = DateFormatter.toDateTime(date);
    if (dt != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(dt);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 5),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isFirst ? AppTheme.primaryColor : AppTheme.borderColor,
                shape: BoxShape.circle,
                border: isFirst
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 250,
                color: AppTheme.borderColor.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF8FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dept,
                        style: const TextStyle(
                          color: Color(0xFF3182CE),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTimelineDetail('Doctor', doctor ?? 'Not specified'),
                const SizedBox(height: 12),
                _buildTimelineDetail('Complaint', complaint ?? 'None'),
                const SizedBox(height: 12),
                _buildTimelineDetail('Diagnosis', diagnosis ?? 'None'),
                const SizedBox(height: 12),
                _buildTimelineDetail('Prescription', prescription ?? 'None'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleTab(PatientModel p) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildLifestyleCard(
              'Occupation',
              p.occupation.isNotEmpty ? p.occupation : 'Not Provided',
              const Color(0xFFEEF2F7),
              const Color(0xFF4A5568),
            ),
            const SizedBox(height: 16),
            _buildLifestyleCard(
              'Hobbies',
              p.hobbies.isNotEmpty ? p.hobbies : 'Not Provided',
              const Color(0xFFEEF2F7),
              const Color(0xFF4A5568),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildLifestyleCard(
                    'Occupation',
                    p.occupation.isNotEmpty ? p.occupation : 'Not Provided',
                    const Color(0xFFEEF2F7),
                    const Color(0xFF4A5568),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLifestyleCard(
                    'Hobbies',
                    p.hobbies.isNotEmpty ? p.hobbies : 'Not Provided',
                    const Color(0xFFEEF2F7),
                    const Color(0xFF4A5568),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _buildLifestyleCard(
            'Food Habits',
            p.foodHabits.isNotEmpty ? p.foodHabits : 'Not Provided',
            const Color(0xFFEEF2F7),
            const Color(0xFF4A5568),
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildLifestyleCard(
              'Smoking',
              p.smokingStatus.isNotEmpty ? p.smokingStatus : 'Not Provided',
              const Color(0xFFFFF7ED),
              const Color(0xFF9A3412),
            ),
            const SizedBox(height: 16),
            _buildLifestyleCard(
              'Alcohol Usage',
              p.alcoholStatus.isNotEmpty ? p.alcoholStatus : 'Not Provided',
              const Color(0xFFFEFCE8),
              const Color(0xFF713F12),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildLifestyleCard(
                    'Smoking',
                    p.smokingStatus.isNotEmpty
                        ? p.smokingStatus
                        : 'Not Provided',
                    const Color(0xFFFFF7ED),
                    const Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLifestyleCard(
                    'Alcohol Usage',
                    p.alcoholStatus.isNotEmpty
                        ? p.alcoholStatus
                        : 'Not Provided',
                    const Color(0xFFFEFCE8),
                    const Color(0xFF713F12),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _buildLifestyleCard(
            'Physical Activity',
            p.physicalActivity.isNotEmpty ? p.physicalActivity : 'Not Provided',
            const Color(0xFFEEF2F7),
            const Color(0xFF4A5568),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleCard(
    String label,
    String value,
    Color bgColor,
    Color labelColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: labelColor.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalItem {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final Color textColor;

  _VitalItem({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    required this.textColor,
  });
}
