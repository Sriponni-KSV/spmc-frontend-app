import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/logout_helper.dart';
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/nurse_shift_controller.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart';
import '../widgets/custom_dropdown_search.dart';
import '../services/api_service.dart';
import '../utils/unsaved_changes_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';

class IPDPatientDetailPage extends StatefulWidget {
  final Map<String, dynamic> admission;

  const IPDPatientDetailPage({Key? key, required this.admission})
    : super(key: key);

  @override
  State<IPDPatientDetailPage> createState() => _IPDPatientDetailPageState();
}

class _IPDPatientDetailPageState extends State<IPDPatientDetailPage>
    with TickerProviderStateMixin {
  final IpdController _ipdController = IpdController();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSimulating = false;
  String _userRole = 'Nurse';
  String _staffName = '';

  // Data Lists
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _medicationLogs = [];
  List<Map<String, dynamic>> _vitalsHistory = [];
  List<Map<String, dynamic>> _icuAlerts = [];
  List<Map<String, dynamic>> _progressNotes = [];
  List<Map<String, dynamic>> _labOrders = [];
  List<String> _medicineCatalog = [];
  final Set<int> _expandedLabOrderIds = {};


  // Prescription Form Controllers
  final _prescFormKey = GlobalKey<FormState>();
  final _medNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _freqController = TextEditingController();
  final _routeController = TextEditingController();
  final _durController = TextEditingController();
  final _instructionsController = TextEditingController();

  // Vitals Form Controllers
  final _vitalsFormKey = GlobalKey<FormState>();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _tempController = TextEditingController();
  final _pulseController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _respRateController = TextEditingController();

  // Progress Note Form Controllers
  final _progFormKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _changesController = TextEditingController();
  final _obsController = TextEditingController();

  // Lab Order Form Controllers
  final _labFormKey = GlobalKey<FormState>();
  final _testNameController = TextEditingController();



  // Discharge Form Controllers
  final _dischargeFormKey = GlobalKey<FormState>();
  final _finalDiagController = TextEditingController();
  final _treatmentSumController = TextEditingController();
  final _medPlanController = TextEditingController();

  // Medication Administration Form Controllers
  final _medAdminFormKey = GlobalKey<FormState>();
  String? _selectedPrescriptionId;
  String _selectedMedStatus = 'Given'; // Given, Missed, Delayed
  final _medRemarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    UnsavedChangesHelper.setUnsavedChanges(true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _userRole = auth.user?.role ?? 'Nurse';
    _staffName = auth.user?.fullname ?? 'Staff Member';

    final tabCount = _userRole == 'Doctor' ? 8 : 5;
    _tabController = TabController(length: tabCount, vsync: this);

    _loadAllData();
    _loadMedicineCatalog();
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _tabController.dispose();
    _medNameController.dispose();
    _dosageController.dispose();
    _freqController.dispose();
    _routeController.dispose();
    _durController.dispose();
    _instructionsController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _tempController.dispose();
    _pulseController.dispose();
    _spo2Controller.dispose();
    _respRateController.dispose();
    _noteController.dispose();
    _changesController.dispose();
    _obsController.dispose();
    _testNameController.dispose();

    _finalDiagController.dispose();
    _treatmentSumController.dispose();
    _medPlanController.dispose();
    _medRemarksController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final admissionId = widget.admission['id'];
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // Enforce shift allocation checks for Nurse role
    if (_userRole == 'Nurse' && user != null) {
      try {
        final _shiftCtrl = NurseShiftController();
        final res = await _shiftCtrl.fetchActiveShift(nurseId: user.id);
        List<String> assignedWards = [];
        if (res['success'] == true && res['active'] == true) {
          final List data = res['data'] ?? [];
          for (final w in data) {
            if (w['assigned_nurse_id']?.toString() == user.id.toString()) {
              final wType = w['ward_type']?.toString();
              if (wType != null) {
                assignedWards.add(wType);
              }
            }
          }
        }

        // Parse assigned nurse from reason_for_admission
        final String rawReason = widget.admission['reason_for_admission'] ?? '';
        String? assignedNurse;
        if (rawReason.startsWith('[Assigned Nurse: ')) {
          final endIdx = rawReason.indexOf(']');
          if (endIdx != -1) {
            assignedNurse = rawReason.substring(17, endIdx).trim().toLowerCase();
          }
        }
        final isAssignedToMe = assignedNurse != null && 
            assignedNurse == user.fullname.trim().toLowerCase();

        if (!assignedWards.contains(widget.admission['ward_type']) && !isAssignedToMe) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  assignedWards.isEmpty 
                      ? 'Access Denied: You are not assigned to an active shift today.'
                      : 'Access Denied: You are assigned to ${assignedWards.join(", ")}, but this patient is in ${widget.admission['ward_type']}.'
                ),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
      } catch (e) {
        debugPrint('Error verifying ward assignment: $e');
      }
    }

    try {
      final futures = await Future.wait([
        _ipdController.fetchPrescriptions(admissionId),
        _ipdController.fetchMedicationLogs(admissionId),
        _ipdController.fetchVitals(admissionId),
        _ipdController.fetchIcuAlerts(admissionId),
        _ipdController.fetchProgressNotes(admissionId),
        _ipdController.fetchLabOrders(admissionId),
      ]);

      if (mounted) {
        setState(() {
          _prescriptions = futures[0];
          _medicationLogs = futures[1];
          _vitalsHistory = futures[2];
          _icuAlerts = futures[3];
          _progressNotes = futures[4];
          _labOrders = futures[5];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patient data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMedicineCatalog() async {
    try {
      final baseUrl = ApiEndpoints.baseUrl;
      final response = await ApiService.get('$baseUrl/inventory/medicine-catalog');
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && mounted) {
        final data = body['data'] as List<dynamic>;
        setState(() {
          _medicineCatalog = data.map((item) => item['name'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading medicine catalog: $e');
    }
  }

  // Check if a vital value is abnormal to flag visually
  bool _isVitalAbnormal(String type, dynamic value) {
    if (value == null) return false;
    num? parsedValue;
    if (value is num) {
      parsedValue = value;
    } else if (value is String) {
      parsedValue = num.tryParse(value);
    }
    if (parsedValue == null) return false;

    if (type == 'SPO2' && parsedValue < 90) return true;
    if (type == 'BP_SYS' && (parsedValue < 90 || parsedValue > 160))
      return true;
    if (type == 'TEMP' && parsedValue > 101) return true;
    if (type == 'PULSE' && (parsedValue < 50 || parsedValue > 120)) return true;
    return false;
  }

  // --- ACTIONS ---

  Future<void> _addPrescription() async {
    if (!_prescFormKey.currentState!.validate()) return;

    try {
      await _ipdController.createPrescription(widget.admission['id'], {
        'patient_id': widget.admission['patient_id'],
        'doctor_name': _staffName,
        'medicine_name': _medNameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _freqController.text.trim(),
        'route': _routeController.text.trim(),
        'duration': _durController.text.trim(),
        'instructions': _instructionsController.text.trim(),
      });

      _medNameController.clear();
      _dosageController.clear();
      _freqController.clear();
      _routeController.clear();
      _durController.clear();
      _instructionsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopPrescription(int id) async {
    try {
      await _ipdController.stopPrescription(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription stopped!'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitMedicationLog({
    required int prescriptionId,
    required String status,
    required String remarks,
  }) async {
    try {
      await _ipdController.createMedicationLog(widget.admission['id'], {
        'prescription_id': prescriptionId,
        'patient_id': widget.admission['patient_id'],
        'nurse_name': _staffName,
        'status': status,
        'remarks': remarks,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medication logged as "$status" successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showMedicationDeviationDialog(Map<String, dynamic> prescription) {
    final remarksController = TextEditingController();
    String selectedStatus = 'Missed';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('Record Medication Deviation'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medicine: ${prescription['medicine_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Missed', child: Text('Missed')),
                      DropdownMenuItem(
                        value: 'Delayed',
                        child: Text('Delayed'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          selectedStatus = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Remarks / Reason',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Enter reason (e.g. Patient asleep, NPO, Refused...)',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitMedicationLog(
                      prescriptionId: prescription['id'],
                      status: selectedStatus,
                      remarks: remarksController.text.trim(),
                    );
                  },
                  child: const Text('Log Deviation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitVitals() async {
    if (!_vitalsFormKey.currentState!.validate()) return;

    try {
      await _ipdController.createVitals(widget.admission['id'], {
        'patient_id': widget.admission['patient_id'],
        'blood_pressure_systolic': int.tryParse(
          _bpSystolicController.text.trim(),
        ),
        'blood_pressure_diastolic': int.tryParse(
          _bpDiastolicController.text.trim(),
        ),
        'temperature': double.tryParse(_tempController.text.trim()),
        'pulse': int.tryParse(_pulseController.text.trim()),
        'spo2': int.tryParse(_spo2Controller.text.trim()),
        'respiratory_rate': int.tryParse(_respRateController.text.trim()),
      });

      _bpSystolicController.clear();
      _bpDiastolicController.clear();
      _tempController.clear();
      _pulseController.clear();
      _spo2Controller.clear();
      _respRateController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vitals recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resolveAlert(int id) async {
    try {
      await _ipdController.resolveIcuAlert(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert resolved!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _simulateVitals({
    required double spo2,
    required double systolic,
    required double diastolic,
    required double temp,
    required double pulse,
    required double respRate,
    required String description,
  }) async {
    setState(() => _isSimulating = true);
    try {
      final admissionId = widget.admission['id'];
      final patientId = widget.admission['patient_id'];

      await _ipdController.createVitals(admissionId, {
        'patient_id': patientId,
        'spo2': spo2,
        'blood_pressure_systolic': systolic,
        'blood_pressure_diastolic': diastolic,
        'temperature': temp,
        'pulse': pulse,
        'respiratory_rate': respRate,
        'reason_for_visit': 'ICU Telemetry: $description',
      });

      await _loadAllData();

      if (mounted) {
        final activeAlerts = _icuAlerts.where((a) => a['status'] == 'Active').toList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Telemetry Logged: $description.' +
              (activeAlerts.isNotEmpty
                  ? ' ⚠️ Critical Alert Triggered: ${activeAlerts.first['alert_message']}'
                  : ' Vitals within safe range.'),
            ),
            backgroundColor: activeAlerts.isNotEmpty ? Colors.red : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
    }
  }

  Future<void> _submitProgressNote() async {
    if (!_progFormKey.currentState!.validate()) return;

    try {
      final String notesText = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : (_obsController.text.trim().isNotEmpty
              ? _obsController.text.trim()
              : 'Vitals updated');

      await _ipdController.createProgressNote(widget.admission['id'], {
        'patient_id': widget.admission['patient_id'],
        'doctor_name': _staffName,
        'notes': notesText,
        'treatment_changes': _changesController.text.trim(),
        'observation': _obsController.text.trim(),
      });

      // Also save vitals if any vital field is filled (e.g. from the Nursing Notes tab)
      final String bpText = _bpSystolicController.text.trim();
      final String tempText = _tempController.text.trim();
      final String pulseText = _pulseController.text.trim();
      final String spo2Text = _spo2Controller.text.trim();

      if (bpText.isNotEmpty || tempText.isNotEmpty || pulseText.isNotEmpty || spo2Text.isNotEmpty) {
        int? sys;
        int? dia;
        if (bpText.isNotEmpty) {
          if (bpText.contains('/')) {
            final parts = bpText.split('/');
            sys = int.tryParse(parts[0].trim());
            dia = int.tryParse(parts[1].trim());
          } else {
            sys = int.tryParse(bpText);
          }
        }

        await _ipdController.createVitals(widget.admission['id'], {
          'patient_id': widget.admission['patient_id'],
          'blood_pressure_systolic': sys,
          'blood_pressure_diastolic': dia,
          'temperature': double.tryParse(tempText),
          'pulse': int.tryParse(pulseText),
          'spo2': int.tryParse(spo2Text),
        });

        _bpSystolicController.clear();
        _tempController.clear();
        _pulseController.clear();
        _spo2Controller.clear();
      }

      _noteController.clear();
      _changesController.clear();
      _obsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitLabOrder() async {
    if (!_labFormKey.currentState!.validate()) return;

    try {
      await _ipdController.createLabOrder(widget.admission['id'], {
        'patient_id': widget.admission['patient_id'],
        'test_name': _testNameController.text.trim(),
        'doctor_name': _staffName,
      });

      _testNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab test ordered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ordering test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateLabStatus(int id, String status) async {
    try {
      await _ipdController.updateLabOrderStatus(id, {'status': status});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lab status updated to: $status'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goBack() {
    try {
      final path = GoRouterState.of(context).matchedLocation;
      if (path == '/nurse/ipd-management/nursing-station') {
        context.go('/nurse/ipd-management');
      } else if (path == '/doctor/ipd-management/monitoring') {
        context.go('/doctor/ipd-management');
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _executeDischarge() async {
    if (!_dischargeFormKey.currentState!.validate()) return;

    try {
      await _ipdController.dischargePatient(
        widget.admission['id'],
        '',
        finalDiagnosis: _finalDiagController.text.trim(),
        treatmentSummary: _treatmentSumController.text.trim(),
        medicationPlan: _medPlanController.text.trim(),
      );

      _finalDiagController.clear();
      _treatmentSumController.clear();
      _medPlanController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient successfully discharged!'),
          backgroundColor: Colors.green,
        ),
      );
      _goBack();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error discharging: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- RENDER METHODS ---

  Widget _buildSidebarItem(
    IconData icon,
    String label,
    String routePath,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        final router = GoRouter.of(context);
        final scaffoldState = Scaffold.maybeOf(context);
        if (scaffoldState != null && scaffoldState.isDrawerOpen) {
          Navigator.of(context).pop(); // Close drawer
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Pop IPDPatientDetailPage
        }
        router.go(routePath);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSidebar() {
    final bool isAdmin =
        _userRole == 'Admin' ||
        _userRole == 'Supervisor' ||
        _userRole == 'Super Admin';
    final bool isDoctor = _userRole == 'Doctor';

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.only(
              left: 24,
              top: 0,
              bottom: 0,
              right: 24,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/image/full_logo.png',
                  width: 100,
                  height: 89,
                ),
              ],
            ),
          ),

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  if (isDoctor) ...[
                    _buildSidebarItem(
                      Icons.grid_view_outlined,
                      'Dashboard',
                      AppRoutes.doctorDashboard,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.history_edu_outlined,
                      'My Consultations',
                      AppRoutes.doctorPatients,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.local_hospital_outlined,
                      'IPD Management',
                      AppRoutes.doctorIpd,
                      true,
                    ),
                    _buildSidebarItem(
                      Icons.healing_outlined,
                      'OT Management',
                      AppRoutes.doctorOt,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.person_outline,
                      'My Profile',
                      AppRoutes.doctorProfile,
                      false,
                    ),
                  ] else if (isAdmin) ...[
                    _buildSidebarItem(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      AppRoutes.adminDashboard,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.people_outline,
                      'Staff Management',
                      AppRoutes.adminUsers,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.people_outline,
                      'Patients',
                      AppRoutes.adminPatients,
                      false,
                    ),
                    if (_userRole == 'Super Admin')
                      _buildSidebarItem(
                        Icons.settings_suggest_outlined,
                        'RBAC Settings',
                        AppRoutes.adminSettings,
                        false,
                      ),
                    _buildSidebarItem(
                      Icons.calendar_today_outlined,
                      'Appointments',
                      AppRoutes.adminAppointments,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.local_hospital_outlined,
                      'OPD Assistance',
                      AppRoutes.adminOpd,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.bedroom_child_outlined,
                      'IPD Management',
                      AppRoutes.adminIpd,
                      true,
                    ),
                    _buildSidebarItem(
                      Icons.healing_outlined,
                      'OT Management',
                      AppRoutes.adminOt,
                      false,
                    ),
                  ] else ...[
                    // Nurse
                    _buildSidebarItem(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      AppRoutes.nurseDashboard,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.people_outline,
                      'Patients',
                      AppRoutes.nursePatients,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.calendar_today_outlined,
                      'Appointments',
                      AppRoutes.nurseAppointments,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.medical_services_outlined,
                      'Doctors',
                      AppRoutes.nurseDoctors,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.local_hospital_outlined,
                      'OPD Assistance',
                      AppRoutes.nurseOpd,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.bedroom_child_outlined,
                      'IPD Management',
                      AppRoutes.nurseIpd,
                      true,
                    ),
                    _buildSidebarItem(
                      Icons.healing_outlined,
                      'OT Management',
                      AppRoutes.nurseOt,
                      false,
                    ),
                    _buildSidebarItem(
                      Icons.person_outline,
                      'Profile',
                      AppRoutes.nurseProfile,
                      false,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // User Profile Footer
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                color: AppTheme.borderColor,
                height: 1,
                thickness: 1,
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.user;
                    if (user == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: CircleAvatar(
                            backgroundColor: AppTheme.getAvatarColors(
                              user.fullname,
                            )['bg'],
                            radius: 18,
                            child: Text(
                              user.fullname.isNotEmpty
                                  ? user.fullname[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppTheme.getAvatarColors(
                                  user.fullname,
                                )['text'],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: AppTheme.textSecondaryColor,
                          ),
                          onPressed: () => LogoutHelper.showLogoutConfirmation(
                            context,
                            auth,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavbar(bool isMobile) {
    return Container(
      height: isMobile ? 80 : 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        children: [
          if (isMobile) ...[
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextFormField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: isMobile ? 'Search...' : 'Quick search...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: const EdgeInsets.only(top: 2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                readOnly: true,
              ),
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Spacer(),
            const Icon(
              Icons.notifications_none_outlined,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 16),
            const Icon(Icons.help_outline, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: AppTheme.primaryButton.copyWith(
                minimumSize: WidgetStateProperty.all(const Size(80, 40)),
              ),
              child: const Text('Share', style: TextStyle(fontSize: 14)),
            ),
          ],
          SizedBox(width: isMobile ? 12 : 24),

          // Date & Time
          const LiveClock(),
        ],
      ),
    );
  }

  Widget _buildPatientInfoBar() {
    final adm = widget.admission;
    final patientName = adm['patient_name'] ?? 'IPD Patient';
    final wardType = adm['ward_type'] ?? '--';
    final bedNumber = adm['bed_number'] ?? '--';
    final status = adm['status'] ?? 'Admitted';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: _goBack,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Patient Info
          Expanded(
            child: Row(
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.bed_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Bed $bedNumber • $wardType',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Admitted'
                        ? AppTheme.successBg
                        : status == 'Discharged'
                        ? Colors.grey.shade100
                        : AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status == 'Admitted'
                          ? AppTheme.successColor
                          : status == 'Discharged'
                          ? Colors.grey
                          : AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(
              Icons.refresh,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'Refresh data',
            onPressed: _loadAllData,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final doctorTabs = [
      const Tab(text: 'Overview'),
      const Tab(text: 'Vitals'),
      const Tab(text: 'Prescription'),
      const Tab(text: 'Nurse Notes'),
      const Tab(text: 'Lab Reports'),
      const Tab(text: 'Progress Notes'),
      const Tab(text: 'ICU Monitoring'),
      const Tab(text: 'Discharge'),
    ];

    final nurseTabs = [
      const Tab(text: 'Vitals Entry'),
      const Tab(text: 'Medication Admin'),
      const Tab(text: 'Nursing Notes'),
      const Tab(text: 'Lab Coordination'),
      const Tab(text: 'ICU Alerts'),
    ];

    final Widget contentArea = Column(
      children: [
        // Top Navbar (dashboard style)
        _buildTopNavbar(isMobile),
        // Patient Info Bar
        _buildPatientInfoBar(),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
            tabs: _userRole == 'Doctor' ? doctorTabs : nurseTabs,
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
        // Tab Body
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _userRole == 'Doctor'
                      ? [
                          _buildOverviewTab(),
                          _buildDoctorVitalsTab(),
                          _buildDoctorPrescriptionTab(),
                          _buildDoctorNurseNotesTab(),
                          _buildDoctorLabTab(),
                          _buildDoctorProgressNotesTab(),
                          _buildDoctorIcuTab(),
                          _buildDoctorDischargeTab(),
                        ]
                      : [
                          _buildNurseVitalsEntryTab(),
                          _buildNurseMedAdminTab(),
                          _buildNurseNotesTab(),
                          _buildNurseLabTab(),
                          _buildNurseIcuTab(),
                        ],
                ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildRoleSidebar()) : null,
      appBar: isMobile
          ? AppBar(
              title: Text(
                widget.admission['patient_name'] ?? 'IPD Patient',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimaryColor,
              elevation: 0,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) _buildRoleSidebar(),
          Expanded(child: contentArea),
        ],
      ),
    );
  }

  // --- DOCTOR & SHARED TABS ---

  Widget _buildOverviewTab() {
    final adm = widget.admission;
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final dateStr = DateFormat(
      'dd/MM/yyyy hh:mm a',
    ).format(DateTime.parse(adm['admission_date']).toLocal());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP HEADER
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_hospital,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Admission Details',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Patient admission info',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Admitted',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Admission Details',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Current patient admission information',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Admitted',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 30),

              // PATIENT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white,
                      child: Text(
                        adm['patient_name']
                            .toString()
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 18),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adm['patient_name'] ?? '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              _buildInfoBadge(
                                Icons.badge_outlined,
                                adm['patient_display_id'] ?? '--',
                              ),

                              _buildInfoBadge(
                                Icons.person_outline,
                                '${adm['patient_age']} Years',
                              ),

                              _buildInfoBadge(
                                Icons.wc,
                                adm['patient_gender'] ?? '--',
                              ),

                              _buildInfoBadge(
                                Icons.bed_outlined,
                                adm['bed_number'] ?? '--',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // DETAILS GRID
              GridView.count(
                crossAxisCount: isMobile ? 1 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: isMobile ? 4.5 : 3.8,
                children: [
                  _buildOverviewTile(
                    'Admission Type',
                    adm['ward_type'] == 'ICU' ? 'ICU' : 'IPD',
                    Icons.local_hospital_outlined,
                  ),

                  _buildOverviewTile(
                    'Date of Admission',
                    dateStr,
                    Icons.calendar_today_outlined,
                  ),

                  _buildOverviewTile(
                    'Treating Doctor',
                    adm['doctor_name'] ?? '--',
                    Icons.person_outline,
                    subtitle: adm['doctor_display_id'],
                  ),

                  _buildOverviewTile(
                    'Room / Bed',
                    '${adm['bed_number']} (${adm['ward_type']})',
                    Icons.hotel_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // REASON
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reason For Admission',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            adm['reason_for_admission'] ?? '--',
                            style: TextStyle(
                              height: 1.5,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTile(String title, String value, IconData icon, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),

                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),

          const SizedBox(width: 6),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsHistoryList({
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    if (_vitalsHistory.isEmpty) {
      return _buildEmptyState('No vitals logged yet.', Icons.monitor_heart);
    }

    return ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: _vitalsHistory.length,
      itemBuilder: (context, index) {
        final v = _vitalsHistory[index];
        final recordedAt = DateFormat(
          'dd/MM/yyyy hh:mm a',
        ).format(DateTime.parse(v['created_at']).toLocal());

        final hasLowSpo2 =
            v['spo2'] != null && _isVitalAbnormal('SPO2', v['spo2']);
        final hasAbnormalBP =
            v['blood_pressure_systolic'] != null &&
            _isVitalAbnormal('BP_SYS', v['blood_pressure_systolic']);
        final hasFever =
            v['temperature'] != null &&
            _isVitalAbnormal('TEMP', v['temperature']);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: (hasLowSpo2 || hasAbnormalBP || hasFever)
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
              width: (hasLowSpo2 || hasAbnormalBP || hasFever) ? 1.5 : 1,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          color: (hasLowSpo2 || hasAbnormalBP || hasFever)
              ? Colors.red.shade50.withOpacity(0.5)
              : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recorded on: $recordedAt',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (hasLowSpo2 || hasAbnormalBP || hasFever)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ABNORMAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildVitalParam(
                      'BP',
                      '${v['blood_pressure_systolic'] ?? '--'}/${v['blood_pressure_diastolic'] ?? '--'} mmHg',
                      hasAbnormalBP,
                    ),
                    _buildVitalParam(
                      'Temp',
                      '${v['temperature'] ?? '--'} °F',
                      hasFever,
                    ),
                    _buildVitalParam(
                      'Pulse',
                      '${v['pulse'] ?? '--'} bpm',
                      v['pulse'] != null &&
                          _isVitalAbnormal('PULSE', v['pulse']),
                    ),
                    _buildVitalParam(
                      'SPO2',
                      '${v['spo2'] ?? '--'} %',
                      hasLowSpo2,
                    ),
                    _buildVitalParam(
                      'Resp Rate',
                      '${v['respiratory_rate'] ?? '--'} bpm',
                      false,
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

  Widget _buildDoctorVitalsTab() {
    return _buildVitalsHistoryList();
  }

  Widget _buildVitalParam(String label, String value, bool isAbnormal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isAbnormal ? Colors.red : Colors.black,
          ),
        ),
      ],
    );
  }
  Widget _buildDoctorPrescriptionTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget formCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _prescFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Prescription',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create medication prescription for patient',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // MEDICINE NAME
              CustomDropdownSearch(
                label: 'Medicine Name',
                value: _medNameController.text.isEmpty ? null : _medNameController.text,
                dropdownItems: _medicineCatalog,
                hint: 'Select or search medicine',
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _medNameController.text = val;
                      // Auto-extract and populate dosage if found in catalog name
                      final match = RegExp(r'\d+\s*(?:mg/ml|IU/ml|mg|mcg|g|ml|IU)', caseSensitive: false).firstMatch(val);
                      if (match != null) {
                        _dosageController.text = match.group(0) ?? '';
                      }
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              // DOSAGE + FREQUENCY
              isMobile
                  ? Column(
                      children: [
                        _buildPrescriptionField(
                          controller: _dosageController,
                          label: 'Dosage',
                          hint: '500mg',
                          icon: Icons.scale_outlined,
                          maxLength: 10,
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        _buildPrescriptionField(
                          controller: _freqController,
                          label: 'Frequency',
                          hint: '1-0-1',
                          icon: Icons.schedule_outlined,
                          maxLength: 7,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildPrescriptionField(
                            controller: _dosageController,
                            label: 'Dosage',
                            hint: '500mg',
                            icon: Icons.scale_outlined,
                            maxLength: 10,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildPrescriptionField(
                            controller: _freqController,
                            label: 'Frequency',
                            hint: '1-0-1',
                            icon: Icons.schedule_outlined,
                            maxLength: 7,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                            ],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 20),

              // ROUTE + DURATION
              isMobile
                  ? Column(
                      children: [
                        _buildPrescriptionField(
                          controller: _routeController,
                          label: 'Route',
                          hint: 'Oral / IV',
                          icon: Icons.route_outlined,
                          maxLength: 15,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z/ ]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildPrescriptionField(
                          controller: _durController,
                          label: 'Duration',
                          hint: '5 Days',
                          icon: Icons.calendar_today_outlined,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildPrescriptionField(
                            controller: _routeController,
                            label: 'Route',
                            hint: 'Oral / IV',
                            icon: Icons.route_outlined,
                            maxLength: 15,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z/ ]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildPrescriptionField(
                            controller: _durController,
                            label: 'Duration',
                            hint: '5 Days',
                            icon: Icons.calendar_today_outlined,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                            ],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 24),

              // INSTRUCTIONS
              const Text(
                'Special Instructions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _instructionsController,
                maxLines: 5,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: 'Enter special medication instructions...',
                  alignLabelWithHint: true,
                  counterText: '',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 90),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _addPrescription,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Medicine',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget listCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.list_alt_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Prescriptions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Currently active patient medications',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_prescriptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active prescriptions',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._prescriptions.map((prescription) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.medication,
                              color: Colors.green,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prescription['medicine_name'] ?? '--',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${prescription['dosage']} • ${prescription['frequency']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: prescription['status'] == 'Active'
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              prescription['status'] ?? '--',
                              style: TextStyle(
                                color:
                                    prescription['status'] == 'Active'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildPrescriptionChip(
                            'Route',
                            prescription['route'] ?? '--',
                            Icons.route_outlined,
                          ),
                          _buildPrescriptionChip(
                            'Duration',
                            prescription['duration'] ?? '--',
                            Icons.calendar_today_outlined,
                          ),
                        ],
                      ),

                      if ((prescription['instructions'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              prescription['instructions'],
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ),

                      const SizedBox(height: 18),

                      if (prescription['status'] == 'Active')
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _stopPrescription(prescription['id']),
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Stop Prescription',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                formCard,
                const SizedBox(height: 24),
                listCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formCard),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: listCard),
              ],
            ),
    );
  }

  Widget _buildPrescriptionField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            counterText: maxLength != null ? '' : null,
            prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 18),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? Colors.grey.shade300 : AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionChip(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '$title: $value',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorNurseNotesTab() {
    // Shows daily updates logged by nurse in a beautiful list
    // Look at: widget.admission['daily_updates'] JSON list
    List<dynamic> nurseUpdates = [];
    try {
      final du = widget.admission['daily_updates'];
      if (du != null) {
        nurseUpdates = du is List ? du : jsonDecode(du);
      }
    } catch (_) {}

    if (nurseUpdates.isEmpty) {
      return _buildEmptyState('No nursing updates recorded.', Icons.notes);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: nurseUpdates.length,
      itemBuilder: (context, index) {
        final u = nurseUpdates[index];
        final date = u['date'] != null
            ? DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(DateTime.parse(u['date']).toLocal())
            : '--';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recorded by Nurse: ${u['nurse_name'] ?? '--'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  children: [
                    Text('BP: ${u['blood_pressure'] ?? '--'}'),
                    Text('Temp: ${u['temperature'] ?? '--'} °F'),
                    Text('Pulse: ${u['pulse'] ?? '--'} bpm'),
                    Text('Sugar: ${u['sugar_level'] ?? '--'} mg/dL'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Observations:\n${u['notes'] ?? '--'}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoctorLabTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget formCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _labFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Lab Test',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Request laboratory investigations for patient',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              CustomDropdownSearch(
                label: 'Test Name',
                value: _testNameController.text.isEmpty
                    ? null
                    : _testNameController.text,
                hint: 'Select lab test',
                dropdownItems: const [
                  'Complete Blood Count (CBC)',
                  'Blood Sugar',
                  'Liver Function Test (LFT)',
                  'Renal Function Test (RFT)',
                  'Urine Routine',
                  'X-Ray',
                  'CT Scan',
                  'MRI Scan',
                  'ECG',
                ],
                onChanged: (value) {
                  setState(() {
                    _testNameController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select lab test';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitLabOrder,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Order Test',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget historyCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lab Test History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Previously ordered laboratory tests',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_labOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No lab tests ordered',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._labOrders.map((lab) {
                final status = (lab['status'] ?? 'Pending').toString();
                final int labId = lab['id'] is int ? lab['id'] : int.parse(lab['id'].toString());
                final isExpanded = _expandedLabOrderIds.contains(labId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: status == 'Completed'
                        ? () {
                            setState(() {
                              if (isExpanded) {
                                _expandedLabOrderIds.remove(labId);
                              } else {
                                _expandedLabOrderIds.add(labId);
                              }
                            });
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.green.withOpacity(
                                  0.1,
                                ),
                                child: const Icon(
                                  Icons.science,
                                  color: Colors.green,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lab['test_name'] ?? '--',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ordered by Dr. ${lab['doctor_name'] ?? '--'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'Completed'
                                      ? Colors.green.shade50
                                      : status == 'In Progress'
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Completed'
                                        ? Colors.green
                                        : status == 'In Progress'
                                        ? Colors.orange
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (status == 'Completed') ...[
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),

                          if (status != 'Completed' || isExpanded) ...[
                            const SizedBox(height: 18),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildLabChip(
                                  'Ordered',
                                  lab['created_at'] != null
                                      ? DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(lab['created_at']).toLocal(),
                                        )
                                      : '--',
                                  Icons.calendar_today_outlined,
                                ),

                                _buildLabChip(
                                  'Status',
                                  status,
                                  Icons.info_outline,
                                ),
                              ],
                            ),

                            if (status == 'Completed') ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.description_outlined,
                                          size: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Lab Results / Notes',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (lab['result_notes'] ?? '')
                                              .toString()
                                              .isNotEmpty
                                          ? lab['result_notes']
                                          : 'No result notes entered.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                formCard,
                const SizedBox(height: 24),
                historyCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formCard),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: historyCard),
              ],
            ),
    );
  }

  Widget _buildLabChip(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '$title: $value',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorProgressNotesTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget formCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _progFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Progress Note',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Record doctor observations and treatment updates',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // MAIN NOTE
              const Text(
                'Observation / Note',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _noteController,
                maxLines: 5,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: 'Enter patient progress notes...',
                  counterText: '',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 90),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter note';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // TREATMENT CHANGES
              const Text(
                'Treatment Changes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _changesController,
                maxLines: 3,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: 'Medication updates, dosage changes...',
                  counterText: '',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 45),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // OBSERVATIONS
              const Text(
                'Additional Observations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _obsController,
                maxLines: 3,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: 'Clinical observations...',
                  counterText: '',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 45),
                    child: Icon(
                      Icons.visibility_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitProgressNote,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Progress Note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget historyCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: Colors.green),
                ),

                const SizedBox(width: 12),

                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Note History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Previously recorded doctor progress notes',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_progressNotes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'No progress notes recorded',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._progressNotes.map((note) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.green,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['doctor_name'] ?? 'Doctor',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  note['created_at'] != null
                                      ? DateFormat(
                                          'dd/MM/yyyy hh:mm a',
                                        ).format(
                                          DateTime.parse(
                                            note['created_at'],
                                          ).toLocal(),
                                        )
                                      : '--',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // MAIN NOTE
                      _buildProgressInfoBox(
                        'Progress Note',
                        note['notes'] ?? '--',
                        Icons.description_outlined,
                      ),

                      if ((note['treatment_changes'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _buildProgressInfoBox(
                            'Treatment Changes',
                            note['treatment_changes'],
                            Icons.medical_services_outlined,
                          ),
                        ),

                      if ((note['observation'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _buildProgressInfoBox(
                            'Additional Observations',
                            note['observation'],
                            Icons.visibility_outlined,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                formCard,
                const SizedBox(height: 24),
                historyCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formCard),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: historyCard),
              ],
            ),
    );
  }

  Widget _buildProgressInfoBox(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(value, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonIcuNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.monitor_heart_outlined, color: Colors.blueGrey.shade300, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'ICU Monitoring Inactive',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This patient is currently admitted to a ${widget.admission['ward_type'] ?? 'regular'} bed. ICU Telemetry and active alert logging are only available for patients admitted to ICU beds.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedsideMonitor(Map<String, dynamic>? latestVitals) {
    final bool hasData = latestVitals != null;
    
    final pulseVal = hasData ? latestVitals['pulse']?.toString() ?? '--' : '--';
    final spo2Val = hasData ? latestVitals['spo2']?.toString() ?? '--' : '--';
    final sysVal = hasData ? latestVitals['blood_pressure_systolic']?.toString() ?? '--' : '--';
    final diaVal = hasData ? latestVitals['blood_pressure_diastolic']?.toString() ?? '--' : '--';
    final tempVal = hasData ? latestVitals['temperature']?.toString() ?? '--' : '--';
    
    final pulseAbnormal = hasData && latestVitals['pulse'] != null && _isVitalAbnormal('PULSE', latestVitals['pulse']);
    final spo2Abnormal = hasData && latestVitals['spo2'] != null && _isVitalAbnormal('SPO2', latestVitals['spo2']);
    final bpAbnormal = hasData && latestVitals['blood_pressure_systolic'] != null && _isVitalAbnormal('BP_SYS', latestVitals['blood_pressure_systolic']);
    final tempAbnormal = hasData && latestVitals['temperature'] != null && _isVitalAbnormal('TEMP', latestVitals['temperature']);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blueGrey.shade800, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          (() {
            final bool isMobile = MediaQuery.of(context).size.width < 900;
            return isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monitor_heart, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ICU BEDSIDE MONITOR - BED ${widget.admission['bed_number'] ?? 'ICU'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PulseDot(active: hasData && !pulseAbnormal, alert: pulseAbnormal),
                          const SizedBox(width: 6),
                          Text(
                            hasData ? 'TELEMETRY LIVE' : 'MONITOR STANDBY',
                            style: TextStyle(
                              color: hasData 
                                ? (pulseAbnormal || spo2Abnormal ? Colors.redAccent : Colors.greenAccent) 
                                : Colors.amberAccent,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monitor_heart, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ICU BEDSIDE MONITOR - BED ${widget.admission['bed_number'] ?? 'ICU'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _PulseDot(active: hasData && !pulseAbnormal, alert: pulseAbnormal),
                          const SizedBox(width: 6),
                          Text(
                            hasData ? 'TELEMETRY LIVE' : 'MONITOR STANDBY',
                            style: TextStyle(
                              color: hasData 
                                ? (pulseAbnormal || spo2Abnormal ? Colors.redAccent : Colors.greenAccent) 
                                : Colors.amberAccent,
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
          })(),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width < 800 ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildTelemetryCell(
                title: 'PULSE / HR',
                value: pulseVal,
                unit: 'bpm',
                icon: Icons.favorite,
                color: const Color(0xFF10B981),
                isAbnormal: pulseAbnormal,
                hasData: pulseVal != '--',
              ),
              _buildTelemetryCell(
                title: 'SPO2',
                value: spo2Val,
                unit: '%',
                icon: Icons.opacity,
                color: const Color(0xFF06B6D4),
                isAbnormal: spo2Abnormal,
                hasData: spo2Val != '--',
              ),
              _buildTelemetryCell(
                title: 'BLOOD PRESSURE',
                value: hasData && sysVal != '--' ? '$sysVal/$diaVal' : '--',
                unit: 'mmHg',
                icon: Icons.bloodtype,
                color: const Color(0xFFF59E0B),
                isAbnormal: bpAbnormal,
                hasData: sysVal != '--',
              ),
              _buildTelemetryCell(
                title: 'TEMPERATURE',
                value: tempVal,
                unit: '°F',
                icon: Icons.thermostat,
                color: const Color(0xFFEC4899),
                isAbnormal: tempAbnormal,
                hasData: tempVal != '--',
              ),
            ],
          ),
          if (!hasData) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade800.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amberAccent.shade200, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'No vitals telemetry streamed. Use the simulator below to log baseline vitals.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            (() {
              final bool isMobile = MediaQuery.of(context).size.width < 900;
              return isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Streamed: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(latestVitals['created_at']).toLocal())}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        if (pulseAbnormal || spo2Abnormal || bpAbnormal || tempAbnormal) ...[
                          const SizedBox(height: 6),
                          const _BlinkingAlertText(),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last Streamed: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(latestVitals['created_at']).toLocal())}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        if (pulseAbnormal || spo2Abnormal || bpAbnormal || tempAbnormal)
                          const _BlinkingAlertText(),
                      ],
                    );
            })(),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryCell({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isAbnormal,
    required bool hasData,
  }) {
    final displayColor = isAbnormal ? Colors.redAccent : color;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAbnormal ? Colors.redAccent.withOpacity(0.8) : Colors.blueGrey.shade800,
          width: isAbnormal ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              Icon(
                icon,
                color: displayColor.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: displayColor,
                    fontSize: value.length > 5 ? 16 : 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isAbnormal 
                  ? Colors.red.withOpacity(0.2) 
                  : (hasData ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isAbnormal ? 'CRITICAL' : (hasData ? 'NORMAL' : 'STANDBY'),
              style: TextStyle(
                color: isAbnormal ? Colors.redAccent : (hasData ? color : Colors.grey.shade500),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationPanel() {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'ICU Telemetry Simulator',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                if (_isSimulating) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Verify the bedside monitor and critical ICU alert triggers on-the-fly using preset telemetry signs:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSimButton(
                  label: 'Normal Vitals',
                  description: 'Pulse 72 | SPO2 98% | BP 120/80',
                  color: Colors.green,
                  onPressed: _isSimulating ? null : () => _simulateVitals(
                    spo2: 98,
                    systolic: 120,
                    diastolic: 80,
                    temp: 98.4,
                    pulse: 72,
                    respRate: 16,
                    description: 'Normal Vitals Preset',
                  ),
                ),
                _buildSimButton(
                  label: 'Critical SPO2 (Hypoxia)',
                  description: 'SPO2 88% (Threshold < 90%)',
                  color: Colors.red,
                  onPressed: _isSimulating ? null : () => _simulateVitals(
                    spo2: 88,
                    systolic: 110,
                    diastolic: 70,
                    temp: 98.6,
                    pulse: 85,
                    respRate: 22,
                    description: 'Critical SPO2 (Hypoxia)',
                  ),
                ),
                _buildSimButton(
                  label: 'Critical BP (Hypertension)',
                  description: 'BP Systolic 175 (Threshold > 170)',
                  color: Colors.orange,
                  onPressed: _isSimulating ? null : () => _simulateVitals(
                    spo2: 96,
                    systolic: 175,
                    diastolic: 95,
                    temp: 98.2,
                    pulse: 98,
                    respRate: 18,
                    description: 'Critical BP (Hypertension)',
                  ),
                ),
                _buildSimButton(
                  label: 'High Fever (Hyperpyrexia)',
                  description: 'Temp 103.0°F (Threshold > 102°F)',
                  color: Colors.pink,
                  onPressed: _isSimulating ? null : () => _simulateVitals(
                    spo2: 95,
                    systolic: 115,
                    diastolic: 75,
                    temp: 103.0,
                    pulse: 110,
                    respRate: 20,
                    description: 'High Fever (Hyperpyrexia)',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimButton({
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorIcuTab() {
    if (widget.admission['ward_type'] != 'ICU') {
      return _buildNonIcuNotice();
    }

    final activeAlerts = _icuAlerts
        .where((a) => a['status'] == 'Active')
        .toList();
    final resolvedAlerts = _icuAlerts
        .where((a) => a['status'] == 'Resolved')
        .toList();

    final latestVitals = _vitalsHistory.isNotEmpty ? _vitalsHistory.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBedsideMonitor(latestVitals),
          const SizedBox(height: 20),
          _buildSimulationPanel(),
          const SizedBox(height: 24),
          const Text(
            'Active ICU Alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          if (activeAlerts.isEmpty)
            const Text('No active critical alerts.')
          else
            ...activeAlerts.map((a) => _buildAlertCard(a, true)),
          const Divider(height: 40),
          const Text(
            'Resolved Alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          if (resolvedAlerts.isEmpty)
            const Text('No past alerts.')
          else
            ...resolvedAlerts.map((a) => _buildAlertCard(a, false)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> a, bool isActive) {
    final date = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.parse(a['created_at']).toLocal());
    return Card(
      elevation: 0,
      color: isActive ? Colors.red.shade50 : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isActive ? Colors.red : Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          '${a['alert_type']} (${a['severity']})',
          style: TextStyle(
            color: isActive ? Colors.red.shade800 : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('${a['alert_message']}\nTriggered at: $date'),
        trailing: isActive && _userRole == 'Doctor'
            ? OutlinedButton(
                onPressed: () => _resolveAlert(a['id']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
                child: const Text('Resolve'),
              )
            : null,
      ),
    );
  }

  Widget _buildDoctorDischargeTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _dischargeFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.logout_outlined,
                            color: Colors.red,
                            size: 26,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Initiate Patient Discharge',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Complete discharge summary and release patient from IPD care.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ALERT CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 22,
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              'Discharging this patient will automatically free the allocated bed and move the patient record to discharge history.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // FINAL DIAGNOSIS
                    _buildDischargeTextArea(
                      controller: _finalDiagController,
                      title: 'Final Diagnosis',
                      hint: 'Enter final diagnosis and patient condition...',
                      icon: Icons.medical_information_outlined,
                      validatorMessage: 'Final diagnosis is required',
                    ),

                    const SizedBox(height: 24),

                    // TREATMENT SUMMARY
                    _buildDischargeTextArea(
                      controller: _treatmentSumController,
                      title: 'Treatment Summary',
                      hint: 'Describe treatment provided during admission...',
                      icon: Icons.healing_outlined,
                      validatorMessage: 'Treatment summary is required',
                    ),

                    const SizedBox(height: 24),

                    // MEDICATION PLAN
                    _buildDischargeTextArea(
                      controller: _medPlanController,
                      title: 'Medication Plan & Follow-up',
                      hint:
                          'Prescribed medications, follow-up instructions, review dates...',
                      icon: Icons.medication_outlined,
                      validatorMessage: 'Medication plan is required',
                    ),

                    const SizedBox(height: 34),

                    // BUTTON ROW
                    isMobile
                        ? Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _finalDiagController.clear();
                                    _treatmentSumController.clear();
                                    _medPlanController.clear();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text(
                                    'Reset Form',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _executeDischarge,
                                  icon: const Icon(Icons.logout, color: Colors.white),
                                  label: const Text(
                                    'Discharge Patient',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 54),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _finalDiagController.clear();
                                    _treatmentSumController.clear();
                                    _medPlanController.clear();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text(
                                    'Reset Form',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _executeDischarge,
                                  icon: const Icon(Icons.logout, color: Colors.white),
                                  label: const Text(
                                    'Discharge Patient',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 54),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDischargeTextArea({
    required TextEditingController controller,
    required String title,
    required String hint,
    required IconData icon,
    required String validatorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),

        const SizedBox(height: 10),

        TextFormField(
          controller: controller,
          maxLines: 5,
          maxLength: 255,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: true,
            counterText: '',

            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: Icon(icon, color: Colors.red.shade400),
            ),

            filled: true,
            fillColor: Colors.grey.shade50,

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),

            contentPadding: const EdgeInsets.all(18),
          ),

          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return validatorMessage;
            }
            return null;
          },
        ),
      ],
    );
  }

  // --- NURSE TABS ---

  Widget _buildNurseVitalsEntryTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget formCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _vitalsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Daily Vitals',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Record patient vital measurements',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              isMobile
                  ? Column(
                      children: [
                        _buildVitalsField(
                          controller: _bpSystolicController,
                          label: 'Systolic BP',
                          hint: 'Enter Systolic',
                          suffix: 'mmHg',
                          icon: Icons.favorite_outline,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 20),
                        _buildVitalsField(
                          controller: _bpDiastolicController,
                          label: 'Diastolic BP',
                          hint: 'Enter Diastolic',
                          suffix: 'mmHg',
                          icon: Icons.favorite_outline,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildVitalsField(
                            controller: _bpSystolicController,
                            label: 'Systolic BP',
                            hint: 'Enter Systolic',
                            suffix: 'mmHg',
                            icon: Icons.favorite_outline,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildVitalsField(
                            controller: _bpDiastolicController,
                            label: 'Diastolic BP',
                            hint: 'Enter Diastolic',
                            suffix: 'mmHg',
                            icon: Icons.favorite_outline,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 20),

              isMobile
                  ? Column(
                      children: [
                        _buildVitalsField(
                          controller: _tempController,
                          label: 'Temperature',
                          hint: 'Enter Temperature',
                          suffix: '°F',
                          icon: Icons.thermostat,
                          maxLength: 5,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildVitalsField(
                          controller: _pulseController,
                          label: 'Pulse',
                          hint: 'Enter Pulse',
                          suffix: 'bpm',
                          icon: Icons.monitor_heart_outlined,
                          maxLength: 3,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildVitalsField(
                            controller: _tempController,
                            label: 'Temperature',
                            hint: 'Enter Temperature',
                            suffix: '°F',
                            icon: Icons.thermostat,
                            maxLength: 5,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildVitalsField(
                            controller: _pulseController,
                            label: 'Pulse',
                            hint: 'Enter Pulse',
                            suffix: 'bpm',
                            icon: Icons.monitor_heart_outlined,
                            maxLength: 3,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 20),

              isMobile
                  ? Column(
                      children: [
                        _buildVitalsField(
                          controller: _spo2Controller,
                          label: 'SPO2',
                          hint: 'Enter SPO2',
                          suffix: '%',
                          icon: Icons.air,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 20),
                        _buildVitalsField(
                          controller: _respRateController,
                          label: 'Respiratory Rate',
                          hint: 'Enter Respiratory Rate',
                          suffix: 'bpm',
                          icon: Icons.water_drop_outlined,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildVitalsField(
                            controller: _spo2Controller,
                            label: 'SPO2',
                            hint: 'Enter SPO2',
                            suffix: '%',
                            icon: Icons.air,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildVitalsField(
                            controller: _respRateController,
                            label: 'Respiratory Rate',
                            hint: 'Enter Respiratory Rate',
                            suffix: 'bpm',
                            icon: Icons.water_drop_outlined,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitVitals,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Record Vitals',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget historyCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vitals Log History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'History of logged vitals',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildVitalsHistoryList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? Column(
                  children: [formCard, const SizedBox(height: 24), historyCard],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: formCard),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: historyCard),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVitalsField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    TextInputType keyboardType = TextInputType.number,
  }) {
    final String labelWithStar = '$label *';
    final bool hasStar = labelWithStar.endsWith(' *');
    final String baseText = hasStar
        ? labelWithStar.substring(0, labelWithStar.length - 2)
        : labelWithStar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: RichText(
            text: TextSpan(
              text: baseText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'Inter',
              ),
              children: [
                if (hasStar)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 13),
            suffixText: suffix,
            counterText: maxLength != null ? '' : null,
            suffixStyle: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
            final text = value.trim();
            if (label == 'Systolic BP') {
              final num = int.tryParse(text);
              if (num == null) return 'Must be integer';
              if (num == 0) return 'Cannot be 0';
              if (num < 90 || num > 300) return 'Must be 90 to 300';
            } else if (label == 'Diastolic BP') {
              final num = int.tryParse(text);
              if (num == null) return 'Must be integer';
              if (num == 0) return 'Cannot be 0';
              if (num < 50 || num > 180) return 'Must be 50 to 180';
            } else if (label == 'Temperature') {
              final num = double.tryParse(text);
              if (num == null) return 'Must be number';
              if (num == 0) return 'Cannot be 0';
              if (num < 90 || num > 115) return 'Must be 90 to 115';
            } else if (label == 'Pulse') {
              final num = int.tryParse(text);
              if (num == null) return 'Must be integer';
              if (num == 0) return 'Cannot be 0';
              if (num < 30 || num > 250) return 'Must be 30 to 250';
            } else if (label == 'SPO2') {
              final num = int.tryParse(text);
              if (num == null) return 'Must be integer';
              if (num == 0) return 'Cannot be 0';
              if (num < 50 || num > 100) return 'Must be 50 to 100';
            } else if (label == 'Respiratory Rate') {
              final num = int.tryParse(text);
              if (num == null) return 'Must be integer';
              if (num == 0) return 'Cannot be 0';
              if (num < 8 || num > 60) return 'Must be 8 to 60';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNurseMedAdminTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget leftCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Prescriptions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Record medication administrations',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            if (_prescriptions
                .where((p) => p['status'] == 'Active')
                .isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active prescriptions from doctor',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._prescriptions
                  .where((p) => p['status'] == 'Active')
                  .map((p) => _buildNursePrescriptionCard(p)),
          ],
        ),
      ),
    );

    final Widget rightCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medication Log History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Previously administered medications',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_medicationLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_liquid_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No medications logged',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._medicationLogs.map((log) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: log['status'] == 'Given'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        child: Icon(
                          Icons.medication,
                          color: log['status'] == 'Given'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['medicine_name'] ?? '--',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${log['status']}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            if (log['remarks'] != null &&
                                log['remarks'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  log['remarks'],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftCard,
                const SizedBox(height: 24),
                rightCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: leftCard),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: rightCard),
              ],
            ),
    );
  }

  Widget _buildNursePrescriptionCard(Map<String, dynamic> p) {
    final String name = p['medicine_name'] ?? '--';
    final String dosage = p['dosage'] ?? '--';
    final String frequency = p['frequency'] ?? '--';
    final String route = p['route'] ?? '--';
    final String duration = p['duration'] ?? '--';
    final String instructions = p['instructions'] ?? '';

    final int prescriptionId = p['id'];
    final bool isAlreadyGiven = _medicationLogs.any((log) {
      if (log['prescription_id'] != prescriptionId) return false;
      if (log['status'] != 'Given') return false;
      try {
        final loggedAt = DateTime.parse(
          log['administered_at'] ?? log['created_at'],
        ).toLocal();
        return DateTime.now().difference(loggedAt).inHours < 8;
      } catch (_) {
        return true;
      }
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medication,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dosage • $frequency',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isAlreadyGiven
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAlreadyGiven ? 'Given' : 'Active',
                  style: TextStyle(
                    color: isAlreadyGiven ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPrescriptionChip('Route', route, Icons.route_outlined),
              _buildPrescriptionChip(
                'Duration',
                duration,
                Icons.calendar_today_outlined,
              ),
            ],
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                instructions,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (!isAlreadyGiven) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMedicationDeviationDialog(p),
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Miss/Delay',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submitMedicationLog(
                      prescriptionId: p['id'],
                      status: 'Given',
                      remarks: '',
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Give Dose',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNurseNotesTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final Widget leftCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _progFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.note_alt_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Nursing Log',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add nursing observations and patient notes',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // BP FIELD
              _buildNursingField(
                controller: _bpSystolicController,
                label: 'Blood Pressure',
                hint: '120/80',
                icon: Icons.favorite_outline,
                maxLength: 7,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                ],
                keyboardType: TextInputType.text,
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return null;
                  if (!text.contains('/')) {
                    final num = int.tryParse(text);
                    if (num == null) return 'BP must be systolic/diastolic (e.g. 120/80)';
                    if (num == 0) return 'Cannot be 0';
                    if (num < 90 || num > 300) return 'Systolic must be 90 to 300';
                    return null;
                  }
                  final parts = text.split('/');
                  final sys = int.tryParse(parts[0].trim());
                  final dia = int.tryParse(parts[1].trim());
                  if (sys == null || dia == null) return 'Invalid numbers';
                  if (sys == 0 || dia == 0) return 'Cannot be 0';
                  if (sys < 90 || sys > 300) return 'Systolic must be 90 to 300';
                  if (dia < 50 || dia > 180) return 'Diastolic must be 50 to 180';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // TEMP & PULSE
              isMobile
                  ? Column(
                      children: [
                        _buildNursingField(
                          controller: _tempController,
                          label: 'Temperature',
                          hint: '98.6 °F',
                          icon: Icons.thermostat_outlined,
                          maxLength: 5,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final num = double.tryParse(text);
                            if (num == null) return 'Must be number';
                            if (num == 0) return 'Cannot be 0';
                            if (num < 90 || num > 115) return 'Must be 90 to 115';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildNursingField(
                          controller: _pulseController,
                          label: 'Pulse',
                          hint: '72 bpm',
                          icon: Icons.monitor_heart_outlined,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final num = int.tryParse(text);
                            if (num == null) return 'Must be integer';
                            if (num == 0) return 'Cannot be 0';
                            if (num < 30 || num > 250) return 'Must be 30 to 250';
                            return null;
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildNursingField(
                            controller: _tempController,
                            label: 'Temperature',
                            hint: '98.6 °F',
                            icon: Icons.thermostat_outlined,
                            maxLength: 5,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              final text = val?.trim() ?? '';
                              if (text.isEmpty) return null;
                              final num = double.tryParse(text);
                              if (num == null) return 'Must be number';
                              if (num == 0) return 'Cannot be 0';
                              if (num < 90 || num > 115) return 'Must be 90 to 115';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildNursingField(
                            controller: _pulseController,
                            label: 'Pulse',
                            hint: '72 bpm',
                            icon: Icons.monitor_heart_outlined,
                            maxLength: 3,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              final text = val?.trim() ?? '';
                              if (text.isEmpty) return null;
                              final num = int.tryParse(text);
                              if (num == null) return 'Must be integer';
                              if (num == 0) return 'Cannot be 0';
                              if (num < 30 || num > 250) return 'Must be 30 to 250';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 20),

              // SUGAR LEVEL
              _buildNursingField(
                controller: _spo2Controller,
                label: 'Sugar Level',
                hint: '98 mg/dL',
                icon: Icons.water_drop_outlined,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final num = double.tryParse(text);
                  if (num == null) return 'Must be number';
                  if (num == 0) return 'Cannot be 0';
                  if (num < 30 || num > 600) return 'Must be 30 to 600';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // NOTES
              const Text(
                'Nursing Observation / Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _obsController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText:
                      'Enter nursing observations, symptoms, medication response...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 110),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitProgressNote,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Save Nursing Note',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget rightCard = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nursing Log History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Previously recorded nursing observations',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_progressNotes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No nursing notes recorded',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._progressNotes.map((note) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP HEADER
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryColor
                                .withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recorded by Nurse',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  note['doctor_name'] ?? 'Duty Nurse',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Text(
                            note['created_at'] != null
                                ? DateFormat(
                                    'dd/MM/yyyy hh:mm a',
                                  ).format(
                                    DateTime.parse(
                                      note['created_at'],
                                    ).toLocal(),
                                  )
                                : '--',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // VITALS ROW
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildMiniVitalChip(
                            'BP',
                            note['blood_pressure'] ?? '--',
                            Icons.favorite_outline,
                          ),
                          _buildMiniVitalChip(
                            'Temp',
                            note['temperature'] ?? '--',
                            Icons.thermostat_outlined,
                          ),
                          _buildMiniVitalChip(
                            'Pulse',
                            note['pulse'] ?? '--',
                            Icons.monitor_heart_outlined,
                          ),
                          _buildMiniVitalChip(
                            'Sugar',
                            note['sugar_level'] ?? '--',
                            Icons.water_drop_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          note['observation'] ??
                              'No observations added',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftCard,
                const SizedBox(height: 24),
                rightCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: leftCard),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: rightCard),
              ],
            ),
    );
  }

  Widget _buildNursingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 18),
            filled: true,
            fillColor: Colors.grey.shade50,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniVitalChip(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '$title: $value',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseLabTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lab Coordination Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Update statuses of ordered lab tests for this patient.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _labOrders.isEmpty
                ? const Center(child: Text('No lab tests ordered.'))
                : ListView.builder(
                    itemCount: _labOrders.length,
                    itemBuilder: (context, index) {
                      final o = _labOrders[index];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          o['test_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Ordered by: Dr. ${o['doctor_name'] ?? '--'}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    children: [
                                      _buildStatusBadge(o['status']),
                                      const SizedBox(height: 8),
                                      if (o['status'] == 'Pending')
                                        ElevatedButton(
                                          onPressed: () => _updateLabStatus(
                                            o['id'],
                                            'Sample Collected',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            fixedSize: const Size(140, 36),
                                          ),
                                          child: const Text(
                                            'Collect Sample',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else if (o['status'] ==
                                          'Sample Collected')
                                        ElevatedButton(
                                          onPressed: () => _updateLabStatus(
                                            o['id'],
                                            'Sent to Lab',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            fixedSize: const Size(140, 36),
                                          ),
                                          child: const Text(
                                            'Send to Lab',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else if (o['status'] == 'Sent to Lab')
                                        ElevatedButton(
                                          onPressed: () {
                                            final notesCont =
                                                TextEditingController();
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Enter Lab Results',
                                                ),
                                                content: TextField(
                                                  controller: notesCont,
                                                  maxLines: 3,
                                                  decoration: const InputDecoration(
                                                    hintText:
                                                        'Enter test results...',
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      try {
                                                        await _ipdController
                                                            .updateLabOrderStatus(
                                                              o['id'],
                                                              {
                                                                'status':
                                                                    'Completed',
                                                                'result_notes':
                                                                    notesCont
                                                                        .text
                                                                        .trim(),
                                                              },
                                                            );
                                                        _loadAllData();
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: const Text('Submit'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            fixedSize: const Size(140, 36),
                                          ),
                                          child: const Text(
                                            'Complete Test',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (o['status'] == 'Completed') ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.description_outlined,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Lab Results / Notes',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (o['result_notes'] ?? '')
                                                .toString()
                                                .isNotEmpty
                                            ? o['result_notes']
                                            : 'No result notes entered.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseIcuTab() {
    if (widget.admission['ward_type'] != 'ICU') {
      return _buildNonIcuNotice();
    }

    final activeAlerts = _icuAlerts
        .where((a) => a['status'] == 'Active')
        .toList();

    final latestVitals = _vitalsHistory.isNotEmpty ? _vitalsHistory.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBedsideMonitor(latestVitals),
          const SizedBox(height: 20),
          _buildSimulationPanel(),
          const SizedBox(height: 24),
          const Text(
            'ICU Alerts Desk',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Active alerts generated automatically based on critical vitals input.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (activeAlerts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No active critical alerts.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeAlerts.length,
              itemBuilder: (context, index) {
                final a = activeAlerts[index];
                final date = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(DateTime.parse(a['created_at']).toLocal());

                return Card(
                  elevation: 0,
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.red),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      '${a['alert_type']} (${a['severity']})',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${a['alert_message']}\nTriggered: $date',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _resolveAlert(a['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Resolve Alert',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- REUSABLE BADGES & WIDGETS ---

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey;
    if (status == 'Pending') bg = Colors.orange;
    if (status == 'Sample Collected') bg = Colors.blue;
    if (status == 'Sent to Lab') bg = Colors.indigo;
    if (status == 'Completed') bg = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
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
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  final bool alert;
  const _PulseDot({Key? key, required this.active, required this.alert}) : super(key: key);

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && !widget.alert) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
      );
    }
    
    final color = widget.alert ? Colors.redAccent : Colors.greenAccent;
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingAlertText extends StatefulWidget {
  const _BlinkingAlertText({Key? key}) : super(key: key);

  @override
  State<_BlinkingAlertText> createState() => _BlinkingAlertTextState();
}

class _BlinkingAlertTextState extends State<_BlinkingAlertText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.1, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '⚠️ TELEMETRY CRITICAL ALERT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
