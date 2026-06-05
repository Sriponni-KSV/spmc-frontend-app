import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/ot_controller.dart';
import '../widgets/custom_dropdown_search.dart';

// --- DATA STRUCTURES ---

class AuditLog {
  final String actorName;
  final String role;
  final DateTime timestamp;
  final String action;

  AuditLog({
    required this.actorName,
    required this.role,
    required this.timestamp,
    required this.action,
  });
}

class IntraOpLog {
  final DateTime timestamp;
  final String bp;
  final int pulse;
  final double temp;
  final int spo2;
  final String medications;
  final String fluids;
  final String blood;
  final int instrumentCount;

  IntraOpLog({
    required this.timestamp,
    required this.bp,
    required this.pulse,
    required this.temp,
    required this.spo2,
    required this.medications,
    required this.fluids,
    required this.blood,
    required this.instrumentCount,
  });
}

class OtCase {
  int? dbId;
  int? patientDbId;
  final String id;
  final String patientId;
  final String patientName;
  final int age;
  final String gender;
  final String bloodGroup;
  final String diagnosis;
  String status; // 'OT Requested', 'OT Scheduled', 'Pre-Op Completed', 'Anaesthesia Cleared', 'Patient In OT', 'Surgery In Progress', 'Surgery Completed', 'Post-Op Monitoring', 'OT Case Closed'

  // Step 1: Request
  String? surgeryType;
  String? priority; // Elective, Emergency
  DateTime? surgeryDateTime;
  String? surgeon;
  String? anaesthetist;
  String? remarks;

  // Step 2: Scheduling
  String? otRoom; // OT 1, OT 2, OT 3, Emergency OT
  String? surgerySlot;
  String? nursingTeam;

  // Step 3: Pre-Op Preparation
  bool idVerified = false;
  bool consentSigned = false;
  bool fastingConfirmed = false;
  bool labVerified = false;
  bool bloodAvailable = false;
  String? preOpBp;
  int? preOpPulse;
  double? preOpTemp;
  int? preOpSpo2;

  // Step 4: Anaesthesia Assessment
  String? anaesthesiaNotes;
  String? anaesthesiaType; // General, Spinal, Epidural, Local, etc.
  bool anaesthesiaCleared = false;

  // Step 5: Transfer to OT
  bool patientArrived = false;
  bool handoverVerified = false;
  String? handoverNotes;

  // Step 6: Surgery Procedure
  DateTime? surgeryStartTime;
  DateTime? surgeryEndTime;
  String? procedureDetails;
  String? surgicalFindings;
  String? complications;

  // Step 7: Intra-Op Logs
  List<IntraOpLog> intraOpLogs = [];

  // Step 8: Post-Op Notes
  String? operationSummary;
  String? procedurePerformed;
  String? outcome;
  String? postOpInstructions;
  String? followUpRecommendations;

  // Step 9: Recovery / ICU / Ward Transfer
  String? transferDestination; // Recovery Room, ICU, Ward
  String? transferDetails;
  String? nursingHandoverNotes;

  // Step 10: Care Log
  List<String> nurseCareVitalsLogs = [];
  List<String> nurseMedicationsAdministered = [];
  List<String> doctorProgressNotes = [];

  // Audit Logs
  List<AuditLog> auditLogs = [];

  OtCase({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.diagnosis,
    this.status = 'OT Requested',
  });
}

class OTManagementScreen extends StatefulWidget {
  final bool isMobile;
  const OTManagementScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<OTManagementScreen> createState() => _OTManagementScreenState();
}

class _OTManagementScreenState extends State<OTManagementScreen> {
  int _activeTab = 0; // 0: Dashboard, 1: Active Cases, 2: New Request
  List<OtCase> _otCases = [];
  OtCase? _selectedCase;
  final _requestFormKey = GlobalKey<FormState>();
  final _preOpVitalsFormKey = GlobalKey<FormState>();
  final _intraOpVitalsFormKey = GlobalKey<FormState>();
  final _surgeryProcedureFormKey = GlobalKey<FormState>();
  String _searchQuery = '';

  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();
  final OtController _otController = OtController();
  List<PatientModel> _patients = [];
  List<UserModel> _doctors = [];
  bool _isLoadingPatients = false;
  bool _isLoadingDoctors = false;
  bool _isLoadingCases = false;
  String? _selectedPatientId;
  String? _selectedPatientDisplayId;

  // Form Field Values (New Request)
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'O+';
  final _diagnosisController = TextEditingController();
  String _selectedSurgeryType = 'Laparoscopic Cholecystectomy';
  String _selectedPriority = 'Elective';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final _surgeonController = TextEditingController();
  final _anaesthetistController = TextEditingController();
  final _remarksController = TextEditingController();

  // Temporary Inputs for Workflow steps
  final _otRoomController = TextEditingController();
  final _slotController = TextEditingController();
  final _nursingTeamController = TextEditingController();

  // Pre-Op vitals
  final _preOpBpController = TextEditingController();
  final _preOpPulseController = TextEditingController();
  final _preOpTempController = TextEditingController();
  final _preOpSpo2Controller = TextEditingController();

  // Anaesthesia Form
  final _anaesthesiaNotesController = TextEditingController();
  String _selectedAnaesthesiaType = 'General Anaesthesia';

  // Handover notes
  final _handoverNotesController = TextEditingController();

  // Surgery Procedure Form
  final _procedureDetailsController = TextEditingController();
  final _findingsController = TextEditingController();
  final _complicationsController = TextEditingController();

  // Intra-Op Logs
  final _intraOpBpController = TextEditingController();
  final _intraOpPulseController = TextEditingController();
  final _intraOpTempController = TextEditingController();
  final _intraOpSpo2Controller = TextEditingController();
  final _intraOpMedsController = TextEditingController();
  final _intraOpFluidsController = TextEditingController();
  final _intraOpBloodController = TextEditingController();
  final _intraOpInstrumentController = TextEditingController();

  // Post-Op Notes
  final _opSummaryController = TextEditingController();
  final _procPerformedController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _postOpInstController = TextEditingController();
  final _followUpController = TextEditingController();

  // Transfer Form
  String _selectedTransferDest = 'Recovery Room';
  final _transferDetailsController = TextEditingController();
  final _nursingHandoverController = TextEditingController();

