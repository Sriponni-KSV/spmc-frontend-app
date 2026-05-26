import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../widgets/custom_dropdown_search.dart';

class IPDManagementScreen extends StatefulWidget {
  final bool isMobile;

  const IPDManagementScreen({Key? key, required this.isMobile})
    : super(key: key);

  @override
  State<IPDManagementScreen> createState() => _IPDManagementScreenState();
}

class _IPDManagementScreenState extends State<IPDManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IpdController _ipdController = IpdController();
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  List<Map<String, dynamic>> _beds = [];
  List<Map<String, dynamic>> _admissions = [];
  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> bedsList = [];
    List<Map<String, dynamic>> admissionsList = [];
    List<PatientModel> patientsList = [];
    List<UserModel> doctorsList = [];
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
      patientsList = await _patientController.fetchPatients();
    } catch (_) {}
    try {
      doctorsList = await _adminController.fetchStaff(role: 'Doctor');
    } catch (_) {}

    if (mounted) {
      setState(() {
        _beds = bedsList;
        _admissions = admissionsList;
        _patients = patientsList;
        _doctors = doctorsList;
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildStatsRow(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveAdmissionsTab(),
                      _buildBedAvailabilityTab(),
                      _buildDischargeHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
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
                'IPD Admission Management',
                style: TextStyle(
                  fontSize: widget.isMobile ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Monitor bed assignments, nursing charts, and patient discharges',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
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

  Widget _buildTabBar() {
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
          const Tab(text: 'Active Wards'),
          const Tab(text: 'Bed Availability'),
          const Tab(text: 'Discharge History'),
        ],
      ),
    );
  }

  Widget _buildActiveAdmissionsTab() {
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
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showNursingDashboard(adm),
                      icon: const Icon(
                        Icons.edit_note,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Nursing Station',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5A8E),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showDischargeDialog(adm),
                      icon: const Icon(
                        Icons.logout,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Discharge',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
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
    int? selectedPatientId;
    String? selectedBedNumber;
    String? selectedWardType;
    String? selectedDoctorName;
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
                      await _ipdController.createAdmission({
                        'patient_id': selectedPatientId,
                        'doctor_name': selectedDoctorName,
                        'bed_number': selectedBedNumber,
                        'ward_type': selectedWardType,
                        'reason_for_admission': reasonController.text.trim(),
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
}
