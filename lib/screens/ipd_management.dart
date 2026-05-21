import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';

class IPDManagementScreen extends StatefulWidget {
  final bool isMobile;

  const IPDManagementScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<IPDManagementScreen> createState() => _IPDManagementScreenState();
}

class _IPDManagementScreenState extends State<IPDManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IpdController _ipdController = IpdController();
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  List<Map<String, dynamic>> _beds = [];
  List<Map<String, dynamic>> _admissions = [];
  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  List<Map<String, dynamic>> _pendingAdmissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    try {
      final bedsList = await _ipdController.fetchBeds();
      final admissionsList = await _ipdController.fetchAdmissions();
      final patientsList = await _patientController.fetchPatients();
      final doctorsList = await _adminController.fetchStaff(role: 'Doctor');
      final pendingList = await _ipdController.fetchPendingAdmissions();
      
      if (mounted) {
        setState(() {
          _beds = bedsList;
          _admissions = admissionsList;
          _patients = patientsList;
          _doctors = doctorsList;
          _pendingAdmissions = pendingList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading IPD data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int get _admittedCount => _admissions.where((a) => a['status'] == 'Admitted').length;
  int get _availableBedsCount => _beds.where((b) => b['status'] == 'Available').length;
  int get _icuOccupancy => _admissions.where((a) => a['status'] == 'Admitted' && a['ward_type'] == 'ICU').length;

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
                      _buildPendingAdmissionsTab(),
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
      padding: EdgeInsets.fromLTRB(widget.isMobile ? 16 : 24, 24, widget.isMobile ? 16 : 24, 8),
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
                style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showAdmitDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Admit Patient', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          Expanded(child: _buildStatCard('Currently Admitted', _admittedCount.toString(), 'Patients in Wards', Icons.bedroom_child_outlined, Colors.blue)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard('Available Beds', '$_availableBedsCount/${_beds.length}', 'Ready for intake', Icons.hotel_outlined, Colors.green)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard('ICU Occupancy', _icuOccupancy.toString(), 'Critical cases', Icons.local_hospital_outlined, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String sub, IconData icon, Color color) {
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending Intake'),
                if (_pendingAdmissions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _pendingAdmissions.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Active Wards'),
          const Tab(text: 'Bed Wards & Grid'),
          const Tab(text: 'Discharge History'),
        ],
      ),
    );
  }

  Widget _buildActiveAdmissionsTab() {
    final active = _admissions.where((a) => a['status'] == 'Admitted').toList();
    if (active.isEmpty) {
      return _buildEmptyState('No active admissions.', Icons.hotel_class_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final adm = active[index];
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(adm['admission_date']));
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(adm['patient_name']?[0].toUpperCase() ?? 'P', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adm['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Bed: ${adm['bed_number']} (${adm['ward_type']}) • Admitted: $dateStr', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Treating Doctor: ${adm['doctor_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
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
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: _beds.length,
      itemBuilder: (context, index) {
        final bed = _beds[index];
        final bool isAvail = bed['status'] == 'Available';
        final Color cardColor = isAvail ? Colors.green.shade50 : Colors.red.shade50;
        final Color borderColor = isAvail ? Colors.green.shade300 : Colors.red.shade300;
        final Color textColor = isAvail ? Colors.green.shade800 : Colors.red.shade800;

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(bed['bed_number'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  Icon(Icons.king_bed, color: textColor, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ward: ${bed['ward_type']}', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(bed['status'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDischargeHistoryTab() {
    final discharged = _admissions.where((a) => a['status'] == 'Discharged').toList();
    if (discharged.isEmpty) {
      return _buildEmptyState('No discharged records.', Icons.history);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: discharged.length,
      itemBuilder: (context, index) {
        final adm = discharged[index];
        final dischargeDateStr = adm['discharge_date'] != null 
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(adm['discharge_date']))
            : '--';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: const Icon(Icons.assignment_turned_in, color: Colors.green),
            ),
            title: Text(adm['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Bed: ${adm['bed_number']} • Discharged: $dischargeDateStr\nDoctor: ${adm['doctor_name']}', style: const TextStyle(height: 1.5, fontSize: 12)),
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
          Text(text, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPendingAdmissionsTab() {
    if (_pendingAdmissions.isEmpty) {
      return _buildEmptyState('No pending admissions from OPD.', Icons.done_all_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _pendingAdmissions.length,
      itemBuilder: (context, index) {
        final pending = _pendingAdmissions[index];
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade100, width: 1.5),
          ),
          color: Colors.red.shade50.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bed_outlined, color: Colors.red.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pending['patient_name'] ?? 'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pending['patient_display_id'] ?? 'ID-N/A',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gender: ${pending['patient_gender'] ?? "N/A"}  •  Age: ${pending['patient_age'] ?? "N/A"} yrs  •  Department: ${pending['department'] ?? "N/A"}',
                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recommending Doctor: Dr. ${pending['doctor_name']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (pending['reason_for_visit'] != null && pending['reason_for_visit'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            'Reason: ${pending['reason_for_visit']}',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAdmitDialog(
                      preselectedPatientId: pending['patient_id'],
                      preselectedDoctorName: pending['doctor_name'],
                      preselectedReason: pending['reason_for_visit'],
                      preselectedAppointmentId: pending['appointment_id'],
                    );
                  },
                  icon: const Icon(Icons.hotel_outlined, size: 16, color: Colors.white),
                  label: const Text('Allocate Bed & Admit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdmitDialog({
    int? preselectedPatientId,
    String? preselectedDoctorName,
    String? preselectedReason,
    int? preselectedAppointmentId,
  }) {
    int? selectedPatientId = preselectedPatientId;
    String? selectedBedNumber;
    String? selectedWardType;
    String? selectedDoctorName = preselectedDoctorName;
    final TextEditingController reasonController = TextEditingController(text: preselectedReason ?? '');

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
              title: const Text('Admit Patient to IPD', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Select Patient', border: OutlineInputBorder()),
                        value: selectedPatientId,
                        items: _patients.map((p) => DropdownMenuItem<int>(value: p.id, child: Text('${p.name} (${p.patientId ?? p.id})'))).toList(),
                        onChanged: preselectedPatientId != null ? null : (val) => setDialogState(() => selectedPatientId = val),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Treating Doctor', border: OutlineInputBorder()),
                        value: selectedDoctorName,
                        items: _doctors.map((d) => DropdownMenuItem(value: d.fullname, child: Text(d.fullname))).toList(),
                        onChanged: (val) => setDialogState(() => selectedDoctorName = val),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Ward Type', border: OutlineInputBorder()),
                        items: ['General', 'Semi-Private', 'Private', 'ICU'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                        onChanged: updateBedsForWard,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Select Available Bed', border: OutlineInputBorder()),
                        value: selectedBedNumber,
                        items: availableBeds.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) => setDialogState(() => selectedBedNumber = val),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Reason for Admission', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedPatientId == null || selectedBedNumber == null || selectedDoctorName == null || selectedDoctorName!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    try {
                      await _ipdController.createAdmission({
                        'patient_id': selectedPatientId,
                        'appointment_id': preselectedAppointmentId,
                        'doctor_name': selectedDoctorName,
                        'bed_number': selectedBedNumber,
                        'ward_type': selectedWardType,
                        'reason_for_admission': reasonController.text.trim(),
                      });
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Patient Admitted Successfully!'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
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
              title: Text('Nursing Chart: ${admission['patient_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            const Text('Add Daily Update Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                            const SizedBox(height: 12),
                            TextField(controller: nurseController, decoration: const InputDecoration(labelText: 'Nurse Name', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(controller: bpController, decoration: const InputDecoration(labelText: 'Blood Pressure (mmHg)', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(controller: tempController, decoration: const InputDecoration(labelText: 'Temperature (°F)', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(controller: sugarController, decoration: const InputDecoration(labelText: 'Sugar Level (mg/dL)', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(controller: pulseController, decoration: const InputDecoration(labelText: 'Pulse Rate (bpm)', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Clinical Notes', isDense: true, border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                if (nurseController.text.trim().isEmpty || notesController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Nurse name and clinical notes required'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                try {
                                  await _ipdController.addDailyUpdate(admission['id'], {
                                    'nurse_name': nurseController.text.trim(),
                                    'temperature': tempController.text.trim(),
                                    'blood_pressure': bpController.text.trim(),
                                    'sugar_level': sugarController.text.trim(),
                                    'pulse': pulseController.text.trim(),
                                    'notes': notesController.text.trim(),
                                  });
                                  
                                  // Reload local list
                                  final freshAdms = await _ipdController.fetchAdmissions();
                                  final freshAdm = freshAdms.firstWhere((element) => element['id'] == admission['id']);
                                  
                                  setDialogState(() {
                                    admission = freshAdm;
                                    if (freshAdm['daily_updates'] is List) {
                                      updates = freshAdm['daily_updates'];
                                    } else {
                                      updates = jsonDecode(freshAdm['daily_updates']);
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
                                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                              child: const Text('Record Vitals / Update', style: TextStyle(color: Colors.white)),
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
                          const Text('Admitted Vitals History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: updates.isEmpty
                                ? const Center(child: Text('No entries recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 11)))
                                : ListView.builder(
                                    itemCount: updates.length,
                                    itemBuilder: (context, idx) {
                                      final item = updates[idx];
                                      final dateParsed = DateTime.parse(item['date']);
                                      final displayDate = DateFormat('dd/MM HH:mm').format(dateParsed);
                                      return Card(
                                        color: Colors.grey.shade50,
                                        elevation: 0,
                                        margin: const EdgeInsets.only(bottom: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.grey.shade200)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor)),
                                                  Text('By: ${item['nurse_name']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text('BP: ${item['blood_pressure']} | Temp: ${item['temperature']}°F | Sugar: ${item['sugar_level']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(item['notes'] ?? '', style: const TextStyle(fontSize: 11)),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
          title: Text('Discharge Patient: ${admission['patient_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bed Number: ${admission['bed_number']} (${admission['ward_type']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: summaryController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Discharge Summary / Patient Advice',
                    hintText: 'Describe patient condition, prescribed medications on discharge, and review date...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (summaryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discharge summary is required'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  await _ipdController.dischargePatient(admission['id'], summaryController.text.trim());
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Patient Discharged Successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Discharge', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDischargeSummaryView(Map<String, dynamic> admission) {
    final admitDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(admission['admission_date']));
    final dischargeDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(admission['discharge_date']));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Discharge Summary Card', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryLabel('Patient Name', admission['patient_name']),
                  _buildSummaryLabel('Gender / Age', '${admission['patient_gender'] ?? '--'} / ${admission['patient_age'] ?? '--'} yrs'),
                  _buildSummaryLabel('Treating Doctor', admission['doctor_name']),
                  _buildSummaryLabel('Bed Number', '${admission['bed_number']} (${admission['ward_type']})'),
                  _buildSummaryLabel('Admission Date', admitDate),
                  _buildSummaryLabel('Discharge Date', dischargeDate),
                  const Divider(height: 24),
                  const Text('Discharge Advice & Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Text(admission['discharge_summary'] ?? 'No summary recorded.', style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
          SizedBox(width: 140, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondaryColor))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}