  // Care Logs
  final _careVitalsController = TextEditingController();
  final _careMedsController = TextEditingController();
  final _doctorProgressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatientsAndDoctors();
  }

  Future<void> _loadPatientsAndDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPatients = true;
      _isLoadingDoctors = true;
      _isLoadingCases = true;
    });
    try {
      final results = await Future.wait([
        _patientController.fetchPatients(),
        _adminController.fetchStaff(role: 'Doctor'),
        _otController.fetchOtCases(),
      ]);
      if (mounted) {
        _patients = results[0] as List<PatientModel>;
        _doctors = results[1] as List<UserModel>;
        final fetchedCases = results[2] as List<OtCase>;

        if (fetchedCases.isEmpty && _patients.isNotEmpty) {
          // Seed DB with mock cases dynamically mapped to loaded patients/doctors
          await _seedMockCasesToDatabase();
          final refetched = await _otController.fetchOtCases();
          setState(() {
            _otCases = refetched;
            _selectedCase = null;
          });
        } else {
          setState(() {
            _otCases = fetchedCases;
            _selectedCase = null;
          });
        }
        setState(() {
          _isLoadingPatients = false;
          _isLoadingDoctors = false;
          _isLoadingCases = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPatients = false;
          _isLoadingDoctors = false;
          _isLoadingCases = false;
        });
        debugPrint('Error loading OT database dependencies: $e');
      }
    }
  }

  Future<void> _seedMockCasesToDatabase() async {
    if (_patients.isEmpty) return;
    try {
      final String baseUrl = dotenv.env['BASE_URL']!;
      final mockData = [
        {
          'diagnosis': 'Chronic Calculous Cholecystitis',
          'surgery_type': 'Laparoscopic Cholecystectomy',
          'priority': 'Elective',
          'surgeon': 'Dr. Vikram Sen',
          'anaesthetist': 'Dr. Rajesh Shah',
          'remarks': 'Patient has stable vitals. Scheduled for elective gallbladder removal.',
          'status': 'OT Requested',
          'audit_logs': [
            {
              'actorName': 'Dr. Vikram Sen',
              'role': 'Surgeon',
              'timestamp': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
              'action': 'Created Surgery Request: Laparoscopic Cholecystectomy (Priority: Elective).',
            }
          ]
        },
        {
          'diagnosis': 'Acute Appendicitis',
          'surgery_type': 'Appendectomy',
          'priority': 'Emergency',
          'surgeon': 'Dr. Vikram Sen',
          'anaesthetist': 'Dr. Sunita Mehta',
          'remarks': 'Acute symptoms. Immediate surgery requested.',
          'status': 'Pre-Op Completed',
          'ot_room': 'OT 2',
          'surgery_slot': '10:30 AM - 12:00 PM',
          'nursing_team': 'Nursing Team B (Nurse Maria, Nurse Kevin)',
          'id_verified': true,
          'consent_signed': true,
          'fasting_confirmed': true,
          'lab_verified': true,
          'blood_available': true,
          'pre_op_bp': '118/75',
          'pre_op_pulse': 82,
          'pre_op_temp': 99.1,
          'pre_op_spo2': 98,
          'audit_logs': [
            {
              'actorName': 'Dr. Vikram Sen',
              'role': 'Surgeon',
              'timestamp': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
              'action': 'Created Emergency Surgery Request for Appendectomy.',
            },
            {
              'actorName': 'Nurse Maria',
              'role': 'Nurse Coordinator',
              'timestamp': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
              'action': 'Scheduled OT 2 and slot 10:30 AM - 12:00 PM.',
            },
            {
              'actorName': 'Nurse Kevin',
              'role': 'Pre-Op Nurse',
              'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
              'action': 'Completed pre-operative checklist and recorded vitals. Patient ready for transfer.',
            }
          ]
        },
        {
          'diagnosis': 'Triple Vessel Coronary Artery Disease',
          'surgery_type': 'CABG (Heart Bypass)',
          'priority': 'Elective',
          'surgeon': 'Dr. Sanjay Gupta',
          'anaesthetist': 'Dr. Sunita Mehta',
          'remarks': 'Double check heparin availability.',
          'status': 'Patient In OT',
          'ot_room': 'OT 1',
          'surgery_slot': '08:00 AM - 12:00 PM',
          'nursing_team': 'Cardiac Nurse Team (Nurse Albert, Nurse Stella)',
          'id_verified': true,
          'consent_signed': true,
          'fasting_confirmed': true,
          'lab_verified': true,
          'blood_available': true,
          'pre_op_bp': '130/82',
          'pre_op_pulse': 68,
          'pre_op_temp': 98.4,
          'pre_op_spo2': 97,
          'anaesthesia_notes': 'Patient cleared. No difficult airway predicted.',
          'anaesthesia_type': 'General Anaesthesia',
          'anaesthesia_cleared': true,
          'patient_arrived': true,
          'handover_verified': true,
          'handover_notes': 'All parameters stable. Skin prep complete.',
          'audit_logs': [
            {'actorName': 'Dr. Sanjay Gupta', 'role': 'Surgeon', 'timestamp': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'action': 'Scheduled Elective CABG.'},
            {'actorName': 'Nurse Stella', 'role': 'OT Coordinator', 'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'action': 'Allocated OT 1.'},
            {'actorName': 'Nurse Stella', 'role': 'Pre-Op Nurse', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'action': 'Completed pre-op verification.'},
            {'actorName': 'Dr. Sunita Mehta', 'role': 'Anaesthetist', 'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'action': 'Completed assessment and cleared patient under General Anaesthesia.'},
            {'actorName': 'Nurse Albert', 'role': 'OT Nurse', 'timestamp': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(), 'action': 'Verified handover checklist and confirmed patient arrival in OT 1.'},
          ]
        }
      ];

      for (int i = 0; i < mockData.length; i++) {
        final data = mockData[i];
        final realPatient = _patients[i % _patients.length];
        
        final requestBody = {
          'patient_id': realPatient.id,
          'diagnosis': data['diagnosis'],
          'surgery_type': data['surgery_type'],
          'priority': data['priority'],
          'surgery_date_time': DateTime.now().add(Duration(days: i + 1)).toIso8601String(),
          'surgeon': _doctors.isNotEmpty ? _doctors[i % _doctors.length].fullname : data['surgeon'],
          'anaesthetist': _doctors.isNotEmpty ? _doctors[(i + 1) % _doctors.length].fullname : data['anaesthetist'],
          'remarks': data['remarks'],
          'audit_logs': data['audit_logs'],
        };
        
        final response = await ApiService.post('$baseUrl/ot/cases', requestBody);
        if (response.statusCode == 201) {
          final createdJson = jsonDecode(response.body)['data'];
          final dbId = createdJson['id'];
          
          if (data['status'] != 'OT Requested') {
            final Map<String, dynamic> updateFields = {
              'status': data['status'],
              'ot_room': data['ot_room'],
              'surgery_slot': data['surgery_slot'],
              'nursing_team': data['nursing_team'],
              'id_verified': data['id_verified'] ?? false,
              'consent_signed': data['consent_signed'] ?? false,
              'fasting_confirmed': data['fasting_confirmed'] ?? false,
              'lab_verified': data['lab_verified'] ?? false,
              'blood_available': data['blood_available'] ?? false,
              'pre_op_bp': data['pre_op_bp'],
              'pre_op_pulse': data['pre_op_pulse'],
              'pre_op_temp': data['pre_op_temp'],
              'pre_op_spo2': data['pre_op_spo2'],
              'anaesthesia_notes': data['anaesthesia_notes'],
              'anaesthesia_type': data['anaesthesia_type'],
              'anaesthesia_cleared': data['anaesthesia_cleared'] ?? false,
              'patient_arrived': data['patient_arrived'] ?? false,
              'handover_verified': data['handover_verified'] ?? false,
              'handover_notes': data['handover_notes'],
            };
            
            await _otController.updateOtCase(dbId, updateFields);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to seed database mock cases: $e');
    }
  }

  void _populateControllersForCase(OtCase otCase) {
    _otRoomController.text = otCase.otRoom ?? '';
    _slotController.text = otCase.surgerySlot ?? '';
    _nursingTeamController.text = otCase.nursingTeam ?? '';

    _preOpBpController.text = otCase.preOpBp ?? '';
    _preOpPulseController.text = otCase.preOpPulse?.toString() ?? '';
    _preOpTempController.text = otCase.preOpTemp?.toString() ?? '';
    _preOpSpo2Controller.text = otCase.preOpSpo2?.toString() ?? '';

    _anaesthesiaNotesController.text = otCase.anaesthesiaNotes ?? '';
    if (otCase.anaesthesiaType != null) {
      _selectedAnaesthesiaType = otCase.anaesthesiaType!;
    } else {
      _selectedAnaesthesiaType = 'General Anaesthesia';
    }

    _handoverNotesController.text = otCase.handoverNotes ?? '';

    _procedureDetailsController.text = otCase.procedureDetails ?? '';
    _findingsController.text = otCase.surgicalFindings ?? '';
    _complicationsController.text = otCase.complications ?? '';

    _intraOpBpController.clear();
    _intraOpPulseController.clear();
    _intraOpTempController.clear();
    _intraOpSpo2Controller.clear();
    _intraOpMedsController.clear();
    _intraOpFluidsController.clear();
    _intraOpBloodController.clear();
    _intraOpInstrumentController.clear();

    _opSummaryController.text = otCase.operationSummary ?? '';
    _procPerformedController.text = otCase.procedurePerformed ?? '';
    _outcomeController.text = otCase.outcome ?? '';
    _postOpInstController.text = otCase.postOpInstructions ?? '';
    _followUpController.text = otCase.followUpRecommendations ?? '';

    _selectedTransferDest = otCase.transferDestination ?? 'Recovery Room';
    _transferDetailsController.text = otCase.transferDetails ?? '';
    _nursingHandoverController.text = otCase.nursingHandoverNotes ?? '';

    _careVitalsController.clear();
    _careMedsController.clear();
    _doctorProgressController.clear();
  }

  void _selectOtCase(OtCase otCase) {
    setState(() {
      _selectedCase = otCase;
      _populateControllersForCase(otCase);
    });
  }

  Future<void> _updateCaseInDb(OtCase otCase, Map<String, dynamic> updates) async {
    if (otCase.dbId == null) {
      setState(() {});
      return;
    }
    
    // Always attach the latest audit logs on update
    updates['audit_logs'] = otCase.auditLogs.map((log) => {
      'actorName': log.actorName,
      'role': log.role,
      'timestamp': log.timestamp.toIso8601String(),
      'action': log.action,
    }).toList();

    try {
      final updated = await _otController.updateOtCase(otCase.dbId!, updates);
      setState(() {
        final idx = _otCases.indexWhere((c) => c.dbId == otCase.dbId);
        if (idx != -1) {
          _otCases[idx] = updated;
          if (_selectedCase?.dbId == otCase.dbId) {
            _selectedCase = updated;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save update to database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _logAction(OtCase otCase, String action) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final log = AuditLog(
      actorName: user?.fullname ?? 'System Staff',
      role: user?.role ?? 'Doctor',
      timestamp: DateTime.now(),
      action: action,
    );
    setState(() {
      otCase.auditLogs.insert(0, log);
    });
  }

  // --- ACTIONS ---

  Future<void> _saveSurgeryRequest() async {
    if (!_requestFormKey.currentState!.validate()) return;
    
    final int? patientDbId = int.tryParse(_selectedPatientId ?? '');
    if (patientDbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient from the database.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final initAuditLog = AuditLog(
      actorName: user?.fullname ?? 'System Staff',
      role: user?.role ?? 'Doctor',
      timestamp: DateTime.now(),
      action: 'Created Surgery Request: $_selectedSurgeryType (Priority: $_selectedPriority).',
    );

    try {
      final newCase = await _otController.createOtCase(
        patientDbId: patientDbId,
        diagnosis: _diagnosisController.text.trim(),
        surgeryType: _selectedSurgeryType,
        priority: _selectedPriority,
        surgeryDateTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        surgeon: _surgeonController.text.trim(),
        anaesthetist: _anaesthetistController.text.trim(),
        remarks: _remarksController.text.trim(),
        auditLogs: [initAuditLog],
      );

      setState(() {
        _otCases.insert(0, newCase);
        _activeTab = 1; // Switch to list
        _selectedCase = newCase;
        _populateControllersForCase(newCase);
      });

      // Clear controllers
      _patientNameController.clear();
      _ageController.clear();
      _diagnosisController.clear();
      _remarksController.clear();
      setState(() {
        _selectedPatientId = null;
        _selectedPatientDisplayId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Surgery requested successfully! Status: OT Requested'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save surgery request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmScheduling(OtCase otCase) {
    otCase.otRoom = _otRoomController.text.isNotEmpty ? _otRoomController.text : 'OT 1';
    otCase.surgerySlot = _slotController.text.isNotEmpty ? _slotController.text : '09:00 AM - 11:30 AM';
    otCase.nursingTeam = _nursingTeamController.text.isNotEmpty ? _nursingTeamController.text : 'Team A (Nurse Sarah, Nurse John)';
    otCase.status = 'OT Scheduled';

    _logAction(otCase, 'Scheduled surgery: Room ${otCase.otRoom}, Slot: ${otCase.surgerySlot}, Nursing Team: ${otCase.nursingTeam}.');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Scheduled',
      'ot_room': otCase.otRoom,
      'surgery_slot': otCase.surgerySlot,
      'nursing_team': otCase.nursingTeam,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Surgery scheduled for ${otCase.patientName}. Status: OT Scheduled')),
    );
  }

  void _savePreOpPrep(OtCase otCase) {
    otCase.preOpBp = _preOpBpController.text.isNotEmpty ? _preOpBpController.text : '120/80';
    otCase.preOpPulse = int.tryParse(_preOpPulseController.text) ?? 72;
    otCase.preOpTemp = double.tryParse(_preOpTempController.text) ?? 98.4;
    otCase.preOpSpo2 = int.tryParse(_preOpSpo2Controller.text) ?? 99;
    otCase.status = 'Pre-Op Completed';

    _logAction(otCase, 'Completed pre-operative checklist & vitals (BP: ${otCase.preOpBp}, PR: ${otCase.preOpPulse}, Temp: ${otCase.preOpTemp}, SpO2: ${otCase.preOpSpo2}). Marked patient as ready.');
    
    _updateCaseInDb(otCase, {
      'status': 'Pre-Op Completed',
      'id_verified': otCase.idVerified,
      'consent_signed': otCase.consentSigned,
      'fasting_confirmed': otCase.fastingConfirmed,
      'lab_verified': otCase.labVerified,
      'blood_available': otCase.bloodAvailable,
      'pre_op_bp': otCase.preOpBp,
      'pre_op_pulse': otCase.preOpPulse,
      'pre_op_temp': otCase.preOpTemp,
      'pre_op_spo2': otCase.preOpSpo2,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pre-operative preparation completed. Ready for anaesthesia.')),
    );
  }

  void _saveAnaesthesia(OtCase otCase) {
    otCase.anaesthesiaNotes = _anaesthesiaNotesController.text;
    otCase.anaesthesiaType = _selectedAnaesthesiaType;
    otCase.anaesthesiaCleared = true;
    otCase.status = 'Anaesthesia Cleared';

    _logAction(otCase, 'Cleared patient for surgery. Anaesthesia type: ${otCase.anaesthesiaType}. Notes: ${otCase.anaesthesiaNotes}.');
    
    _updateCaseInDb(otCase, {
      'status': 'Anaesthesia Cleared',
      'anaesthesia_notes': otCase.anaesthesiaNotes,
      'anaesthesia_type': otCase.anaesthesiaType,
      'anaesthesia_cleared': true,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient cleared by Anaesthetist. Status: Anaesthesia Cleared')),
    );
  }

  void _confirmHandover(OtCase otCase) {
    otCase.patientArrived = true;
    otCase.handoverVerified = true;
    otCase.handoverNotes = _handoverNotesController.text;
    otCase.status = 'Patient In OT';

    _logAction(otCase, 'Verified handover details and confirmed patient arrival inside the assigned OT Room (${otCase.otRoom}).');
    
    _updateCaseInDb(otCase, {
      'status': 'Patient In OT',
      'patient_arrived': true,
      'handover_verified': true,
      'handover_notes': otCase.handoverNotes,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient transferred to OT. Status: Patient In OT')),
    );
  }

  void _startSurgery(OtCase otCase) {
    final now = DateTime.now();
    otCase.surgeryStartTime = now;
    otCase.status = 'Surgery In Progress';

    _logAction(otCase, 'Started Surgery Procedure.');
    
    _updateCaseInDb(otCase, {
      'status': 'Surgery In Progress',
      'surgery_start_time': now.toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Surgery Started! Status: Surgery In Progress')),
    );
  }

  void _addIntraOpLog(OtCase otCase) {
    final log = IntraOpLog(
      timestamp: DateTime.now(),
      bp: _intraOpBpController.text,
      pulse: int.tryParse(_intraOpPulseController.text) ?? 74,
      temp: double.tryParse(_intraOpTempController.text) ?? 98.5,
      spo2: int.tryParse(_intraOpSpo2Controller.text) ?? 98,
      medications: _intraOpMedsController.text,
      fluids: _intraOpFluidsController.text,
      blood: _intraOpBloodController.text,
      instrumentCount: int.tryParse(_intraOpInstrumentController.text.split('/')[0]) ?? 24,
    );

    setState(() {
      otCase.intraOpLogs.add(log);
    });

    _logAction(otCase, 'Recorded intra-operative vital log (BP: ${log.bp}, PR: ${log.pulse}, SpO2: ${log.spo2}%, Instrument Count: ${log.instrumentCount}).');
    
    _updateCaseInDb(otCase, {
      'intra_op_logs': otCase.intraOpLogs.map((l) => {
        'timestamp': l.timestamp.toIso8601String(),
        'bp': l.bp,
        'pulse': l.pulse,
        'temp': l.temp,
        'spo2': l.spo2,
        'medications': l.medications,
        'fluids': l.fluids,
        'blood': l.blood,
        'instrumentCount': l.instrumentCount,
      }).toList(),
    });

    _intraOpBpController.clear();
    _intraOpPulseController.clear();
    _intraOpTempController.clear();
    _intraOpSpo2Controller.clear();
    _intraOpMedsController.clear();
    _intraOpFluidsController.clear();
    _intraOpBloodController.clear();
    _intraOpInstrumentController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intra-operative monitoring log entry saved.')),
    );
  }

  void _completeSurgery(OtCase otCase) {
    final now = DateTime.now();
    otCase.surgeryEndTime = now;
    otCase.procedureDetails = _procedureDetailsController.text;
    otCase.surgicalFindings = _findingsController.text;
    otCase.complications = _complicationsController.text;
    otCase.status = 'Surgery Completed';

    _logAction(otCase, 'Surgery Completed. Recorded procedure details, surgical findings, and complications: "${otCase.complications}".');
    
    _updateCaseInDb(otCase, {
      'status': 'Surgery Completed',
      'surgery_end_time': now.toIso8601String(),
      'procedure_details': otCase.procedureDetails,
      'surgical_findings': otCase.surgicalFindings,
      'complications': otCase.complications,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Surgery Completed! Status: Surgery Completed')),
    );
  }

  void _savePostOpNotes(OtCase otCase) {
    otCase.operationSummary = _opSummaryController.text;
    otCase.procedurePerformed = _procPerformedController.text;
    otCase.outcome = _outcomeController.text;
    otCase.postOpInstructions = _postOpInstController.text;
    otCase.followUpRecommendations = _followUpController.text;

    _logAction(otCase, 'Saved post-operative notes. Outcome: ${otCase.outcome}. Instructions: ${otCase.postOpInstructions}.');
    
    _updateCaseInDb(otCase, {
      'operation_summary': otCase.operationSummary,
      'procedure_performed': otCase.procedurePerformed,
      'outcome': otCase.outcome,
      'post_op_instructions': otCase.postOpInstructions,
      'follow_up_recommendations': otCase.followUpRecommendations,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post-operative notes saved.')),
    );
  }

  void _executeTransfer(OtCase otCase) {
    otCase.transferDestination = _selectedTransferDest;
    otCase.transferDetails = _transferDetailsController.text;
    otCase.nursingHandoverNotes = _nursingHandoverController.text;
    otCase.status = 'Post-Op Monitoring';

    _logAction(otCase, 'Transferred patient to ${otCase.transferDestination}. Handover details: ${otCase.nursingHandoverNotes}. Status: Post-Op Monitoring.');
    
    _updateCaseInDb(otCase, {
      'status': 'Post-Op Monitoring',
      'transfer_destination': otCase.transferDestination,
      'transfer_details': otCase.transferDetails,
      'nursing_handover_notes': otCase.nursingHandoverNotes,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient transferred to ${otCase.transferDestination}. Status: Post-Op Monitoring')),
    );
  }

  void _addNurseCareLog(OtCase otCase) {
    final vitalsText = _careVitalsController.text.isNotEmpty
        ? _careVitalsController.text
        : 'BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%';
    final medsText = _careMedsController.text.isNotEmpty
        ? _careMedsController.text
        : 'Paracetamol 1g IV';

    otCase.nurseCareVitalsLogs.add('$vitalsText (Recorded by Nurse at ${DateFormat('hh:mm a').format(DateTime.now())})');
    otCase.nurseMedicationsAdministered.add('$medsText (Administered at ${DateFormat('hh:mm a').format(DateTime.now())})');

    _logAction(otCase, 'Recorded nurse care entry. Vitals: $vitalsText. Meds: $medsText.');
    
    _updateCaseInDb(otCase, {
      'nurse_care_vitals_logs': otCase.nurseCareVitalsLogs,
      'nurse_medications_administered': otCase.nurseMedicationsAdministered,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nurse care details recorded.')),
    );
  }

  void _addDoctorProgressNote(OtCase otCase) {
    final noteText = _doctorProgressController.text.isNotEmpty
        ? _doctorProgressController.text
        : 'Patient recovering well. Continue monitoring.';
    otCase.doctorProgressNotes.add('$noteText (Added at ${DateFormat('hh:mm a').format(DateTime.now())})');

    _logAction(otCase, 'Doctor added progress note: "$noteText".');
    
    _updateCaseInDb(otCase, {
      'doctor_progress_notes': otCase.doctorProgressNotes,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doctor progress note saved.')),
    );
  }

  void _closeCase(OtCase otCase) {
    otCase.status = 'OT Case Closed';

    _logAction(otCase, 'Closed OT Workflow and generated final operation summary report.');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Case Closed',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('OT Case Closed for ${otCase.patientName}. Workflow completed!')),
    );
  }

  // Helper to check if step belongs to current role
  bool _canPerformAction(String requiredRole) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final userRole = user?.role ?? 'Doctor';
    if (userRole == 'Admin' || userRole == 'Super Admin') return true;
    if (requiredRole == 'Doctor' && (userRole == 'Doctor' || userRole == 'Surgeon')) return true;
    if (requiredRole == 'Surgeon' && (userRole == 'Surgeon' || userRole == 'Doctor')) return true;
    if (requiredRole == 'Nurse' && (userRole == 'Nurse' || userRole == 'OT Coordinator')) return true;
    if (requiredRole == 'OT Coordinator' && (userRole == 'OT Coordinator' || userRole == 'Nurse')) return true;
    if (requiredRole == 'Anaesthetist' && (userRole == 'Anaesthetist' || userRole == 'Doctor' || userRole == 'Surgeon')) return true;
    return false;
  }

  // Color Coding for Status Badges
  Color _getStatusColor(String status) {
    switch (status) {
      case 'OT Requested':
        return Colors.orange;
      case 'OT Scheduled':
        return Colors.blue;
      case 'Pre-Op Completed':
        return Colors.teal;
      case 'Anaesthesia Cleared':
        return Colors.indigo;
      case 'Patient In OT':
        return Colors.cyan;
      case 'Surgery In Progress':
        return Colors.purple;
      case 'Surgery Completed':
        return Colors.green;
      case 'Post-Op Monitoring':
        return Colors.pink;
      case 'OT Case Closed':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Section (Title) ───────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operation Theatre (OT) Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete Surgery Lifecycle & Patient Handover Tracking',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),

          // ── Tabs Header ───────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTabButton(0, 'OT Dashboard & Room Board', Icons.grid_view_outlined),
                const SizedBox(width: 16),
                _buildTabButton(1, 'Active Patients (${_otCases.where((c) => c.status != 'OT Case Closed').length})', Icons.people_outline),
                const SizedBox(width: 16),
                _buildTabButton(2, 'Schedule New Surgery', Icons.add_circle_outline),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Main Content Body ─────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inner view switcher
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: _buildActiveTabView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabView() {
    switch (_activeTab) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildActivePatientsView();
      case 2:
        return _buildRequestView();
      default:
        return _buildDashboardView();
    }
  }

  // ── VIEW 1: DASHBOARD & ROOM BOARD ──────────────────────────────────

  Widget _buildDashboardView() {
    // Count states
    final reqCount = _otCases.where((c) => c.status == 'OT Requested').length;
    final schedCount = _otCases.where((c) => c.status == 'OT Scheduled' || c.status == 'Pre-Op Completed' || c.status == 'Anaesthesia Cleared').length;
    final inProgress = _otCases.where((c) => c.status == 'Patient In OT' || c.status == 'Surgery In Progress').length;
    final recCount = _otCases.where((c) => c.status == 'Surgery Completed' || c.status == 'Post-Op Monitoring').length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Pending Requests', reqCount.toString(), 'Requires Schedule', Icons.calendar_month, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Scheduled Today', schedCount.toString(), 'Pre-op in progress', Icons.schedule, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Active In Surgery', inProgress.toString(), 'Live operating room', Icons.flash_on, Colors.purple)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Recovery & Post-Op', recCount.toString(), 'Monitoring vitals', Icons.monitor_heart, Colors.pink)),
            ],
          ),
          const SizedBox(height: 24),

          // OT Room Grid Layout (Visually Stunning)
          const Text(
            'Live Operation Theatre Room Occupancy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildRoomCard('OT Room 1', 'OT-1', 'OT 1')),
              const SizedBox(width: 16),
              Expanded(child: _buildRoomCard('OT Room 2', 'OT-2', 'OT 2')),
              const SizedBox(width: 16),
              Expanded(child: _buildRoomCard('OT Room 3', 'OT-3', 'OT 3')),
              const SizedBox(width: 16),
              Expanded(child: _buildRoomCard('Emergency OT', 'OT-EMERGENCY', 'Emergency OT')),
            ],
          ),
          const SizedBox(height: 24),

          // Integration Hub status
          _buildIntegrationPanel(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subText, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subText, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 24,
            child: Icon(icon, color: color, size: 24),
          )
        ],
      ),
    );
  }

  Widget _buildRoomCard(String roomName, String code, String otId) {
    // Find active case in this room
    final activeInRoom = _otCases.firstWhere(
      (c) => c.otRoom == otId && c.status != 'OT Case Closed' && c.status != 'OT Requested',
      orElse: () => OtCase(id: '', patientId: '', patientName: '', age: 0, gender: '', bloodGroup: '', diagnosis: ''),
    );

    final bool isOccupied = activeInRoom.id.isNotEmpty;
    final color = isOccupied ? _getStatusColor(activeInRoom.status) : Colors.green;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  roomName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOccupied ? color.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOccupied ? activeInRoom.status : 'AVAILABLE',
                    style: TextStyle(color: isOccupied ? color : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isOccupied
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeInRoom.patientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${activeInRoom.age} yrs \u2022 ${activeInRoom.gender} \u2022 Blood: ${activeInRoom.bloodGroup}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.healing, size: 14, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activeInRoom.surgeryType ?? '',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Surgeon: ${activeInRoom.surgeon ?? 'TBD'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Action details
                      InkWell(
                        onTap: () {
                          _selectOtCase(activeInRoom);
                          setState(() {
                            _activeTab = 1; // Go to active patients (where live tracker is inline)
                          });
                        },
                        child: Text(
                          'Open Workflow Panel \u2192',
                          style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                      SizedBox(height: 8),
                      Text(
                        'Ready for Scheduling',
                        style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'ERP Modular Integration Hub (Simulated)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildIntegrationTag('IPD Integration', 'Active: Fetches patient data from admission wards', true),
              _buildIntegrationTag('ICU Integration', 'Active: Auto-triggers alert logs for post-op ICU bed block', true),
              _buildIntegrationTag('Pharmacy Integration', 'Active: Pre-orders surgery drug packages', true),
              _buildIntegrationTag('Lab Integration', 'Active: Syncs pre-op reports (CBC, Platelets)', true),
              _buildIntegrationTag('Billing Integration', 'Active: Dynamically adds charges on case closure', true),
              _buildIntegrationTag('Nursing Dashboard', 'Active: Visual alerts of current OT state', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationTag(String title, String description, bool isConnected) {
    return Tooltip(
      message: description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
            ),
          ],
        ),
      ),
    );
  }

  // ── VIEW 2: ACTIVE WORKFLOW TIMELINE & ACTIONS ──────────────────────

  Widget _buildActivePatientsView() {
    if (_selectedCase != null && _selectedCase!.status != 'OT Case Closed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _selectedCase = null;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Back to Active Patients Registry',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildCaseWorkflowDetails(_selectedCase!)),
        ],
      );
    }

    final activeCases = _otCases.where((c) => c.status != 'OT Case Closed').toList();
    if (activeCases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: AppTheme.textSecondaryColor),
            SizedBox(height: 16),
            Text('No active patients in OT pipeline.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15)),
          ],
        ),
      );
    }

    final filteredCases = activeCases.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.patientName.toLowerCase().contains(query) ||
             c.id.toLowerCase().contains(query) ||
             (c.surgeryType ?? '').toLowerCase().contains(query) ||
             c.status.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar: Search Bar + Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Patients Registry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Grid view of Patient Cards
        Expanded(
          child: filteredCases.isEmpty
              ? const Center(
                  child: Text('No active patients match your search filter.', style: TextStyle(color: AppTheme.textSecondaryColor)),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredCases.length,
                  itemBuilder: (context, idx) {
                    final c = filteredCases[idx];
                    final avatarColors = AppTheme.getAvatarColors(c.patientName);
                    final priorityColor = c.priority == 'Emergency' ? Colors.red.shade700 : AppTheme.primaryColor;
                    final priorityBg = c.priority == 'Emergency' ? Colors.red.shade50 : AppTheme.primaryLight;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: avatarColors['bg'],
                                  child: Text(
                                    c.patientName.isNotEmpty ? c.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase() : '?',
                                    style: TextStyle(
                                      color: avatarColors['text'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.patientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimaryColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: ${c.patientId ?? c.id} \u2022 ${c.age} yrs \u2022 ${c.gender}',
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Card Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.healing_outlined, size: 14, color: AppTheme.textSecondaryColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          c.surgeryType ?? 'Diagnosis: ${c.diagnosis}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(c.status).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          c.status.toUpperCase(),
                                          style: TextStyle(
                                            color: _getStatusColor(c.status),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (c.priority != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: priorityBg,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            c.priority!.toUpperCase(),
                                            style: TextStyle(
                                              color: priorityColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      _selectOtCase(c);
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Open Live Workflow Tracker',
                                          style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward, size: 14, color: AppTheme.primaryColor),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }





  Widget _buildCaseWorkflowDetails(OtCase otCase) {
    final avatarColors = AppTheme.getAvatarColors(otCase.patientName);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient Header Details (Redesigned)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              // Large Clinical Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarColors['bg'],
                child: Text(
                  otCase.patientName.isNotEmpty ? otCase.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase() : '?',
                  style: TextStyle(
                    color: avatarColors['text'],
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Patient Info & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 320,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: otCase.id,
                              icon: const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor, size: 28),
                              ),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                                fontFamily: AppTheme.fontFamily,
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              selectedItemBuilder: (BuildContext context) {
                                final dropdownCases = _otCases
                                    .where((c) => c.status != 'OT Case Closed' || c.id == otCase.id)
                                    .toList();
                                return dropdownCases.map<Widget>((OtCase value) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      value.patientName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor,
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                              onChanged: (String? newCaseId) {
                                if (newCaseId != null) {
                                  final newCase = _otCases.firstWhere((c) => c.id == newCaseId);
                                  _selectOtCase(newCase);
                                }
                              },
                              items: _otCases
                                  .where((c) => c.status != 'OT Case Closed' || c.id == otCase.id)
                                  .map<DropdownMenuItem<String>>((OtCase value) {
                                return DropdownMenuItem<String>(
                                  value: value.id,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          value.patientName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimaryColor,
                                            fontFamily: AppTheme.fontFamily,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(value.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          value.status,
                                          style: TextStyle(
                                            color: _getStatusColor(value.status),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(otCase.status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            otCase.status,
                            style: TextStyle(color: _getStatusColor(otCase.status), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Metadata pills with icons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildHeaderMetadataChip(Icons.fingerprint, 'ID: ${otCase.patientId}'),
                        _buildHeaderMetadataChip(Icons.cake_outlined, '${otCase.age} yrs'),
                        _buildHeaderMetadataChip(
                          otCase.gender == 'Male' ? Icons.male : (otCase.gender == 'Female' ? Icons.female : Icons.transgender),
                          otCase.gender,
                        ),
                        _buildHeaderMetadataChip(Icons.bloodtype_outlined, 'Blood: ${otCase.bloodGroup}', color: Colors.red.shade700),
                        if (otCase.priority != null)
                          _buildHeaderMetadataChip(
                            Icons.warning_amber_rounded,
                            otCase.priority!,
                            color: otCase.priority == 'Emergency' ? Colors.red.shade700 : AppTheme.primaryColor,
                            bgColor: otCase.priority == 'Emergency' ? Colors.red.shade50 : AppTheme.primaryLight,
                          ),
                        _buildHeaderMetadataChip(Icons.healing_outlined, 'Diagnosis: ${otCase.diagnosis}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // OT Assignment Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          otCase.otRoom != null ? 'OT Room: ${otCase.otRoom}' : 'OT Room: Not Assigned',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 6),
                        Text(
                          otCase.surgeon != null ? 'Surgeon: ${otCase.surgeon}' : 'Surgeon: Not Assigned',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Core workflow split layout
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Vertical timeline stepper (flex 1)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 650,
                    child: _buildVerticalWorkflowStepper(otCase),
                  ),
                ),
                const SizedBox(width: 16),
                // Right Column: Tabbed Workflow Workspace (flex 2)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 650,
                  decoration: AppTheme.cardDecoration,
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TabBar(
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bolt, size: 14),
                                    const SizedBox(width: 4),
                                    Text('Active: ${_getStepShortName(otCase.status)}'),
                                  ],
                                ),
                              ),
                              const Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history, size: 14),
                                    SizedBox(width: 4),
                                    Text('Audit Trail'),
                                  ],
                                ),
                              ),
                              const Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment, size: 14),
                                    SizedBox(width: 4),
                                    Text('Case History'),
                                  ],
                                ),
                              ),
                            ],
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            labelColor: AppTheme.primaryColor,
                            unselectedLabelColor: AppTheme.textSecondaryColor,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: Interactive Step Panel
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Interactive Step Panel',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                                        ),
                                        Text(
                                          'Required: ${_getStepOperator(otCase.status)}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildStepForm(otCase),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tab 2: Audit Trail
                              _buildAuditTrailTab(otCase),
                              // Tab 3: Case History
                              _buildCaseHistoryTab(otCase),
                            ],
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
        ),
      ],
    );
  }

  Widget _buildHeaderMetadataChip(IconData icon, String label, {Color? color, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (color ?? Colors.grey.shade400).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? AppTheme.textSecondaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color ?? AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepOperator(String status) {
    switch (status) {
      case 'OT Requested':
        return 'OT Coordinator / Nurse';
      case 'OT Scheduled':
        return 'Nurse';
      case 'Pre-Op Completed':
        return 'Anaesthetist Doctor';
      case 'Anaesthesia Cleared':
        return 'Nurse';
      case 'Patient In OT':
        return 'Doctor / Surgeon';
      case 'Surgery In Progress':
        return 'Nurse & Surgeon';
      case 'Surgery Completed':
        return 'Doctor / Surgeon';
      case 'Post-Op Monitoring':
        return 'Doctor & Nurse';
      default:
        return 'N/A';
    }
  }

  String _getStepShortName(String status) {
    switch (status) {
      case 'OT Requested':
        return 'Booking';
      case 'OT Scheduled':
        return 'Pre-Op Prep';
      case 'Pre-Op Completed':
        return 'Anesthesia';
      case 'Anaesthesia Cleared':
        return 'Handover';
      case 'Patient In OT':
        return 'Start Surgery';
      case 'Surgery In Progress':
        return 'Intra-Op Log';
      case 'Surgery Completed':
        return 'Post-Op Notes';
      case 'Post-Op Monitoring':
        return 'Recovery';
      case 'OT Case Closed':
        return 'Closed';
      default:
        return 'Form';
    }
  }

  Widget _buildVerticalWorkflowStepper(OtCase otCase) {
    final steps = [
      'Surgery Requested',
      'Surgery Scheduled',
      'Pre-Op Checklist',
      'Anaesthesia Clearance',
      'Patient Handover to OT',
      'Surgery In Progress',
      'Surgery Completed',
      'Recovery & Transfer',
      'Case Closed'
    ];

    final stepIcons = [
      Icons.assignment_outlined,
      Icons.calendar_month_outlined,
      Icons.checklist_outlined,
      Icons.medical_services_outlined,
      Icons.door_sliding_outlined,
      Icons.biotech_outlined,
      Icons.check_circle_outline,
      Icons.local_hospital_outlined,
      Icons.archive_outlined
    ];

    int activeIndex = 0;
    if (otCase.status == 'OT Scheduled') activeIndex = 1;
    if (otCase.status == 'Pre-Op Completed') activeIndex = 2;
    if (otCase.status == 'Anaesthesia Cleared') activeIndex = 3;
    if (otCase.status == 'Patient In OT') activeIndex = 4;
    if (otCase.status == 'Surgery In Progress') activeIndex = 5;
    if (otCase.status == 'Surgery Completed') activeIndex = 6;
    if (otCase.status == 'Post-Op Monitoring') activeIndex = 7;
    if (otCase.status == 'OT Case Closed') activeIndex = 8;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workflow Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (context, idx) {
                bool isCompleted = idx < activeIndex;
                bool isActive = idx == activeIndex;
                bool isLast = idx == steps.length - 1;

                Color stepColor = isCompleted
                    ? Colors.green
                    : (isActive ? AppTheme.primaryColor : Colors.grey.shade300);

                Color textColor = isCompleted
                    ? Colors.green.shade800
                    : (isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor);

                // Quick visual summaries for completed/active steps
                Widget? detailsWidget;
                if (idx == 0 && otCase.surgeryType != null) {
                  detailsWidget = Text('${otCase.surgeryType} (${otCase.priority})', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 1 && otCase.otRoom != null) {
                  detailsWidget = Text('Room: ${otCase.otRoom} \u2022 ${otCase.surgerySlot}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 2 && otCase.preOpBp != null) {
                  detailsWidget = Text('Vitals: ${otCase.preOpBp}, Pulse: ${otCase.preOpPulse}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 3 && otCase.anaesthesiaType != null) {
                  detailsWidget = Text('Type: ${otCase.anaesthesiaType}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 4 && otCase.handoverNotes != null && otCase.handoverNotes!.isNotEmpty) {
                  detailsWidget = Text('Notes: ${otCase.handoverNotes}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor), maxLines: 1, overflow: TextOverflow.ellipsis);
                } else if (idx == 5 && otCase.surgeryStartTime != null) {
                  detailsWidget = Text('Started: ${DateFormat('hh:mm a').format(otCase.surgeryStartTime!)}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 6 && otCase.procedurePerformed != null) {
                  detailsWidget = Text('Performed: ${otCase.procedurePerformed}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                } else if (idx == 7 && otCase.transferDestination != null) {
                  detailsWidget = Text('To: ${otCase.transferDestination}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor));
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Node with line
                      Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.green : (isActive ? AppTheme.primaryColor : Colors.white),
                              shape: BoxShape.circle,
                              border: Border.all(color: stepColor, width: isActive ? 2 : 1),
                              boxShadow: isActive
                                  ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.25), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Icon(stepIcons[idx], size: 13, color: isActive ? Colors.white : Colors.grey.shade500),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isCompleted ? Colors.green : Colors.grey.shade200,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                steps[idx],
                                style: TextStyle(
                                  fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ACTIVE STEP',
                                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (detailsWidget != null) ...[
                                const SizedBox(height: 2),
                                detailsWidget,
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Render the proper step action panels
  Widget _buildChecklistCard({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? AppTheme.successBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppTheme.successColor.withOpacity(0.4) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            color: value ? AppTheme.successColor : AppTheme.textPrimaryColor,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.successColor,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildStepForm(OtCase otCase) {
    bool canAct = true;
    String requiredText = '';

    if (otCase.status == 'OT Requested') {
      canAct = _canPerformAction('Nurse') || _canPerformAction('OT Coordinator');
      requiredText = 'OT Coordinator or Nurse';
    } else if (otCase.status == 'OT Scheduled') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Pre-Op Completed') {
      canAct = _canPerformAction('Anaesthetist') || _canPerformAction('Doctor');
      requiredText = 'Anaesthetist or Doctor';
    } else if (otCase.status == 'Anaesthesia Cleared') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Patient In OT') {
      canAct = _canPerformAction('Surgeon') || _canPerformAction('Doctor');
      requiredText = 'Doctor or Surgeon';
    } else if (otCase.status == 'Surgery In Progress') {
      canAct = _canPerformAction('Surgeon') || _canPerformAction('Doctor') || _canPerformAction('Nurse');
      requiredText = 'Surgeon, Doctor, or Nurse';
    } else if (otCase.status == 'Surgery Completed') {
      canAct = _canPerformAction('Doctor') || _canPerformAction('Nurse');
      requiredText = 'Doctor or Nurse';
    } else if (otCase.status == 'Post-Op Monitoring') {
      canAct = _canPerformAction('Doctor') || _canPerformAction('Nurse');
      requiredText = 'Doctor or Nurse';
    }

    if (!canAct) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'Role Restricted Panel',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              'This step requires the $requiredText role. Switch your active role in the simulation dropdown at the top right to complete this step.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
        ),
      );
    }

    // Step-by-Step Forms
    if (otCase.status == 'OT Requested') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assign Scheduling Parameters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otRoomController,
                  decoration: AppTheme.standardInputDecoration(
                    label: 'Assign OT Room',
                    prefixIcon: Icons.meeting_room_outlined,
                    hintText: 'OT 1',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _slotController,
                  decoration: AppTheme.standardInputDecoration(
                    label: 'Surgery Slot',
                    prefixIcon: Icons.access_time_outlined,
                    hintText: '09:00 AM - 11:30 AM',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nursingTeamController,
            decoration: AppTheme.standardInputDecoration(
              label: 'Assign Nursing Team',
              prefixIcon: Icons.people_outline,
              hintText: 'Team A (Nurse Sarah, Nurse John)',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _confirmScheduling(otCase),
            icon: const Icon(Icons.check),
            label: const Text('Confirm Schedule Booking'),
            style: AppTheme.successButton,
          ),
        ],
      );
    }

    if (otCase.status == 'OT Scheduled') {
      return Form(
        key: _preOpVitalsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pre-Operative Preparation Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _buildChecklistCard(
              title: 'Patient Identity Verified',
              value: otCase.idVerified,
              onChanged: (val) => setState(() => otCase.idVerified = val ?? false),
            ),
            _buildChecklistCard(
              title: 'Consent Form Signed',
              value: otCase.consentSigned,
              onChanged: (val) => setState(() => otCase.consentSigned = val ?? false),
            ),
            _buildChecklistCard(
              title: 'Fasting (NPO) Confirmed',
              value: otCase.fastingConfirmed,
              onChanged: (val) => setState(() => otCase.fastingConfirmed = val ?? false),
            ),
            _buildChecklistCard(
              title: 'Lab & Investigation Reports Verified',
              value: otCase.labVerified,
              onChanged: (val) => setState(() => otCase.labVerified = val ?? false),
            ),
            _buildChecklistCard(
              title: 'Blood Availability Checked',
              value: otCase.bloodAvailable,
              onChanged: (val) => setState(() => otCase.bloodAvailable = val ?? false),
            ),
            const SizedBox(height: 20),
            const Text('Record Pre-Operative Vitals:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _preOpBpController,
                    validator: (val) => val == null || val.trim().isEmpty ? 'please enter bp' : null,
                    decoration: AppTheme.standardInputDecoration(
                      label: 'BP (mmHg)',
                      prefixIcon: Icons.monitor_heart_outlined,
                      hintText: 'enter bp',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preOpPulseController,
                    validator: (val) => val == null || val.trim().isEmpty ? 'please enter pulse' : null,
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Pulse (bpm)',
                      prefixIcon: Icons.favorite_outline,
                      hintText: 'enter pulse',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preOpTempController,
                    validator: (val) => val == null || val.trim().isEmpty ? 'please enter temp' : null,
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Temp (°F)',
                      prefixIcon: Icons.thermostat_outlined,
                      hintText: 'enter temp',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preOpSpo2Controller,
                    validator: (val) => val == null || val.trim().isEmpty ? 'please enter spo2' : null,
                    decoration: AppTheme.standardInputDecoration(
                      label: 'SpO2 (%)',
                      prefixIcon: Icons.bloodtype_outlined,
                      hintText: 'enter spo2',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (otCase.idVerified && otCase.consentSigned && otCase.fastingConfirmed && otCase.labVerified && otCase.bloodAvailable)
                  ? () {
                      if (_preOpVitalsFormKey.currentState!.validate()) {
                        _savePreOpPrep(otCase);
                      }
                    }
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mark Patient Ready for Anaesthesia'),
              style: AppTheme.primaryButton,
            ),
            if (!(otCase.idVerified && otCase.consentSigned && otCase.fastingConfirmed && otCase.labVerified && otCase.bloodAvailable))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '*All checklist items must be verified before proceeding.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }

    if (otCase.status == 'Pre-Op Completed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Anaesthesia Pre-Assessment Form:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAnaesthesiaType,
            decoration: AppTheme.standardInputDecoration(
              label: 'Anaesthesia Type',
              prefixIcon: Icons.vaccines_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'General Anaesthesia', child: Text('General Anaesthesia')),
              DropdownMenuItem(value: 'Spinal Anaesthesia', child: Text('Spinal Anaesthesia')),
              DropdownMenuItem(value: 'Epidural Anaesthesia', child: Text('Epidural Anaesthesia')),
              DropdownMenuItem(value: 'Local Anaesthesia', child: Text('Local Anaesthesia')),
              DropdownMenuItem(value: 'MAC (Monitored Care)', child: Text('MAC (Monitored Care)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedAnaesthesiaType = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _anaesthesiaNotesController,
            maxLines: 3,
            decoration: AppTheme.standardInputDecoration(
              label: 'Assessment Notes & Warnings',
              hintText: 'Enter patient history, airway, risk details...',
              prefixIcon: Icons.note_alt_outlined,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _saveAnaesthesia(otCase),
            icon: const Icon(Icons.thumb_up_alt_outlined),
            label: const Text('Clear Patient for Surgery'),
            style: AppTheme.successButton,
          ),
        ],
      );
    }

    if (otCase.status == 'Anaesthesia Cleared') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transfer Patient to OT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildChecklistCard(
            title: 'Transfer to Assigned OT Room Complete',
            value: otCase.patientArrived,
            onChanged: (val) => setState(() => otCase.patientArrived = val ?? false),
          ),
          _buildChecklistCard(
            title: 'Confirm Identity, Consent & Markings on Arrival',
            value: otCase.handoverVerified,
            onChanged: (val) => setState(() => otCase.handoverVerified = val ?? false),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _handoverNotesController,
            decoration: AppTheme.standardInputDecoration(
              label: 'OT Handover Remarks',
              hintText: 'Note any checklist variances or prep details...',
              prefixIcon: Icons.comment_outlined,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: (otCase.patientArrived && otCase.handoverVerified) ? () => _confirmHandover(otCase) : null,
            icon: const Icon(Icons.airline_seat_flat_outlined),
            label: const Text('Confirm Patient Arrived in OT Room'),
            style: AppTheme.primaryButton,
          ),
        ],
      );
    }

    if (otCase.status == 'Patient In OT') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.sensors, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Patient Ready in Operating Room',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verify that the surgical team is scrubbed, surgical site markings are checked, and all preoperative parameters are cleared.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _startSurgery(otCase),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start Surgery'),
              style: AppTheme.logoRedButton,
            ),
          ],
        ),
      );
    }

    if (otCase.status == 'Surgery In Progress') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Surgery In Progress...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
              Text('Started: ${DateFormat('hh:mm a').format(otCase.surgeryStartTime ?? DateTime.now())}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Form(
            key: _intraOpVitalsFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Intra-Operative Vital & Event Logging:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpBpController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter bp' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'BP',
                          prefixIcon: Icons.monitor_heart_outlined,
                          hintText: 'enter bp',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpPulseController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter hr' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'HR',
                          prefixIcon: Icons.favorite_outline,
                          hintText: 'enter hr',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpTempController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter temp' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Temp',
                          prefixIcon: Icons.thermostat_outlined,
                          hintText: 'enter temp',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpSpo2Controller,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter spo2' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'SpO2',
                          prefixIcon: Icons.bloodtype_outlined,
                          hintText: 'enter spo2',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpMedsController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter meds given' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Meds Given',
                          prefixIcon: Icons.vaccines_outlined,
                          hintText: 'enter meds given',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpFluidsController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter iv fluids' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'IV Fluids',
                          prefixIcon: Icons.water_drop_outlined,
                          hintText: 'enter iv fluids',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpBloodController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter blood products' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Blood Products',
                          prefixIcon: Icons.bloodtype_outlined,
                          hintText: 'enter blood products',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _intraOpInstrumentController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'please enter instrument count' : null,
                        decoration: AppTheme.standardInputDecoration(
                          label: 'Instrument Count',
                          prefixIcon: Icons.checklist_outlined,
                          hintText: 'enter instrument count',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_intraOpVitalsFormKey.currentState!.validate()) {
                      _addIntraOpLog(otCase);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Record Vitals & Log Entry'),
                  style: AppTheme.secondaryButton,
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Form(
            key: _surgeryProcedureFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complete Surgery Procedure (Doctor):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _procedureDetailsController,
                  maxLines: 2,
                  validator: (val) => val == null || val.trim().isEmpty ? 'please enter procedure details done' : null,
                  decoration: AppTheme.standardInputDecoration(
                    label: 'Procedure Details Done',
                    prefixIcon: Icons.biotech_outlined,
                    hintText: 'enter procedure details done',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _findingsController,
                  maxLines: 2,
                  validator: (val) => val == null || val.trim().isEmpty ? 'please enter surgical findings' : null,
                  decoration: AppTheme.standardInputDecoration(
                    label: 'Surgical Findings',
                    prefixIcon: Icons.search_outlined,
                    hintText: 'enter surgical findings',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _complicationsController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'please enter complications (if any)' : null,
                  decoration: AppTheme.standardInputDecoration(
                    label: 'Complications (if any)',
                    prefixIcon: Icons.report_problem_outlined,
                    hintText: 'enter complications (if any)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_surgeryProcedureFormKey.currentState!.validate()) {
                      _completeSurgery(otCase);
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Surgery & Save Details'),
                  style: AppTheme.successButton,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (otCase.status == 'Surgery Completed') {
      final isDoctor = _canPerformAction('Doctor');
      final isNurse = _canPerformAction('Nurse');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post-Operative Surgeon Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: _opSummaryController,
            maxLines: 2,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Operation Summary',
              prefixIcon: Icons.note_alt_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _procPerformedController,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Procedure Performed',
              prefixIcon: Icons.biotech_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outcomeController,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Surgical Outcome',
              prefixIcon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postOpInstController,
            maxLines: 2,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Post-Operative Instructions',
              prefixIcon: Icons.medical_information_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _followUpController,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Follow-Up Recommendations',
              prefixIcon: Icons.calendar_today_outlined,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isDoctor ? () => _savePostOpNotes(otCase) : null,
            icon: const Icon(Icons.save),
            label: const Text('Save Post-Op Notes'),
            style: AppTheme.primaryButton,
          ),
          const Divider(height: 32),

          const Text('Transfer to Recovery / ICU / Ward (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTransferDest,
            decoration: AppTheme.standardInputDecoration(
              label: 'Transfer Destination',
              prefixIcon: Icons.local_hospital_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'Recovery Room', child: Text('Recovery Room')),
              DropdownMenuItem(value: 'ICU', child: Text('ICU')),
              DropdownMenuItem(value: 'Ward', child: Text('General Ward')),
            ],
            onChanged: isNurse ? (val) {
              if (val != null) setState(() => _selectedTransferDest = val);
            } : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transferDetailsController,
            enabled: isNurse,
            decoration: AppTheme.standardInputDecoration(
              label: 'Transfer Details (e.g. Bed Number)',
              prefixIcon: Icons.bed_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nursingHandoverController,
            maxLines: 2,
            enabled: isNurse,
            decoration: AppTheme.standardInputDecoration(
              label: 'Nursing Handover Notes',
              prefixIcon: Icons.note_alt_outlined,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isNurse ? () => _executeTransfer(otCase) : null,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Confirm Patient Ward/ICU Transfer'),
            style: AppTheme.successButton,
          ),
        ],
      );
    }

    if (otCase.status == 'Post-Op Monitoring') {
      final isDoctor = _canPerformAction('Doctor');
      final isNurse = _canPerformAction('Nurse');
      final isAdmin = _canPerformAction('Admin');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post-Operative Recovery Vitals & Care (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _careVitalsController,
            enabled: isNurse,
            decoration: AppTheme.standardInputDecoration(
              label: 'Vitals Entry (BP, Pulse, Temp, SPO2)',
              prefixIcon: Icons.monitor_heart_outlined,
              hintText: 'BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _careMedsController,
            enabled: isNurse,
            decoration: AppTheme.standardInputDecoration(
              label: 'Medication Given (Dosage/Route)',
              prefixIcon: Icons.vaccines_outlined,
              hintText: 'Paracetamol 1g IV',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isNurse ? () => _addNurseCareLog(otCase) : null,
            icon: const Icon(Icons.add),
            label: const Text('Record Vitals & Med Admin Log'),
            style: AppTheme.primaryButton,
          ),
          const Divider(height: 32),

          const Text('Add Daily Progress Notes (Doctor):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _doctorProgressController,
            maxLines: 2,
            enabled: isDoctor,
            decoration: AppTheme.standardInputDecoration(
              label: 'Doctor Daily Progress Note & Treatment Plan',
              prefixIcon: Icons.note_add_outlined,
              hintText: 'Patient recovering well. Continue monitoring.',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isDoctor ? () => _addDoctorProgressNote(otCase) : null,
            icon: const Icon(Icons.note_add),
            label: const Text('Add Progress Note'),
            style: AppTheme.secondaryButton,
          ),
          const Divider(height: 32),

          const Text('OT Workflow Closure:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          const Text(
            'Ensure the patient recovery is satisfactory, billing entries are complete, and documentation is closed.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (isDoctor || isAdmin) ? () => _closeCase(otCase) : null,
            icon: const Icon(Icons.archive),
            label: const Text('Approve OT Closure & Generate Summary'),
            style: AppTheme.logoRedButton,
          ),
        ],
      );
    }

    return const SizedBox();
  }

  // Tabs for right panel (Redesigned with vertical timelines and card layouts)
  Widget _buildAuditTrailTab(OtCase otCase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: otCase.auditLogs.isEmpty
          ? const Center(child: Text('No audit logs yet.'))
          : ListView.builder(
              itemCount: otCase.auditLogs.length,
              itemBuilder: (context, idx) {
                final log = otCase.auditLogs[idx];
                bool isLast = idx == otCase.auditLogs.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline nodes and connected line
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: idx == 0 ? AppTheme.primaryColor : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: idx == 0 ? AppTheme.primaryColor.withOpacity(0.3) : Colors.white,
                                width: idx == 0 ? 3 : 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: Colors.grey.shade200,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Content details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.action,
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: idx == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: idx == 0 ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By: ${log.actorName} (${log.role}) \u2022 ${DateFormat('hh:mm a').format(log.timestamp)}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMutedColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCaseHistoryTab(OtCase otCase) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistorySection('Surgery Booking', [
            'Procedure: ${otCase.surgeryType ?? "Not scheduled"}',
            'Priority: ${otCase.priority ?? "N/A"}',
            'Surgeon: ${otCase.surgeon ?? "N/A"}',
            'Time: ${otCase.surgeryDateTime != null ? DateFormat('dd/MM/yyyy hh:mm a').format(otCase.surgeryDateTime!) : "N/A"}',
          ]),
          if (otCase.preOpBp != null)
            _buildHistorySection('Pre-Operative Vitals', [
              'BP: ${otCase.preOpBp}',
              'Pulse: ${otCase.preOpPulse} bpm',
              'Temp: ${otCase.preOpTemp} °F',
              'SpO2: ${otCase.preOpSpo2}%',
            ]),
          if (otCase.anaesthesiaType != null)
            _buildHistorySection('Anaesthesia Clearance', [
              'Type: ${otCase.anaesthesiaType}',
              'Notes: ${otCase.anaesthesiaNotes ?? "None"}',
            ]),
          if (otCase.procedureDetails != null)
            _buildHistorySection('Intra-Operative Notes', [
              'Procedure Done: ${otCase.procedureDetails}',
              'Findings: ${otCase.surgicalFindings}',
              'Complications: ${otCase.complications ?? "None"}',
            ]),
          if (otCase.intraOpLogs.isNotEmpty)
            _buildHistorySection('Intra-Op Monitoring Logs', 
              otCase.intraOpLogs.map((l) => 'Time: ${DateFormat('hh:mm a').format(l.timestamp)} \u2022 BP: ${l.bp} \u2022 HR: ${l.pulse} \u2022 SpO2: ${l.spo2}%').toList()
            ),
          if (otCase.operationSummary != null)
            _buildHistorySection('Post-Operative Surgeon Notes', [
              'Summary: ${otCase.operationSummary}',
              'Outcome: ${otCase.outcome}',
              'Post-Op Care Inst: ${otCase.postOpInstructions}',
            ]),
          if (otCase.nurseCareVitalsLogs.isNotEmpty)
            _buildHistorySection('Recovery Vitals Log', otCase.nurseCareVitalsLogs),
          if (otCase.nurseMedicationsAdministered.isNotEmpty)
            _buildHistorySection('Meds Administered Log', otCase.nurseMedicationsAdministered),
          if (otCase.doctorProgressNotes.isNotEmpty)
            _buildHistorySection('Doctor Progress Notes', otCase.doctorProgressNotes),
        ],
      ),
    );
  }

  Widget _buildHistorySection(String title, List<String> lines) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_outline, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) {
              if (l.contains(':')) {
                final parts = l.split(':');
                final key = parts[0].trim();
                final val = parts.sublist(1).join(':').trim();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontFamily: AppTheme.fontFamily),
                      children: [
                        TextSpan(text: '$key: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: val),
                      ],
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(l, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    final hasStar = text.endsWith('*');
    final cleanText = hasStar ? text.substring(0, text.length - 1).trim() : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: cleanText,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasStar)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _noLabelDecoration({required String hintText, IconData? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.4),
      ),
    );
  }

  // ── VIEW 3: SCHEDULE NEW SURGERY REQUEST (Step 1) ─────────────────

  Widget _buildRequestView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Form(
        key: _requestFormKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Operation Theatre Surgery Request',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
              ),
              const Text(
                'Enter surgery request details for scheduling and pre-op preparation.',
                style: TextStyle(color: AppTheme.textMutedColor, fontSize: 12),
              ),
              const Divider(height: 32),

              const Text('Patient Demographics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              if (_isLoadingPatients)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Loading patients from database...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                    ],
                  ),
                )
              else ...[
                CustomDropdownSearch(
                  label: 'Select Patient from DB (Auto-populates fields)',
                  hint: 'search by name or patient id',
                  value: _selectedPatientId,
                  dropdownMap: {
                    for (var p in _patients)
                      p.id.toString(): '${p.name} (${p.patientId ?? "ID: ${p.id}"})'
                  },
                  onChanged: (val) {
                    if (val != null) {
                      final p = _patients.firstWhere((p) => p.id.toString() == val);
                      setState(() {
                        _selectedPatientId = val;
                        _selectedPatientDisplayId = p.patientId ?? 'PT-${p.id}';
                        _patientNameController.text = p.name;
                        _ageController.text = p.age.toString();
                        
                        // Normalize Gender
                        final gen = p.gender.trim();
                        if (gen.toLowerCase().startsWith('m')) {
                          _selectedGender = 'Male';
                        } else if (gen.toLowerCase().startsWith('f')) {
                          _selectedGender = 'Female';
                        } else {
                          _selectedGender = 'Other';
                        }

                        // Normalize Blood Group
                        final bg = p.bloodGroup.trim();
                        final allowedBloodGroups = ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'];
                        if (allowedBloodGroups.contains(bg)) {
                          _selectedBloodGroup = bg;
                        } else {
                          _selectedBloodGroup = 'O+';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Patient Full Name *'),
                        TextFormField(
                          controller: _patientNameController,
                          decoration: _noLabelDecoration(hintText: 'enter patient name'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'please enter patient name' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Age *'),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: _noLabelDecoration(hintText: 'enter age'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'please enter age' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdownSearch(
                      label: 'Gender',
                      hint: 'select gender',
                      value: _selectedGender,
                      dropdownItems: const ['Male', 'Female', 'Other'],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdownSearch(
                      label: 'Blood Group',
                      hint: 'select blood group',
                      value: _selectedBloodGroup,
                      dropdownItems: const ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBloodGroup = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Diagnosis Details *'),
                  TextFormField(
                    controller: _diagnosisController,
                    decoration: _noLabelDecoration(hintText: 'enter diagnosis'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'please enter diagnosis' : null,
                  ),
                ],
              ),

              const SizedBox(height: 32),
              const Text('Surgery Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomDropdownSearch(
                      label: 'Surgery Type',
                      hint: 'select surgery type',
                      value: _selectedSurgeryType,
                      dropdownItems: const [
                        'Laparoscopic Cholecystectomy',
                        'Appendectomy',
                        'Hernioplasty (Mesh Repair)',
                        'Total Knee Replacement',
                        'CABG (Heart Bypass)',
                        'Cataract Surgery',
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSurgeryType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdownSearch(
                      label: 'Priority / Urgency',
                      hint: 'select priority',
                      value: _selectedPriority,
                      dropdownItems: const ['Elective', 'Emergency'],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPriority = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Surgery Date', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListTile(
                      title: const Text('Suggested Time', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                      subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _isLoadingDoctors
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        : CustomDropdownSearch(
                            label: 'Primary Surgeon Name',
                            requiredMark: true,
                            hint: 'search surgeon',
                            value: _surgeonController.text.isNotEmpty ? _surgeonController.text : null,
                            dropdownItems: _doctors.isNotEmpty
                                ? _doctors.map((d) => d.fullname).toList()
                                : const ['Dr. Vikram Sen', 'Dr. Rajesh Shah', 'Dr. Sanjay Gupta', 'Dr. Amit Singhal', 'Dr. Sunita Mehta'],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _surgeonController.text = val;
                                });
                              }
                            },
                            validator: (val) => val == null || val.isEmpty ? 'please select primary surgeon' : null,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _isLoadingDoctors
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        : CustomDropdownSearch(
                            label: 'Suggested Anaesthetist',
                            requiredMark: true,
                            hint: 'search anaesthetist',
                            value: _anaesthetistController.text.isNotEmpty ? _anaesthetistController.text : null,
                            dropdownItems: _doctors.isNotEmpty
                                ? _doctors.map((d) => d.fullname).toList()
                                : const ['Dr. Vikram Sen', 'Dr. Rajesh Shah', 'Dr. Sanjay Gupta', 'Dr. Amit Singhal', 'Dr. Sunita Mehta'],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _anaesthetistController.text = val;
                                });
                              }
                            },
                            validator: (val) => val == null || val.isEmpty ? 'please select suggested anaesthetist' : null,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Remarks / Special Instructions'),
                  TextFormField(
                    controller: _remarksController,
                    maxLines: 2,
                    decoration: _noLabelDecoration(hintText: 'enter remarks'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveSurgeryRequest,
                icon: const Icon(Icons.save),
                label: const Text('Request Surgery & Open Case File'),
                style: AppTheme.primaryButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
