import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_dropdown_search.dart';

class IPDManagementScreen extends StatefulWidget {
  final bool isMobile;

  const IPDManagementScreen({Key? key, required this.isMobile})
    : super(key: key);

  @override
  State<IPDManagementScreen> createState() => _IPDManagementScreenState();
}

class _IPDManagementScreenState extends State<IPDManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final IpdController _ipdController = IpdController();
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  List<Map<String, dynamic>> _beds = [];
  List<Map<String, dynamic>> _admissions = [];
  List<Map<String, dynamic>> _pendingAdmissions = [];
  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  List<Map<String, dynamic>> _nurses = [];
  bool _isLoading = true;
  bool _isDoctor = false;
  bool _tabControllerReady = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// didChangeDependencies is the first place Provider.of(context) is safe.
  /// We read the role here ONCE and create the correctly-sized TabController.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tabControllerReady) {
      final role =
          Provider.of<AuthProvider>(context, listen: false).user?.role ?? '';
      _isDoctor = role == 'Doctor';
      _tabController = TabController(
        length: _isDoctor ? 5 : 4,
        vsync: this,
      );
      _tabControllerReady = true;
    }
  }

  @override
  void dispose() {
    if (_tabControllerReady) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> bedsList = [];
    List<Map<String, dynamic>> admissionsList = [];
    List<Map<String, dynamic>> pendingAdmissionsList = [];
    List<PatientModel> patientsList = [];
    List<UserModel> doctorsList = [];
    List<Map<String, dynamic>> nursesList = [];
    String? errorMsg;

    try {
      bedsList = await _ipdController.fetchBeds();
    } catch (e) {
      errorMsg = e.toString();
    }
    try {
      admissionsList = await _ipdController.fetchAdmissions();
    } catch (e) {
      errorMsg ??= e.toString();
    }
    try {
      pendingAdmissionsList = await _ipdController.fetchPendingAdmissions();
    } catch (e) {
      errorMsg ??= e.toString();
    }
    try {
      patientsList = await _patientController.fetchPatients();
    } catch (_) {}
    try {
      doctorsList = await _adminController.fetchStaff(role: 'Doctor');
    } catch (_) {}
    try {
      nursesList = await _ipdController.fetchNurses();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _beds = bedsList;
        _admissions = admissionsList;
        _pendingAdmissions = pendingAdmissionsList;
        _patients = patientsList;
        _doctors = doctorsList;
        _nurses = nursesList;
        _isLoading = false;
      });
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: $errorMsg'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  int get _admittedCount =>
      _admissions.where((a) => a['status'] == 'Admitted').length;
  int get _availableBedsCount =>
      _beds.where((b) => b['status'] == 'Available').length;
  int get _icuOccupancy => _admissions
      .where((a) => a['status'] == 'Admitted' && a['ward_type'] == 'ICU')
      .length;

  @override
  Widget build(BuildContext context) {
    final userRole =
        Provider.of<AuthProvider>(context, listen: false).user?.role ?? 'Doctor';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userRole),
                _buildStatsRow(),
                _buildTabBar(_isDoctor),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveAdmissionsTab(userRole),
                      _buildPendingAdmissionsTab(),
                      _buildBedAvailabilityTab(),
                      _buildDischargeHistoryTab(),
                      if (_isDoctor) _buildICUDashboardTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(String userRole) {
    final headerTitle = userRole == 'Nurse'
        ? 'Nurse IPD Management'
        : userRole == 'Admin'
            ? 'Admin IPD Management'
            : 'Doctor IPD Management';
    final headerSubtitle = userRole == 'Nurse'
        ? 'Allocate beds, record vitals, and manage nursing updates'
        : userRole == 'Admin'
            ? 'Oversee admissions, bed inventory, and discharge workflows'
            : 'Admit patients, review progress, and manage discharge decisions';

    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.isMobile ? 16 : 24,
        24,
        widget.isMobile ? 16 : 24,
        8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerTitle,
                style: TextStyle(
                  fontSize: widget.isMobile ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                headerSubtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (userRole != 'Nurse')
            ElevatedButton.icon(
              onPressed: () => _showAdmitDialog(),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text(
                'Admit Patient',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(120, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Currently Admitted',
              _admittedCount.toString(),
              'Patients in Wards',
              Icons.bedroom_child_outlined,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Available Beds',
              '$_availableBedsCount/${_beds.length}',
              'Ready for intake',
              Icons.hotel_outlined,
              Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'ICU Occupancy',
              _icuOccupancy.toString(),
              'Critical cases',
              Icons.local_hospital_outlined,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDoctor) {
    final activeCount = _admittedCount;
    final pendingCount = _pendingAdmissions.length;
    final availableBeds = _availableBedsCount;
    final totalBeds = _beds.length;
    final dischargeCount = _admissions.where((a) => a['status'] == 'Discharged').length;
    final icuCount = _icuOccupancy;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        tabs: [
          Tab(text: 'Active Wards ($activeCount)'),
          Tab(text: 'Pending Admissions ($pendingCount)'),
          Tab(text: 'Bed Availability ($availableBeds/$totalBeds)'),
          Tab(text: 'Discharge History ($dischargeCount)'),
          if (isDoctor) Tab(text: 'ICU Dashboard ($icuCount)'),
        ],
      ),
    );
  }

  Widget _buildActiveAdmissionsTab([String userRole = 'Admin']) {
    final isDoctor = userRole == 'Doctor';
    final active = _admissions.where((a) => a['status'] == 'Admitted').toList();
    if (active.isEmpty) {
      return _buildEmptyState(
        'No active admissions.',
        Icons.hotel_class_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final adm = active[index];
        final dateStr = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(DateTime.parse(adm['admission_date']));

        final String rawReason = adm['reason_for_admission'] ?? '';
        String? assignedNurse;
        if (rawReason.startsWith('[Assigned Nurse: ')) {
          final endIdx = rawReason.indexOf(']');
          if (endIdx != -1) {
            assignedNurse = rawReason.substring(17, endIdx);
          }
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    adm['patient_name']?[0].toUpperCase() ?? 'P',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adm['patient_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bed: ${adm['bed_number']} (${adm['ward_type']}) • Admitted: $dateStr',
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Treating Doctor: ${adm['doctor_name']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (assignedNurse != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.teal.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.teal.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Assigned Nurse: $assignedNurse',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (isDoctor) ..._buildDoctorAdmissionActions(adm)
                    else ..._buildNurseAdmissionActions(adm),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDoctorAdmissionActions(Map<String, dynamic> adm) {
    return [
      ElevatedButton.icon(
        onPressed: () => _showDoctorMonitoringDialog(adm),
        icon: const Icon(Icons.medical_services_outlined, size: 16, color: Colors.white),
        label: const Text('IPD Monitoring', style: TextStyle(color: Colors.white, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A7A4A),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => _showDoctorDischargeDialog(adm),
        icon: const Icon(Icons.logout, size: 16, color: Colors.red),
        label: const Text('Discharge', style: TextStyle(color: Colors.red, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
      ),
    ];
  }

  List<Widget> _buildNurseAdmissionActions(Map<String, dynamic> adm) {
    return [
      ElevatedButton.icon(
        onPressed: () => _showNursingDashboard(adm),
        icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
        label: const Text('Nursing Station', style: TextStyle(color: Colors.white, fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5A8E)),
      ),
      OutlinedButton.icon(
        onPressed: () => _showDischargeDialog(adm),
        icon: const Icon(Icons.logout, size: 16, color: Colors.red),
        label: const Text('Discharge', style: TextStyle(color: Colors.red, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
      ),
    ];
  }

  Widget _buildPendingAdmissionsTab() {
    if (_pendingAdmissions.isEmpty) {
      return _buildEmptyState(
        'No pending admissions.',
        Icons.hourglass_bottom,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _pendingAdmissions.length,
      itemBuilder: (context, index) {
        final pending = _pendingAdmissions[index];
        final admittedAt = pending['admitted_at'] != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(pending['admitted_at']))
            : 'Unknown';

        final String rawReason = pending['reason_for_visit'] ?? 'Reason not recorded';
        String? assignedNurse;
        String displayReason = rawReason;
        if (rawReason.startsWith('[Assigned Nurse: ')) {
          final endIdx = rawReason.indexOf(']');
          if (endIdx != -1) {
            assignedNurse = rawReason.substring(17, endIdx);
            displayReason = rawReason.substring(endIdx + 1).trim();
          }
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    pending['patient_name']?[0].toUpperCase() ?? 'P',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending['patient_name'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Doctor: ${pending['doctor_name'] ?? '--'} • Admitted: $admittedAt',
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      if (assignedNurse != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.teal.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.teal.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Assigned Nurse: $assignedNurse',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        displayReason,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDoctor)
                  ElevatedButton(
                    onPressed: () => _showAllocateBedDialog(pending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(130, 42),
                    ),
                    child: const Text('Allocate Bed'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllocateBedDialog(Map<String, dynamic> pending) {
    String? selectedWardType;
    String? selectedBedNumber;
    final TextEditingController reasonController = TextEditingController(
      text: pending['reason_for_visit'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    List<String> availableBeds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateBedsForWard(String? ward) {
              setDialogState(() {
                selectedWardType = ward;
                selectedBedNumber = null;
                if (ward != null) {
                  availableBeds = _beds
                      .where((b) => b['ward_type'] == ward && b['status'] == 'Available')
                      .map((b) => b['bed_number'].toString())
                      .toList();
                } else {
                  availableBeds = [];
                }
              });
            }

            return AlertDialog(
              title: Text(
                'Allocate Bed for ${pending['patient_name'] ?? 'Patient'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Ward Type',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedWardType,
                        items: const [
                          DropdownMenuItem(value: 'General', child: Text('General')),
                          DropdownMenuItem(value: 'Semi-Private', child: Text('Semi-Private')),
                          DropdownMenuItem(value: 'Private', child: Text('Private')),
                          DropdownMenuItem(value: 'ICU', child: Text('ICU')),
                        ],
                        onChanged: updateBedsForWard,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please select a ward type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Available Bed',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedBedNumber,
                        items: availableBeds
                            .map((bed) => DropdownMenuItem(value: bed, child: Text(bed)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedBedNumber = val),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please select a bed';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reason for Admission',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter admission reason',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Reason for admission is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    try {
                      await _ipdController.createAdmission({
                        'patient_id': pending['patient_id'],
                        'appointment_id': pending['appointment_id'],
                        'doctor_name': pending['doctor_name'],
                        'bed_number': selectedBedNumber,
                        'ward_type': selectedWardType,
                        'reason_for_admission': reasonController.text.trim(),
                      });
                      Navigator.pop(context);
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bed allocated and admission completed.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: const Text('Allocate Bed'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBedAvailabilityTab() {
    final Map<String, List<Map<String, dynamic>>> groupedBeds = {};
    final wardOrder = ['General', 'Semi-Private', 'Private', 'ICU'];

    for (var ward in wardOrder) {
      groupedBeds[ward] = [];
    }

    for (var bed in _beds) {
      final ward = bed['ward_type'] ?? 'Other';
      groupedBeds.putIfAbsent(ward, () => []).add(bed);
    }

    groupedBeds.removeWhere((key, value) => value.isEmpty);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: groupedBeds.entries.map((entry) {
        final wardName = entry.key;
        final wardBeds = entry.value;

        final totalBeds = wardBeds.length;
        final availableBeds = wardBeds
            .where((b) => b['status'] == 'Available')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 16),
              child: Row(
                children: [
                  Icon(
                    wardName == 'ICU' ? Icons.local_hospital : Icons.king_bed,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$wardName Ward',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$availableBeds / $totalBeds Available',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: wardBeds.length,
              itemBuilder: (context, index) {
                final bed = wardBeds[index];
                final bool isAvail = bed['status'] == 'Available';
                final Color cardColor = isAvail
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE);
                final Color borderColor = isAvail
                    ? const Color(0xFF81C784)
                    : const Color(0xFFE57373);
                final Color textColor = isAvail
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828);

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bed['bed_number'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Icon(
                            Icons.king_bed_outlined,
                            color: textColor.withOpacity(0.7),
                            size: 16,
                          ),
                        ],
                      ),
                      Text(
                        isAvail ? 'Available' : 'Occupied',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDischargeHistoryTab() {
    final discharged = _admissions
        .where((a) => a['status'] == 'Discharged')
        .toList();
    if (discharged.isEmpty) {
      return _buildEmptyState('No discharged records.', Icons.history);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: discharged.length,
      itemBuilder: (context, index) {
        final adm = discharged[index];
        final dischargeDateStr = adm['discharge_date'] != null
            ? DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(DateTime.parse(adm['discharge_date']))
            : '--';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: const Icon(
                Icons.assignment_turned_in,
                color: Colors.green,
              ),
            ),
            title: Text(
              adm['patient_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Bed: ${adm['bed_number']} • Discharged: $dischargeDateStr\nDoctor: ${adm['doctor_name']}',
              style: const TextStyle(height: 1.5, fontSize: 12),
            ),
            trailing: TextButton.icon(
              onPressed: () => _showDischargeSummaryView(adm),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('View Summary'),
            ),
          ),
        );
      },
    );
  }

  // ─── ICU Dashboard (Doctor-only) ─────────────────────────────────────────
  Widget _buildICUDashboardTab() {
    final icuPatients = _admissions
        .where((a) => a['status'] == 'Admitted' && a['ward_type'] == 'ICU')
        .toList();
    if (icuPatients.isEmpty) {
      return _buildEmptyState('No patients in ICU currently.', Icons.local_hospital_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: icuPatients.length,
      itemBuilder: (context, index) {
        final adm = icuPatients[index];
        final alerts = _buildICUAlerts(adm);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: alerts.isNotEmpty ? Colors.red.shade200 : Colors.grey.shade200,
              width: alerts.isNotEmpty ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: alerts.isNotEmpty
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        alerts.isNotEmpty
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: alerts.isNotEmpty ? Colors.red : Colors.green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adm['patient_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Bed: ${adm['bed_number']} • Dr. ${adm['doctor_name']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (alerts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '${alerts.length} Alert${alerts.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (alerts.isNotEmpty) ...[  
                  const SizedBox(height: 12),
                  ...alerts.map(
                    (alert) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: alert['color'] == 'red'
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: alert['color'] == 'red'
                              ? Colors.red.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_outlined,
                            size: 14,
                            color: alert['color'] == 'red'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert['message'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: alert['color'] == 'red'
                                    ? Colors.red.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Last vitals summary
                _buildLastVitalsSummary(adm),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showDoctorMonitoringDialog(adm),
                      icon: const Icon(Icons.medical_services_outlined,
                          size: 15, color: Colors.white),
                      label: const Text('Monitor & Notes',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A7A4A),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEmergencyInterventionDialog(adm),
                      icon: const Icon(Icons.emergency_outlined,
                          size: 15, color: Colors.deepOrange),
                      label: const Text('Emergency Action',
                          style: TextStyle(
                              color: Colors.deepOrange, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepOrange),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showDoctorDischargeDialog(adm),
                      icon: const Icon(Icons.logout, size: 15, color: Colors.red),
                      label: const Text('Discharge',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, String>> _buildICUAlerts(Map<String, dynamic> adm) {
    final alerts = <Map<String, String>>[];
    final updates = _getUpdates(adm);
    if (updates.isEmpty) return alerts;
    final latest = updates.last;

    // Blood pressure
    final bpStr = latest['blood_pressure']?.toString() ?? '--';
    if (bpStr != '--') {
      try {
        final parts = bpStr.split('/');
        final sys = int.parse(parts[0].trim());
        final dias = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (sys >= 180 || dias >= 120) {
          alerts.add({'message': 'BP Critical: $bpStr mmHg (Hypertensive Crisis)', 'color': 'red'});
        } else if (sys >= 140 || dias >= 90) {
          alerts.add({'message': 'BP Elevated: $bpStr mmHg', 'color': 'orange'});
        } else if (sys < 90) {
          alerts.add({'message': 'BP Low: $bpStr mmHg (Hypotension)', 'color': 'red'});
        }
      } catch (_) {}
    }

    // Temperature
    final tempStr = latest['temperature']?.toString() ?? '--';
    if (tempStr != '--') {
      try {
        final temp = double.parse(tempStr);
        if (temp >= 104) {
          alerts.add({'message': 'Temp Critical: ${temp}°F (High Fever)', 'color': 'red'});
        } else if (temp >= 100.4) {
          alerts.add({'message': 'Temp Elevated: ${temp}°F (Fever)', 'color': 'orange'});
        } else if (temp < 95) {
          alerts.add({'message': 'Temp Low: ${temp}°F (Hypothermia)', 'color': 'red'});
        }
      } catch (_) {}
    }

    // Pulse
    final pulseStr = latest['pulse']?.toString() ?? '--';
    if (pulseStr != '--') {
      try {
        final pulse = int.parse(pulseStr);
        if (pulse > 150) {
          alerts.add({'message': 'Pulse Critical: $pulse bpm (Tachycardia)', 'color': 'red'});
        } else if (pulse < 40) {
          alerts.add({'message': 'Pulse Critical: $pulse bpm (Bradycardia)', 'color': 'red'});
        }
      } catch (_) {}
    }

    // Sugar
    final sugarStr = latest['sugar_level']?.toString() ?? '--';
    if (sugarStr != '--') {
      try {
        final sugar = double.parse(sugarStr);
        if (sugar > 400) {
          alerts.add({'message': 'Sugar Critical: ${sugar} mg/dL (Hyperglycemia)', 'color': 'red'});
        } else if (sugar < 50) {
          alerts.add({'message': 'Sugar Critical: ${sugar} mg/dL (Hypoglycemia)', 'color': 'red'});
        }
      } catch (_) {}
    }

    return alerts;
  }

  List<dynamic> _getUpdates(Map<String, dynamic> adm) {
    if (adm['daily_updates'] == null) return [];
    if (adm['daily_updates'] is List) return adm['daily_updates'] as List;
    try {
      return jsonDecode(adm['daily_updates'].toString()) as List;
    } catch (_) {
      return [];
    }
  }

  Widget _buildLastVitalsSummary(Map<String, dynamic> adm) {
    final updates = _getUpdates(adm);
    if (updates.isEmpty) {
      return const Text(
        'No vitals recorded yet.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
      );
    }
    final latest = updates.last;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildVitalChip('BP', latest['blood_pressure'] ?? '--', Icons.favorite_outline),
          _buildVitalChip('Temp', '${latest['temperature'] ?? '--'}°F', Icons.thermostat_outlined),
          _buildVitalChip('Pulse', '${latest['pulse'] ?? '--'} bpm', Icons.monitor_heart_outlined),
          _buildVitalChip('Sugar', '${latest['sugar_level'] ?? '--'}', Icons.water_drop_outlined),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
      ],
    );
  }

  // ─── Doctor IPD Monitoring Dialog (Step 6) ───────────────────────────────
  void _showDoctorMonitoringDialog(Map<String, dynamic> admission) {
    final progressController = TextEditingController();
    final diagnosisController = TextEditingController();
    final medicationController = TextEditingController();
    final doctorName =
        Provider.of<AuthProvider>(context, listen: false).user?.fullname ?? 'Doctor';

    List<dynamic> updates = _getUpdates(admission);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.medical_services_outlined,
                      color: Color(0xFF1A7A4A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'IPD Monitoring: ${admission['patient_name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                height: 520,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Progress Note Entry
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Patient Info'),
                            const SizedBox(height: 8),
                            _infoRow('Ward / Bed',
                                '${admission['ward_type']} / ${admission['bed_number']}'),
                            _infoRow('Doctor', admission['doctor_name'] ?? '--'),
                            const SizedBox(height: 20),
                            _sectionLabel('Add Progress Note'),
                            const SizedBox(height: 10),
                            TextField(
                              controller: diagnosisController,
                              decoration: const InputDecoration(
                                labelText: 'Updated Diagnosis / Findings',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: medicationController,
                              decoration: const InputDecoration(
                                labelText: 'Medication / Treatment Changes',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: progressController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Progress Note / Observations *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (progressController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Progress note is required'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  final noteText = [
                                    if (diagnosisController.text.trim().isNotEmpty)
                                      'Diagnosis: ${diagnosisController.text.trim()}',
                                    if (medicationController.text.trim().isNotEmpty)
                                      'Medication: ${medicationController.text.trim()}',
                                    progressController.text.trim(),
                                  ].join(' | ');

                                  try {
                                    await _ipdController.addDoctorProgressNote(
                                      admission['id'],
                                      {
                                        'nurse_name': doctorName,
                                        'notes': noteText,
                                        'temperature': '--',
                                        'blood_pressure': '--',
                                        'sugar_level': '--',
                                        'pulse': '--',
                                      },
                                    );
                                    // Reload and refresh
                                    final freshAdms =
                                        await _ipdController.fetchAdmissions();
                                    final freshAdm = freshAdms.firstWhere(
                                        (e) => e['id'] == admission['id'],
                                        orElse: () => admission);
                                    setDialogState(() {
                                      updates = _getUpdates(freshAdm);
                                      progressController.clear();
                                      diagnosisController.clear();
                                      medicationController.clear();
                                    });
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Progress note saved.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_outlined,
                                    size: 16, color: Colors.white),
                                label: const Text('Save Progress Note',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A7A4A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    // Right: Timeline of notes
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Progress Notes / Vitals History'),
                          const SizedBox(height: 10),
                          Expanded(
                            child: updates.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No entries recorded yet.',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: updates.length,
                                    reverse: true,
                                    itemBuilder: (ctx, idx) {
                                      final item = updates[
                                          updates.length - 1 - idx];
                                      final dp = DateTime.parse(item['date']);
                                      final displayDate =
                                          DateFormat('dd/MM HH:mm')
                                              .format(dp);
                                      final isDoctor = !(item['nurse_name']
                                              ?.toString()
                                              .toLowerCase()
                                              .startsWith('nurse') ??
                                          false);
                                      return Card(
                                        color: isDoctor
                                            ? const Color(0xFFF0FFF4)
                                            : Colors.grey.shade50,
                                        elevation: 0,
                                        margin: const EdgeInsets.only(
                                            bottom: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isDoctor
                                                ? const Color(0xFFA7F3D0)
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    displayDate,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: isDoctor
                                                          ? const Color(
                                                              0xFF1A7A4A)
                                                          : AppTheme
                                                              .primaryColor,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        isDoctor
                                                            ? Icons
                                                                .medical_services_outlined
                                                            : Icons.person_outline,
                                                        size: 12,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                      const SizedBox(
                                                          width: 2),
                                                      Text(
                                                        item['nurse_name'] ??
                                                            '',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (item['blood_pressure'] !=
                                                      '--' ||
                                                  item['temperature'] != '--')
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    'BP: ${item['blood_pressure']} | Temp: ${item['temperature']}°F | Sugar: ${item['sugar_level']} | Pulse: ${item['pulse']}',
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['notes'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Emergency Intervention Dialog ───────────────────────────────────────
  void _showEmergencyInterventionDialog(Map<String, dynamic> admission) {
    final actionController = TextEditingController();
    final doctorName =
        Provider.of<AuthProvider>(context, listen: false).user?.fullname ?? 'Doctor';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.emergency_outlined,
                  color: Colors.deepOrange, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Intervention',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    admission['patient_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.deepOrange.shade700, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This intervention will be logged as a critical progress note on the patient record.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Intervention Action / Order',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: actionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Describe the emergency action taken (e.g. administered adrenaline, CPR initiated, transferred to ventilator)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (actionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please describe the intervention'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await _ipdController.addDoctorProgressNote(
                  admission['id'],
                  {
                    'nurse_name': doctorName,
                    'notes':
                        '[EMERGENCY INTERVENTION] ${actionController.text.trim()}',
                    'temperature': '--',
                    'blood_pressure': '--',
                    'sugar_level': '--',
                    'pulse': '--',
                  },
                );
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency intervention logged.'),
                    backgroundColor: Colors.deepOrange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_outlined,
                size: 16, color: Colors.white),
            label: const Text('Log Intervention',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper section label & info row ────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdmitDialog() {
    final userRole =
        Provider.of<AuthProvider>(context, listen: false).user?.role ?? 'Admin';
    final doctorName =
        Provider.of<AuthProvider>(context, listen: false).user?.fullname ?? '';
    final isDoctor = userRole == 'Doctor';

    if (isDoctor) {
      _showDoctorAdmitDialog(doctorName);
    } else {
      _showAdminAdmitDialog();
    }
  }

  // ─── Doctor Admit: send to queue OR allocate bed directly ────────────────
  void _showDoctorAdmitDialog(String doctorName) {
    int? selectedPatientId;
    bool allocateNow = false;
    String? selectedWardType;
    String? selectedBedNumber;
    String? selectedNurseName;
    List<String> availableBeds = [];
    bool isSubmitting = false;
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void updateBeds(String? ward) {
              setDialogState(() {
                selectedWardType = ward;
                selectedBedNumber = null;
                availableBeds = ward == null
                    ? []
                    : _beds
                        .where((b) =>
                            b['ward_type'] == ward &&
                            b['status'] == 'Available')
                        .map((b) => b['bed_number'].toString())
                        .toList();
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_outlined,
                        color: AppTheme.dangerColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admit Patient to IPD',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        allocateNow
                            ? 'Bed allocated directly'
                            : 'Nurse will allocate the bed',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Admission mode toggle ──
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(
                                      () => allocateNow = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !allocateNow
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: !allocateNow
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.06),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_outlined,
                                            size: 14,
                                            color: !allocateNow
                                                ? AppTheme.primaryColor
                                                : Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Send to Queue',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: !allocateNow
                                                ? AppTheme.primaryColor
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setDialogState(() => allocateNow = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: allocateNow
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: allocateNow
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.06),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bed_outlined,
                                            size: 14,
                                            color: allocateNow
                                                ? Colors.orange.shade700
                                                : Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Allocate Now',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: allocateNow
                                                ? Colors.orange.shade700
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Info banner ──
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: allocateNow
                              ? Container(
                                  key: const ValueKey('now'),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt,
                                          color: Colors.orange.shade700,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Patient will be admitted directly to the selected bed — no nurse queue needed.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('queue'),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.blue.shade600,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Request sent to the Pending Admissions queue. Nurse will allocate the bed.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // ── Patient picker ──
                        const Text.rich(
                          TextSpan(
                            text: 'Select Patient',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Patient',
                          value: selectedPatientId?.toString(),
                          dropdownMap: {
                            for (var p in _patients)
                              p.id.toString():
                                  '${p.name} (${p.patientId ?? p.id})',
                          },
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a patient';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(
                                () => selectedPatientId = int.tryParse(val),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Reason ──
                        const Text.rich(
                          TextSpan(
                            text: 'Reason for Admission',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'Describe the medical reason for IPD admission...',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppTheme.primaryColor),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter reason for admission';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Assign to Nurse (Optional)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select nurse to assign',
                          value: selectedNurseName,
                          dropdownMap: {
                            for (var n in _nurses)
                              n['name'].toString():
                                  "${n['name']} (${n['department'] ?? 'General'})",
                          },
                          onChanged: (v) =>
                              setDialogState(() => selectedNurseName = v),
                        ),

                        // ── Allocate Now: ward + bed ──
                        if (allocateNow) ...[
                          const SizedBox(height: 16),
                          const Text.rich(
                            TextSpan(
                              text: 'Select Ward Type',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Select Ward Type',
                            value: selectedWardType,
                            dropdownItems: const [
                              'General',
                              'Semi-Private',
                              'Private',
                              'ICU',
                            ],
                            onChanged: updateBeds,
                            validator: allocateNow
                                ? (v) => (v == null || v.isEmpty)
                                    ? 'Please select a ward'
                                    : null
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Text.rich(
                            TextSpan(
                              text: 'Available Bed',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomDropdownSearch(
                            label: '',
                            hint: selectedWardType == null
                                ? 'Select ward first'
                                : availableBeds.isEmpty
                                    ? 'No beds available in this ward'
                                    : 'Select bed',
                            value: selectedBedNumber,
                            dropdownMap: {
                              for (var b in availableBeds) b: 'Bed $b',
                            },
                            onChanged: (v) =>
                                setDialogState(() => selectedBedNumber = v),
                            validator: allocateNow
                                ? (v) => (v == null || v.isEmpty)
                                    ? 'Please select a bed'
                                    : null
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                StatefulBuilder(
                  builder: (ctx2, setBtn) => ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setBtn(() => isSubmitting = true);
                            try {
                              final reason = selectedNurseName != null
                                  ? '[Assigned Nurse: $selectedNurseName] ${reasonController.text.trim()}'
                                  : reasonController.text.trim();
                              if (allocateNow) {
                                // Direct admission with bed allocation
                                await _ipdController.createAdmission({
                                  'patient_id': selectedPatientId,
                                  'doctor_name': doctorName,
                                  'bed_number': selectedBedNumber,
                                  'ward_type': selectedWardType,
                                  'reason_for_admission': reason,
                                });
                                Navigator.pop(ctx);
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Patient admitted and bed allocated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                // Send to pending queue
                                await _ipdController.createPendingAdmission({
                                  'patient_id': selectedPatientId,
                                  'doctor_name': doctorName,
                                  'reason_for_admission': reason,
                                });
                                Navigator.pop(ctx);
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Admission request sent. Nurse will allocate a bed.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setBtn(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            allocateNow
                                ? Icons.bed_outlined
                                : Icons.send_outlined,
                            size: 16,
                            color: Colors.white),
                    label: Text(
                      isSubmitting
                          ? 'Submitting...'
                          : allocateNow
                              ? 'Admit Patient'
                              : 'Send Request',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allocateNow
                          ? Colors.orange.shade700
                          : AppTheme.dangerColor,
                      minimumSize: const Size(130, 48),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Admin/Nurse Full Admit Dialog ────────────────────────────────────────
  void _showAdminAdmitDialog() {
    int? selectedPatientId;
    String? selectedBedNumber;
    String? selectedWardType;
    String? selectedDoctorName;
    String? selectedNurseName;
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    List<String> availableBeds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateBedsForWard(String? ward) {
              setDialogState(() {
                selectedWardType = ward;
                selectedBedNumber = null;
                if (ward != null) {
                  availableBeds = _beds
                      .where(
                        (b) =>
                            b['ward_type'] == ward &&
                            b['status'] == 'Available',
                      )
                      .map((b) => b['bed_number'].toString())
                      .toList();
                } else {
                  availableBeds = [];
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text(
                'Admit Patient to IPD',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              text: 'Select Patient',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Patient',
                          value: selectedPatientId?.toString(),
                          dropdownMap: {
                            for (var p in _patients)
                              p.id.toString():
                                  '${p.name} (${p.patientId ?? p.id})',
                          },
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a patient';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(
                                () => selectedPatientId = int.tryParse(val),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              text: 'Treating Doctor',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Treating Doctor',
                          value: selectedDoctorName,
                          dropdownItems: _doctors
                              .map((d) => d.fullname)
                              .toList(),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a treating doctor';
                            }
                            return null;
                          },
                          onChanged: (val) =>
                              setDialogState(() => selectedDoctorName = val),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              text: 'Ward Type',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Ward Type',
                          value: selectedWardType,
                          dropdownItems: const [
                            'General',
                            'Semi-Private',
                            'Private',
                            'ICU',
                          ],
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a ward type';
                            }
                            return null;
                          },
                          onChanged: updateBedsForWard,
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              text: 'Select Available Bed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Available Bed',
                          value: selectedBedNumber,
                          dropdownItems: availableBeds,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select an available bed';
                            }
                            return null;
                          },
                          onChanged: (val) =>
                              setDialogState(() => selectedBedNumber = val),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reason for Admission',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Reason for Admission',
                            hintStyle: const TextStyle(
                              color: Color(0xFFCBD5E0),
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Assign to Nurse (Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedNurseName,
                          items: _nurses
                              .map((n) {
                                final dept = n['department'] ?? 'General';
                                return DropdownMenuItem<String>(
                                  value: n['name'].toString(),
                                  child: Text("${n['name']} ($dept)"),
                                );
                              })
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedNurseName = v),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            hintText: 'Select nurse to assign',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    try {
                      final reason = selectedNurseName != null
                          ? '[Assigned Nurse: $selectedNurseName] ${reasonController.text.trim()}'
                          : reasonController.text.trim();
                      await _ipdController.createAdmission({
                        'patient_id': selectedPatientId,
                        'doctor_name': selectedDoctorName,
                        'bed_number': selectedBedNumber,
                        'ward_type': selectedWardType,
                        'reason_for_admission': reason,
                      });
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Patient Admitted Successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                  ),
                  child: const Text('Confirm Admission'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNursingDashboard(Map<String, dynamic> admission) {
    final TextEditingController nurseController = TextEditingController();
    final TextEditingController bpController = TextEditingController();
    final TextEditingController tempController = TextEditingController();
    final TextEditingController sugarController = TextEditingController();
    final TextEditingController pulseController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    List<dynamic> updates = [];
    if (admission['daily_updates'] != null) {
      if (admission['daily_updates'] is List) {
        updates = admission['daily_updates'];
      } else {
        try {
          updates = jsonDecode(admission['daily_updates']);
        } catch (_) {}
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Nursing Chart: ${admission['patient_name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 600,
                height: 500,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Entry Form
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Daily Update Vitals',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nurseController,
                              decoration: const InputDecoration(
                                labelText: 'Nurse Name',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: bpController,
                              decoration: const InputDecoration(
                                labelText: 'Blood Pressure (mmHg)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: tempController,
                              decoration: const InputDecoration(
                                labelText: 'Temperature (°F)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: sugarController,
                              decoration: const InputDecoration(
                                labelText: 'Sugar Level (mg/dL)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pulseController,
                              decoration: const InputDecoration(
                                labelText: 'Pulse Rate (bpm)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Clinical Notes',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                if (nurseController.text.trim().isEmpty ||
                                    notesController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nurse name and clinical notes required',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await _ipdController.addDailyUpdate(
                                    admission['id'],
                                    {
                                      'nurse_name': nurseController.text.trim(),
                                      'temperature': tempController.text.trim(),
                                      'blood_pressure': bpController.text
                                          .trim(),
                                      'sugar_level': sugarController.text
                                          .trim(),
                                      'pulse': pulseController.text.trim(),
                                      'notes': notesController.text.trim(),
                                    },
                                  );

                                  // Reload local list
                                  final freshAdms = await _ipdController
                                      .fetchAdmissions();
                                  final freshAdm = freshAdms.firstWhere(
                                    (element) =>
                                        element['id'] == admission['id'],
                                  );

                                  setDialogState(() {
                                    admission = freshAdm;
                                    if (freshAdm['daily_updates'] is List) {
                                      updates = freshAdm['daily_updates'];
                                    } else {
                                      updates = jsonDecode(
                                        freshAdm['daily_updates'],
                                      );
                                    }

                                    // Clear vitals inputs
                                    bpController.clear();
                                    tempController.clear();
                                    sugarController.clear();
                                    pulseController.clear();
                                    notesController.clear();
                                  });

                                  _loadData(); // Sync parent dashboard
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              child: const Text(
                                'Record Vitals / Update',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    // Right Column: Timeline / History of Vitals
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admitted Vitals History',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: updates.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No entries recorded yet.',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: updates.length,
                                    itemBuilder: (context, idx) {
                                      final item = updates[idx];
                                      final dateParsed = DateTime.parse(
                                        item['date'],
                                      );
                                      final displayDate = DateFormat(
                                        'dd/MM HH:mm',
                                      ).format(dateParsed);
                                      return Card(
                                        color: Colors.grey.shade50,
                                        elevation: 0,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    displayDate,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    'By: ${item['nurse_name']}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'BP: ${item['blood_pressure']} | Temp: ${item['temperature']}°F | Sugar: ${item['sugar_level']}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['notes'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDischargeDialog(Map<String, dynamic> admission) {
    final TextEditingController summaryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Discharge Patient: ${admission['patient_name']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bed Number: ${admission['bed_number']} (${admission['ward_type']})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Discharge Summary / Patient Advice',
                    hintText:
                        'Describe patient condition, prescribed medications on discharge, and review date...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (summaryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Discharge summary is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await _ipdController.dischargePatient(
                    admission['id'],
                    summaryController.text.trim(),
                  );
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient Discharged Successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Confirm Discharge',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDischargeSummaryView(Map<String, dynamic> admission) {
    final admitDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.parse(admission['admission_date']));
    final dischargeDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.parse(admission['discharge_date']));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Discharge Summary Card',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryLabel('Patient Name', admission['patient_name']),
                  _buildSummaryLabel(
                    'Gender / Age',
                    '${admission['patient_gender'] ?? '--'} / ${admission['patient_age'] ?? '--'} yrs',
                  ),
                  _buildSummaryLabel(
                    'Treating Doctor',
                    admission['doctor_name'],
                  ),
                  _buildSummaryLabel(
                    'Bed Number',
                    '${admission['bed_number']} (${admission['ward_type']})',
                  ),
                  _buildSummaryLabel('Admission Date', admitDate),
                  _buildSummaryLabel('Discharge Date', dischargeDate),
                  const Divider(height: 24),
                  const Text(
                    'Discharge Advice & Summary:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      admission['discharge_summary'] ?? 'No summary recorded.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Doctor Discharge Dialog (Step 9: structured fields) ─────────────────
  void _showDoctorDischargeDialog(Map<String, dynamic> admission) {
    final finalDiagnosisController = TextEditingController();
    final treatmentSummaryController = TextEditingController();
    final medicationPlanController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Initiate Discharge',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        admission['patient_name'] ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Ward / Bed',
                          '${admission['ward_type']} / ${admission['bed_number']}'),
                      _infoRow(
                          'Admitted',
                          DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(admission['admission_date']))),
                      const Divider(height: 20),
                      _sectionLabel('Discharge Details'),
                      const SizedBox(height: 12),
                      const Text('Final Diagnosis *',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: finalDiagnosisController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Primary and secondary diagnoses...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Final diagnosis is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Treatment Summary',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: treatmentSummaryController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'Procedures performed, treatments administered...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Medication Plan on Discharge',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: medicationPlanController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'Medications prescribed, dosage, duration, follow-up date...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_outlined,
                                color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'A discharge summary card will be auto-generated from the details above.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await _ipdController.dischargePatient(
                      admission['id'],
                      '',
                      finalDiagnosis: finalDiagnosisController.text.trim(),
                      treatmentSummary:
                          treatmentSummaryController.text.trim(),
                      medicationPlan: medicationPlanController.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Patient discharged. Summary card generated.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.white),
                label: const Text('Confirm Discharge',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(120, 48),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
