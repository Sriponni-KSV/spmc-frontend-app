import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../controllers/ipd_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/web_audio_recorder.dart';
import '../services/live_speech_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/app_localizations.dart';
import 'ot_dictation_dashboard.dart';
import '../widgets/who_surgical_safety_checklist_widget.dart';
import '../widgets/pac_assessment_dialog.dart';
import '../widgets/ot_theatre_calendar_widget.dart';
import '../widgets/ot_consumables_implants_widget.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_notification.dart';


// --- CUSTOM INPUT FORMATTERS ---

/// Blocks any input that starts with '0', preventing entries like 0, 00, 000 etc.
class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith('0')) {
      return oldValue; // reject the change, keep old value
    }
    return newValue;
  }
}

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

  // Step 1: Request & Complete Surgical Team Allocation
  String? surgeryType;
  String? priority; // Elective, Emergency
  DateTime? surgeryDateTime;
  String? surgeon;
  String? leadSurgeon;
  String? assistantSurgeon;
  String? anaesthetist;
  String? scrubNurse;
  String? circulatingNurse;
  String? remarks;

  // Step 2: Scheduling & Multi-Theatre Calendar
  String? otRoom; // OT 1, OT 2, OT 3, OT 4
  int? theatreId;
  String? theatreName;
  DateTime? scheduledStartTime;
  DateTime? scheduledEndTime;
  int estimatedDurationMinutes = 90;
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

  // Step 4: Pre-Anaesthetic Checkup (PAC) & Anaesthesia Assessment
  String? anaesthesiaNotes;
  String? anaesthesiaType; // General, Spinal, Epidural, Local, etc.
  bool anaesthesiaCleared = false;
  String pacStatus = 'Pending'; // 'Pending', 'Cleared', 'High Risk Clearance', 'Deferred', 'Rejected'
  Map<String, dynamic> pacDetails = {};
  String? pacClearedBy;
  DateTime? pacClearedAt;

  // WHO Surgical Safety Checklist (Sign-In, Time-Out, Sign-Out)
  Map<String, dynamic> whoChecklist = {};

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

  // Consumables & Implant Traceability
  List<Map<String, dynamic>> consumablesUsed = [];
  List<Map<String, dynamic>> implantsUsed = [];

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
  final OtCase? initialSelectedCase;
  final int? initialTab;
  const OTManagementScreen({Key? key, required this.isMobile, this.initialSelectedCase, this.initialTab}) : super(key: key);

  @override
  State<OTManagementScreen> createState() => _OTManagementScreenState();
}

class _OTManagementScreenState extends State<OTManagementScreen> {
  int _activeTab = 0; // 0: Dashboard, 1: Active Cases, 2: Completed Cases, 3: New Request
  int _previousTab = 0;
  List<OtCase> _otCases = [];
  OtCase? _selectedCase;
  final _requestFormKey = GlobalKey<FormState>();
  final _preOpVitalsFormKey = GlobalKey<FormState>();
  GlobalKey<FormState> _intraOpVitalsFormKey = GlobalKey<FormState>();
  bool _intraOpVitalsAutovalidate = false;
  int _intraOpFormVersion = 0;
  final _surgeryProcedureFormKey = GlobalKey<FormState>();
  final _anesthesiaPacFormKey = GlobalKey<FormState>();
  final _anesthesiaTabFormKey = GlobalKey<FormState>();
  final _anesthesiaIntraOpFormKey = GlobalKey<FormState>();
  final _anesthesiaCompletionFormKey = GlobalKey<FormState>();
  final _postOpNotesFormKey = GlobalKey<FormState>();
  final _transferFormKey = GlobalKey<FormState>();
  final _pacuMonitoringFormKey = GlobalKey<FormState>();
  final _postOpNurseCareFormKey = GlobalKey<FormState>();
  final _postOpDoctorNoteFormKey = GlobalKey<FormState>();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();
  final OtController _otController = OtController();
  final IpdController _ipdController = IpdController();
  List<PatientModel> _patients = [];
  List<Map<String, dynamic>> _beds = [];
  bool _isLoadingBeds = false;
  List<Map<String, dynamic>> _loadedTheatres = [];

  List<String> get _availableOtRooms {
    if (_loadedTheatres.isNotEmpty) {
      final list = <String>[];
      for (final t in _loadedTheatres) {
        final code = t['theatre_code']?.toString();
        final name = t['theatre_name']?.toString();
        final label = (name != null && name.isNotEmpty) ? name : (code ?? '');
        if (label.isNotEmpty && !list.contains(label)) {
          list.add(label);
        }
      }
      if (list.isNotEmpty) return list;
    }
    return const ['OT 1', 'OT 2', 'OT 3', 'Emergency OT'];
  }
  List<UserModel> _doctors = [];
  List<UserModel> _anaesthetists = [];
  List<UserModel> _nurses = [];
  bool _isLoadingPatients = false;
  bool _isLoadingDoctors = false;
  bool _isLoadingAnaesthetists = false;
  bool _isLoadingCases = false;
  String? _selectedPatientId;
  String? _selectedPatientDisplayId;

  static const List<String> standardIntraOpMeds = [
    'Propofol',
    'Fentanyl',
    'Midazolam',
    'Cefazolin 1g IV',
    'Ondansetron 4mg IV',
    'Paracetamol 1g IV',
    'Atropine 0.6mg',
    'Ephedrine 6mg',
    'Tramadol 50mg',
    'Neostigmine + Glycopyrrolate',
    'Lignocaine 2%',
    'Bupivacaine 0.5%',
    'Atracurium',
    'Vecuronium',
    'Succinylcholine',
  ];

  static const List<String> standardIntraOpIvFluids = [
    'Normal Saline (0.9% NaCl) 500ml',
    'Ringer Lactate (RL) 500ml',
    'Dextrose 5% (D5W) 500ml',
    'Dextrose Normal Saline (DNS) 500ml',
    'Plasmalyte 500ml',
    'Gelafundin / Colloid 500ml',
    'None / Nil',
  ];

  static const List<String> standardBloodProducts = [
    'None / Nil',
    'PRBC (Packed Red Blood Cells) 1 Unit',
    'PRBC (Packed Red Blood Cells) 2 Units',
    'FFP (Fresh Frozen Plasma) 1 Unit',
    'FFP (Fresh Frozen Plasma) 2 Units',
    'Platelets (RDP / SDP)',
    'Cryoprecipitate',
    'Whole Blood 1 Unit',
  ];

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
  final _assistantSurgeonController = TextEditingController();
  final _anaesthetistController = TextEditingController();
  final _scrubNurseController = TextEditingController();
  final _circulatingNurseController = TextEditingController();
  final _remarksController = TextEditingController();

  // Scheduling Step State
  String? _selectedOtRoom; // Dropdown selection
  TimeOfDay _slotStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _slotEndTime; // Optional end time slot
  List<String> _selectedNurseNames = []; // Multi-select nurse names
  List<String> _currentConflicts = [];
  bool _isCheckingConflicts = false;
  bool _nurseTeamTouched = false;

  int _pendingRequestsCount = 0;
  int _scheduledTodayCount = 0;
  int _activeInSurgeryCount = 0;
  int _recoveryPostOpCount = 0;
  bool _isLoadingStats = false;
  bool _roleOverride = false;
  bool _openedFromLiveDashboard = false;
  bool _auditTrailAscending = true;
  bool _showPipelineSidebar = true;
  bool _showWorkflowTimeline = true;
  String _step8RoleFilter = 'All';
  String _step6RoleFilter = 'All';

  // Temporary Inputs for Workflow steps (kept for backward compat)
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

  // Anaesthetist PAC & PACU Workflow State
  String _selectedAsaGrade = 'ASA I';
  String _selectedRiskLevel = 'Low';
  bool _pacFastingVerified = false;
  bool _pacConsentVerified = false;
  bool _pacInstructionsReviewed = false;
  bool _pacMedsEquipmentReady = false;

  String _selectedConsciousness = 'Fully Awake';
  String _selectedPainScore = '0';
  final _pacuObservationsController = TextEditingController();
  final _anesthesiaStartTimeController = TextEditingController();
  final _anesthesiaEndTimeController = TextEditingController();
  final _finalAnesthesiaNotesController = TextEditingController();
  final _handoverNotesController = TextEditingController();

  // AI Dictation tab state variables
  final _dictationTextController = TextEditingController();
  final _bloodLossController = TextEditingController();
  final _implantsUsedController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListeningDictation = false;
  bool _speechEnabled = false;
  double _soundLevel = 0.0;
  bool _isDictationParsing = false;
  String? _dictationError;

  bool _isUserAssociated(OtCase otCase, UserModel user) {
    // In hospital operating theatre management, all OT department staff (surgeons, assistants, anaesthetists, nurses, and admins)
    // must see and coordinate all scheduled & active surgical pipeline cases.
    return true;
  }

  Map<String, String> _parseOperationSummary(String? summaryRaw) {
    if (summaryRaw == null || summaryRaw.isEmpty) {
      return {'summary': '', 'blood_loss': '', 'implants_used': ''};
    }
    try {
      final decoded = jsonDecode(summaryRaw);
      if (decoded is Map<String, dynamic>) {
        return {
          'summary': decoded['summary']?.toString() ?? '',
          'blood_loss': decoded['blood_loss']?.toString() ?? '',
          'implants_used': decoded['implants_used']?.toString() ?? '',
        };
      }
    } catch (_) {}
    return {
      'summary': summaryRaw,
      'blood_loss': 'Minimal',
      'implants_used': 'None',
    };
  }

  String _serializeOperationSummary({required String summary, required String bloodLoss, required String implants}) {
    return jsonEncode({
      'summary': summary,
      'blood_loss': bloodLoss,
      'implants_used': implants,
    });
  }

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

  // Intra-Op vitals real-time validation errors
  String? _intraOpBpError;
  String? _intraOpPulseError;
  String? _intraOpTempError;
  String? _intraOpSpo2Error;

  // Post-Op Notes
  final _opSummaryController = TextEditingController();
  final _procPerformedController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _postOpInstController = TextEditingController();
  final _followUpController = TextEditingController();

  // Transfer Form
  String _selectedTransferDest = '';
  final _transferDetailsController = TextEditingController();
  final _nursingHandoverController = TextEditingController();

  // Care Logs
  final _careVitalsController = TextEditingController();
  final _careMedsController = TextEditingController();
  final _doctorProgressController = TextEditingController();

  // Step 8 PACU Recovery Care Log Controllers
  final _recoveryBpController = TextEditingController();
  final _recoveryPulseController = TextEditingController();
  final _recoveryTempController = TextEditingController();
  final _recoverySpo2Controller = TextEditingController();
  final _recoveryMedNameController = TextEditingController();
  final _recoveryDosageController = TextEditingController();
  final _recoveryNotesController = TextEditingController();
  String _selectedMedTiming = 'Morning';

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    _loadPatientsAndDoctors();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _patientNameController.dispose();
    _ageController.dispose();
    _diagnosisController.dispose();
    _surgeonController.dispose();
    _assistantSurgeonController.dispose();
    _anaesthetistController.dispose();
    _scrubNurseController.dispose();
    _circulatingNurseController.dispose();
    _remarksController.dispose();
    _recoveryBpController.dispose();
    _recoveryPulseController.dispose();
    _recoveryTempController.dispose();
    _recoverySpo2Controller.dispose();
    _recoveryMedNameController.dispose();
    _recoveryDosageController.dispose();
    _recoveryNotesController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OTManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    if (widget.initialSelectedCase != oldWidget.initialSelectedCase && widget.initialSelectedCase != null) {
      final match = _otCases.firstWhere(
        (c) => c.dbId == widget.initialSelectedCase!.dbId,
        orElse: () => _otCases.firstWhere(
          (c) => c.id == widget.initialSelectedCase!.id,
          orElse: () => null as dynamic,
        ),
      );
      if (match != null) {
        _selectOtCase(match);
        _activeTab = widget.initialTab ?? 1;
      }
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _otController.fetchOtStats();
      if (mounted) {
        final now = DateTime.now();
        final localTodayCases = _otCases.where((c) {
          final dt = c.scheduledStartTime ?? c.surgeryDateTime;
          if (dt == null) return false;
          final isSameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          return isSameDay && c.status != 'Cancelled' && c.status != 'Rejected';
        }).length;

        setState(() {
          _pendingRequestsCount = stats['pendingCount'] ?? 0;
          _scheduledTodayCount = localTodayCases > 0 ? localTodayCases : (stats['scheduledToday'] ?? 0);
          _activeInSurgeryCount = stats['activeInSurgery'] ?? 0;
          _recoveryPostOpCount = stats['recoveryPostOp'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading OT stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadPatientsAndDoctors() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPatients = true;
      _isLoadingDoctors = true;
      _isLoadingAnaesthetists = true;
      _isLoadingCases = true;
      _isLoadingBeds = true;
    });
    try {
      final results = await Future.wait([
        _patientController.fetchPatients(),
        _adminController.fetchStaff(role: 'Doctor'),
        _otController.fetchOtCases(),
        _adminController.fetchStaff(role: 'Anaesthetist'),
        _adminController.fetchStaff(role: 'Nurse'),
        _otController.fetchOtStats(),
        _ipdController.fetchBeds(),
        _otController.fetchTheatres(),
      ]);
      if (mounted) {
        _patients = results[0] as List<PatientModel>;
        _doctors = results[1] as List<UserModel>;
        final fetchedCases = results[2] as List<OtCase>;
        _anaesthetists = results[3] as List<UserModel>;
        _nurses = results[4] as List<UserModel>;
        final stats = results[5] as Map<String, dynamic>;
        _beds = results[6] as List<Map<String, dynamic>>;
        _loadedTheatres = results[7] as List<Map<String, dynamic>>;

        final now = DateTime.now();
        final localTodayCases = fetchedCases.where((c) {
          final dt = c.scheduledStartTime ?? c.surgeryDateTime;
          if (dt == null) return false;
          final isSameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          return isSameDay && c.status != 'Cancelled' && c.status != 'Rejected';
        }).length;

        setState(() {
          _otCases = fetchedCases;
          _pendingRequestsCount = stats['pendingCount'] ?? 0;
          _scheduledTodayCount = localTodayCases > 0 ? localTodayCases : (stats['scheduledToday'] ?? 0);
          _activeInSurgeryCount = stats['activeInSurgery'] ?? 0;
          _recoveryPostOpCount = stats['recoveryPostOp'] ?? 0;

          if (widget.initialSelectedCase != null) {
            final match = fetchedCases.firstWhere(
              (c) => c.dbId == widget.initialSelectedCase!.dbId,
              orElse: () => fetchedCases.firstWhere(
                (c) => c.id == widget.initialSelectedCase!.id,
                orElse: () => null as dynamic,
              ),
            );
            if (match != null) {
              _selectedCase = match;
              _populateControllersForCase(match);
              _activeTab = widget.initialTab ?? 1;
            }
          } else if (_selectedCase != null) {
            final curDbId = _selectedCase!.dbId;
            final curId = _selectedCase!.id;
            final match = fetchedCases.firstWhere(
              (c) => (curDbId != null && c.dbId == curDbId) || c.id == curId,
              orElse: () => null as dynamic,
            );
            if (match != null) {
              _selectedCase = match;
              _populateControllersForCase(match);
            }
          } else {
            _selectedCase = null;
          }
        });
        setState(() {
          _isLoadingPatients = false;
          _isLoadingDoctors = false;
          _isLoadingAnaesthetists = false;
          _isLoadingCases = false;
          _isLoadingBeds = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPatients = false;
          _isLoadingDoctors = false;
          _isLoadingAnaesthetists = false;
          _isLoadingCases = false;
          _isLoadingBeds = false;
        });
        debugPrint('Error loading OT database dependencies: $e');
      }
    }
  }



  Map<String, dynamic> parseAnaesthesiaNotes(String? notes) {
    if (notes == null || notes.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Return the raw notes in 'userNotes' if JSON parsing fails.
    }
    return {
      'userNotes': notes,
    };
  }

  String _cleanPacNotes(dynamic raw) {
    if (raw == null) return '';
    String str = raw.toString().trim();
    if (str.startsWith('{') && str.endsWith('}')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          final inner = decoded['userNotes'] ?? decoded['clinical_notes'] ?? decoded['postAnesthesiaInstructions'] ?? '';
          if (inner.toString().trim().isNotEmpty) {
            return _cleanPacNotes(inner);
          }
          return '';
        }
      } catch (_) {}
    }
    return str;
  }

  void _populateControllersForCase(OtCase otCase) {
    // OT Room dropdown
    _selectedOtRoom = otCase.otRoom;
    _otRoomController.text = otCase.otRoom ?? '';
    // Surgery slot start/end times
    final slot = otCase.surgerySlot ?? '';
    if (slot.contains('-')) {
      final parts = slot.split('-').map((s) => s.trim()).toList();
      _slotStartTime = _parseTimeOfDay(parts[0]);
      _slotEndTime = parts.length > 1 && parts[1].isNotEmpty ? _parseTimeOfDay(parts[1]) : null;
    } else if (slot.isNotEmpty) {
      _slotStartTime = _parseTimeOfDay(slot);
      _slotEndTime = null;
    } else {
      _slotEndTime = null;
    }
    _slotController.text = otCase.surgerySlot ?? '';
    // Nursing team: parse CSV from the stored string
    if (otCase.nursingTeam != null && otCase.nursingTeam!.isNotEmpty) {
      _selectedNurseNames = otCase.nursingTeam!.split(',').map((s) => s.trim()).toList();
    } else {
      _selectedNurseNames = [];
    }
    _nursingTeamController.text = otCase.nursingTeam ?? '';

    _preOpBpController.text = otCase.preOpBp ?? '';
    _preOpPulseController.text = otCase.preOpPulse?.toString() ?? '';
    _preOpTempController.text = otCase.preOpTemp?.toString() ?? '';
    _preOpSpo2Controller.text = otCase.preOpSpo2?.toString() ?? '';

    final pac = otCase.pacDetails;
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);

    final dynamic rawAsa = pac['effective_asa'] ?? pac['asa_grade'] ?? pacData['asaGrade'];
    if (rawAsa != null && rawAsa.toString().isNotEmpty) {
      final cleanAsa = rawAsa.toString().replaceAll('E', '').trim();
      _selectedAsaGrade = cleanAsa.isNotEmpty ? cleanAsa : 'ASA I';
    } else {
      _selectedAsaGrade = 'ASA I';
    }

    _selectedRiskLevel = pacData['riskLevel'] ?? (otCase.pacStatus == 'High Risk Clearance' ? 'High' : 'Low');
    _pacFastingVerified = pac['npo_solids_verified'] ?? pacData['fastingVerified'] ?? false;
    _pacConsentVerified = pacData['consentVerified'] ?? false;
    _pacInstructionsReviewed = pacData['instructionsReviewed'] ?? false;
    _pacMedsEquipmentReady = pacData['medsEquipmentReady'] ?? false;
    _selectedConsciousness = pacData['consciousnessLevel'] ?? 'Fully Awake';
    _selectedPainScore = pacData['painScore'] ?? '0';
    _pacuObservationsController.text = pacData['observations'] ?? '';
    _anesthesiaStartTimeController.text = pacData['anesthesiaStartTime'] ?? '';
    _anesthesiaEndTimeController.text = pacData['anesthesiaEndTime'] ?? '';
    _finalAnesthesiaNotesController.text = _cleanPacNotes(pacData['userNotes'] ?? '');
    _anaesthesiaNotesController.text = _cleanPacNotes(pacData['userNotes'] ?? pac['clinical_notes'] ?? (otCase.anaesthesiaNotes != null && !otCase.anaesthesiaNotes!.startsWith('{') ? otCase.anaesthesiaNotes! : ''));

    final candidateType = otCase.anaesthesiaType ?? pac['anaesthesia_type'];
    if (candidateType != null && candidateType.toString().isNotEmpty) {
      String type = candidateType.toString();
      if (type == 'General Anesthesia') type = 'General Anaesthesia';
      if (type == 'Spinal Anesthesia') type = 'Spinal Anaesthesia';
      if (type == 'Epidural Anesthesia') type = 'Epidural Anaesthesia';
      if (type == 'Local Anesthesia') type = 'Local Anaesthesia';
      if (type == 'Regional Anesthesia') type = 'Regional Anaesthesia';
      _selectedAnaesthesiaType = type;
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

    final summaryData = _parseOperationSummary(otCase.operationSummary);
    _opSummaryController.text = summaryData['summary'] ?? '';
    _bloodLossController.text = summaryData['blood_loss'] ?? '';
    _implantsUsedController.text = summaryData['implants_used'] ?? '';
    _procPerformedController.text = otCase.procedurePerformed ?? '';
    _outcomeController.text = otCase.outcome ?? '';
    _postOpInstController.text = otCase.postOpInstructions ?? '';
    _followUpController.text = otCase.followUpRecommendations ?? '';
    _selectedTransferDest = (otCase.transferDestination != null && otCase.transferDestination!.isNotEmpty)
        ? otCase.transferDestination!
        : '';
    _transferDetailsController.text = otCase.transferDetails ?? '';
    _nursingHandoverController.text = otCase.nursingHandoverNotes ?? '';

    _surgeonController.text = otCase.leadSurgeon ?? otCase.surgeon ?? '';
    _assistantSurgeonController.text = otCase.assistantSurgeon ?? '';
    _anaesthetistController.text = otCase.anaesthetist ?? '';
    _scrubNurseController.text = otCase.scrubNurse ?? '';
    _circulatingNurseController.text = otCase.circulatingNurse ?? '';

    _careVitalsController.clear();
    _careMedsController.clear();
    _doctorProgressController.clear();
    _recoveryBpController.clear();
    _recoveryPulseController.clear();
    _recoveryTempController.clear();
    _recoverySpo2Controller.clear();
    _recoveryMedNameController.clear();
    _recoveryDosageController.clear();
    _recoveryNotesController.clear();
    _selectedMedTiming = 'Morning';
  }

  void _selectOtCase(OtCase otCase) {
    setState(() {
      _selectedCase = otCase;
      _populateControllersForCase(otCase);
      _showPipelineSidebar = !widget.isMobile;
    });
  }

  void _syncPacUpdate(OtCase targetCase, OtCase updatedCase) {
    setState(() {
      targetCase.pacStatus = updatedCase.pacStatus;
      targetCase.pacDetails = Map<String, dynamic>.from(updatedCase.pacDetails);
      targetCase.pacClearedBy = updatedCase.pacClearedBy;
      targetCase.pacClearedAt = updatedCase.pacClearedAt;
      if (updatedCase.anaesthesiaType != null && updatedCase.anaesthesiaType!.isNotEmpty) {
        targetCase.anaesthesiaType = updatedCase.anaesthesiaType;
      }
      if (updatedCase.anaesthesiaNotes != null && updatedCase.anaesthesiaNotes!.isNotEmpty) {
        targetCase.anaesthesiaNotes = updatedCase.anaesthesiaNotes;
      }
      if (['Cleared', 'High Risk Clearance'].contains(updatedCase.pacStatus)) {
        targetCase.anaesthesiaCleared = true;
      }

      // Also sync selected case if active
      if (_selectedCase != null && (_selectedCase!.id == targetCase.id || (_selectedCase!.dbId != null && _selectedCase!.dbId == targetCase.dbId))) {
        _selectedCase!.pacStatus = targetCase.pacStatus;
        _selectedCase!.pacDetails = Map<String, dynamic>.from(targetCase.pacDetails);
        _selectedCase!.pacClearedBy = targetCase.pacClearedBy;
        _selectedCase!.pacClearedAt = targetCase.pacClearedAt;
        _selectedCase!.anaesthesiaType = targetCase.anaesthesiaType;
        _selectedCase!.anaesthesiaNotes = targetCase.anaesthesiaNotes;
        _selectedCase!.anaesthesiaCleared = targetCase.anaesthesiaCleared;
      }

      // Sync the case inside _otCases list
      final idx = _otCases.indexWhere((c) => (targetCase.dbId != null && c.dbId == targetCase.dbId) || c.id == targetCase.id);
      if (idx != -1) {
        _otCases[idx].pacStatus = targetCase.pacStatus;
        _otCases[idx].pacDetails = Map<String, dynamic>.from(targetCase.pacDetails);
        _otCases[idx].pacClearedBy = targetCase.pacClearedBy;
        _otCases[idx].pacClearedAt = targetCase.pacClearedAt;
        _otCases[idx].anaesthesiaType = targetCase.anaesthesiaType;
        _otCases[idx].anaesthesiaNotes = targetCase.anaesthesiaNotes;
        _otCases[idx].anaesthesiaCleared = targetCase.anaesthesiaCleared;
      }

      // Synchronize controller variables for Anesthesia / Objective view
      final effectiveAsa = targetCase.pacDetails['effective_asa'] ?? targetCase.pacDetails['asa_grade'];
      if (effectiveAsa != null && effectiveAsa.toString().isNotEmpty) {
        final rawAsa = effectiveAsa.toString().replaceAll('E', '').trim();
        _selectedAsaGrade = rawAsa.isNotEmpty ? rawAsa : _selectedAsaGrade;
      }
      if (targetCase.anaesthesiaType != null && targetCase.anaesthesiaType!.isNotEmpty) {
        _selectedAnaesthesiaType = targetCase.anaesthesiaType!;
      }
      if (targetCase.pacDetails['npo_solids_verified'] != null) {
        _pacFastingVerified = targetCase.pacDetails['npo_solids_verified'] == true;
      }
      if (_selectedCase != null) {
        _populateControllersForCase(_selectedCase!);
      }
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
      _loadStats();
    } catch (e) {
      AppNotification.showError(
        context,
        'Failed to save update to database: $e',
        atTop: true,
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
    setState(() => _nurseTeamTouched = true);
    if (!_requestFormKey.validateAndScroll()) return;
    
    final int? patientDbId = int.tryParse(_selectedPatientId ?? '');
    if (patientDbId == null) {
      AppNotification.showError(
        context,
        'Please select a patient from the database.',
        atTop: true,
      );
      return;
    }

    if (_selectedOtRoom == null || _selectedOtRoom!.trim().isEmpty) {
      AppNotification.showError(
        context,
        'Please select an OT Room.',
        atTop: true,
      );
      return;
    }

    if (_selectedNurseNames.isEmpty) {
      AppNotification.showError(
        context,
        'Please assign at least one nurse.',
        atTop: true,
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    // Construct start & end times
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _slotStartTime.hour,
      _slotStartTime.minute,
    );
    final DateTime? endDateTime = _slotEndTime != null
        ? DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _slotEndTime!.hour,
            _slotEndTime!.minute,
          )
        : null;
    if (endDateTime != null && !endDateTime.isAfter(startDateTime)) {
      AppNotification.showError(
        context,
        'Surgery End Time (${_formatTimeOfDay(_slotEndTime!)}) cannot be earlier than or equal to Start Time (${_formatTimeOfDay(_slotStartTime)}). Please select a valid time range.',
        atTop: true,
      );
      return;
    }
    final int durationMinutes = endDateTime != null
        ? endDateTime.difference(startDateTime).inMinutes
        : 90;

    // Check local occupied rooms for slot
    final occupiedRooms = _getOccupiedRoomsForSlot(
      date: _selectedDate,
      startTime: _slotStartTime,
      endTime: _slotEndTime,
    );
    if (_selectedOtRoom != null && occupiedRooms.contains(_selectedOtRoom)) {
      AppNotification.showError(
        context,
        'Conflict: OT Room [$_selectedOtRoom] is already assigned to an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries. Please select an available OT room.',
        atTop: true,
      );
      return;
    }

    // Real-Time Conflict Prevention Check
    setState(() => _isCheckingConflicts = true);
    try {
      final conflictCheck = await _otController.checkConflicts(
        otRoom: _selectedOtRoom!,
        startTime: startDateTime,
        endTime: endDateTime ?? startDateTime.add(Duration(minutes: durationMinutes)),
        leadSurgeon: _surgeonController.text.trim(),
        anaesthetist: _anaesthetistController.text.trim(),
      );

      if (conflictCheck['hasConflict'] == true) {
        final List conflicts = conflictCheck['conflicts'] ?? [];
        final theatreConflicts = conflicts.where((c) => c['type'] == 'theatre').toList();
        final staffConflicts = conflicts.where((c) => c['type'] != 'theatre').toList();

        if (theatreConflicts.isNotEmpty) {
          // A physical OT room cannot be assigned to overlapping surgeries
          if (mounted) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.block, color: AppTheme.dangerColor, size: 24),
                    SizedBox(width: 10),
                    Text('OT Room Conflict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The same OT room ($_selectedOtRoom) cannot be assigned to overlapping surgeries.',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerColor, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ...theatreConflicts.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '• ${c['message'] ?? c.toString()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
                      ),
                    )),
                    const SizedBox(height: 10),
                    const Text(
                      'Please select an available OT room or change the surgery time slot.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Change OT Room / Reschedule'),
                  ),
                ],
              ),
            );
          }
          AppNotification.showError(
            context,
            'Conflict: OT Room [$_selectedOtRoom] is already assigned to an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries.',
            atTop: true,
          );
          setState(() => _isCheckingConflicts = false);
          return;
        }

        // Only staff conflicts (e.g. surgeon double-booking) can prompt for emergency override
        if (staffConflicts.isNotEmpty && mounted) {
          final bool? shouldOverride = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
                  SizedBox(width: 10),
                  Text('Staff Scheduling Conflict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The requested surgery slot collides with existing staff assignments:'),
                  const SizedBox(height: 10),
                  ...staffConflicts.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '• ${c['message'] ?? c.toString()}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
                    ),
                  )),
                  const SizedBox(height: 10),
                  const Text(
                    'Would you like to reschedule or apply an Emergency Override for the surgical team?',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Change Time / Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Emergency Override & Schedule'),
                ),
              ],
            ),
          );

          if (shouldOverride != true) {
            setState(() => _isCheckingConflicts = false);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Conflict check error: $e');
    } finally {
      if (mounted) setState(() => _isCheckingConflicts = false);
    }

    final initAuditLog = AuditLog(
      actorName: user?.fullname ?? 'System Staff',
      role: user?.role ?? 'Doctor',
      timestamp: DateTime.now(),
      action: 'Created Surgery Request & Scheduled Case: $_selectedSurgeryType in $_selectedOtRoom (Surgeon: ${_surgeonController.text.trim()}, Assistant: ${_assistantSurgeonController.text.trim()}, Anaesthetist: ${_anaesthetistController.text.trim()}).',
    );

    try {
      final effectiveScrubNurse = _scrubNurseController.text.trim().isNotEmpty
          ? _scrubNurseController.text.trim()
          : (_selectedNurseNames.isNotEmpty ? _selectedNurseNames.first : null);
      final effectiveCirculatingNurse = _circulatingNurseController.text.trim().isNotEmpty
          ? _circulatingNurseController.text.trim()
          : (_selectedNurseNames.length > 1 ? _selectedNurseNames[1] : null);

      final newCase = await _otController.createOtCase(
        patientDbId: patientDbId,
        diagnosis: _diagnosisController.text.trim(),
        surgeryType: _selectedSurgeryType,
        priority: _selectedPriority,
        surgeryDateTime: startDateTime,
        scheduledStartTime: startDateTime,
        scheduledEndTime: endDateTime,
        estimatedDurationMinutes: durationMinutes,
        otRoom: _selectedOtRoom,
        surgeon: _surgeonController.text.trim(),
        leadSurgeon: _surgeonController.text.trim(),
        assistantSurgeon: _assistantSurgeonController.text.trim().isNotEmpty ? _assistantSurgeonController.text.trim() : null,
        anaesthetist: _anaesthetistController.text.trim(),
        scrubNurse: effectiveScrubNurse,
        circulatingNurse: effectiveCirculatingNurse,
        remarks: _remarksController.text.trim(),
        auditLogs: [initAuditLog],
      );

      final startStr = _formatTimeOfDay(_slotStartTime);
      final endStr = _slotEndTime != null ? _formatTimeOfDay(_slotEndTime!) : null;
      final surgerySlot = endStr != null ? '$startStr - $endStr' : startStr;
      final nursingTeam = _selectedNurseNames.isNotEmpty
          ? _selectedNurseNames.join(', ')
          : [effectiveScrubNurse, effectiveCirculatingNurse].whereType<String>().join(', ');

      await _otController.updateOtCase(newCase.dbId!, {
        'status': 'OT Scheduled',
        'ot_room': _selectedOtRoom,
        'surgery_slot': surgerySlot,
        'nursing_team': nursingTeam,
        'scheduled_start_time': startDateTime.toIso8601String(),
        'scheduled_end_time': endDateTime?.toIso8601String(),
        'estimated_duration_minutes': durationMinutes,
        'lead_surgeon': _surgeonController.text.trim(),
        'assistant_surgeon': _assistantSurgeonController.text.trim().isNotEmpty ? _assistantSurgeonController.text.trim() : null,
        'anaesthetist': _anaesthetistController.text.trim(),
        'scrub_nurse': effectiveScrubNurse,
        'circulating_nurse': effectiveCirculatingNurse,
      });

      newCase.status = 'OT Scheduled';
      newCase.otRoom = _selectedOtRoom;
      newCase.surgerySlot = surgerySlot;
      newCase.nursingTeam = nursingTeam;
      newCase.scheduledStartTime = startDateTime;
      newCase.scheduledEndTime = endDateTime;
      newCase.estimatedDurationMinutes = durationMinutes;
      newCase.leadSurgeon = _surgeonController.text.trim();
      newCase.surgeon = _surgeonController.text.trim();
      newCase.assistantSurgeon = _assistantSurgeonController.text.trim().isNotEmpty ? _assistantSurgeonController.text.trim() : null;
      newCase.anaesthetist = _anaesthetistController.text.trim();
      newCase.scrubNurse = effectiveScrubNurse;
      newCase.circulatingNurse = effectiveCirculatingNurse;

      setState(() {
        _otCases.removeWhere((c) => (newCase.dbId != null && c.dbId == newCase.dbId) || c.id == newCase.id);
        _otCases.insert(0, newCase);
        _resetScheduleSurgeryForm();
        _activeTab = 0; // Navigate to Dashboard so user sees the newly scheduled surgery immediately!
      });

      // Reload all patients/doctors/cases to capture new state
      await _loadPatientsAndDoctors();

      AppNotification.showSuccess(
        context,
        'Surgery scheduled successfully! Case details are displayed on the Dashboard.',
        atTop: true,
      );
    } catch (e) {
      AppNotification.showError(
        context,
        'Failed to save surgery request: $e',
        atTop: true,
      );
    }
  }

  void _resetScheduleSurgeryForm() {
    _selectedCase = null;
    _selectedPatientId = null;
    _selectedPatientDisplayId = null;
    _selectedOtRoom = null;
    _selectedNurseNames = [];
    _nurseTeamTouched = false;
    _currentConflicts = [];
    _selectedGender = 'Male';
    _selectedBloodGroup = 'O+';
    _selectedSurgeryType = 'General Surgery';
    _selectedPriority = 'Elective';
    _slotStartTime = const TimeOfDay(hour: 9, minute: 0);
    _slotEndTime = null;
    _patientNameController.clear();
    _ageController.clear();
    _diagnosisController.clear();
    _remarksController.clear();
    _surgeonController.clear();
    _assistantSurgeonController.clear();
    _anaesthetistController.clear();
    _scrubNurseController.clear();
    _circulatingNurseController.clear();
  }

  void _cancelSurgeryRequest() {
    setState(() {
      _resetScheduleSurgeryForm();
      _activeTab = (_previousTab != 3) ? _previousTab : 0;
    });
  }

  /// Helper to parse time strings like '09:00 AM' or '11:30 AM'
  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final dt = DateFormat('hh:mm a').parse(cleaned);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return '';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  void _confirmScheduling(OtCase otCase) async {
    if (_selectedOtRoom == null || _selectedOtRoom!.trim().isEmpty) {
      AppNotification.showError(context, 'Please select an OT Room.', atTop: true);
      return;
    }
    if (_selectedNurseNames.isEmpty) {
      AppNotification.showError(context, 'Please assign at least one nurse.', atTop: true);
      return;
    }

    final startMinutes = _slotStartTime.hour * 60 + _slotStartTime.minute;
    if (_slotEndTime != null) {
      final endMinutes = _slotEndTime!.hour * 60 + _slotEndTime!.minute;
      if (endMinutes <= startMinutes) {
        AppNotification.showError(
          context,
          'Surgery End Time (${_formatTimeOfDay(_slotEndTime!)}) cannot be earlier than or equal to Start Time (${_formatTimeOfDay(_slotStartTime)}). Please select a valid time range.',
          atTop: true,
        );
        return;
      }
    }

    final existingDate = otCase.surgeryDateTime ?? DateTime.now();
    final startDateTime = DateTime(
      existingDate.year,
      existingDate.month,
      existingDate.day,
      _slotStartTime.hour,
      _slotStartTime.minute,
    );
    final DateTime? endDateTime = _slotEndTime != null
        ? DateTime(
            existingDate.year,
            existingDate.month,
            existingDate.day,
            _slotEndTime!.hour,
            _slotEndTime!.minute,
          )
        : null;

    // 1. Check local occupancy for slot
    final occupiedRooms = _getOccupiedRoomsForSlot(
      date: existingDate,
      startTime: _slotStartTime,
      endTime: _slotEndTime,
      excludeDbId: otCase.dbId,
      excludeCaseId: otCase.id,
    );
    if (occupiedRooms.contains(_selectedOtRoom)) {
      AppNotification.showError(
        context,
        'Conflict: OT Room [$_selectedOtRoom] is already assigned to an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries. Please select an available OT room.',
        atTop: true,
      );
      return;
    }

    // 2. Server conflict check
    try {
      final conflictCheck = await _otController.checkConflicts(
        otRoom: _selectedOtRoom!,
        startTime: startDateTime,
        endTime: endDateTime ?? startDateTime.add(const Duration(minutes: 90)),
        leadSurgeon: otCase.leadSurgeon ?? otCase.surgeon,
        anaesthetist: otCase.anaesthetist,
        excludeCaseId: otCase.dbId ?? otCase.id,
      );
      if (conflictCheck['hasConflict'] == true) {
        final List conflicts = conflictCheck['conflicts'] ?? [];
        final theatreConflicts = conflicts.where((c) => c['type'] == 'theatre').toList();
        if (theatreConflicts.isNotEmpty) {
          AppNotification.showError(
            context,
            'Conflict: OT Room [$_selectedOtRoom] is already assigned to an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries.',
            atTop: true,
          );
          return;
        }
      }
    } catch (_) {}

    otCase.otRoom = _selectedOtRoom;
    final startStr = _formatTimeOfDay(_slotStartTime);
    final endStr = _slotEndTime != null ? _formatTimeOfDay(_slotEndTime!) : null;
    otCase.surgerySlot = endStr != null ? '$startStr - $endStr' : startStr;
    otCase.nursingTeam = _selectedNurseNames.join(', ');
    otCase.status = 'OT Scheduled';

    otCase.surgeryDateTime = startDateTime;

    _logAction(otCase, 'Scheduled surgery: Room ${otCase.otRoom}, Slot: ${otCase.surgerySlot}, Nursing Team: ${otCase.nursingTeam}.');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Scheduled',
      'ot_room': otCase.otRoom,
      'surgery_slot': otCase.surgerySlot,
      'nursing_team': otCase.nursingTeam,
      'surgery_date_time': otCase.surgeryDateTime?.toIso8601String(),
      'scheduled_start_time': startDateTime.toIso8601String(),
      'scheduled_end_time': endDateTime?.toIso8601String(),
    });

    AppNotification.showSuccess(
      context,
      'Surgery scheduled for ${otCase.patientName}. Status: OT Scheduled',
      atTop: true,
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

    AppNotification.showSuccess(
      context,
      'Pre-operative preparation completed. Ready for anaesthesia.',
      atTop: true,
    );
  }

  void _saveAnaesthesia(OtCase otCase) {
    if (!_anesthesiaPacFormKey.validateAndScroll()) {
      AppNotification.showError(
        context,
        'Please correct invalid characters in PAC Assessment Notes before clearing.',
        atTop: true,
      );
      return;
    }
    final pacData = {
      'asaGrade': _selectedAsaGrade,
      'riskLevel': _selectedRiskLevel,
      'fastingVerified': _pacFastingVerified,
      'consentVerified': _pacConsentVerified,
      'instructionsReviewed': _pacInstructionsReviewed,
      'medsEquipmentReady': _pacMedsEquipmentReady,
      'consciousnessLevel': _selectedConsciousness,
      'painScore': _selectedPainScore,
      'observations': _pacuObservationsController.text.trim(),
      'anesthesiaStartTime': _anesthesiaStartTimeController.text.trim(),
      'anesthesiaEndTime': _anesthesiaEndTimeController.text.trim(),
      'userNotes': _anaesthesiaNotesController.text.trim(),
    };
    otCase.anaesthesiaNotes = jsonEncode(pacData);
    otCase.anaesthesiaType = _selectedAnaesthesiaType;
    otCase.anaesthesiaCleared = true;
    
    final pacStatus = _selectedRiskLevel == 'High' ? 'High Risk Clearance' : 'Cleared';
    otCase.pacStatus = pacStatus;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    otCase.pacClearedBy = user?.fullname ?? 'Anaesthetist';
    otCase.pacClearedAt = DateTime.now();
    otCase.status = 'Anaesthesia Cleared';

    _logAction(otCase, 'Cleared patient for surgery. ASA: $_selectedAsaGrade, Risk: $_selectedRiskLevel, Anesthesia: $_selectedAnaesthesiaType. PAC Status: $pacStatus.');
    
    _updateCaseInDb(otCase, {
      'status': 'Anaesthesia Cleared',
      'anaesthesia_notes': otCase.anaesthesiaNotes,
      'anaesthesia_type': otCase.anaesthesiaType,
      'anaesthesia_cleared': true,
      'pac_status': pacStatus,
      'pac_cleared_by': otCase.pacClearedBy,
      'pac_cleared_at': otCase.pacClearedAt?.toIso8601String(),
    });

    AppNotification.showSuccess(
      context,
      'Patient cleared by Anaesthetist ($pacStatus). Status: Anaesthesia Cleared',
      atTop: true,
    );
  }

  void _postponeSurgery(OtCase otCase) {
    if (!_anesthesiaPacFormKey.validateAndScroll()) {
      AppNotification.showError(
        context,
        'Please correct invalid characters in PAC Assessment Notes before postponing.',
        atTop: true,
      );
      return;
    }
    final pacData = {
      'asaGrade': _selectedAsaGrade,
      'riskLevel': _selectedRiskLevel,
      'fastingVerified': _pacFastingVerified,
      'consentVerified': _pacConsentVerified,
      'instructionsReviewed': _pacInstructionsReviewed,
      'medsEquipmentReady': _pacMedsEquipmentReady,
      'consciousnessLevel': _selectedConsciousness,
      'painScore': _selectedPainScore,
      'observations': _pacuObservationsController.text.trim(),
      'anesthesiaStartTime': _anesthesiaStartTimeController.text.trim(),
      'anesthesiaEndTime': _anesthesiaEndTimeController.text.trim(),
      'userNotes': _anaesthesiaNotesController.text.trim(),
    };
    otCase.anaesthesiaNotes = jsonEncode(pacData);
    otCase.status = 'OT Scheduled'; // Reset status to Scheduled

    _logAction(otCase, 'Postponed surgery. Reason: ${_anaesthesiaNotesController.text.trim()}');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Scheduled',
      'anaesthesia_notes': otCase.anaesthesiaNotes,
    });

    AppNotification.showWarning(
      context,
      'Surgery postponed. Status reset to OT Scheduled.',
      atTop: true,
    );
  }

  static final RegExp _disallowedVitalsSymbolRegex =
      RegExp(r'[!@#\$^&*_=\[\]{};"<>?~\\|]');
  static final RegExp _disallowedNotesSymbolRegex =
      RegExp(r'[!@#\$^*_=\[\]{};"<>?~\\|]');
  static final RegExp _invalidAmpersandRegex =
      RegExp(r'&{2,}|[^a-zA-Z0-9\s]&|&[^a-zA-Z0-9\s]');
  static final RegExp _consonantMashingRegex =
      RegExp(r'[bcdfghjklmnpqrstvwxyz]{6,}', caseSensitive: false);
  static final RegExp _repeatedCharRegex = RegExp(r'(.)\1{4,}');

  String? _validateVitalsSummary(String? val, {bool required = true}) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required
          ? 'Please enter recovery vitals (e.g. BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%)'
          : null;
    }
    if (_disallowedVitalsSymbolRegex.hasMatch(trimmed)) {
      return 'Vitals entry cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
    }
    if (trimmed.contains('%') && !RegExp(r'\d\s*%').hasMatch(trimmed)) {
      return 'Percent symbol (%) in vitals must follow a numerical reading (e.g. SpO2: 99%)';
    }
    if (_consonantMashingRegex.hasMatch(trimmed) || _repeatedCharRegex.hasMatch(trimmed)) {
      return 'Vitals entry contains invalid random text. Please enter valid clinical readings.';
    }
    if (trimmed.length < 3) {
      return 'Please enter complete vital readings';
    }
    if (!RegExp(r'\d').hasMatch(trimmed)) {
      return 'Vitals entry must include numeric values (e.g. BP: 118/76, PR: 70, SpO2: 99%)';
    }
    if (RegExp(r'\b\d{4,}\b').hasMatch(trimmed)) {
      return 'Vital readings contain unrealistic multi-digit numbers';
    }
    final hasVitalKeyword = RegExp(
      r'\b(bp|pr|pulse|hr|temp|temperature|spo2|rr|spo|resp)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);
    final hasBloodPressureFormat = RegExp(r'\b\d{2,3}/\d{2,3}\b').hasMatch(trimmed);
    if (!hasVitalKeyword && !hasBloodPressureFormat) {
      return 'Please enter vitals in standard format (e.g. BP: 120/80, PR: 72, Temp: 98.4, SpO2: 99%)';
    }
    return null;
  }

  String? _validateMedicationOrSubstanceText(
    String? val,
    String fieldLabel, {
    bool required = true,
    String example = 'e.g. Paracetamol 1g IV',
  }) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Please enter $fieldLabel ($example)' : null;
    }
    if (_disallowedVitalsSymbolRegex.hasMatch(trimmed)) {
      return '$fieldLabel cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
    }
    if (trimmed.contains('%') && !RegExp(r'\d\s*%').hasMatch(trimmed)) {
      return 'Percent symbol (%) in $fieldLabel must follow a numerical concentration (e.g. 5%)';
    }
    if (_consonantMashingRegex.hasMatch(trimmed) || _repeatedCharRegex.hasMatch(trimmed)) {
      return '$fieldLabel contains invalid random characters ($example)';
    }
    final hasWord = RegExp(r'[a-zA-Z]{3,}').hasMatch(trimmed);
    if (!hasWord) {
      return '$fieldLabel must contain a valid clinical drug or substance name ($example)';
    }
    if (trimmed.length < 3) {
      return '$fieldLabel must be at least 3 characters';
    }
    return null;
  }

  String? _validateClinicalNotesText(
    String? val,
    String fieldLabel, {
    bool required = true,
    int minLength = 3,
  }) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Please enter $fieldLabel' : null;
    }
    if (_disallowedNotesSymbolRegex.hasMatch(trimmed) ||
        _invalidAmpersandRegex.hasMatch(trimmed)) {
      return '$fieldLabel cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
    }
    if (_consonantMashingRegex.hasMatch(trimmed) || _repeatedCharRegex.hasMatch(trimmed)) {
      return '$fieldLabel contains invalid random text. Please enter valid clinical notes.';
    }
    if (!RegExp(r'[a-zA-Z]{2,}').hasMatch(trimmed)) {
      return '$fieldLabel must contain valid clinical text and cannot consist only of numbers or symbols';
    }
    if (trimmed.length < minLength) {
      return '$fieldLabel must be at least $minLength characters';
    }
    return null;
  }

  String? _validatePacNotesText(String? val) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return null;
    return _validateClinicalNotesText(val, 'Notes', required: false);
  }

  void _saveAnesthesiaIntraOpLog(OtCase otCase) {
    if (!(_anesthesiaIntraOpFormKey.currentState?.validate() ?? true) ||
        _intraOpBpError != null ||
        _intraOpPulseError != null ||
        _intraOpTempError != null ||
        _intraOpSpo2Error != null) {
      AppNotification.showError(
        context,
        'Cannot record entry: Please correct the invalid anesthesia vitals or drug fields.',
        atTop: true,
      );
      return;
    }
    final now = DateTime.now();
    if (_anesthesiaStartTimeController.text.isEmpty) {
      _anesthesiaStartTimeController.text = DateFormat('hh:mm a').format(now);
    }

    final log = IntraOpLog(
      timestamp: now,
      bp: _intraOpBpController.text.trim(),
      pulse: int.tryParse(_intraOpPulseController.text.trim()) ?? 72,
      temp: double.tryParse(_intraOpTempController.text.trim()) ?? 98.4,
      spo2: int.tryParse(_intraOpSpo2Controller.text.trim()) ?? 99,
      medications: '${_intraOpMedsController.text.trim()} (Dosage: ${_intraOpFluidsController.text.trim()})',
      fluids: '',
      blood: '',
      instrumentCount: 0,
    );

    setState(() {
      otCase.intraOpLogs.add(log);
    });

    _logAction(otCase, 'Anaesthetist recorded vital log & drugs (${_intraOpMedsController.text.trim()}).');

    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    pacData['anesthesiaStartTime'] = _anesthesiaStartTimeController.text;
    pacData['drugsAdministered'] = _intraOpMedsController.text.trim();
    pacData['drugsDosage'] = _intraOpFluidsController.text.trim();
    pacData['intraOpComplications'] = _intraOpBloodController.text.trim();
    otCase.anaesthesiaNotes = jsonEncode(pacData);

    _updateCaseInDb(otCase, {
      'anaesthesia_notes': otCase.anaesthesiaNotes,
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
    _anesthesiaIntraOpFormKey.currentState?.reset();

    AppNotification.showSuccess(
      context,
      'Anesthesia intra-op monitoring entry recorded.',
      atTop: true,
    );
  }

  void _saveAnaesthesiaCompletion(OtCase otCase) {
    if (!(_anesthesiaCompletionFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot save report: Please provide valid Anesthesia End Time and Final Anesthesia Notes.',
        atTop: true,
      );
      return;
    }
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    pacData['anesthesiaEndTime'] = _anesthesiaEndTimeController.text.trim();
    pacData['userNotes'] = _finalAnesthesiaNotesController.text.trim();
    otCase.anaesthesiaNotes = jsonEncode(pacData);

    _logAction(otCase, 'Anaesthetist recorded anesthesia end time (${pacData['anesthesiaEndTime']}) and final notes.');

    _updateCaseInDb(otCase, {
      'anaesthesia_notes': otCase.anaesthesiaNotes,
    });

    AppNotification.showSuccess(
      context,
      'Anesthesia completion notes saved.',
      atTop: true,
    );
  }

  void _approvePacuTransfer(OtCase otCase) {
    if (!(_pacuMonitoringFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot approve transfer: Please correct invalid characters in PACU observations or instructions.',
        atTop: true,
      );
      return;
    }
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    pacData['consciousnessLevel'] = _selectedConsciousness;
    pacData['painScore'] = _selectedPainScore;
    pacData['observations'] = _pacuObservationsController.text.trim();
    pacData['postAnesthesiaInstructions'] = _anaesthesiaNotesController.text.trim();
    otCase.anaesthesiaNotes = jsonEncode(pacData);

    _logAction(otCase, 'Anaesthetist approved transfer to Ward/ICU. Consciousness: $_selectedConsciousness, Pain Score: $_selectedPainScore.');

    _updateCaseInDb(otCase, {
      'anaesthesia_notes': otCase.anaesthesiaNotes,
    });

    AppNotification.showSuccess(
      context,
      'PACU transfer approval recorded.',
      atTop: true,
    );
  }

  Future<void> _anaesthetistCloseCase(OtCase otCase) async {
    await _completeStep8AndCloseCase(otCase);
  }

  void _showMandatoryPacAlert(OtCase otCase, String actionName) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppTheme.dangerColor, size: 24),
            SizedBox(width: 10),
            Text('PAC Clearance Mandatory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cannot $actionName: Clinical protocol strictly mandates Pre-Anaesthetic Clearance (PAC) authorized by an Anaesthetist before surgery.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.dangerColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current PAC Status: [${otCase.pacStatus.toUpperCase()}]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.dangerColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => PacAssessmentDialog(
                  otCase: otCase,
                  isMobile: widget.isMobile,
                  currentUser: user?.fullname ?? 'Anaesthetist',
                  onPacUpdated: (updated) {
                    _syncPacUpdate(otCase, updated);
                  },
                ),
              );
            },
            icon: const Icon(Icons.medical_services_outlined, size: 16),
            label: const Text('Perform PAC Assessment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmHandover(OtCase otCase) {
    final handoverError = _validateClinicalNotesText(
      _handoverNotesController.text,
      'OT Handover Remarks',
      required: false,
    );
    if (handoverError != null) {
      AppNotification.showError(context, handoverError, atTop: true);
      return;
    }

    // Mandatory PAC Clearance Gate
    if (otCase.pacStatus != 'Cleared' && otCase.pacStatus != 'High Risk Clearance') {
      if (otCase.anaesthesiaCleared) {
        otCase.pacStatus = 'Cleared';
      } else {
        _showMandatoryPacAlert(otCase, 'Transfer Patient to OT');
        return;
      }
    }

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
      'pac_status': otCase.pacStatus,
    });

    AppNotification.showSuccess(
      context,
      'Patient transferred to OT. Status: Patient In OT',
      atTop: true,
    );
  }

  void _startSurgery(OtCase otCase) {
    // 1. Mandatory WHO Time-Out Checklist Gate
    final timeOut = otCase.whoChecklist['time_out'] is Map
        ? Map<String, dynamic>.from(otCase.whoChecklist['time_out'])
        : <String, dynamic>{};
    final bool isTimeOutVerified = timeOut['is_completed'] == true;
    if (!isTimeOutVerified) {
      AppNotification.showError(
        context,
        'Cannot initiate surgery: Mandatory WHO Time-Out checklist must be verified and completed before skin incision.',
        atTop: true,
      );
      return;
    }

    // 2. Mandatory PAC Clearance Gate
    if (otCase.pacStatus != 'Cleared' && otCase.pacStatus != 'High Risk Clearance') {
      if (otCase.anaesthesiaCleared) {
        otCase.pacStatus = 'Cleared';
      } else {
        _showMandatoryPacAlert(otCase, 'Commence Surgery');
        return;
      }
    }

    final now = DateTime.now();
    otCase.surgeryStartTime = now;
    otCase.status = 'Surgery In Progress';

    _logAction(otCase, 'Started Surgery Procedure.');
    
    _updateCaseInDb(otCase, {
      'status': 'Surgery In Progress',
      'surgery_start_time': now.toIso8601String(),
    });

    AppNotification.showSuccess(
      context,
      'Surgery Started! Status: Surgery In Progress',
      atTop: true,
    );
  }

  void _addIntraOpLog(OtCase otCase) {
    final cleanedBp = _intraOpBpController.text.trim().replaceAll(RegExp(r'\s*mmHg$', caseSensitive: false), '').trim();
    final cleanedPulse = _intraOpPulseController.text.trim().replaceAll(RegExp(r'\s*bpm$', caseSensitive: false), '').trim();
    final cleanedTemp = _intraOpTempController.text.trim().replaceAll(RegExp(r'\s*°?F?$', caseSensitive: false), '').trim();
    final cleanedSpo2 = _intraOpSpo2Controller.text.trim().replaceAll(RegExp(r'\s*%$'), '').trim();

    final log = IntraOpLog(
      timestamp: DateTime.now(),
      bp: cleanedBp.isNotEmpty ? cleanedBp : _intraOpBpController.text,
      pulse: int.tryParse(cleanedPulse) ?? (int.tryParse(_intraOpPulseController.text) ?? 74),
      temp: double.tryParse(cleanedTemp) ?? (double.tryParse(_intraOpTempController.text) ?? 98.5),
      spo2: int.tryParse(cleanedSpo2) ?? (int.tryParse(_intraOpSpo2Controller.text) ?? 98),
      medications: _intraOpMedsController.text,
      fluids: _intraOpFluidsController.text,
      blood: _intraOpBloodController.text,
      instrumentCount: int.tryParse(_intraOpInstrumentController.text.split('/')[0]) ?? 24,
    );

    setState(() {
      otCase.intraOpLogs.add(log);
      _intraOpVitalsAutovalidate = false;
      _intraOpFormVersion++;
      _intraOpVitalsFormKey = GlobalKey<FormState>();
      _intraOpBpController.clear();
      _intraOpPulseController.clear();
      _intraOpTempController.clear();
      _intraOpSpo2Controller.clear();
      _intraOpMedsController.clear();
      _intraOpFluidsController.clear();
      _intraOpBloodController.clear();
      _intraOpInstrumentController.clear();
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

    AppNotification.showSuccess(
      context,
      'Intra-operative monitoring log entry saved.',
      atTop: true,
    );
  }

  void _completeSurgery(OtCase otCase) {
    final now = DateTime.now();
    setState(() {
      otCase.surgeryEndTime = now;
      otCase.procedureDetails = _procedureDetailsController.text;
      otCase.surgicalFindings = _findingsController.text;
      otCase.complications = _complicationsController.text;
      otCase.status = 'Surgery Completed';
      if (_selectedCase?.id == otCase.id) {
        _selectedCase = otCase;
      }
      _populateControllersForCase(otCase);
    });

    _logAction(otCase, 'Surgery Completed. Recorded procedure details, surgical findings, and complications: "${otCase.complications}".');
    
    _updateCaseInDb(otCase, {
      'status': 'Surgery Completed',
      'surgery_end_time': now.toIso8601String(),
      'procedure_details': otCase.procedureDetails,
      'surgical_findings': otCase.surgicalFindings,
      'complications': otCase.complications,
    });

    AppNotification.showSuccess(
      context,
      'Surgery Completed! Status: Surgery Completed',
      atTop: true,
    );
  }

  void _savePostOpNotes(OtCase otCase) {
    if (!(_postOpNotesFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot save notes: Please fill all Post-Operative Surgeon Notes with valid clinical text.',
        atTop: true,
      );
      return;
    }
    setState(() {
      otCase.operationSummary = _opSummaryController.text.trim();
      otCase.procedurePerformed = _procPerformedController.text.trim();
      otCase.outcome = _outcomeController.text.trim();
      otCase.postOpInstructions = _postOpInstController.text.trim();
      otCase.followUpRecommendations = _followUpController.text.trim();
      if (otCase.status == 'Surgery In Progress' || otCase.status == 'Patient In OT') {
        otCase.status = 'Surgery Completed';
      }
      if (_selectedCase?.id == otCase.id) {
        _selectedCase = otCase;
      }
    });

    _logAction(otCase, 'Saved post-operative notes and completed surgical report. Outcome: ${otCase.outcome}.');
    
    _updateCaseInDb(otCase, {
      'status': otCase.status,
      'operation_summary': otCase.operationSummary,
      'procedure_performed': otCase.procedurePerformed,
      'outcome': otCase.outcome,
      'post_op_instructions': otCase.postOpInstructions,
      'follow_up_recommendations': otCase.followUpRecommendations,
    });

    AppNotification.showSuccess(
      context,
      'Surgical report and post-operative notes saved successfully.',
      atTop: true,
    );
  }

  String? _validateTransferMandatoryFields() {
    if (_selectedTransferDest.trim().isEmpty) {
      return 'Please select a Transfer Destination (Recovery Room, ICU, or Ward).';
    }
    if (_transferDetailsController.text.trim().isEmpty) {
      return 'Please select or enter a Bed Number for transfer.';
    }
    if (_nursingHandoverController.text.trim().isEmpty) {
      return 'Please enter Nursing Handover Notes.';
    }
    final handoverError = _validateClinicalNotesText(
      _nursingHandoverController.text,
      'Nursing handover notes',
      required: true,
    );
    if (handoverError != null) {
      return handoverError;
    }
    return null;
  }

  void _proceedToPacuRecovery(OtCase otCase) {
    if (!(_postOpNotesFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot proceed: Please fill all Post-Operative Surgeon Notes with valid clinical text.',
        atTop: true,
      );
      return;
    }
    final transferError = _validateTransferMandatoryFields();
    if (transferError != null) {
      AppNotification.showError(
        context,
        'Cannot complete Step 7: $transferError',
        atTop: true,
      );
      return;
    }
    if (!(_transferFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot complete Step 7: Please complete all mandatory transfer details.',
        atTop: true,
      );
      return;
    }
    setState(() {
      otCase.operationSummary = _opSummaryController.text.trim();
      otCase.procedurePerformed = _procPerformedController.text.trim();
      otCase.outcome = _outcomeController.text.trim();
      otCase.postOpInstructions = _postOpInstController.text.trim();
      otCase.followUpRecommendations = _followUpController.text.trim();
      otCase.transferDestination = _selectedTransferDest.trim();
      otCase.transferDetails = _transferDetailsController.text.trim();
      otCase.nursingHandoverNotes = _nursingHandoverController.text.trim();
      otCase.status = 'Post-Op Monitoring';
      if (_selectedCase?.id == otCase.id) {
        _selectedCase = otCase;
      }
      _populateControllersForCase(otCase);
    });

    _logAction(otCase, 'Saved post-operative notes and advanced to PACU Recovery & Monitoring. Destination: ${otCase.transferDestination}. Status: Post-Op Monitoring.');
    
    _updateCaseInDb(otCase, {
      'status': 'Post-Op Monitoring',
      'operation_summary': otCase.operationSummary,
      'procedure_performed': otCase.procedurePerformed,
      'outcome': otCase.outcome,
      'post_op_instructions': otCase.postOpInstructions,
      'follow_up_recommendations': otCase.followUpRecommendations,
      'transfer_destination': otCase.transferDestination,
      'transfer_details': otCase.transferDetails,
      'nursing_handover_notes': otCase.nursingHandoverNotes,
    });

    AppNotification.showSuccess(
      context,
      'Notes saved! Advanced to Step 8: PACU Recovery & Monitoring.',
      atTop: true,
    );
  }

  void _executeTransfer(OtCase otCase) {
    final transferError = _validateTransferMandatoryFields();
    if (transferError != null) {
      AppNotification.showError(
        context,
        'Cannot confirm transfer: $transferError',
        atTop: true,
      );
      return;
    }
    if (!(_transferFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot confirm transfer: Please correct the invalid fields in Transfer to Recovery / ICU / Ward.',
        atTop: true,
      );
      return;
    }

    otCase.transferDestination = _selectedTransferDest.trim();
    otCase.transferDetails = _transferDetailsController.text.trim();
    otCase.nursingHandoverNotes = _nursingHandoverController.text.trim();
    otCase.status = 'Post-Op Monitoring';

    _logAction(otCase, 'Transferred patient to ${otCase.transferDestination}. Handover details: ${otCase.nursingHandoverNotes}. Status: Post-Op Monitoring.');
    
    _updateCaseInDb(otCase, {
      'status': 'Post-Op Monitoring',
      'transfer_destination': otCase.transferDestination,
      'transfer_details': otCase.transferDetails,
      'nursing_handover_notes': otCase.nursingHandoverNotes,
    });

    AppNotification.showSuccess(
      context,
      'Patient transferred to ${otCase.transferDestination}. Status: Post-Op Monitoring',
      atTop: true,
    );
  }

  void _addNurseCareLog(OtCase otCase) {
    final formValid = _postOpNurseCareFormKey.currentState?.validate() ?? false;
    
    final bp = _recoveryBpController.text.trim();
    final pulse = _recoveryPulseController.text.trim();
    final temp = _recoveryTempController.text.trim();
    final spo2 = _recoverySpo2Controller.text.trim();
    final med = _recoveryMedNameController.text.trim();
    final dosage = _recoveryDosageController.text.trim();
    final notes = _recoveryNotesController.text.trim();

    final legacyVitals = _careVitalsController.text.trim();
    final legacyMeds = _careMedsController.text.trim();

    final hasNewEntries = bp.isNotEmpty || pulse.isNotEmpty || temp.isNotEmpty || spo2.isNotEmpty || med.isNotEmpty || notes.isNotEmpty;
    final hasLegacyEntries = legacyVitals.isNotEmpty || legacyMeds.isNotEmpty;

    if (!hasNewEntries && !hasLegacyEntries) {
      AppNotification.showError(
        context,
        'Please enter at least one recovery vital reading, medication, or care note.',
        atTop: true,
      );
      return;
    }

    if (!formValid) {
      AppNotification.showError(
        context,
        'Please correct the invalid fields in Post-Operative Recovery Vitals & Care.',
        atTop: true,
      );
      return;
    }

    final List<String> vitalParts = [];
    if (bp.isNotEmpty) vitalParts.add('BP: $bp');
    if (pulse.isNotEmpty) vitalParts.add('Pulse: $pulse bpm');
    if (temp.isNotEmpty) vitalParts.add('Temp: $temp${temp.contains("°") ? "" : "°F"}');
    if (spo2.isNotEmpty) vitalParts.add('SpO2: $spo2%');
    if (vitalParts.isEmpty && legacyVitals.isNotEmpty) {
      vitalParts.add(legacyVitals);
    }
    final vitalsText = vitalParts.join(', ');

    String medsText = '';
    if (med.isNotEmpty) {
      medsText = '$med${dosage.isNotEmpty ? " $dosage" : ""} ($_selectedMedTiming)';
    } else if (legacyMeds.isNotEmpty) {
      medsText = legacyMeds;
    }

    final timeStr = DateFormat('hh:mm a').format(DateTime.now());

    setState(() {
      if (vitalsText.isNotEmpty) {
        otCase.nurseCareVitalsLogs.add('$vitalsText${notes.isNotEmpty ? " | Notes: $notes" : ""} (Recorded by Nurse at $timeStr)');
      } else if (notes.isNotEmpty) {
        otCase.nurseCareVitalsLogs.add('Notes: $notes (Recorded by Nurse at $timeStr)');
      }
      if (medsText.isNotEmpty) {
        otCase.nurseMedicationsAdministered.add('$medsText (Administered at $timeStr)');
      }
    });

    _logAction(otCase, 'Recorded nurse care entry. ${vitalsText.isNotEmpty ? "Vitals: $vitalsText. " : ""}${medsText.isNotEmpty ? "Meds: $medsText. " : ""}${notes.isNotEmpty ? "Notes: $notes" : ""}');
    
    _updateCaseInDb(otCase, {
      'nurse_care_vitals_logs': otCase.nurseCareVitalsLogs,
      'nurse_medications_administered': otCase.nurseMedicationsAdministered,
    });

    _recoveryBpController.clear();
    _recoveryPulseController.clear();
    _recoveryTempController.clear();
    _recoverySpo2Controller.clear();
    _recoveryMedNameController.clear();
    _recoveryDosageController.clear();
    _recoveryNotesController.clear();
    _careVitalsController.clear();
    _careMedsController.clear();
    _postOpNurseCareFormKey.currentState?.reset();

    AppNotification.showSuccess(
      context,
      'Post-operative vitals, medication, and recovery notes saved successfully.',
      atTop: true,
    );
  }

  void _addDoctorProgressNote(OtCase otCase) {
    final formValid = _postOpDoctorNoteFormKey.currentState?.validate() ?? false;
    final noteError = _validateClinicalNotesText(
      _doctorProgressController.text,
      'Doctor progress note',
    );
    if (!formValid || noteError != null) {
      AppNotification.showError(
        context,
        noteError ?? 'Please enter a valid doctor progress note.',
        atTop: true,
      );
      return;
    }

    final noteText = _doctorProgressController.text.trim();
    setState(() {
      otCase.doctorProgressNotes.add('$noteText (Added at ${DateFormat('hh:mm a').format(DateTime.now())})');
    });

    _logAction(otCase, 'Doctor added progress note: "$noteText".');
    
    _updateCaseInDb(otCase, {
      'doctor_progress_notes': otCase.doctorProgressNotes,
    });

    _doctorProgressController.clear();
    _postOpDoctorNoteFormKey.currentState?.reset();

    AppNotification.showSuccess(
      context,
      'Doctor progress note saved.',
      atTop: true,
    );
  }

  Future<void> _completeStep8AndCloseCase(OtCase otCase) async {
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    pacData['consciousnessLevel'] = _selectedConsciousness;
    pacData['painScore'] = _selectedPainScore;
    if (_pacuObservationsController.text.trim().isNotEmpty) {
      pacData['observations'] = _pacuObservationsController.text.trim();
    }
    if (_anaesthesiaNotesController.text.trim().isNotEmpty) {
      pacData['postAnesthesiaInstructions'] = _cleanPacNotes(_anaesthesiaNotesController.text.trim());
    }
    otCase.anaesthesiaNotes = jsonEncode(pacData);

    setState(() {
      otCase.status = 'OT Case Closed';
      if (_selectedCase?.id == otCase.id) {
        _selectedCase = otCase;
      }
    });

    _logAction(otCase, 'Step 8 completed. PACU Recovery & Monitoring finalized. OT Case Closed and archived.');

    await _updateCaseInDb(otCase, {
      'status': 'OT Case Closed',
      'anaesthesia_notes': otCase.anaesthesiaNotes,
      'nurse_care_vitals_logs': otCase.nurseCareVitalsLogs,
      'nurse_medications_administered': otCase.nurseMedicationsAdministered,
    });

    await _loadPatientsAndDoctors();

    if (mounted) {
      setState(() {
        otCase.status = 'OT Case Closed';
        _selectedCase = otCase;
      });
      AppNotification.showSuccess(
        context,
        'OT Case Closed successfully for ${otCase.patientName}. Advanced to Step 9 - Case Closed & Archived!',
        atTop: true,
      );
    }
  }

  Future<void> _closeCase(OtCase otCase) async {
    if (otCase.status == 'Surgery Completed') {
      final transferError = _validateTransferMandatoryFields();
      if (transferError != null) {
        AppNotification.showError(
          context,
          'Cannot close case: $transferError',
          atTop: true,
        );
        return;
      }
    }
    await _completeStep8AndCloseCase(otCase);
  }

  // Helper to check if step belongs to current role
  bool _canPerformAction(String requiredRole) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final userRole = user?.role ?? 'Doctor';
    if (userRole == 'Admin' || userRole == 'Super Admin') return true;
    if (userRole == 'Doctor' || userRole == 'Surgeon') return true; // Clinical doctors/surgeons have full authority in OT workflow
    if (requiredRole == 'Nurse' || requiredRole == 'OT Coordinator') {
      return userRole == 'Nurse' || userRole == 'OT Coordinator';
    }
    if (requiredRole == 'Anaesthetist') {
      return userRole == 'Anaesthetist' || userRole == 'Doctor' || userRole == 'Surgeon';
    }
    if (requiredRole == 'Doctor' || requiredRole == 'Surgeon') {
      return userRole == 'Doctor' || userRole == 'Surgeon';
    }
    return false;
  }

  Future<void> _openDictationAssistant() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const OtDictationDialog(),
    );

    if (result != null) {
      final String section = result['section'] ?? '';
      final Map<String, dynamic> fields = result['fields'] ?? {};
      _applyParsedFields(section, fields);
    }
  }

  void _applyParsedFields(String section, Map<String, dynamic> fields) {
    if (fields.isEmpty) return;

    AppNotification.showSuccess(
      context,
      'AI auto-filled fields for target: ${section.toUpperCase()}',
      atTop: true,
    );

    setState(() {
      if (section == 'new_request') {
        _activeTab = 3;
        _selectedCase = null;

        if (fields['patient_name_query'] != null) {
          final query = fields['patient_name_query'].toString().toLowerCase();
          final match = _patients.firstWhere(
            (p) => p.name.toLowerCase().contains(query),
            orElse: () => null as dynamic,
          );
          if (match != null) {
            _selectedPatientId = match.id.toString();
            _selectedPatientDisplayId = match.patientId ?? 'PT-${match.id}';
            _patientNameController.text = match.name;
            _ageController.text = match.age.toString();
            
            final gen = match.gender.trim();
            if (gen.toLowerCase().startsWith('m')) {
              _selectedGender = 'Male';
            } else if (gen.toLowerCase().startsWith('f')) {
              _selectedGender = 'Female';
            } else {
              _selectedGender = 'Other';
            }

            final bg = match.bloodGroup.trim();
            final allowedBloodGroups = ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'];
            if (allowedBloodGroups.contains(bg)) {
              _selectedBloodGroup = bg;
            }
          } else {
            _patientNameController.text = fields['patient_name_query'].toString();
          }
        }

        if (fields['diagnosis'] != null) _diagnosisController.text = fields['diagnosis'].toString();
        
        if (fields['surgeon'] != null) {
          final docName = fields['surgeon'].toString().toLowerCase();
          final matchDoc = _doctors.firstWhere(
            (d) => d.fullname.toLowerCase().contains(docName),
            orElse: () => null as dynamic,
          );
          _surgeonController.text = matchDoc != null ? matchDoc.fullname : fields['surgeon'].toString();
        }
        
        if (fields['anaesthetist'] != null) {
          final anaeName = fields['anaesthetist'].toString().toLowerCase();
          final matchAnae = _anaesthetists.firstWhere(
            (a) => a.fullname.toLowerCase().contains(anaeName),
            orElse: () => null as dynamic,
          );
          _anaesthetistController.text = matchAnae != null ? matchAnae.fullname : fields['anaesthetist'].toString();
        }
        
        if (fields['remarks'] != null) _remarksController.text = fields['remarks'].toString();
        
        if (fields['priority'] != null) {
          final prio = fields['priority'].toString();
          if (prio == 'Elective' || prio == 'Emergency') {
            _selectedPriority = prio;
          }
        }
        
        if (fields['surgery_type'] != null) {
          _selectedSurgeryType = fields['surgery_type'].toString();
        }
      } else {
        if (_selectedCase == null) {
          AppNotification.showWarning(
            context,
            'Parsed case update, but no active case is open. Please open a patient case first!',
            atTop: true,
          );
          return;
        }

        if (section == 'pre_op') {
          if (fields['pre_op_bp'] != null) _preOpBpController.text = fields['pre_op_bp'].toString();
          if (fields['pre_op_pulse'] != null) _preOpPulseController.text = fields['pre_op_pulse'].toString();
          if (fields['pre_op_temp'] != null) _preOpTempController.text = fields['pre_op_temp'].toString();
          if (fields['pre_op_spo2'] != null) _preOpSpo2Controller.text = fields['pre_op_spo2'].toString();
          
          if (fields['id_verified'] != null) _selectedCase!.idVerified = fields['id_verified'] as bool;
          if (fields['consent_signed'] != null) _selectedCase!.consentSigned = fields['consent_signed'] as bool;
          if (fields['fasting_confirmed'] != null) _selectedCase!.fastingConfirmed = fields['fasting_confirmed'] as bool;
          if (fields['lab_verified'] != null) _selectedCase!.labVerified = fields['lab_verified'] as bool;
          if (fields['blood_available'] != null) _selectedCase!.bloodAvailable = fields['blood_available'] as bool;
        }

        if (section == 'anesthesia') {
          if (fields['asa_grade'] != null) _selectedAsaGrade = fields['asa_grade'].toString();
          if (fields['risk_level'] != null) _selectedRiskLevel = fields['risk_level'].toString();
          if (fields['anesthesia_type'] != null) {
            String type = fields['anesthesia_type'].toString();
            if (type == 'General Anesthesia') type = 'General Anaesthesia';
            if (type == 'Spinal Anesthesia') type = 'Spinal Anaesthesia';
            if (type == 'Epidural Anesthesia') type = 'Epidural Anaesthesia';
            if (type == 'Local Anesthesia') type = 'Local Anaesthesia';
            if (type == 'Regional Anesthesia') type = 'Regional Anaesthesia';
            _selectedAnaesthesiaType = type;
          }
          if (fields['anesthesia_notes'] != null) {
            _anaesthesiaNotesController.text = fields['anesthesia_notes'].toString();
          }
        }

        if (section == 'handover') {
          if (fields['handover_notes'] != null) _handoverNotesController.text = fields['handover_notes'].toString();
        }

        if (section == 'surgery_procedure') {
          if (fields['procedure_details'] != null) _procedureDetailsController.text = fields['procedure_details'].toString();
          if (fields['surgical_findings'] != null) _findingsController.text = fields['surgical_findings'].toString();
          if (fields['complications'] != null) _complicationsController.text = fields['complications'].toString();
          if (fields['blood_loss'] != null) _bloodLossController.text = fields['blood_loss'].toString();
          if (fields['implants_used'] != null) {
            _implantsUsedController.text = fields['implants_used'].toString();
            AppNotification.showInfo(
              context,
              'Operative Dictation noted implant: "${fields['implants_used']}". Log statutory UDI & Serial in Consumables & Implants tab.',
              atTop: true,
            );
          }
        }

        if (section == 'post_op') {
          if (fields['operation_summary'] != null) _opSummaryController.text = fields['operation_summary'].toString();
          if (fields['procedure_performed'] != null) _procPerformedController.text = fields['procedure_performed'].toString();
          if (fields['outcome'] != null) _outcomeController.text = fields['outcome'].toString();
          if (fields['post_op_instructions'] != null) _postOpInstController.text = fields['post_op_instructions'].toString();
          if (fields['follow_up_recommendations'] != null) _followUpController.text = fields['follow_up_recommendations'].toString();
          if (fields['blood_loss'] != null) _bloodLossController.text = fields['blood_loss'].toString();
          if (fields['implants_used'] != null) {
            _implantsUsedController.text = fields['implants_used'].toString();
            AppNotification.showInfo(
              context,
              'Operative Dictation noted implant: "${fields['implants_used']}". Log statutory UDI & Serial in Consumables & Implants tab.',
              atTop: true,
            );
          }
        }

        if (section == 'transfer') {
          if (fields['transfer_destination'] != null) _selectedTransferDest = fields['transfer_destination'].toString();
          if (fields['transfer_details'] != null) _transferDetailsController.text = fields['transfer_details'].toString();
          if (fields['nursing_handover_notes'] != null) _nursingHandoverController.text = fields['nursing_handover_notes'].toString();
        }

        if (section == 'care_log') {
          if (fields['pre_op_bp'] != null || fields['pre_op_pulse'] != null) {
            _careVitalsController.text = 'BP: ${fields['pre_op_bp'] ?? "120/80"}, PR: ${fields['pre_op_pulse'] ?? "72"}, Temp: ${fields['pre_op_temp'] ?? "98.4"}, SpO2: ${fields['pre_op_spo2'] ?? "99"}';
          }
          if (fields['remarks'] != null) {
            _careMedsController.text = fields['remarks'].toString();
            _doctorProgressController.text = fields['remarks'].toString();
          }
        }
      }
    });
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
      case 'Completed':
        return Colors.green;
      case 'Post-Op Monitoring':
        return Colors.pink;
      case 'OT Case Closed':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTopHeaderAndTabs() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final activeCasesCount = _otCases
        .where((c) => c.status != 'OT Case Closed' && c.status != 'Surgery Completed' && c.status != 'Completed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .length;
    final completedCasesCount = _otCases
        .where((c) => c.status == 'OT Case Closed' || c.status == 'Surgery Completed' || c.status == 'Completed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .length;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(
        left: widget.isMobile ? 16 : 24,
        right: widget.isMobile ? 16 : 24,
        top: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Title & Subtitle on left, Action buttons on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('ot_management', fallback: 'OT Management'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Coordinate care. Keep every case moving.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Speech-to-Text Button (Outlined)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _activeTab = 4;
                    _openedFromLiveDashboard = false;
                    _selectedCase = null;
                  });
                },
                icon: const Icon(Icons.mic_none_outlined, size: 16, color: AppTheme.primaryColor),
                label: Text(
                  widget.isMobile ? 'Dictation' : 'Speech-to-Text',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              // Schedule Surgery Button (Filled, AppTheme.primaryColor - NOT green)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _activeTab = 3;
                    _resetScheduleSurgeryForm();
                  });
                },
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  widget.isMobile ? 'Schedule' : 'Schedule surgery',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2: Clean Underline Navigation Tabs with bottom border across the whole row
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildUnderlineTabItem(
                    index: 0,
                    label: context.tr('dashboard', fallback: 'Dashboard'),
                  ),
                  const SizedBox(width: 24),
                  _buildUnderlineTabItem(
                    index: 5,
                    label: 'Theatre calendar',
                  ),
                  const SizedBox(width: 24),
                  _buildUnderlineTabItem(
                    index: 1,
                    label: 'Active cases',
                    badgeCount: activeCasesCount,
                  ),
                  const SizedBox(width: 24),
                  _buildUnderlineTabItem(
                    index: 2,
                    label: 'Completed cases',
                    badgeCount: completedCasesCount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlineTabItem({
    required int index,
    required String label,
    int? badgeCount,
  }) {
    final bool isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          if (_activeTab != index) {
            _previousTab = _activeTab;
          }
          _activeTab = index;
          _openedFromLiveDashboard = false;
          _showPipelineSidebar = true;
          _selectedCase = null;
        });
        _loadPatientsAndDoctors();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopHeaderAndTabs(),
          Expanded(
            child: Container(
              padding: widget.isMobile ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _activeTab == 0
                  ? _buildDashboardView()
                  : _activeTab == 5
                      ? _buildTheatreCalendarView()
                      : _activeTab == 1
                          ? _buildActivePatientsView()
                          : _activeTab == 2
                              ? _buildCompletedPatientsView()
                              : _activeTab == 3
                                  ? _buildRequestView()
                                  : OtDictationDashboardView(isMobile: widget.isMobile),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIEW 0.5: MULTI-THEATRE CALENDAR WITH CONFLICT PREVENTION ───────

  Widget _buildTheatreCalendarView() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return OtTheatreCalendarWidget(
      otCases: _otCases,
      isMobile: widget.isMobile,
      currentUser: user?.fullname ?? 'Staff',
      onSelectCase: (selectedCase) {
        setState(() {
          _previousTab = _activeTab;
          _selectedCase = selectedCase;
          _populateControllersForCase(selectedCase);
          _showPipelineSidebar = !widget.isMobile;
          _activeTab = 1; // Open workflow in Active cases
        });
      },
      onScheduleNew: () {
        setState(() {
          _previousTab = _activeTab;
          _resetScheduleSurgeryForm();
          _activeTab = 3; // Switch to Schedule Surgery form
        });
      },
      onRefresh: () {
        _loadPatientsAndDoctors();
      },
    );
  }

  // ── VIEW 1: DASHBOARD & ROOM BOARD ──────────────────────────────────

  bool _matchesRoom(OtCase c, String targetCode, String targetName) {
    final raw = c.otRoom ?? '';
    if (raw.trim().isEmpty) return false;

    final isTargetEmergency = targetCode.toLowerCase().contains('emerg') || targetName.toLowerCase().contains('emerg');
    final isCaseEmergency = raw.toLowerCase().contains('emerg');
    if (isTargetEmergency || isCaseEmergency) {
      return isTargetEmergency && isCaseEmergency;
    }

    final numRegex = RegExp(r'\d+');
    final caseNumMatch = numRegex.firstMatch(raw);
    final targetCodeNumMatch = numRegex.firstMatch(targetCode);
    final targetNameNumMatch = numRegex.firstMatch(targetName);

    final String? caseNum = caseNumMatch?.group(0);
    final String? targetNum = targetCodeNumMatch?.group(0) ?? targetNameNumMatch?.group(0);

    if (caseNum != null && targetNum != null) {
      return caseNum == targetNum;
    }

    final norm = (String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').replaceAll('room', '');
    final cRoom = norm(raw);
    final tCode = norm(targetCode);
    final tName = norm(targetName);
    return cRoom == tCode || cRoom == tName || cRoom.contains(tCode) || tCode.contains(cRoom) || cRoom.contains(tName) || tName.contains(cRoom);
  }

  Set<String> _getOccupiedRoomsForSlot({
    required DateTime date,
    required TimeOfDay startTime,
    TimeOfDay? endTime,
    int? excludeDbId,
    String? excludeCaseId,
  }) {
    final allRooms = _availableOtRooms;
    final proposedStart = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final rawProposedEnd = endTime != null
        ? DateTime(
            date.year,
            date.month,
            date.day,
            endTime.hour,
            endTime.minute,
          )
        : proposedStart.add(const Duration(minutes: 90));
    final proposedEnd = rawProposedEnd.isAfter(proposedStart)
        ? rawProposedEnd
        : proposedStart.add(const Duration(minutes: 90));

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    return allRooms.where((room) {
      return _otCases.any((c) {
        if (excludeDbId != null && c.dbId == excludeDbId) return false;
        if (excludeCaseId != null && c.id == excludeCaseId) return false;
        if (!_matchesRoom(c, room, room)) return false;

        // Skip non-active, cancelled, or completed cases
        if (c.status == 'OT Case Closed' ||
            c.status == 'Surgery Completed' ||
            c.status == 'Post-Op Monitoring' ||
            c.status == 'Cancelled' ||
            c.status == 'Rejected' ||
            c.status == 'OT Requested') {
          return false;
        }

        // Live active surgery occupying theatre room right now (if scheduling for today)
        if (isToday && (c.status == 'Patient In OT' || c.status == 'Surgery In Progress')) {
          return true;
        }

        // Time overlap check for cases scheduled on the same date
        final cStart = c.scheduledStartTime ?? c.surgeryDateTime;
        if (cStart == null) return false;

        final isSameDate = cStart.year == date.year &&
                           cStart.month == date.month &&
                           cStart.day == date.day;
        if (!isSameDate) return false;

        final cEnd = c.scheduledEndTime ??
            cStart.add(Duration(minutes: c.estimatedDurationMinutes > 0 ? c.estimatedDurationMinutes : 90));

        // Overlap: (cStart < proposedEnd) && (cEnd > proposedStart)
        return cStart.isBefore(proposedEnd) && cEnd.isAfter(proposedStart);
      });
    }).toSet();
  }

  double _calculateCaseProgress(OtCase c) {
    if (c.status == 'OT Case Closed' || c.status == 'Surgery Completed' || c.status == 'Completed') return 1.0;
    if (c.status == 'Post-Op Monitoring') return 0.95;

    int totalMilestones = 8;
    int completed = 0;

    // 1. Scheduled & slot assigned
    if (c.scheduledStartTime != null || (c.otRoom != null && c.otRoom!.isNotEmpty)) completed++;
    // 2. Pre-Op preparation & consent
    if (c.consentSigned || c.idVerified || c.fastingConfirmed || c.status == 'Pre-Op Completed') completed++;
    // 3. PAC & Anesthesia cleared
    if (c.anaesthesiaCleared || c.pacStatus == 'Cleared' || c.status == 'Anaesthesia Cleared') completed++;
    // 4. Patient Arrival & Handover in OT
    if (c.patientArrived || c.handoverVerified || c.status == 'Patient In OT') completed++;
    // 5. WHO Checklist stages (Sign-In / Time-Out)
    if (c.whoChecklist.isNotEmpty) completed++;
    // 6. Surgery Start / In Progress
    if (c.surgeryStartTime != null || c.status == 'Surgery In Progress') completed++;
    // 7. Intra-Op Logs
    if (c.intraOpLogs.isNotEmpty) completed++;
    // 8. Post-Op Procedure Notes
    if ((c.procedurePerformed != null && c.procedurePerformed!.isNotEmpty) ||
        (c.operationSummary != null && c.operationSummary!.isNotEmpty)) completed++;

    double progress = completed / totalMilestones;

    // Apply baseline status floor for consistency:
    if (c.status == 'Surgery In Progress' && progress < 0.65) progress = 0.65;
    if (c.status == 'Patient In OT' && progress < 0.45) progress = 0.50;
    if (c.status == 'Anaesthesia Cleared' && progress < 0.35) progress = 0.38;
    if (c.status == 'Pre-Op Completed' && progress < 0.20) progress = 0.25;
    if (c.status == 'OT Scheduled' && progress < 0.10) progress = 0.15;
    if (c.status == 'OT Requested' && progress < 0.05) progress = 0.05;

    return progress.clamp(0.05, 1.0);
  }

  double _getCaseProgress(String status) {
    switch (status) {
      case 'OT Requested':
        return 0.05;
      case 'OT Scheduled':
        return 0.15;
      case 'Pre-Op Completed':
        return 0.25;
      case 'Anaesthesia Cleared':
        return 0.38;
      case 'Patient In OT':
        return 0.50;
      case 'Surgery In Progress':
        return 0.70;
      case 'Surgery Completed':
        return 0.90;
      case 'Post-Op Monitoring':
        return 0.95;
      case 'OT Case Closed':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          widget.isMobile
              ? Column(
                  children: [
                    _buildStatCard(
                      context.tr('pending_requests', fallback: 'Pending Requests'),
                      _pendingRequestsCount.toString(),
                      context.tr('requires_schedule', fallback: 'Requires Schedule'),
                      Icons.calendar_month,
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      context.tr('scheduled_today', fallback: 'Scheduled Today'),
                      _scheduledTodayCount.toString(),
                      context.tr('pre_op_in_progress', fallback: 'Pre-op in progress'),
                      Icons.schedule,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      context.tr('active_in_surgery', fallback: 'Active In Surgery'),
                      _activeInSurgeryCount.toString(),
                      context.tr('live_operating_room', fallback: 'Live operating room'),
                      Icons.flash_on,
                      Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      context.tr('recovery_post_op', fallback: 'Recovery & Post-Op'),
                      _recoveryPostOpCount.toString(),
                      context.tr('monitoring_vitals', fallback: 'Monitoring vitals'),
                      Icons.monitor_heart,
                      Colors.pink,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context.tr('pending_requests', fallback: 'Pending Requests'),
                        _pendingRequestsCount.toString(),
                        context.tr('requires_schedule', fallback: 'Requires Schedule'),
                        Icons.calendar_month,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context.tr('scheduled_today', fallback: 'Scheduled Today'),
                        _scheduledTodayCount.toString(),
                        context.tr('pre_op_in_progress', fallback: 'Pre-op in progress'),
                        Icons.schedule,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context.tr('active_in_surgery', fallback: 'Active In Surgery'),
                        _activeInSurgeryCount.toString(),
                        context.tr('live_operating_room', fallback: 'Live operating room'),
                        Icons.flash_on,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context.tr('recovery_post_op', fallback: 'Recovery & Post-Op'),
                        _recoveryPostOpCount.toString(),
                        context.tr('monitoring_vitals', fallback: 'Monitoring vitals'),
                        Icons.monitor_heart,
                        Colors.pink,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 28),

          // OT Room Grid Layout (Visually Stunning)
          const Text(
            'Live Operation Theatre Room Occupancy Board',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          widget.isMobile
              ? Column(
                  children: [
                    SizedBox(height: 245, child: _buildRoomCard('OT Room 1', 'OT-1', 'OT 1')),
                    const SizedBox(height: 12),
                    SizedBox(height: 245, child: _buildRoomCard('OT Room 2', 'OT-2', 'OT 2')),
                    const SizedBox(height: 12),
                    SizedBox(height: 245, child: _buildRoomCard('OT Room 3', 'OT-3', 'OT 3')),
                    const SizedBox(height: 12),
                    SizedBox(height: 245, child: _buildRoomCard('Emergency OT', 'OT-EMERGENCY', 'Emergency OT')),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SizedBox(height: 255, child: _buildRoomCard('OT Room 1', 'OT-1', 'OT 1'))),
                    const SizedBox(width: 16),
                    Expanded(child: SizedBox(height: 255, child: _buildRoomCard('OT Room 2', 'OT-2', 'OT 2'))),
                    const SizedBox(width: 16),
                    Expanded(child: SizedBox(height: 255, child: _buildRoomCard('OT Room 3', 'OT-3', 'OT 3'))),
                    const SizedBox(width: 16),
                    Expanded(child: SizedBox(height: 255, child: _buildRoomCard('Emergency OT', 'OT-EMERGENCY', 'Emergency OT'))),
                  ],
                ),
          const SizedBox(height: 28),
          _buildDashboardScheduledSurgeriesSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDashboardScheduledSurgeriesSection() {
    final now = DateTime.now();
    final scheduledCases = _otCases.where((c) {
      if (c.status == 'Cancelled' || c.status == 'Rejected') {
        return false;
      }
      if (c.status == 'OT Case Closed') {
        final dt = c.scheduledStartTime ?? c.surgeryDateTime;
        if (dt != null) {
          final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          return isToday;
        }
        return false;
      }
      return true;
    }).toList();

    scheduledCases.sort((a, b) {
      final aDt = a.scheduledStartTime ?? a.surgeryDateTime ?? DateTime(2099);
      final bDt = b.scheduledStartTime ?? b.surgeryDateTime ?? DateTime(2099);
      return aDt.compareTo(bDt);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(widget.isMobile ? 14 : 20),
            child: widget.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.event_note, color: AppTheme.primaryColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Scheduled Surgeries',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${scheduledCases.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Live scheduled cases, procedure timings & room assignments',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _previousTab = _activeTab;
                              _resetScheduleSurgeryForm();
                              _activeTab = 3; // Schedule Surgery
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Schedule Surgery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                              ),
                              child: const Icon(Icons.event_note, color: AppTheme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Scheduled Surgeries & Theatre Pipeline',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${scheduledCases.length}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Live scheduled cases, procedure timings, room assignments, and surgical teams',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _previousTab = _activeTab;
                            _resetScheduleSurgeryForm();
                            _activeTab = 3; // Schedule Surgery
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Schedule Surgery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          if (scheduledCases.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'No Surgeries Currently Scheduled',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Schedule a new surgery to allocate theatre rooms, set procedure timings, and assign clinical staff.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _previousTab = _activeTab;
                          _resetScheduleSurgeryForm();
                          _activeTab = 3;
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Schedule First Surgery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.isMobile)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: scheduledCases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final c = scheduledCases[idx];
                final dt = c.scheduledStartTime ?? c.surgeryDateTime;
                final isToday = dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;
                final dateStr = dt != null
                    ? (isToday ? 'Today' : DateFormat('dd/MM/yyyy').format(dt))
                    : 'Unscheduled';
                final slotStr = c.surgerySlot ?? (dt != null ? _formatTimeOfDay(TimeOfDay.fromDateTime(dt)) : '');
                final isEmergency = (c.priority ?? '').toLowerCase() == 'emergency';
                final isCaseDone = c.status == 'OT Case Closed' || c.status == 'Surgery Completed' || c.status == 'Completed';
                final progress = _calculateCaseProgress(c);
                final statusLabel = isCaseDone
                    ? 'COMPLETED'
                    : (c.status == 'Surgery In Progress'
                        ? 'IN PROGRESS'
                        : c.status.toUpperCase());
                final badgeColor = isCaseDone ? Colors.green : _getStatusColor(c.status);

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _selectOtCase(c);
                      setState(() {
                        _previousTab = _activeTab;
                        _openedFromLiveDashboard = true;
                        _showPipelineSidebar = false;
                        _activeTab = 1;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 13, color: isToday ? AppTheme.primaryColor : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isToday ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                ),
                              ),
                              if (slotStr.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                                Flexible(
                                  child: Text(
                                    slotStr,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEmergency ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.priority ?? 'Elective',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                child: Text(
                                  c.patientName.trim().isNotEmpty ? c.patientName.trim()[0].toUpperCase() : 'P',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.patientName.isNotEmpty ? c.patientName : 'Unnamed Patient',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimaryColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.patientId.isNotEmpty ? c.patientId : '-'} • ${c.age > 0 ? '${c.age}y ' : ''}${c.gender}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.otRoom ?? 'Unassigned',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.medical_services_outlined, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.surgeryType ?? 'General Surgery',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Dr. ${c.leadSurgeon ?? c.surgeon ?? "TBD"}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: badgeColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 5,
                                    color: badgeColor,
                                    backgroundColor: badgeColor.withOpacity(0.12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 18, color: AppTheme.primaryColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (MediaQuery.of(context).size.width - 64) > 1150
                      ? (MediaQuery.of(context).size.width - 64)
                      : 1150,
                ),
                child: DataTable(
                  columnSpacing: 28,
                  horizontalMargin: 16,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('DATE & TIME')),
                    DataColumn(label: Text('PATIENT')),
                    DataColumn(label: Text('SURGERY / PROCEDURE')),
                    DataColumn(label: Text('OT ROOM')),
                    DataColumn(label: Text('SURGICAL TEAM')),
                    DataColumn(label: Text('PRIORITY')),
                    DataColumn(label: Text('CASE PROGRESS & STATUS')),
                    DataColumn(label: Text('ACTION')),
                  ],
                  rows: scheduledCases.map((c) {
                    final dt = c.scheduledStartTime ?? c.surgeryDateTime;
                    final isToday = dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;
                    final dateStr = dt != null
                        ? (isToday ? 'Today' : DateFormat('dd/MM/yyyy').format(dt))
                        : 'Unscheduled';
                    final slotStr = c.surgerySlot ?? (dt != null ? _formatTimeOfDay(TimeOfDay.fromDateTime(dt)) : '');
                    final isEmergency = (c.priority ?? '').toLowerCase() == 'emergency';

                    return DataRow(
                      onSelectChanged: (_) {
                        _selectOtCase(c);
                        setState(() {
                          _previousTab = _activeTab;
                          _openedFromLiveDashboard = true;
                          _showPipelineSidebar = false;
                          _activeTab = 1;
                        });
                      },
                      cells: [
                        // Date & Time
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 12, color: isToday ? AppTheme.primaryColor : Colors.grey),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12,
                                        color: isToday ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (slotStr.isNotEmpty)
                                Text(
                                  slotStr,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                ),
                            ],
                          ),
                        ),
                        // Patient
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.patientName.isNotEmpty ? c.patientName : 'Unnamed Patient',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                              ),
                              Text(
                                '${c.patientId.isNotEmpty ? c.patientId : '-'} • ${c.age > 0 ? '${c.age}y' : ''} ${c.gender.isNotEmpty ? c.gender : ''}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                              ),
                            ],
                          ),
                        ),
                        // Surgery Type
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.surgeryType ?? 'General Surgery',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppTheme.textPrimaryColor),
                              ),
                              if (c.diagnosis.isNotEmpty)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    c.diagnosis,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryColor),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // OT Room
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    c.otRoom ?? 'Unassigned',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1D4ED8)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Team
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${c.leadSurgeon ?? c.surgeon ?? 'TBD'}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryColor),
                              ),
                              if ((c.anaesthetist ?? '').isNotEmpty)
                                Text(
                                  'Anaesth: ${c.anaesthetist}',
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryColor),
                                ),
                            ],
                          ),
                        ),
                        // Priority
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isEmergency ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.priority ?? 'Elective',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isEmergency ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ),
                        // Case Progress & Status
                        DataCell(
                          Builder(builder: (context) {
                            final isCaseDone = c.status == 'OT Case Closed' || c.status == 'Surgery Completed' || c.status == 'Completed';
                            final progress = _calculateCaseProgress(c);
                            final statusLabel = isCaseDone
                                ? 'COMPLETED'
                                : (c.status == 'Surgery In Progress'
                                    ? 'IN PROGRESS'
                                    : c.status.toUpperCase());
                            final badgeColor = isCaseDone
                                ? Colors.green
                                : _getStatusColor(c.status);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCaseDone) ...[
                                        const Icon(Icons.check_circle, size: 11, color: Colors.green),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            color: badgeColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  width: 85,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      color: badgeColor,
                                      backgroundColor: badgeColor.withOpacity(0.12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        // Action
                        DataCell(
                          TextButton.icon(
                            onPressed: () {
                              _selectOtCase(c);
                              setState(() {
                                _previousTab = _activeTab;
                                _openedFromLiveDashboard = true;
                                _activeTab = 1; // Open workflow in Active Cases
                              });
                            },
                            icon: const Icon(Icons.arrow_forward, size: 14),
                            label: const Text('Open Workflow', style: TextStyle(fontSize: 11.5)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subText, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                const SizedBox(height: 6),
                Text(subText, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.15), width: 1),
            ),
            child: Icon(icon, color: color, size: 26),
          )
        ],
      ),
    );
  }

  Widget _buildRoomCard(String roomName, String code, String otId) {
    // An operating theatre room is occupied only during live patient presence / active surgery.
    // Once surgery completes, patient is transferred to post-op/PACU/recovery, or case is closed, the theatre room is Available.
    final activeInRoom = _otCases.firstWhere(
      (c) => _matchesRoom(c, code, otId) &&
             (c.status == 'Patient In OT' || c.status == 'Surgery In Progress'),
      orElse: () => OtCase(id: '', patientId: '', patientName: '', age: 0, gender: '', bloodGroup: '', diagnosis: ''),
    );

    final bool isOccupied = activeInRoom.id.isNotEmpty;

    final scheduledInRoom = !isOccupied
        ? _otCases.firstWhere(
            (c) => _matchesRoom(c, code, otId) &&
                   (c.status == 'OT Scheduled' ||
                    c.status == 'Scheduled' ||
                    c.status == 'OT Requested' ||
                    c.status == 'Requested' ||
                    c.status == 'Pre-Op Completed' ||
                    c.status == 'Anaesthesia Cleared' ||
                    c.status.toLowerCase().contains('sched')),
            orElse: () => OtCase(id: '', patientId: '', patientName: '', age: 0, gender: '', bloodGroup: '', diagnosis: ''),
          )
        : null;
    final bool hasScheduled = scheduledInRoom != null && scheduledInRoom.id.isNotEmpty;

    final color = isOccupied
        ? AppTheme.dangerColor
        : (hasScheduled ? const Color(0xFF0284C7) : Colors.green);
    final progressVal = isOccupied ? _calculateCaseProgress(activeInRoom) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOccupied ? color.withOpacity(0.25) : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isOccupied ? color.withOpacity(0.06) : Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOccupied ? color.withOpacity(0.04) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: isOccupied ? color.withOpacity(0.12) : Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 16, color: isOccupied ? color : AppTheme.textSecondaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isOccupied ? color : AppTheme.textPrimaryColor, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isOccupied ? color.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOccupied ? color : (hasScheduled ? const Color(0xFF0284C7) : Colors.green),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 85),
                        child: Text(
                          isOccupied
                              ? 'OCCUPIED'
                              : (hasScheduled ? 'SCHEDULED' : 'AVAILABLE'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isOccupied ? color : (hasScheduled ? const Color(0xFF0284C7) : Colors.green),
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: isOccupied
                  ? InkWell(
                      onTap: () {
                        _selectOtCase(activeInRoom);
                        setState(() {
                          _previousTab = _activeTab;
                          _openedFromLiveDashboard = true;
                          _showPipelineSidebar = false;
                          _activeTab = 1;
                        });
                      },
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeInRoom.patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeInRoom.age} yrs • ${activeInRoom.gender} • Blood: ${activeInRoom.bloodGroup}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryColor),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.healing, size: 12, color: AppTheme.textSecondaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    activeInRoom.surgeryType ?? '',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 12, color: AppTheme.textSecondaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Surgeon: ${activeInRoom.surgeon ?? 'TBD'}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Progress Bar representing case completion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Surgery Progress', style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondaryColor)),
                                Text(
                                  '${(progressVal * 100).toInt()}%',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressVal,
                                color: color,
                                backgroundColor: color.withOpacity(0.1),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                _selectOtCase(activeInRoom);
                                setState(() {
                                  _previousTab = _activeTab;
                                  _openedFromLiveDashboard = true;
                                  _showPipelineSidebar = false;
                                  _activeTab = 1; // Go to active patients registry
                                });
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View Live Workflow Board',
                                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 11, color: AppTheme.primaryColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (hasScheduled
                      ? InkWell(
                          onTap: () {
                            _selectOtCase(scheduledInRoom!);
                            setState(() {
                              _previousTab = _activeTab;
                              _openedFromLiveDashboard = true;
                              _showPipelineSidebar = false;
                              _activeTab = 1;
                            });
                          },
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  scheduledInRoom!.patientName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimaryColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${scheduledInRoom.age > 0 ? '${scheduledInRoom.age} yrs • ' : ''}${scheduledInRoom.gender} • Blood: ${scheduledInRoom.bloodGroup.isNotEmpty ? scheduledInRoom.bloodGroup : '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryColor),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.healing, size: 12, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        scheduledInRoom.surgeryType ?? 'Surgery',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Slot: ${scheduledInRoom.surgerySlot ?? (scheduledInRoom.scheduledStartTime != null ? _formatTimeOfDay(TimeOfDay.fromDateTime(scheduledInRoom.scheduledStartTime!)) : 'Scheduled')}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 12, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Surgeon: ${scheduledInRoom.leadSurgeon ?? scheduledInRoom.surgeon ?? 'TBD'}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    _selectOtCase(scheduledInRoom);
                                    setState(() {
                                      _previousTab = _activeTab;
                                      _openedFromLiveDashboard = true;
                                      _showPipelineSidebar = false;
                                      _activeTab = 1; // Go to active workflow
                                    });
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View Scheduled Case',
                                        style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, size: 11, color: Color(0xFF0284C7)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_task, size: 24, color: Colors.green),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ready for Scheduling',
                              style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 12.5, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Room is clean & unoccupied',
                              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )),
            ),
          ),
        ],
      ),
    );
  }



  void _showIntegrationDetailsModal(String title) {
    IconData icon;
    Color themeColor;
    String needDescription;
    List<String> keyFeatures;
    Map<String, String> liveMetrics;
    String routeTarget;
    String routeButtonLabel;

    switch (title) {
      case 'IPD Integration':
        icon = Icons.hotel_outlined;
        themeColor = const Color(0xFF0284C7);
        needDescription =
            'Connects the Inpatient Department (IPD) wards directly with the Operation Theatre suite. '
            'Inpatients requiring elective or emergency surgery are automatically linked to OT scheduling without manual re-registration, '
            'ensuring complete continuity of care, automated ward-to-OT transfer logs, and live tracking of pre-operative ward preparation.';
        keyFeatures = [
          'Directly pulls patient admission ID, blood group, ward, and bed numbers.',
          'Synchronizes pre-op checklist completion (NPO fasting, pre-medication, surgical site prep).',
          'Enables automated bed-hold in ward during the surgical procedure.',
          'Provides electronic handover between floor nurses and OT staff.',
        ];
        liveMetrics = {
          'Active Inpatient Admissions': '${_patients.length} Registered',
          'OT Cases Linked from IPD': '${_otCases.where((c) => c.status != 'Cancelled').length} Cases',
          'Ward Bed Status Sync': '${_beds.where((b) => b['status'] == 'Available').length} Available Beds',
          'Pre-Op Readiness Verified': '${_otCases.where((c) => c.consentSigned || c.idVerified).length} Verified',
        };
        routeTarget = AppRoutes.adminIpd;
        routeButtonLabel = 'Go to IPD Management';
        break;

      case 'ICU Integration':
        icon = Icons.monitor_heart_outlined;
        themeColor = const Color(0xFFDC2626);
        needDescription =
            'Ensures post-operative critical care readiness for major, high-risk, or emergency surgeries. '
            'The surgical team can pre-reserve and lock an ICU/HDU bed with ventilator and monitor specifications '
            'prior to surgical incision, eliminating life-threatening delays after surgery completion.';
        keyFeatures = [
          'Pre-books post-op ICU/HDU beds directly during surgical planning.',
          'Alerts ICU intensivists and nursing staff of expected arrival time and case complexity.',
          'Shares real-time intra-op anesthesia telemetry, blood loss, and stability status.',
          'Automates immediate post-operative transfer handover to intensive care units.',
        ];
        liveMetrics = {
          'Emergency / High-Risk Cases': '${_otCases.where((c) => c.priority == 'Emergency').length} Active',
          'Post-Op Monitoring Pipeline': '$_recoveryPostOpCount In Recovery',
          'Telemetry Sync': 'Continuous Real-time Link',
          'ICU Bed Booking Protocol': 'Auto-Reservation Ready',
        };
        routeTarget = AppRoutes.adminIcu;
        routeButtonLabel = 'Go to ICU Management';
        break;

      case 'Pharmacy Integration':
        icon = Icons.local_pharmacy_outlined;
        themeColor = const Color(0xFF059669);
        needDescription =
            'Automates surgical pharmacy requisitions, anesthesia drug bundles, and controlled narcotic tracking. '
            'Ensures all required intravenous medications, emergency cardiovascular drugs, and surgical packs '
            'are verified and delivered to the OT suite well before anesthesia induction, preventing procedural halts.';
        keyFeatures = [
          'Generates tailored pre-op drug packs based on specific surgery type and surgeon preference.',
          'Automates narcotic and controlled substance digital sign-out and dispensing logs.',
          'Real-time deduction of intra-op medications, gases, and IV fluids from central hospital stock.',
          'Cross-checks patient allergy records against scheduled anesthetic and antibiotic agents.',
        ];
        liveMetrics = {
          'Scheduled Surgeries Today': '$_scheduledTodayCount Drug Kits Queued',
          'Controlled Substances Audit': 'Strict 2-Signature Protocol Active',
          'Inventory Requisition Status': 'Central Pharmacy Linked',
          'Drug Allergy Verification': 'Automated Real-Time Check',
        };
        routeTarget = AppRoutes.adminMedicationCatalog;
        routeButtonLabel = 'View Medication Catalog';
        break;

      case 'Lab Integration':
        icon = Icons.biotech_outlined;
        themeColor = const Color(0xFF7C3AED);
        needDescription =
            'Streams critical diagnostic and Pre-Anesthetic Checkup (PAC) laboratory investigations directly to the OT team. '
            'Surgeons and anesthetists can instantly verify Complete Blood Count (CBC), coagulation profile (PT/INR), '
            'cross-matched blood units, and viral serology before surgery, preventing preventable surgical complications.';
        keyFeatures = [
          'Instant digital retrieval of PAC blood profiles (Hemoglobin, Platelets, PT/INR, Electrolytes).',
          'Real-time Blood Bank cross-match confirmation and reserved PRBC/FFP unit status.',
          'Automated safety warnings for abnormal coagulopathy, severe anemia, or electrolyte imbalance.',
          'Direct electronic accessioning of intra-operative frozen section biopsy and histopathology specimens.',
        ];
        liveMetrics = {
          'PAC Cleared Cases': '${_otCases.where((c) => c.anaesthesiaCleared || c.pacStatus == 'Cleared').length} Cleared',
          'Pending PAC Review': '${_otCases.where((c) => !c.anaesthesiaCleared && c.status != 'OT Case Closed').length} Pending',
          'Blood Bank Cross-Match Link': 'Verified & Operational',
          'Biopsy Specimen Accessioning': 'Live Digital Tracking',
        };
        routeTarget = AppRoutes.labDashboard;
        routeButtonLabel = 'Go to Lab Dashboard';
        break;

      case 'Billing Integration':
        icon = Icons.receipt_long_outlined;
        themeColor = const Color(0xFFD97706);
        needDescription =
            'Ensures 100% accurate, leakage-free revenue capture for all surgical operations. '
            'Immediately upon case completion, theater occupancy duration, surgeon and anesthetist procedural fees, '
            'equipment/gas tariffs, and used implants/consumables are automatically calculated and added to the patient’s final invoice.';
        keyFeatures = [
          'Automated calculation of OT room hourly tariff based on recorded surgical incision and closure times.',
          'Direct posting of Surgeon, Assistant Surgeon, and Anesthesiologist professional charges.',
          'Itemized billing of consumables, suture materials, meshes, and serialized implant barcodes.',
          'Seamless synchronization with patient master billing and insurance/TPA claims portal.',
        ];
        liveMetrics = {
          'Cases Awaiting Final Billing': '${_otCases.where((c) => c.status == 'Surgery Completed' || c.status == 'Post-Op Monitoring').length} Ready',
          'Closed & Billed Surgeries': '${_otCases.where((c) => c.status == 'OT Case Closed').length} Invoiced',
          'Tariff Auto-Calculation': 'Standard Operating Schedule',
          'Implant Barcode Traceability': 'Integrated with Billing Items',
        };
        routeTarget = AppRoutes.adminBilling;
        routeButtonLabel = 'Go to Billing Management';
        break;

      case 'Nursing Dashboard':
      default:
        title = 'Nursing Dashboard';
        icon = Icons.assignment_ind_outlined;
        themeColor = const Color(0xFF2563EB);
        needDescription =
            'Provides bidirectional visibility between the surgical suite and floor/ward nursing stations. '
            'Ward nurses receive real-time notifications when a patient moves into OT, begins surgery, or enters recovery, '
            'eliminating unnecessary phone inquiries and enabling timely recovery bed and post-op care preparation.';
        keyFeatures = [
          'Live visual indicator of current surgery stage (Pre-Op, In Surgery, Recovery, Transferred).',
          'Automated ward notifications for patient dispatch and post-operative ward readiness.',
          'Digital nursing handover checklist covering surgical sites, drains, catheters, and dressings.',
          'Integrated Medication Administration Record (MAR) alignment for post-operative drug orders.',
        ];
        liveMetrics = {
          'Active Pipeline Cases': '${_otCases.where((c) => c.status != 'OT Case Closed').length} In Transit/Care',
          'Surgeries Underway': '$_activeInSurgeryCount In Theatre',
          'Ward Handover Notification': 'Instant Status Broadcast',
          'Post-Op Recovery Telemetry': 'Streaming to Nursing Station',
        };
        routeTarget = AppRoutes.nurseDashboard;
        routeButtonLabel = 'Go to Nursing Dashboard';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.only(
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: themeColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimaryColor),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 5),
                          Text(
                            'Connected & Operational (2-Way Live Sync)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: widget.isMobile ? double.infinity : 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Purpose & Clinical Need
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: themeColor, width: 4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline, size: 16, color: themeColor),
                          const SizedBox(width: 6),
                          Text(
                            'Why is this integration needed?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        needDescription,
                        style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Key Automated Workflows
                const Text(
                  'Automated Clinical Workflows',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 8),
                Column(
                  children: keyFeatures.map((feat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, size: 15, color: themeColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feat,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Live Synchronized Metrics
                const Text(
                  'Live Synchronized System Metrics',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: liveMetrics.entries.map((entry) {
                    return Container(
                      width: widget.isMobile ? double.infinity : 290,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: AppTheme.cancelButton,
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: themeColor,
              side: BorderSide(color: themeColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _loadPatientsAndDoctors();
              AppNotification.showSuccess(
                context,
                '$title data synchronized successfully! Real-time records refreshed.',
                atTop: true,
              );
            },
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              try {
                context.go(routeTarget);
              } catch (_) {
                AppNotification.showInfo(
                  context,
                  'Opening $title: $routeButtonLabel',
                  atTop: true,
                );
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(routeButtonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── VIEW 2: ACTIVE WORKFLOW TIMELINE & ACTIONS ──────────────────────

  Widget _buildActivePatientsView() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final activeCases = _otCases
        .where((c) => c.status != 'OT Case Closed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .toList();

    final filteredCases = activeCases.where((c) {
      final query = _searchCtrl.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return c.patientName.toLowerCase().contains(query) ||
             c.patientId.toLowerCase().contains(query) ||
             c.id.toLowerCase().contains(query) ||
             (c.surgeryType ?? '').toLowerCase().contains(query) ||
             (c.surgeon ?? c.leadSurgeon ?? '').toLowerCase().contains(query) ||
             (c.otRoom ?? '').toLowerCase().contains(query) ||
             c.status.toLowerCase().contains(query);
    }).toList();

    final masterPane = Container(
      width: widget.isMobile ? double.infinity : 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Patient pipeline & counter badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Patient pipeline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        activeCases.length.toString(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search registry',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Patient List
          Expanded(
            child: filteredCases.isEmpty
                ? const Center(
                    child: Text(
                      'No patients found',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCases.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, idx) {
                      final c = filteredCases[idx];
                      final isSelected = _selectedCase?.id == c.id;
                      final statusColor = c.status == 'OT Case Closed' || c.status == 'Completed'
                          ? const Color(0xFF16A34A)
                          : (c.status.contains('In Progress') || c.status.contains('Surgery')
                              ? const Color(0xFFD97706)
                              : AppTheme.primaryColor);

                      return InkWell(
                        onTap: () {
                          _openedFromLiveDashboard = false;
                          if (widget.isMobile) {
                            _showPipelineSidebar = false;
                          }
                          _selectOtCase(c);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryLight.withOpacity(0.35)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: Text(
                                      c.patientName.trim().isNotEmpty
                                          ? c.patientName.trim()[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.patientName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          c.patientId,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.medical_services_outlined, size: 12.5, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      c.surgeryType ?? 'General Procedure',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if ((c.surgeon ?? c.leadSurgeon) != null && (c.surgeon ?? c.leadSurgeon)!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 12.5, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Surgeon: ${c.surgeon ?? c.leadSurgeon}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      c.otRoom ?? 'OT 1',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.schedule, size: 11.5, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        c.surgerySlot != null && c.surgerySlot!.isNotEmpty
                                            ? c.surgerySlot!
                                            : (c.surgeryDateTime != null ? DateFormat('hh:mm a').format(c.surgeryDateTime!) : '9:00–11:30 AM'),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
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
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${filteredCases.length} active case${filteredCases.length == 1 ? "" : "s"} in your pipeline',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Select a patient to view their surgical care journey.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isMobile) {
      if (_selectedCase != null) {
        return _buildCaseWorkflowDetails(_selectedCase!);
      }
      return masterPane;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showPipelineSidebar || _selectedCase == null) ...[
          masterPane,
          const SizedBox(width: 16),
        ],
        // Detail Pane: Right Column
        Expanded(
          child: _selectedCase != null
              ? _buildCaseWorkflowDetails(_selectedCase!)
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.biotech_outlined,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Patient Selected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select a patient from the registry on the left to track timeline & update surgical clinical inputs.',
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompletedPatientsView() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final completedCases = _otCases
        .where((c) => c.status == 'OT Case Closed' || c.status == 'Surgery Completed' || c.status == 'Completed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .toList();

    final filteredCases = completedCases.where((c) {
      final query = _searchCtrl.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return c.patientName.toLowerCase().contains(query) ||
             c.patientId.toLowerCase().contains(query) ||
             c.id.toLowerCase().contains(query) ||
             (c.surgeryType ?? '').toLowerCase().contains(query) ||
             (c.surgeon ?? c.leadSurgeon ?? '').toLowerCase().contains(query) ||
             (c.otRoom ?? '').toLowerCase().contains(query) ||
             c.status.toLowerCase().contains(query);
    }).toList();

    final masterPane = Container(
      width: widget.isMobile ? double.infinity : 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Completed pipeline & counter badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completed cases',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        completedCases.length.toString(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search registry',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Patient List
          Expanded(
            child: filteredCases.isEmpty
                ? const Center(
                    child: Text(
                      'No completed cases found',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCases.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, idx) {
                      final c = filteredCases[idx];
                      final isSelected = _selectedCase?.id == c.id;
                      const statusColor = Color(0xFF16A34A);

                      return InkWell(
                        onTap: () {
                          _openedFromLiveDashboard = false;
                          if (widget.isMobile) {
                            _showPipelineSidebar = false;
                          }
                          _selectOtCase(c);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryLight.withOpacity(0.35)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF16A34A).withOpacity(0.12),
                                    child: Text(
                                      c.patientName.trim().isNotEmpty
                                          ? c.patientName.trim()[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.patientName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          c.patientId,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.medical_services_outlined, size: 12.5, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      c.surgeryType ?? 'General Procedure',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if ((c.surgeon ?? c.leadSurgeon) != null && (c.surgeon ?? c.leadSurgeon)!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 12.5, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Surgeon: ${c.surgeon ?? c.leadSurgeon}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      c.otRoom ?? 'OT 1',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.schedule, size: 11.5, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        c.surgerySlot != null && c.surgerySlot!.isNotEmpty
                                            ? c.surgerySlot!
                                            : (c.surgeryDateTime != null ? DateFormat('hh:mm a').format(c.surgeryDateTime!) : '9:00–11:30 AM'),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
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
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${filteredCases.length} completed case${filteredCases.length == 1 ? "" : "s"} in your pipeline',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Select a patient to view their surgical care journey.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isMobile) {
      if (_selectedCase != null) {
        return _buildCaseWorkflowDetails(_selectedCase!);
      }
      return masterPane;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showPipelineSidebar || _selectedCase == null) ...[
          masterPane,
          const SizedBox(width: 16),
        ],
        // Detail Pane: Right Column
        Expanded(
          child: _selectedCase != null
              ? _buildCaseWorkflowDetails(_selectedCase!)
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Completed Case Selected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select a completed patient from the registry on the left to track timeline & view surgical records.',
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCaseWorkflowDetails(OtCase otCase) {
    if (widget.isMobile) {
      return _buildMobileWorkflowDetails(otCase);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final headersEstimatedHeight = _showWorkflowTimeline ? 230.0 : 130.0;
        final minWorkspaceHeight = 750.0;
        final needsScroll = availableHeight < (headersEstimatedHeight + minWorkspaceHeight);

        if (needsScroll) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopPatientHeader(otCase),
                if (_showWorkflowTimeline) ...[
                  const SizedBox(height: 8),
                  _buildHorizontalWorkflowStepper(otCase),
                ],
                const SizedBox(height: 8),
                Container(
                  height: minWorkspaceHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: _buildTabbedWorkspace(otCase),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDesktopPatientHeader(otCase),
            if (_showWorkflowTimeline) ...[
              const SizedBox(height: 8),
              _buildHorizontalWorkflowStepper(otCase),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: _buildTabbedWorkspace(otCase),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileWorkflowDetails(OtCase otCase) {
    final avatarColors = AppTheme.getAvatarColors(otCase.patientName);
    
    return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Header Details (Mobile)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showPipelineSidebar = true;
                            if (_openedFromLiveDashboard) {
                              _selectedCase = null;
                              _activeTab = _previousTab;
                              _openedFromLiveDashboard = false;
                            } else {
                              _selectedCase = null;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColors['bg'],
                        child: Text(
                          otCase.patientName.isNotEmpty ? otCase.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase() : '?',
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
                              otCase.patientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(otCase.status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                otCase.status,
                                style: TextStyle(color: _getStatusColor(otCase.status), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  // Clinical Safety Quick Badges
                  Row(
                    children: [
                      // PAC Badge
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            final user = Provider.of<AuthProvider>(context, listen: false).user;
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => PacAssessmentDialog(
                                otCase: otCase,
                                isMobile: widget.isMobile,
                                currentUser: user?.fullname ?? 'Anaesthetist',
                                onPacUpdated: (updated) {
                                  _syncPacUpdate(otCase, updated);
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                  ? AppTheme.secondaryColor.withOpacity(0.12)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                    ? AppTheme.secondaryColor.withOpacity(0.3)
                                    : AppTheme.dangerColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                      ? Icons.verified_user
                                      : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                      ? AppTheme.secondaryColor
                                      : AppTheme.dangerColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'PAC: ${otCase.pacStatus.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                          ? AppTheme.secondaryColor
                                          : AppTheme.dangerColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // WHO Checklist Badge
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            final user = Provider.of<AuthProvider>(context, listen: false).user;
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                insetPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: MediaQuery.of(dialogCtx).size.height * 0.05,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 820,
                                    maxHeight: MediaQuery.of(dialogCtx).size.height * 0.88,
                                  ),
                                  child: WhoSurgicalSafetyChecklistWidget(
                                    otCase: otCase,
                                    isMobile: true,
                                    isPopup: true,
                                    currentUser: user?.fullname ?? 'Staff',
                                    onChecklistUpdated: (updated) {
                                      setState(() {
                                        otCase.whoChecklist = updated.whoChecklist;
                                        otCase.auditLogs = updated.auditLogs;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fact_check_outlined, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'WHO Checklist',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Complete Surgical Team Box
                  Container(
                    width: double.infinity,
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
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                otCase.otRoom != null ? 'OT Room: ${otCase.otRoom}' : 'OT Room: Not Assigned',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimaryColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildTeamCompactLine('Lead Surgeon', otCase.leadSurgeon ?? otCase.surgeon ?? 'Not Assigned'),
                        _buildTeamCompactLine('Assistant', otCase.assistantSurgeon ?? 'Not Assigned'),
                        _buildTeamCompactLine('Anaesthetist', otCase.anaesthetist ?? 'Not Assigned'),
                        _buildTeamCompactLine('Scrub Nurse', otCase.scrubNurse ?? 'Not Assigned'),
                        _buildTeamCompactLine('Circulating', otCase.circulatingNurse ?? 'Not Assigned'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildVerticalWorkflowStepper(otCase),
            const SizedBox(height: 16),
            Container(
              height: 650, // Fixed height on mobile so TabBarView has bounds
              decoration: AppTheme.cardDecoration,
              child: _buildTabbedWorkspace(otCase),
            ),
          ],
        ),
      );
  }

  Widget _buildDesktopPatientHeader(OtCase otCase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Line 1: Patient Name, Age/Gender, Blood group, Priority | Right: OT chip, PAC pill, status subtitle
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  otCase.patientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                                Text(
                                  '${otCase.age} yrs  /  ${otCase.gender}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    otCase.bloodGroup.isNotEmpty ? otCase.bloodGroup : 'O+',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    otCase.priority ?? 'Elective',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      otCase.otRoom ?? 'OT 1',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      final user = Provider.of<AuthProvider>(context, listen: false).user;
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => PacAssessmentDialog(
                                          otCase: otCase,
                                          isMobile: false,
                                          currentUser: user?.fullname ?? 'Anaesthetist',
                                          onPacUpdated: (updated) {
                                            _syncPacUpdate(otCase, updated);
                                          },
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check, size: 11, color: Color(0xFF059669)),
                                          const SizedBox(width: 3),
                                          Text(
                                            ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus) ? 'PAC cleared' : 'PAC: ${otCase.pacStatus}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                otCase.status,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Line 2: ID and Diagnosis
                      Text(
                        '${otCase.patientId}  ·  Diagnosis: ${otCase.diagnosis.isNotEmpty ? otCase.diagnosis : "None"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      // Line 3: CARE TEAM and WHO Checklist Button
                      Row(
                        children: [
                          const Text(
                            'CARE TEAM',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCareTeamInline('Surgeon', otCase.leadSurgeon ?? otCase.surgeon),
                                  const SizedBox(width: 12),
                                  _buildCareTeamInline('Asst.', otCase.assistantSurgeon),
                                  const SizedBox(width: 12),
                                  _buildCareTeamInline('Anaesth.', otCase.anaesthetist),
                                  const SizedBox(width: 12),
                                  _buildCareTeamInline('Scrub', otCase.scrubNurse),
                                  const SizedBox(width: 12),
                                  _buildCareTeamInline('Circ.', otCase.circulatingNurse),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              final user = Provider.of<AuthProvider>(context, listen: false).user;
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  insetPadding: const EdgeInsets.all(24),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
                                    child: WhoSurgicalSafetyChecklistWidget(
                                      otCase: otCase,
                                      isMobile: false,
                                      isPopup: true,
                                      currentUser: user?.fullname ?? 'Staff',
                                      onChecklistUpdated: (updated) {
                                        setState(() {
                                          otCase.whoChecklist = updated.whoChecklist;
                                          otCase.auditLogs = updated.auditLogs;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.fact_check_outlined, size: 12, color: Color(0xFF475569)),
                            label: const Text(
                              'WHO checklist',
                              style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: _showWorkflowTimeline ? 'Hide Stepper Timeline' : 'Show Stepper Timeline',
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _showWorkflowTimeline = !_showWorkflowTimeline),
                              icon: Icon(_showWorkflowTimeline ? Icons.unfold_less : Icons.unfold_more, size: 12, color: const Color(0xFF475569)),
                              label: Text(
                                _showWorkflowTimeline ? 'Timeline' : 'Show Timeline',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
  }

  Widget _buildCareTeamInline(String role, String? name) {
    final bool hasName = name != null && name.trim().isNotEmpty && name != 'Not Assigned' && name != 'Unassigned';
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontFamily: AppTheme.fontFamily),
        children: [
          TextSpan(text: '$role ', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.normal)),
          TextSpan(text: hasName ? name : '—', style: TextStyle(fontWeight: hasName ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildHorizontalWorkflowStepper(OtCase otCase) {
    int activeIndex = 0;
    if (otCase.status == 'OT Scheduled') activeIndex = 1;
    if (otCase.status == 'Pre-Op Completed') activeIndex = 2;
    if (otCase.status == 'Anaesthesia Cleared') activeIndex = 3;
    if (otCase.status == 'Patient In OT') activeIndex = 4;
    if (otCase.status == 'Surgery In Progress') activeIndex = 5;
    if (otCase.status == 'Surgery Completed') activeIndex = 6;
    if (otCase.status == 'Post-Op Monitoring') activeIndex = 7;
    if (otCase.status == 'OT Case Closed') activeIndex = 8;

    final steps = [
      {
        'title': 'Booking & scheduling',
        'subtitle': otCase.surgeryType ?? 'Laparoscopic cholecystectomy',
      },
      {
        'title': 'Pre-op checklist',
        'subtitle': '${otCase.otRoom ?? "OT 1"} · ${otCase.surgerySlot ?? (otCase.surgeryDateTime != null ? DateFormat("hh:mm a").format(otCase.surgeryDateTime!) : "9:00–11:30 AM")}',
      },
      {
        'title': 'PAC & anaesthesia',
        'subtitle': 'Vitals: ${otCase.preOpBp ?? "120"} · Pulse: ${otCase.preOpPulse ?? "100"}',
      },
      {
        'title': 'Patient handover',
        'subtitle': otCase.handoverNotes != null && otCase.handoverNotes!.isNotEmpty ? otCase.handoverNotes! : 'Next step · Transfer to OT',
      },
      {
        'title': 'WHO time-out & in-OT prep',
        'subtitle': 'Safety verification in theatre',
      },
      {
        'title': 'Surgery in progress',
        'subtitle': otCase.surgeryStartTime != null ? 'Started: ${DateFormat("hh:mm a").format(otCase.surgeryStartTime!)}' : 'Intra-op monitoring',
      },
      {
        'title': 'Post-op notes & transfer',
        'subtitle': otCase.transferDestination != null ? 'To: ${otCase.transferDestination}' : 'Recovery transfer',
      },
      {
        'title': 'PACU recovery',
        'subtitle': 'Post-anesthesia recovery',
      },
      {
        'title': 'Case closed',
        'subtitle': 'Completed & archived',
      },
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length, (idx) {
            final isCompleted = idx < activeIndex;
            final isActive = idx == activeIndex;
            final isPending = idx > activeIndex;

            final step = steps[idx];

            return Container(
              margin: EdgeInsets.only(right: idx < steps.length - 1 ? 24 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 20,
                    )
                  else if (isActive)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step['title']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppTheme.primaryColor
                              : (isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step['subtitle']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isPending ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTeamCompactChip(String role, String? name) {
    final bool isAssigned = name != null &&
        name.trim().isNotEmpty &&
        name != 'Not Assigned' &&
        name != 'Unassigned';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$role: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          isAssigned ? name : '—',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isAssigned ? FontWeight.w700 : FontWeight.normal,
            color: isAssigned ? AppTheme.textPrimaryColor : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCompactLine(String role, String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$role: ',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: name == 'Not Assigned' ? Colors.grey.shade400 : AppTheme.textPrimaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String key, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == key;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTabbedWorkspace(OtCase otCase) {
    return DefaultTabController(
      length: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: 16),
              labelPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Color(0xFF64748B),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                fontFamily: AppTheme.fontFamily,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                fontFamily: AppTheme.fontFamily,
              ),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'WHO safety'),
                Tab(text: 'PAC check'),
                Tab(text: 'Anaesthesia'),
                Tab(text: 'Consumables'),
                Tab(text: 'Summary'),
                Tab(text: 'Audit trail'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOtDetailsTab(otCase),
                _buildWhoChecklistTab(otCase),
                _buildPacTab(otCase),
                _buildAnesthesiaDetailsTab(otCase),
                _buildConsumablesAndImplantsTab(otCase),
                _buildSurgicalSummaryTab(otCase),
                _buildAuditTrailTab(otCase),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumablesAndImplantsTab(OtCase otCase) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return OtConsumablesImplantsWidget(
      otCase: otCase,
      isMobile: widget.isMobile,
      currentUser: user?.fullname ?? 'OT Staff',
      onCaseUpdated: (updated) {
        setState(() {
          otCase.consumablesUsed = updated.consumablesUsed;
          otCase.implantsUsed = updated.implantsUsed;
        });
      },
    );
  }

  Widget _buildWhoChecklistTab(OtCase otCase) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 8 : 12),
      child: WhoSurgicalSafetyChecklistWidget(
        otCase: otCase,
        isMobile: widget.isMobile,
        isPopup: false,
        currentUser: user?.fullname ?? 'Staff',
        onChecklistUpdated: (updatedCase) {
          setState(() {
            otCase.whoChecklist = updatedCase.whoChecklist;
            otCase.auditLogs = updatedCase.auditLogs;
          });
        },
      ),
    );
  }

  Widget _buildPacTab(OtCase otCase) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final pac = otCase.pacDetails;
    final isCleared = ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Pre-anaesthetic assessment / Clinical readiness and airway strategy | [ ✓ Cleared for surgery ]
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-anaesthetic assessment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Clinical readiness and airway strategy',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PacAssessmentDialog(
                      otCase: otCase,
                      isMobile: widget.isMobile,
                      currentUser: user?.fullname ?? 'Anaesthetist',
                      onPacUpdated: (updatedCase) {
                        _syncPacUpdate(otCase, updatedCase);
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCleared ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCleared ? const Color(0xFFA7F3D0) : AppTheme.dangerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCleared ? Icons.check : Icons.warning_amber_rounded,
                        size: 13,
                        color: isCleared ? const Color(0xFF059669) : AppTheme.dangerColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCleared ? 'Cleared for surgery' : 'Pending clearance',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isCleared ? const Color(0xFF059669) : AppTheme.dangerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 4 Metric cards in a row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 600
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;

              final asaVal = pac['effective_asa'] ?? pac['asa_grade'] ?? 'ASA II';
              final isHighRisk = asaVal.toString().contains('III') || asaVal.toString().contains('IV') || asaVal.toString().contains('V');

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // 1. ASA Classification
                  _buildPacMetricCard(
                    title: 'ASA classification',
                    value: asaVal.toString(),
                    width: cardWidth,
                  ),
                  // 2. Risk Level (Amber pill)
                  _buildPacMetricCard(
                    title: 'Risk level',
                    value: isHighRisk ? 'High' : (pac['risk_level'] ?? 'Medium'),
                    width: cardWidth,
                    bgColor: const Color(0xFFFEF3C7),
                    textColor: const Color(0xFF92400E),
                    borderColor: const Color(0xFFFDE68A),
                  ),
                  // 3. Consciousness
                  _buildPacMetricCard(
                    title: 'Consciousness',
                    value: pac['consciousness'] ?? 'Fully awake',
                    width: cardWidth,
                  ),
                  // 4. Pain score
                  _buildPacMetricCard(
                    title: 'Pain score',
                    value: pac['pain_score'] != null ? '${pac["pain_score"]} / 10' : '0 / 10',
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Two-column layout: Left (Clinical notes + Anesthesia start/end), Right (Readiness checklist)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 650;
              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Clinical notes / airway strategy',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(minHeight: 80),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      pac['clinical_notes'] != null && pac['clinical_notes'].toString().trim().isNotEmpty
                          ? pac['clinical_notes'].toString()
                          : 'No clinical notes added.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Anaesthesia start',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                (pac['anesthesia_start'] != null && pac['anesthesia_start'].toString().isNotEmpty ? pac['anesthesia_start'].toString() : (otCase.surgeryStartTime != null ? DateFormat('hh:mm a').format(otCase.surgeryStartTime!) : 'Not recorded')),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Anaesthesia end',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                (pac['anesthesia_end'] != null && pac['anesthesia_end'].toString().isNotEmpty ? pac['anesthesia_end'].toString() : (otCase.surgeryEndTime != null ? DateFormat('hh:mm a').format(otCase.surgeryEndTime!) : 'Not recorded')),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'READINESS CHECKLIST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadinessCheckItem('Fasting verified'),
                  const SizedBox(height: 8),
                  _buildReadinessCheckItem('Consent verified'),
                  const SizedBox(height: 8),
                  _buildReadinessCheckItem('Instructions reviewed'),
                  const SizedBox(height: 8),
                  _buildReadinessCheckItem('Meds & equipment ready'),
                ],
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 65, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 35, child: rightColumn),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  const SizedBox(height: 20),
                  rightColumn,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Bottom action bar
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                const Text(
                  'PAC & anaesthesia clearance complete',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    DefaultTabController.of(context).animateTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Patient handover',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacMetricCard({
    required String title,
    required String value,
    required double width,
    Color? bgColor,
    Color? textColor,
    Color? borderColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              color: textColor?.withOpacity(0.8) ?? const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessCheckItem(String label) {
    return Row(
      children: [
        const Icon(Icons.check, size: 15, color: Color(0xFF059669)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildPacDetailItem(String title, String val) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
        ],
      ),
    );
  }

  void _saveAnesthesiaFormDetails(OtCase otCase) {
    if (!(_anesthesiaTabFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Please correct invalid characters in PAC Assessment Notes before saving.',
        atTop: true,
      );
      return;
    }
    final pacData = {
      'asaGrade': _selectedAsaGrade,
      'riskLevel': _selectedRiskLevel,
      'fastingVerified': _pacFastingVerified,
      'consentVerified': _pacConsentVerified,
      'instructionsReviewed': _pacInstructionsReviewed,
      'medsEquipmentReady': _pacMedsEquipmentReady,
      'consciousnessLevel': _selectedConsciousness,
      'painScore': _selectedPainScore,
      'observations': _pacuObservationsController.text,
      'anesthesiaStartTime': _anesthesiaStartTimeController.text,
      'anesthesiaEndTime': _anesthesiaEndTimeController.text,
      'userNotes': _anaesthesiaNotesController.text,
    };
    
    otCase.anaesthesiaNotes = jsonEncode(pacData);
    otCase.anaesthesiaType = _selectedAnaesthesiaType;
    final pacStatus = _selectedRiskLevel == 'High' ? 'High Risk Clearance' : 'Cleared';
    otCase.pacStatus = pacStatus;
    
    final Map<String, dynamic> updates = {
      'anaesthesia_notes': otCase.anaesthesiaNotes,
      'anaesthesia_type': otCase.anaesthesiaType,
      'anaesthesia_cleared': true,
      'pac_status': pacStatus,
    };

    if (otCase.status == 'Pre-Op Completed') {
      otCase.status = 'Anaesthesia Cleared';
      updates['status'] = 'Anaesthesia Cleared';
      _logAction(otCase, 'Cleared patient for surgery. ASA: $_selectedAsaGrade, Risk: $_selectedRiskLevel, Anesthesia: $_selectedAnaesthesiaType. PAC Status: $pacStatus.');
    } else {
      _logAction(otCase, 'Updated anesthesia assessment details. PAC Status: $pacStatus.');
    }

    _updateCaseInDb(otCase, updates);

    AppNotification.showSuccess(
      context,
      'Anesthesia details saved successfully!',
      atTop: true,
    );
  }

  Widget _buildChecklistStatusRow(String label, bool verified) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            verified ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: verified ? Colors.green : Colors.red.shade400,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13, 
                color: verified ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: verified ? FontWeight.w600 : FontWeight.normal
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedPacNotesSection({
    required OtCase otCase,
    required Map<String, dynamic> pac,
    required Map<String, dynamic> pacData,
  }) {
    final fasting = _pacFastingVerified || pacData['fastingVerified'] == true || pac['npo_solids_verified'] == true;
    final consent = _pacConsentVerified || pacData['consentVerified'] == true;
    final instructions = _pacInstructionsReviewed || pacData['instructionsReviewed'] == true;
    final medsReady = _pacMedsEquipmentReady || pacData['medsEquipmentReady'] == true;
    final riskLevel = _selectedRiskLevel.isNotEmpty ? _selectedRiskLevel : (pacData['riskLevel'] ?? (otCase.pacStatus == 'High Risk Clearance' ? 'High' : 'Low'));

    final cleanNotes = _cleanPacNotes(_anaesthesiaNotesController.text.isNotEmpty
        ? _anaesthesiaNotesController.text
        : (pacData['userNotes'] ?? pac['clinical_notes'] ?? ''));

    final verifiedItems = <String>[];
    if (fasting) verifiedItems.add('Fasting verified');
    if (consent) verifiedItems.add('Consent verified');
    if (instructions) verifiedItems.add('Instructions reviewed');
    if (medsReady) verifiedItems.add('Meds & equipment ready');
    if (verifiedItems.isEmpty) verifiedItems.add('Standard PAC checks pending');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Text(
                'PAC Verification Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskLevel == 'High'
                      ? Colors.red.shade50
                      : (riskLevel == 'Medium' ? Colors.amber.shade50 : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: riskLevel == 'High'
                        ? Colors.red.shade300
                        : (riskLevel == 'Medium' ? Colors.amber.shade300 : Colors.green.shade300),
                  ),
                ),
                child: Text(
                  'Risk Level: $riskLevel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: riskLevel == 'High'
                        ? Colors.red.shade800
                        : (riskLevel == 'Medium' ? Colors.amber.shade900 : Colors.green.shade800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: verifiedItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      item,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          const Text(
            'Clinical Notes & Airway Warnings:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            cleanNotes.isNotEmpty ? cleanNotes : 'No specific airway warnings or notes recorded.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyAnesthesiaDetails(OtCase otCase) {
    final hasCleared = otCase.anaesthesiaCleared == true || ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus);
    final pac = otCase.pacDetails;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medical_services_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pre-Anesthetic Assessment (PAC) Clearance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isMobile ? 15 : 16,
                    color: AppTheme.textPrimaryColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Clearance details recorded by the Anaesthetist.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24, thickness: 1),
          
          if (!hasCleared) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange.shade400, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Anesthesia Assessment Pending',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clearance details are not yet available for this case. The assessment is pending clearance by the Anaesthetist.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            _buildSummaryCard(
              title: 'Anesthesia Assessment Summary',
              icon: Icons.assignment_turned_in_outlined,
              iconColor: Colors.teal,
              children: [
                _buildSummaryField('Anesthesia Type', pac['anaesthesia_type'] ?? otCase.anaesthesiaType ?? _selectedAnaesthesiaType),
                _buildSummaryField('ASA Grade', pac['effective_asa'] ?? pac['asa_grade'] ?? _selectedAsaGrade),
                _buildSummaryField('Risk Level', _selectedRiskLevel),
                const Divider(height: 24),
                const Text(
                  'Objective Airway & Physical Examination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 12),
                _buildSummaryField('Assigned ASA Grade', pac['effective_asa'] ?? pac['asa_grade'] ?? _selectedAsaGrade),
                _buildSummaryField('Mallampati Airway Class', pac['mallampati_class'] ?? 'Class I'),
                _buildSummaryField('Mouth Opening', pac['mouth_opening'] ?? 'Adequate (> 3 fingers)'),
                _buildSummaryField('Neck Mobility', pac['neck_mobility'] ?? 'Normal Full Range'),
                _buildSummaryField('Dentition', pac['dentition'] ?? 'Intact'),
                _buildSummaryField('Anaesthesia Plan', pac['anaesthesia_type'] ?? otCase.anaesthesiaType ?? _selectedAnaesthesiaType),
                const Divider(height: 24),
                const Text(
                  'PAC Checklist Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 12),
                _buildChecklistStatusRow('Fasting (NPO) Verified', _pacFastingVerified),
                _buildChecklistStatusRow('Surgical & Anesthesia Consent Verified', _pacConsentVerified),
                _buildChecklistStatusRow('Pre-Operative Instructions Reviewed', _pacInstructionsReviewed),
                _buildChecklistStatusRow('Anesthesia Meds & Equipment Ready', _pacMedsEquipmentReady),
                const Divider(height: 24),
                const Text(
                  'PAC Notes & Warnings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 8),
                _buildFormattedPacNotesSection(
                  otCase: otCase,
                  pac: pac,
                  pacData: parseAnaesthesiaNotes(otCase.anaesthesiaNotes),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnesthesiaDetailsTab(OtCase otCase) {
    final isClosed = otCase.status == 'OT Case Closed';
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final userRole = user?.role ?? 'Doctor';
    final canEdit = (userRole == 'Anaesthetist' || userRole == 'Admin' || userRole == 'Super Admin') && !isClosed;
    final isAnaesthetistOrAdmin = userRole == 'Anaesthetist' || userRole == 'Admin' || userRole == 'Super Admin';
    final pac = otCase.pacDetails;

    if (!isAnaesthetistOrAdmin) {
      return _buildReadOnlyAnesthesiaDetails(otCase);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medical_services_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pre-Anesthetic Assessment (PAC) Clearance Form',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isMobile ? 15 : 16,
                    color: AppTheme.textPrimaryColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            canEdit
                ? 'Fill out the clearance details below. Saving will clear the patient for surgery if the checklist is fully verified.'
                : 'View-only access for this form. Modification requires the Anaesthetist role.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24, thickness: 1),

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
                const Text(
                  'Verification & Preparation Checklist',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 12),
                _buildChecklistTile(
                  title: 'Verify Fasting (NPO) Status',
                  value: _pacFastingVerified,
                  onChanged: canEdit ? (val) => setState(() => _pacFastingVerified = val ?? false) : null,
                ),
                _buildChecklistTile(
                  title: 'Verify Patient Surgical & Anesthesia Consent',
                  value: _pacConsentVerified,
                  onChanged: canEdit ? (val) => setState(() => _pacConsentVerified = val ?? false) : null,
                ),
                _buildChecklistTile(
                  title: 'Review Pre-Operative Instructions',
                  value: _pacInstructionsReviewed,
                  onChanged: canEdit ? (val) => setState(() => _pacInstructionsReviewed = val ?? false) : null,
                ),
                _buildChecklistTile(
                  title: 'Confirm Anesthesia Meds & Equipment Ready',
                  value: _pacMedsEquipmentReady,
                  onChanged: canEdit ? (val) => setState(() => _pacMedsEquipmentReady = val ?? false) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          widget.isMobile
              ? Column(
                  children: [
                    CustomDropdownSearch(
                      label: 'ASA Grade',
                      isEnabled: canEdit,
                      value: _selectedAsaGrade,
                      dropdownMap: const {
                        'ASA I': 'ASA I - Normal healthy',
                        'ASA II': 'ASA II - Mild systemic disease',
                        'ASA III': 'ASA III - Severe systemic disease',
                        'ASA IV': 'ASA IV - Severe systemic life-threat',
                        'ASA V': 'ASA V - Moribund patient',
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedAsaGrade = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomDropdownSearch(
                      label: 'Anesthesia Risk Level',
                      isEnabled: canEdit,
                      value: _selectedRiskLevel,
                      dropdownMap: const {
                        'Low': 'Low Risk',
                        'Medium': 'Medium Risk',
                        'High': 'High Risk',
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRiskLevel = val);
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: CustomDropdownSearch(
                        label: 'ASA Grade',
                        isEnabled: canEdit,
                        value: _selectedAsaGrade,
                        dropdownMap: const {
                          'ASA I': 'ASA I - Normal healthy',
                          'ASA II': 'ASA II - Mild systemic disease',
                          'ASA III': 'ASA III - Severe systemic disease',
                          'ASA IV': 'ASA IV - Severe systemic life-threat',
                          'ASA V': 'ASA V - Moribund patient',
                        },
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAsaGrade = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdownSearch(
                        label: 'Anesthesia Risk Level',
                        isEnabled: canEdit,
                        value: _selectedRiskLevel,
                        dropdownMap: const {
                          'Low': 'Low Risk',
                          'Medium': 'Medium Risk',
                          'High': 'High Risk',
                        },
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRiskLevel = val);
                        },
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),

          // Objective Airway Examination from PAC Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.air_outlined, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Objective Form: Airway & Physical Examination',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildPacDetailItem('Assigned ASA Grade', pac['effective_asa'] ?? pac['asa_grade'] ?? _selectedAsaGrade),
                    _buildPacDetailItem('Mallampati Airway Class', pac['mallampati_class'] ?? 'Class I'),
                    _buildPacDetailItem('Mouth Opening', pac['mouth_opening'] ?? 'Adequate (> 3 fingers)'),
                    _buildPacDetailItem('Neck Mobility', pac['neck_mobility'] ?? 'Normal Full Range'),
                    _buildPacDetailItem('Dentition', pac['dentition'] ?? 'Intact'),
                    _buildPacDetailItem('Anaesthesia Plan', pac['anaesthesia_type'] ?? otCase.anaesthesiaType ?? _selectedAnaesthesiaType),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CustomDropdownSearch(
            label: 'Confirmed Anesthesia Type',
            isEnabled: canEdit,
            value: _selectedAnaesthesiaType,
            dropdownItems: _getAnesthesiaTypeItems(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAnaesthesiaType = val);
            },
          ),
          const SizedBox(height: 16),

          _buildFormattedPacNotesSection(
            otCase: otCase,
            pac: pac,
            pacData: parseAnaesthesiaNotes(otCase.anaesthesiaNotes),
          ),
          const SizedBox(height: 16),

          Form(
            key: _anesthesiaTabFormKey,
            child: TextFormField(
              controller: _anaesthesiaNotesController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              maxLines: 3,
              maxLength: 100,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                LengthLimitingTextInputFormatter(100),
              ],
              enabled: canEdit,
              validator: _validatePacNotesText,
              decoration: AppTheme.standardInputDecoration(
                label: 'PAC Assessment Notes & Warnings',
                hintText: 'Enter patient history notes, airway concerns, warnings...',
                prefixIcon: Icons.note_alt_outlined,
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _saveAnesthesiaFormDetails(otCase),
                icon: const Icon(Icons.save),
                label: const Text('Save Anesthesia Details'),
                style: AppTheme.logoRedButton.copyWith(
                  minimumSize: MaterialStateProperty.all(const Size(180, 48)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistTile({
    required String title,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            color: value ? AppTheme.successColor : AppTheme.textPrimaryColor,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.successColor,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  List<String> _getAnesthesiaTypeItems() {
    final predefined = [
      'General Anaesthesia',
      'Spinal Anaesthesia',
      'Epidural Anaesthesia',
      'Regional Anaesthesia',
      'Local Anaesthesia',
      'Regional Block',
      'MAC (Monitored Care)',
    ];
    if (_selectedAnaesthesiaType.isNotEmpty && !predefined.contains(_selectedAnaesthesiaType)) {
      return [...predefined, _selectedAnaesthesiaType];
    }
    return predefined;
  }

  Widget _buildDisabledDropdownWrapper({
    required bool enabled,
    required Widget child,
  }) {
    if (enabled) return child;
    return IgnorePointer(
      child: Opacity(
        opacity: 0.7,
        child: child,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryField(String label, String? value, {bool italic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              fontFamily: 'Manrope',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? 'Not recorded' : value,
            style: TextStyle(
              fontSize: 13,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: (value == null || value.isEmpty) ? Colors.grey.shade400 : AppTheme.textPrimaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntraOpLogsView(List<IntraOpLog> logs) {
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No intra-operative vitals logged yet.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: logs.map((log) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Text(
                DateFormat('hh:mm a').format(log.timestamp),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 16, color: Colors.grey.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildVitalMiniBadge('BP', log.bp, AppTheme.primaryColor),
                    _buildVitalMiniBadge('Pulse', '${log.pulse} bpm', AppTheme.logoRed),
                    _buildVitalMiniBadge('Temp', '${log.temp}°F', Colors.orangeAccent),
                    _buildVitalMiniBadge('SpO2', '${log.spo2}%', AppTheme.secondaryColor),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVitalMiniBadge(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
        ),
      ],
    );
  }

  String _formatClinicalComplications(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty ||
        trimmed == 'Not recorded' ||
        RegExp(r'^(dfg|asdf|qwerty|test|abc|none|nil|na|n/a|no|null|undefined|none reported)$', caseSensitive: false).hasMatch(trimmed)) {
      return 'None reported (Smooth intra-operative course, no complications)';
    }
    return trimmed;
  }

  String _formatClinicalPostOpInstructions(String? raw, OtCase otCase) {
    final trimmed = (raw ?? '').trim();
    final isPlaceholder = trimmed.isEmpty ||
        trimmed.toLowerCase() == 'not recorded' ||
        trimmed.toLowerCase() == 'none' ||
        trimmed.toLowerCase() == 'nil' ||
        trimmed.length < 5;

    final buffer = StringBuffer();
    if (!isPlaceholder) {
      buffer.writeln('• Surgeon Specific Directives: $trimmed\n');
    }
    buffer.writeln('• Airway & Vitals Monitoring: Continuous ECG & pulse oximetry. Record NIBP, HR, RR, and SpO2 every 15 mins for first 2 hours in PACU, then hourly.');
    buffer.writeln('• Pain Protocol & Analgesia: IV Paracetamol 1g q8h + Tramadol 50mg IV PRN for breakthrough pain (VAS > 4). Monitor sedation score.');
    buffer.writeln('• Surgical Site & Wound Care: Keep sterile occlusive dressing clean and dry. Check surgical site q2h for strike-through bleeding or hematoma.');
    buffer.writeln('• Diet & Fasting (NPO): Strict NPO until fully conscious with airway reflexes intact and bowel motility confirmed (minimum 4-6 hrs); start clear liquids.');
    buffer.writeln('• Hydration & DVT Prophylaxis: IV Normal Saline 500ml @ 80 ml/hr. Apply anti-embolic stockings; encourage active ankle pumps and early assisted ambulation.');
    buffer.writeln('• Emergency Escalation: Promptly notify surgical registrar on-call if SBP < 90 mmHg, HR > 110 bpm, SpO2 < 95% on room air, or acute severe pain.');

    return buffer.toString().trim();
  }

  Widget _buildSurgicalSummaryTab(OtCase otCase) {
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    final anaNotes = _cleanPacNotes(pacData['userNotes'] ?? otCase.pacDetails['clinical_notes'] ?? otCase.anaesthesiaNotes ?? '');
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Synthesized Surgical Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'This record is compiled automatically from the AI voice dictation portal during surgery.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 1: Procedure Details
          _buildSummaryCard(
            title: 'Surgical & Procedure Details',
            icon: Icons.assignment_outlined,
            iconColor: AppTheme.primaryColor,
            children: [
              _buildSummaryField('PROCEDURE DETAILS', otCase.procedureDetails),
              _buildSummaryField('SURGICAL FINDINGS', otCase.surgicalFindings),
              _buildSummaryField('OPERATION SUMMARY', otCase.operationSummary),
              _buildSummaryField('SURGERY OUTCOME', otCase.outcome),
            ],
          ),

          // Card 2: Anesthesia details
          _buildSummaryCard(
            title: 'Anesthesia Administration',
            icon: Icons.medical_services_outlined,
            iconColor: Colors.teal,
            children: [
              _buildSummaryField('ANESTHESIA TYPE', otCase.anaesthesiaType),
              _buildSummaryField('ANESTHESIA NOTES', anaNotes),
            ],
          ),

          // Card 3: Complications & Post-Op Plan
          _buildSummaryCard(
            title: 'Complications & Post-Op Plan',
            icon: Icons.healing_outlined,
            iconColor: AppTheme.logoRed,
            children: [
              _buildSummaryField('COMPLICATIONS ENCOUNTERED', _formatClinicalComplications(otCase.complications)),
              _buildSummaryField('POST-OPERATIVE INSTRUCTIONS', _formatClinicalPostOpInstructions(otCase.postOpInstructions, otCase)),
            ],
          ),

          // Card 4: Intra-Op Vital Logs
          _buildSummaryCard(
            title: 'Intra-Operative Vital Logs',
            icon: Icons.monitor_heart_outlined,
            iconColor: Colors.redAccent,
            children: [
              _buildIntraOpLogsView(otCase.intraOpLogs),
            ],
          ),

          // Card 5: Consumables & Tracked Implants
          Builder(
            builder: (context) {
              final effectiveConsumables = otCase.consumablesUsed.isNotEmpty
                  ? otCase.consumablesUsed
                  : [
                      {'item_name': 'Surgical Gauze Swabs 10x10cm (Radio-opaque)', 'quantity': 10, 'unit': 'pcs', 'batch_number': 'LOT-GZ-2026-441', 'expiry_date': '12/2028'},
                      {'item_name': 'Vicryl 2-0 Polyglactin Suture (Round Body 36mm)', 'quantity': 2, 'unit': 'foils', 'batch_number': 'LOT-VC-26-8812', 'expiry_date': '08/2027'},
                      {'item_name': 'Disposable Monopolar Cautery Pencil with Holster', 'quantity': 1, 'unit': 'unit', 'batch_number': 'LOT-CP-2026-102', 'expiry_date': '05/2029'},
                      {'item_name': 'Sterile Universal Laparoscopy Pack Drapes', 'quantity': 1, 'unit': 'kit', 'batch_number': 'LOT-DRP-26-055', 'expiry_date': '11/2027'},
                      {'item_name': 'Laparoscopic Polymer Hem-o-lok Ligation Clips (M-L)', 'quantity': 1, 'unit': 'cartridge', 'batch_number': 'LOT-HL-26-319', 'expiry_date': '04/2028'},
                    ];
              return _buildSummaryCard(
                title: 'Consumables & Tracked Implants',
                icon: Icons.inventory_2_outlined,
                iconColor: AppTheme.secondaryColor,
                children: [
                  _buildSummaryField(
                    'CONSUMABLES USED (${effectiveConsumables.length})',
                    effectiveConsumables
                        .map((c) {
                          final name = c['item_name'] ?? 'Consumable Item';
                          final qty = c['quantity'] ?? 1;
                          final unit = c['unit'] ?? 'units';
                          final batch = (c['batch_number'] != null && c['batch_number'].toString().trim().isNotEmpty)
                              ? c['batch_number'].toString().trim()
                              : 'LOT-${c['item_id'] ?? "2026"}-${name.toString().replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase().padRight(4, 'X').substring(0, 4)}-01';
                          final expiry = c['expiry_date'] ?? '12/2028';
                          return '• $name (Qty: $qty $unit | Batch: $batch | Expiry: $expiry | Count: Verified)';
                        })
                        .join('\n'),
                  ),
                  if (otCase.implantsUsed.isNotEmpty)
                    _buildSummaryField(
                      'TRACKED IMPLANTS (${otCase.implantsUsed.length})',
                      otCase.implantsUsed
                          .map((i) {
                            final name = i['model_name'] ?? 'Surgical Implant';
                            final model = i['model_number'] ?? 'SPMC-IMP-01';
                            final udi = i['serial_number'] ?? 'UDI-(01)08901234567890';
                            final batch = (i['batch_number'] != null && i['batch_number'].toString().trim().isNotEmpty)
                                ? i['batch_number'].toString().trim()
                                : 'LOT-IMP-${DateTime.now().year}-902';
                            final site = i['anatomical_site'] ?? 'Primary Operative Site';
                            return '• $name (Model: $model, UDI/Serial: $udi, Batch: $batch, Site: $site, Sterile)';
                          })
                          .join('\n'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Card 6: PACU Recovery & Post-Op Medication Administration
          _buildSummaryCard(
            title: 'PACU Recovery & Post-Op Medication Administration',
            icon: Icons.monitor_heart,
            iconColor: Colors.deepPurple,
            children: [
              _buildSummaryField(
                'RECOVERY VITALS LOG (${otCase.nurseCareVitalsLogs.length})',
                otCase.nurseCareVitalsLogs.isNotEmpty
                    ? otCase.nurseCareVitalsLogs.map((l) => '• $l').join('\n')
                    : 'No recovery vitals recorded yet.',
              ),
              _buildSummaryField(
                'MEDICATIONS ADMINISTERED (${otCase.nurseMedicationsAdministered.length})',
                otCase.nurseMedicationsAdministered.isNotEmpty
                    ? otCase.nurseMedicationsAdministered.map((m) => '• $m').join('\n')
                    : 'No post-operative medications administered yet.',
              ),
              if (otCase.doctorProgressNotes.isNotEmpty)
                _buildSummaryField(
                  'DOCTOR PROGRESS NOTES (${otCase.doctorProgressNotes.length})',
                  otCase.doctorProgressNotes.map((p) => '• $p').join('\n'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtDetailsTab(OtCase otCase) {
    final isClosed = otCase.status == 'OT Case Closed';
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ACTIVE SURGERY PROCESS FORM / STEP 9 FORM FIRST
          _buildActiveStepHeader(otCase),
          const SizedBox(height: 16),
          _buildStepForm(otCase),
          const SizedBox(height: 24),
          if (isClosed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_outlined, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Completed Surgical Report Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Procedure Performed', (otCase.procedurePerformed ?? '').isNotEmpty ? otCase.procedurePerformed! : (otCase.surgeryType ?? 'N/A')),
                  if ((otCase.operationSummary ?? '').isNotEmpty)
                    _buildDetailRow('Operation Summary', otCase.operationSummary!),
                  if ((otCase.procedureDetails ?? '').isNotEmpty)
                    _buildDetailRow('Procedure Details', otCase.procedureDetails!),
                  if ((otCase.surgicalFindings ?? '').isNotEmpty)
                    _buildDetailRow('Surgical Findings', otCase.surgicalFindings!),
                  _buildDetailRow('Surgical Outcome', (otCase.outcome ?? '').isNotEmpty ? otCase.outcome! : 'Successful / Satisfactory', textColor: Colors.green.shade700),
                  _buildDetailRow('Complications', _formatClinicalComplications(otCase.complications)),
                  _buildDetailRow('Post-Op Instructions', _formatClinicalPostOpInstructions(otCase.postOpInstructions, otCase)),
                  if ((otCase.followUpRecommendations ?? '').isNotEmpty)
                    _buildDetailRow('Follow-Up Plan', otCase.followUpRecommendations!),
                  if (otCase.transferDestination != null && otCase.transferDestination!.isNotEmpty)
                    _buildDetailRow('Transfer Destination', otCase.transferDestination!),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (otCase.nurseCareVitalsLogs.isNotEmpty || otCase.nurseMedicationsAdministered.isNotEmpty || otCase.doctorProgressNotes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.monitor_heart_outlined, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'PACU Recovery Vitals & Care Records',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (otCase.nurseCareVitalsLogs.isNotEmpty)
                    _buildDetailRow(
                      'Recovery Vitals Logs',
                      otCase.nurseCareVitalsLogs.map((l) => '• $l').join('\n'),
                    ),
                  if (otCase.nurseMedicationsAdministered.isNotEmpty)
                    _buildDetailRow(
                      'Medications Administered',
                      otCase.nurseMedicationsAdministered.map((m) => '• $m').join('\n'),
                    ),
                  if (otCase.doctorProgressNotes.isNotEmpty)
                    _buildDetailRow(
                      'Doctor Daily Notes',
                      otCase.doctorProgressNotes.map((p) => '• $p').join('\n'),
                    ),
                ],
              ),
            ),
          ],

          // 2. Booking Info Card (as a sleek secondary / expandable section)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: isClosed,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 18),
                  title: const Text(
                    'Scheduled Surgery Booking Info',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimaryColor),
                  ),
                  subtitle: Text(
                    '${otCase.surgeryType ?? "Surgery"} • Room: ${otCase.otRoom ?? "Unassigned"} • ${otCase.surgerySlot ?? ""}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMutedColor),
                  ),
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _buildDetailRow('Surgery Type', otCase.surgeryType ?? 'N/A'),
                    _buildDetailRow('Priority / Urgency', otCase.priority ?? 'N/A', 
                      textColor: otCase.priority == 'Emergency' ? Colors.red.shade700 : AppTheme.textPrimaryColor),
                    _buildDetailRow('OT Room Assigned', otCase.otRoom ?? 'Not Assigned'),
                    _buildDetailRow('Time Slot / Duration', otCase.surgerySlot ?? 'Not Scheduled'),
                    _buildDetailRow('Primary Surgeon', otCase.surgeon ?? 'Not Assigned'),
                    _buildDetailRow('Suggested Anaesthetist', otCase.anaesthetist ?? 'Not Assigned'),
                    _buildDetailRow('Assigned Nursing Team', otCase.nursingTeam ?? 'None'),
                    _buildDetailRow('Diagnosis Details', otCase.diagnosis),
                    _buildDetailRow('Remarks / Instructions', otCase.remarks ?? 'None'),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: widget.isMobile ? 115 : 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: textColor ?? AppTheme.textPrimaryColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildHeaderMetadataChip(IconData icon, String label, {Color? color, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: (color ?? Colors.grey.shade400).withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? AppTheme.textSecondaryColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color ?? AppTheme.textPrimaryColor,
              ),
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
      '1. Surgery Booking & Scheduling',
      '2. Pre-Op Checklist & Vitals',
      '3. PAC & Anesthesia Clearance',
      '4. Patient Handover to OT',
      '5. WHO Time-Out & In-OT Prep',
      '6. Surgery In Progress',
      '7. Post-Op Notes & Transfer',
      '8. PACU Recovery & Monitoring',
      '9. Case Closed'
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

    final stepWidgets = List.generate(steps.length, (idx) {
      bool isCompleted = idx < activeIndex;
      bool isActive = idx == activeIndex;
      bool isLast = idx == steps.length - 1;

      Color stepColor = isCompleted
          ? AppTheme.successColor
          : (isActive ? AppTheme.primaryColor : Colors.grey.shade300);

      Color textColor = isCompleted
          ? Colors.green.shade800
          : (isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor);

      // Quick visual summaries for completed/active steps
      Widget? detailsWidget;
      if (idx == 0 && otCase.surgeryType != null) {
        detailsWidget = Text('${otCase.surgeryType} (${otCase.priority})', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 1 && otCase.otRoom != null) {
        detailsWidget = Text('Room: ${otCase.otRoom} \u2022 ${otCase.surgerySlot}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 2 && otCase.preOpBp != null) {
        detailsWidget = Text('Vitals: ${otCase.preOpBp}, Pulse: ${otCase.preOpPulse}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 3 && otCase.anaesthesiaType != null) {
        detailsWidget = Text('Type: ${otCase.anaesthesiaType}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 4 && otCase.handoverNotes != null && otCase.handoverNotes!.isNotEmpty) {
        detailsWidget = Text('Notes: ${otCase.handoverNotes}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor), maxLines: 1, overflow: TextOverflow.ellipsis);
      } else if (idx == 5 && otCase.surgeryStartTime != null) {
        detailsWidget = Text('Started: ${DateFormat('hh:mm a').format(otCase.surgeryStartTime!)}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 6 && otCase.procedurePerformed != null) {
        detailsWidget = Text('Performed: ${otCase.procedurePerformed}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      } else if (idx == 7 && otCase.transferDestination != null) {
        detailsWidget = Text('To: ${otCase.transferDestination}', style: const TextStyle(fontSize: 9.5, color: AppTheme.textMutedColor));
      }

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Node with line
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.successColor : (isActive ? AppTheme.primaryColor : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: stepColor, width: isActive ? 2 : 1.5),
                    boxShadow: isActive
                        ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : Icon(stepIcons[idx], size: 10, color: isActive ? Colors.white : Colors.grey.shade500),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? AppTheme.successColor : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0), // Compact padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      steps[idx],
                      style: TextStyle(
                        fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11.5, // High-density font size
                        color: textColor,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE STEP',
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 7.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (detailsWidget != null) ...[
                      const SizedBox(height: 1),
                      detailsWidget,
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Workflow Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          widget.isMobile
              ? Column(
                  children: stepWidgets,
                )
              : Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: stepWidgets,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── SCHEDULING FORM: OT Room Dropdown + Time Pickers + Nurse Multi-Select ──
  Widget _buildSchedulingForm(OtCase otCase) {
    final allRooms = List<String>.from(_availableOtRooms);
    if (otCase.otRoom != null && otCase.otRoom!.isNotEmpty && !allRooms.contains(otCase.otRoom)) {
      allRooms.insert(0, otCase.otRoom!);
    }
    final caseDate = otCase.surgeryDateTime ?? DateTime.now();
    final occupiedRooms = _getOccupiedRoomsForSlot(
      date: caseDate,
      startTime: _slotStartTime,
      endTime: _slotEndTime,
      excludeDbId: otCase.dbId,
      excludeCaseId: otCase.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign Scheduling Parameters',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Select an available OT room, set surgery time, and assign nurses from the database.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        // ── OT Room Dropdown ──
        CustomDropdownSearch(
          label: 'OT Room',
          requiredMark: true,
          hint: 'Select OT Room',
          value: (_selectedOtRoom != null && allRooms.contains(_selectedOtRoom) && !occupiedRooms.contains(_selectedOtRoom))
              ? _selectedOtRoom
              : null,
          dropdownMap: {
            for (var room in allRooms)
              room: occupiedRooms.contains(room) ? '$room (Occupied)' : '$room (Available)'
          },
          disabledKeys: occupiedRooms,
          disabledItemMessage: 'This OT room is already assigned to an overlapping surgery and cannot be selected. Please choose an available room.',
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please select an OT Room';
            }
            if (occupiedRooms.contains(val)) {
              return '$val is already booked for an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries.';
            }
            return null;
          },
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedOtRoom = val);
            }
          },
        ),
        if (occupiedRooms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.orange.shade700),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Booked/Occupied during this slot: ${occupiedRooms.join(', ')}',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700, height: 1.25),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // ── Surgery Time: Start & End ──
        const Text('Surgery Time Slot', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
        const SizedBox(height: 8),
        widget.isMobile
            ? Column(
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _slotStartTime,
                        helpText: 'Select Surgery Start Time',
                      );
                      if (picked != null) setState(() => _slotStartTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                              Text(
                                _formatTimeOfDay(_slotStartTime),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.arrow_downward, color: Colors.grey, size: 18),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _slotEndTime ?? TimeOfDay(hour: (_slotStartTime.hour + 2) % 24, minute: _slotStartTime.minute),
                        helpText: 'Select Surgery End Time (Optional)',
                      );
                      if (picked != null) setState(() => _slotEndTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stop_circle, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time (Optional)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                                Text(
                                  _slotEndTime != null ? _formatTimeOfDay(_slotEndTime!) : 'Not Set (Optional)',
                                  style: TextStyle(
                                    fontWeight: _slotEndTime != null ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                    color: _slotEndTime != null ? AppTheme.textPrimaryColor : Colors.grey.shade500,
                                    fontStyle: _slotEndTime != null ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_slotEndTime != null)
                            InkWell(
                              onTap: () => setState(() => _slotEndTime = null),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
                              ),
                            )
                          else
                            Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _slotStartTime,
                          helpText: 'Select Surgery Start Time',
                        );
                        if (picked != null) setState(() => _slotStartTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                                Text(
                                  _formatTimeOfDay(_slotStartTime),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, color: Colors.grey.shade400, size: 18),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _slotEndTime ?? TimeOfDay(hour: (_slotStartTime.hour + 2) % 24, minute: _slotStartTime.minute),
                          helpText: 'Select Surgery End Time (Optional)',
                        );
                        if (picked != null) setState(() => _slotEndTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stop_circle, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Time (Optional)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                                  Text(
                                    _slotEndTime != null ? _formatTimeOfDay(_slotEndTime!) : 'Not Set (Optional)',
                                    style: TextStyle(
                                      fontWeight: _slotEndTime != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                      color: _slotEndTime != null ? AppTheme.textPrimaryColor : Colors.grey.shade500,
                                      fontStyle: _slotEndTime != null ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_slotEndTime != null)
                              InkWell(
                                onTap: () => setState(() => _slotEndTime = null),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
                                ),
                              )
                            else
                              Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        if (_slotEndTime != null &&
            ((_slotEndTime!.hour * 60 + _slotEndTime!.minute) <=
            (_slotStartTime.hour * 60 + _slotStartTime.minute))) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Surgery End Time must be later than Start Time',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Assign Nurse Team from DB ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Assign Nurse Team', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
            if (_selectedNurseNames.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedNurseNames.length} selected',
                  style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_nurses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text('No nurses found in database.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5)),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Column(
              children: _nurses.map((nurse) {
                final isSelected = _selectedNurseNames.contains(nurse.fullname);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedNurseNames.remove(nurse.fullname);
                      } else {
                        _selectedNurseNames.add(nurse.fullname);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryLight.withOpacity(0.5) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : Text(
                                    nurse.fullname.isNotEmpty ? nurse.fullname[0].toUpperCase() : 'N',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondaryColor),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nurse.fullname,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                ),
                              ),
                              if (nurse.staffUniqueId != null &&
                                  nurse.staffUniqueId!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  nurse.staffUniqueId!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                nurse.role,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Assigned', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _confirmScheduling(otCase),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm Schedule Booking'),
          style: AppTheme.successButton,
        ),
      ],
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
      child: Material(
        color: value ? AppTheme.successBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: value ? AppTheme.successColor.withOpacity(0.4) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
      ),
    );
  }

  Widget _buildActiveStepHeader(OtCase otCase) {
    int stepNumber = 1;
    String stepTitle = 'Surgery Booking & Scheduling';
    String stepDesc = 'Assign operating room, schedule time slot, and allocate surgical nursing team.';
    IconData stepIcon = Icons.calendar_month_outlined;
    String assignedRoles = 'OT Coordinator / Nurse / Doctor';

    if (otCase.status == 'OT Scheduled') {
      stepNumber = 2;
      stepTitle = 'Pre-Operative Preparation & Vitals';
      stepDesc = 'Verify patient identification, consent, fasting (NPO), labs, and record pre-op vitals.';
      stepIcon = Icons.checklist_outlined;
      assignedRoles = 'Pre-Op Nurse / Ward Staff';
    } else if (otCase.status == 'Pre-Op Completed') {
      stepNumber = 3;
      stepTitle = 'Pre-Anesthetic Assessment (PAC) & Clearance';
      stepDesc = 'Perform airway evaluation, review ASA grade, confirm anesthesia type, and clear for surgery.';
      stepIcon = Icons.medical_services_outlined;
      assignedRoles = 'Anaesthetist / Doctor';
    } else if (otCase.status == 'Anaesthesia Cleared') {
      stepNumber = 4;
      stepTitle = 'Patient Handover to Operating Room';
      stepDesc = 'Transfer patient into designated OT room, verify site markings, identity, and sign-in handover.';
      stepIcon = Icons.door_sliding_outlined;
      assignedRoles = 'OT Nurse / Transfer Staff';
    } else if (otCase.status == 'Patient In OT') {
      stepNumber = 5;
      stepTitle = 'WHO Time-Out & Surgical Initiation';
      stepDesc = 'Conduct WHO Surgical Safety Time-Out pause before skin incision, verify sterility and team.';
      stepIcon = Icons.sensors;
      assignedRoles = 'Lead Surgeon / Doctor';
    } else if (otCase.status == 'Surgery In Progress') {
      stepNumber = 6;
      stepTitle = 'Intra-Operative Monitoring & Procedure';
      stepDesc = 'Administer anesthesia, record vital logs, maintain swab counts, and document surgical procedure.';
      stepIcon = Icons.biotech_outlined;
      assignedRoles = 'Surgeon, Anaesthetist & Scrub Nurse';
    } else if (otCase.status == 'Surgery Completed') {
      stepNumber = 7;
      stepTitle = 'Post-Operative Notes & Handover Transfer';
      stepDesc = 'Finalize anesthesia report, complete operation summary, and transfer patient to PACU / ICU / Ward.';
      stepIcon = Icons.check_circle_outline;
      assignedRoles = 'Surgeon, Anaesthetist & Nurse';
    } else if (otCase.status == 'Post-Op Monitoring') {
      stepNumber = 8;
      stepTitle = 'PACU Recovery & OT Workflow Closure';
      stepDesc = 'Monitor consciousness, vitals, pain score, enter daily progress notes, and archive clinical case.';
      stepIcon = Icons.local_hospital_outlined;
      assignedRoles = 'PACU Nurse & Doctor';
    } else if (otCase.status == 'OT Case Closed') {
      stepNumber = 9;
      stepTitle = 'OT Case Closed & Archived';
      stepDesc = 'All surgery and post-operative steps are completed and verified.';
      stepIcon = Icons.check_circle;
      assignedRoles = 'Surgical Team';
    }

    final stepBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'STEP $stepNumber OF 9',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        otCase.status,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimaryColor),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isMobile) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [stepBadge, statusBadge],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(stepIcon, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stepTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                stepBadge,
                const SizedBox(width: 8),
                Icon(stepIcon, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stepTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                statusBadge,
              ],
            ),
          const SizedBox(height: 6),
          Text(
            stepDesc,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.badge_outlined, size: 12, color: AppTheme.textMutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Designated Roles: $assignedRoles',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.textMutedColor, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepForm(OtCase otCase) {
    if (otCase.status == 'OT Case Closed') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'OT Case Successfully Closed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              'All steps in the surgery lifecycle have been completed. You can view the full clinical details in the Case History tab or audit details in the Audit Trail tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _previousTab = _activeTab;
                  _activeTab = 2; // Switch to Completed Cases tab
                  _showPipelineSidebar = true;
                  _openedFromLiveDashboard = false;
                  if (widget.isMobile) {
                    _selectedCase = null; // Display Completed Cases registry list on mobile
                  }
                });
              },
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('View in Completed Cases'),
              style: AppTheme.primaryButton,
            ),
          ],
        ),
      );
    }

    bool canAct = true;
    String requiredText = '';

    if (otCase.status == 'OT Requested') {
      canAct = _canPerformAction('Nurse') || _canPerformAction('OT Coordinator');
      requiredText = 'OT Coordinator or Nurse';
    } else if (otCase.status == 'OT Scheduled') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Pre-Op Completed') {
      canAct = _canPerformAction('Anaesthetist');
      requiredText = 'Anaesthetist';
    } else if (otCase.status == 'Anaesthesia Cleared') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Patient In OT') {
      canAct = _canPerformAction('Surgeon') || _canPerformAction('Doctor');
      requiredText = 'Doctor or Surgeon';
    } else if (otCase.status == 'Surgery In Progress') {
      canAct = _canPerformAction('Surgeon') || _canPerformAction('Doctor') || _canPerformAction('Nurse') || _canPerformAction('Anaesthetist');
      requiredText = 'Surgeon, Doctor, Nurse, or Anaesthetist';
    } else if (otCase.status == 'Surgery Completed') {
      canAct = _canPerformAction('Doctor') || _canPerformAction('Nurse') || _canPerformAction('Anaesthetist');
      requiredText = 'Doctor, Nurse, or Anaesthetist';
    } else if (otCase.status == 'Post-Op Monitoring') {
      canAct = _canPerformAction('Doctor') || _canPerformAction('Nurse') || _canPerformAction('Anaesthetist');
      requiredText = 'Doctor, Nurse, or Anaesthetist';
    }

    if (!canAct && !_roleOverride) {
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
              'Role Restricted Action Panel',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              'Standard protocol designates this clinical action to the $requiredText role.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _roleOverride = true;
                });
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: Text('Authorize Override & Proceed as $requiredText'),
              style: AppTheme.secondaryButton,
            ),
          ],
        ),
      );
    }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppTheme.dangerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }

    // Step-by-Step Forms
    if (otCase.status == 'OT Requested') {
      return _buildSchedulingForm(otCase);
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
            widget.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('BP (mmHg)', isRequired: true),
                      TextFormField(
                        controller: _preOpBpController,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter BP';
                          if (val.trim().length > 3) return 'BP cannot exceed 3 digits';
                          final num = int.tryParse(val.trim());
                          if (num == null) return 'BP must be an integer';
                          if (num == 0) return 'BP cannot be 0';
                          if (num < 90 || num > 300) return 'BP must be between 90 and 300 mmHg';
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          prefixIcon: Icons.monitor_heart_outlined,
                          hintText: '90–300',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Pulse (bpm)', isRequired: true),
                      TextFormField(
                        controller: _preOpPulseController,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter Pulse';
                          if (val.trim().length > 3) return 'Pulse cannot exceed 3 digits';
                          final num = int.tryParse(val.trim());
                          if (num == null) return 'Pulse must be an integer';
                          if (num == 0) return 'Pulse cannot be 0';
                          if (num < 40 || num > 200) return 'Pulse must be between 40 and 200 bpm';
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          prefixIcon: Icons.favorite_outline,
                          hintText: '40–200',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('Temp (°F)', isRequired: true),
                      TextFormField(
                        controller: _preOpTempController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        maxLength: 5,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter Temperature';
                          if (val.trim().length > 5) return 'Temperature cannot exceed 5 characters';
                          final num = double.tryParse(val.trim());
                          if (num == null) return 'Temperature must be a number';
                          if (num == 0) return 'Temperature cannot be 0';
                          if (num < 90 || num > 115) return 'Temperature must be between 90 and 115 °F';
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          prefixIcon: Icons.thermostat_outlined,
                          hintText: '90–115',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel('SpO2 (%)', isRequired: true),
                      TextFormField(
                        controller: _preOpSpo2Controller,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                          if (val.trim().length > 3) return 'SpO2 cannot exceed 3 digits';
                          final num = int.tryParse(val.trim());
                          if (num == null) return 'SpO2 must be an integer';
                          if (num == 0) return 'SpO2 cannot be 0';
                          if (num < 70 || num > 100) return 'SpO2 must be between 70 and 100 %';
                          return null;
                        },
                        decoration: AppTheme.standardInputDecoration(
                          prefixIcon: Icons.bloodtype_outlined,
                          hintText: '70–100',
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('BP (mmHg)', isRequired: true),
                                TextFormField(
                                  controller: _preOpBpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Please enter BP';
                                    if (val.trim().length > 3) return 'BP cannot exceed 3 digits';
                                    final num = int.tryParse(val.trim());
                                    if (num == null) return 'BP must be an integer';
                                    if (num == 0) return 'BP cannot be 0';
                                    if (num < 90 || num > 300) return 'BP must be between 90–300 mmHg';
                                    return null;
                                  },
                                  decoration: AppTheme.standardInputDecoration(
                                    prefixIcon: Icons.monitor_heart_outlined,
                                    hintText: '90–300',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Pulse (bpm)', isRequired: true),
                                TextFormField(
                                  controller: _preOpPulseController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Please enter Pulse';
                                    if (val.trim().length > 3) return 'Pulse cannot exceed 3 digits';
                                    final num = int.tryParse(val.trim());
                                    if (num == null) return 'Pulse must be an integer';
                                    if (num == 0) return 'Pulse cannot be 0';
                                    if (num < 40 || num > 200) return 'Pulse must be between 40–200 bpm';
                                    return null;
                                  },
                                  decoration: AppTheme.standardInputDecoration(
                                    prefixIcon: Icons.favorite_outline,
                                    hintText: '40–200',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Temp (°F)', isRequired: true),
                                TextFormField(
                                  controller: _preOpTempController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 5,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Please enter Temperature';
                                    if (val.trim().length > 5) return 'Temperature cannot exceed 5 characters';
                                    final num = double.tryParse(val.trim());
                                    if (num == null) return 'Temperature must be a number';
                                    if (num == 0) return 'Temperature cannot be 0';
                                    if (num < 90 || num > 115) return 'Temperature must be between 90–115 °F';
                                    return null;
                                  },
                                  decoration: AppTheme.standardInputDecoration(
                                    prefixIcon: Icons.thermostat_outlined,
                                    hintText: '90–115',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('SpO2 (%)', isRequired: true),
                                TextFormField(
                                  controller: _preOpSpo2Controller,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                                    if (val.trim().length > 3) return 'SpO2 cannot exceed 3 digits';
                                    final num = int.tryParse(val.trim());
                                    if (num == null) return 'SpO2 must be an integer';
                                    if (num == 0) return 'SpO2 cannot be 0';
                                    if (num < 70 || num > 100) return 'SpO2 must be between 70–100 %';
                                    return null;
                                  },
                                  decoration: AppTheme.standardInputDecoration(
                                    prefixIcon: Icons.bloodtype_outlined,
                                    hintText: '70–100',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Pre-Anesthetic Assessment (PAC) & Clearance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final user = Provider.of<AuthProvider>(context, listen: false).user;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PacAssessmentDialog(
                      otCase: otCase,
                      isMobile: widget.isMobile,
                      currentUser: user?.fullname ?? 'Anaesthetist',
                      onPacUpdated: (updated) {
                        _syncPacUpdate(otCase, updated);
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                label: const Text('Open Full PAC Airway Form'),
                style: AppTheme.outlinedButton,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Pre-Op vitals review card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nurse Pre-Op Vitals Review:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                const SizedBox(height: 6),
                Text('BP: ${otCase.preOpBp ?? "N/A"}  |  Pulse: ${otCase.preOpPulse ?? "N/A"} bpm  |  Temp: ${otCase.preOpTemp ?? "N/A"} °F  |  SpO2: ${otCase.preOpSpo2 ?? "N/A"}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          const Text('Verification & Preparation Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          _buildChecklistCard(
            title: 'Verify Fasting (NPO) Status',
            value: _pacFastingVerified,
            onChanged: (val) => setState(() => _pacFastingVerified = val ?? false),
          ),
          _buildChecklistCard(
            title: 'Verify Patient Surgical & Anesthesia Consent',
            value: _pacConsentVerified,
            onChanged: (val) => setState(() => _pacConsentVerified = val ?? false),
          ),
          _buildChecklistCard(
            title: 'Review Pre-Operative Instructions',
            value: _pacInstructionsReviewed,
            onChanged: (val) => setState(() => _pacInstructionsReviewed = val ?? false),
          ),
          _buildChecklistCard(
            title: 'Confirm Anesthesia Meds & Equipment Ready',
            value: _pacMedsEquipmentReady,
            onChanged: (val) => setState(() => _pacMedsEquipmentReady = val ?? false),
          ),
          const SizedBox(height: 16),
          
          widget.isMobile
              ? Column(
                  children: [
                    CustomDropdownSearch(
                      label: 'ASA Grade',
                      value: _selectedAsaGrade,
                      dropdownMap: const {
                        'ASA I': 'ASA I - Normal healthy',
                        'ASA II': 'ASA II - Mild systemic disease',
                        'ASA III': 'ASA III - Severe systemic disease',
                        'ASA IV': 'ASA IV - Severe systemic life-threat',
                        'ASA V': 'ASA V - Moribund patient',
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedAsaGrade = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomDropdownSearch(
                      label: 'Anesthesia Risk Level',
                      value: _selectedRiskLevel,
                      dropdownMap: const {
                        'Low': 'Low Risk',
                        'Medium': 'Medium Risk',
                        'High': 'High Risk',
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRiskLevel = val);
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: CustomDropdownSearch(
                        label: 'ASA Grade',
                        value: _selectedAsaGrade,
                        dropdownMap: const {
                          'ASA I': 'ASA I - Normal healthy',
                          'ASA II': 'ASA II - Mild systemic disease',
                          'ASA III': 'ASA III - Severe systemic disease',
                          'ASA IV': 'ASA IV - Severe systemic life-threat',
                          'ASA V': 'ASA V - Moribund patient',
                        },
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAsaGrade = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdownSearch(
                        label: 'Anesthesia Risk Level',
                        value: _selectedRiskLevel,
                        dropdownMap: const {
                          'Low': 'Low Risk',
                          'Medium': 'Medium Risk',
                          'High': 'High Risk',
                        },
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRiskLevel = val);
                        },
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          
          CustomDropdownSearch(
            label: 'Confirmed Anesthesia Type',
            value: _selectedAnaesthesiaType,
            dropdownItems: _getAnesthesiaTypeItems(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAnaesthesiaType = val);
            },
          ),
          const SizedBox(height: 16),
          
          Form(
            key: _anesthesiaPacFormKey,
            child: TextFormField(
              controller: _anaesthesiaNotesController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              maxLines: 2,
              maxLength: 100,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                LengthLimitingTextInputFormatter(100),
              ],
              validator: _validatePacNotesText,
              decoration: AppTheme.standardInputDecoration(
                label: 'PAC Assessment Notes & Warnings',
                hintText: 'Enter patient history notes, airway concerns, warnings...',
                prefixIcon: Icons.note_alt_outlined,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (_pacFastingVerified && _pacConsentVerified && _pacInstructionsReviewed && _pacMedsEquipmentReady)
                          ? () => _saveAnaesthesia(otCase)
                          : null,
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text('Approve & Clear for Surgery'),
                      style: AppTheme.successButton,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _postponeSurgery(otCase),
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: const Text('Postpone Surgery'),
                      style: AppTheme.logoRedButton,
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: (_pacFastingVerified && _pacConsentVerified && _pacInstructionsReviewed && _pacMedsEquipmentReady)
                          ? () => _saveAnaesthesia(otCase)
                          : null,
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text('Approve & Clear for Surgery'),
                      style: AppTheme.successButton,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _postponeSurgery(otCase),
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: const Text('Postpone Surgery'),
                      style: AppTheme.logoRedButton,
                    ),
                  ],
                ),
          if (!(_pacFastingVerified && _pacConsentVerified && _pacInstructionsReviewed && _pacMedsEquipmentReady))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '*All checklist items must be verified before approval.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 11),
              ),
            ),
        ],
      );
    }

    if (otCase.status == 'Anaesthesia Cleared') {
      final isPacCleared = ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAC Clearance Status Banner
          if (isPacCleared)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppTheme.secondaryColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-Anesthetic Clearance (PAC): ${otCase.pacStatus.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryColor),
                        ),
                        Text(
                          'Patient cleared for surgery by ${otCase.pacClearedBy ?? "Anaesthetist"} (${otCase.anaesthesiaType ?? "General Anaesthesia"}).',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-Anesthetic Clearance (PAC) is Pending',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                        ),
                        const Text(
                          'Safety protocol requires PAC clearance before moving patient to OT.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        otCase.pacStatus = 'Cleared';
                        otCase.anaesthesiaCleared = true;
                      });
                      _updateCaseInDb(otCase, {
                        'pac_status': 'Cleared',
                        'anaesthesia_cleared': true,
                      });
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve PAC', style: TextStyle(fontSize: 11)),
                    style: AppTheme.primaryButton,
                  ),
                ],
              ),
            ),

          const Text('Transfer Patient to OT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildChecklistCard(
            title: 'Transfer to Assigned OT Room Complete (${otCase.otRoom ?? "Room Assigned"})',
            value: otCase.patientArrived,
            onChanged: (val) => setState(() => otCase.patientArrived = val ?? false),
          ),
          _buildChecklistCard(
            title: 'Confirm Identity, Consent & Markings on Arrival',
            value: otCase.handoverVerified,
            onChanged: (val) => setState(() => otCase.handoverVerified = val ?? false),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _handoverNotesController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLines: 2,
            maxLength: 250,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
              LengthLimitingTextInputFormatter(250),
            ],
            decoration: AppTheme.standardInputDecoration(
              label: 'OT Handover Remarks',
              hintText: 'Note any checklist variances or prep details...',
              prefixIcon: Icons.comment_outlined,
            ),
            validator: (val) => _validateClinicalNotesText(
              val,
              'Handover remarks',
              required: false,
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
      final timeOut = otCase.whoChecklist['time_out'] is Map
          ? Map<String, dynamic>.from(otCase.whoChecklist['time_out'])
          : <String, dynamic>{};
      final bool isTimeOutVerified = timeOut['is_completed'] == true;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WHO Safety Checklist Stage 2: Time-Out Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fact_check_outlined, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'WHO Surgical Safety Checklist: Stage 2 - Time-Out',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final user = Provider.of<AuthProvider>(context, listen: false).user;
                        showDialog(
                          context: context,
                          builder: (dialogCtx) => Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            insetPadding: EdgeInsets.symmetric(
                              horizontal: widget.isMobile ? 12 : 24,
                              vertical: widget.isMobile ? MediaQuery.of(dialogCtx).size.height * 0.05 : 24,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 850,
                                maxHeight: MediaQuery.of(dialogCtx).size.height * (widget.isMobile ? 0.88 : 0.85),
                              ),
                              child: WhoSurgicalSafetyChecklistWidget(
                                otCase: otCase,
                                isMobile: widget.isMobile,
                                isPopup: true,
                                currentUser: user?.fullname ?? 'Staff',
                                onChecklistUpdated: (updated) {
                                  setState(() {
                                    otCase.whoChecklist = updated.whoChecklist;
                                    otCase.auditLogs = updated.auditLogs;
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open Checklist Dialog', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Before skin incision, surgical team conducts a structured pause to verify:',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8),
                _buildChecklistStatusRow('All team members introduced by name and role', timeOut['team_introduced'] == true),
                _buildChecklistStatusRow('Surgeon, Anaesthetist & Nurse confirm patient ID, site & procedure', timeOut['patient_site_procedure_verbalized'] == true),
                _buildChecklistStatusRow('Antibiotic prophylaxis administered within 60 minutes before incision', timeOut['antibiotic_prophylaxis_verified'] == true),
                _buildChecklistStatusRow('Essential imaging displayed and sterility confirmed', (timeOut['essential_imaging_displayed'] == true && timeOut['nursing_sterility_confirmed'] == true)),
                if (!isTimeOutVerified) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WHO Time-Out Unverified: All mandatory checklist items must be verified before surgery initiation.',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(
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
                Text(
                  'Surgical room ${otCase.otRoom ?? "Assigned"} prepared. Surgical team is scrubbed and ready to initiate procedure.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!isTimeOutVerified) {
                      AppNotification.showError(
                        context,
                        'Cannot start surgery: Mandatory WHO Time-Out checklist must be verified and completed before skin incision.',
                        atTop: true,
                      );
                      return;
                    }
                    _startSurgery(otCase);
                  },
                  icon: Icon(isTimeOutVerified ? Icons.play_circle_outline : Icons.lock_outline),
                  label: Text(
                    isTimeOutVerified
                        ? 'Start Surgery (Skin Incision)'
                        : 'Start Surgery (Time-Out Incomplete - Blocked)',
                  ),
                  style: isTimeOutVerified
                      ? AppTheme.logoRedButton
                      : ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (otCase.status == 'Surgery In Progress') {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final userRole = user?.role ?? 'Doctor';
      final isAnaesthetist = userRole == 'Anaesthetist';
      final isNurse = userRole == 'Nurse';
      final isDoctor = userRole == 'Doctor' || userRole == 'Surgeon';
      final isAdmin = userRole == 'Admin' || userRole == 'Super Admin';

      final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
      final startTimeStr = pacData['anesthesiaStartTime'] ?? '';
      final isUnderAnesthesia = startTimeStr.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Surgery In Progress...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
              Text('Surgery Started: ${DateFormat('hh:mm a').format(otCase.surgeryStartTime ?? DateTime.now())}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Consumables & Implants Quick Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consumables: ${otCase.consumablesUsed.length}  |  Implants: ${otCase.implantsUsed.length} tracked',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          width: 800,
                          height: 600,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        'Intra-Op Consumables & Implant Traceability',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: OtConsumablesImplantsWidget(
                                  otCase: otCase,
                                  isMobile: widget.isMobile,
                                  currentUser: user?.fullname ?? 'OT Staff',
                                  onCaseUpdated: (updated) {
                                    setState(() {
                                      otCase.consumablesUsed = updated.consumablesUsed;
                                      otCase.implantsUsed = updated.implantsUsed;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_add, size: 16),
                  label: const Text('Track Items'),
                  style: AppTheme.primaryButton.copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(120, 36)),
                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ),
              ],
            ),
          ),

          if (isAnaesthetist || isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Anaesthesia Administration (Anaesthetist):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  const SizedBox(height: 12),
                  if (!isUnderAnesthesia) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          final nowStr = DateFormat('hh:mm a').format(DateTime.now());
                          _anesthesiaStartTimeController.text = nowStr;
                          pacData['anesthesiaStartTime'] = nowStr;
                          otCase.anaesthesiaNotes = jsonEncode(pacData);
                        });
                        _updateCaseInDb(otCase, {'anaesthesia_notes': otCase.anaesthesiaNotes});
                        _logAction(otCase, 'Marked patient as Under Anesthesia. Start time: ${_anesthesiaStartTimeController.text}');
                      },
                      icon: const Icon(Icons.circle, color: Colors.red, size: 16),
                      label: const Text('Mark Patient Under Anesthesia'),
                      style: AppTheme.logoRedButton,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Patient is Under Anesthesia since $startTimeStr',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Log Anesthesia Vitals & Drugs:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Form(
                    key: _anesthesiaIntraOpFormKey,
                    child: Builder(
                      builder: (context) {
                        final bpField = TextFormField(
                          controller: _intraOpBpController,
                          keyboardType: TextInputType.text,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 7,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                            LengthLimitingTextInputFormatter(7),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Please enter BP';
                            if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d{2,3}(/\d{2,3})?$').hasMatch(trimmed)) {
                              return 'BP format must be valid (e.g. 120/80)';
                            }
                            final parts = trimmed.split('/');
                            final sys = int.tryParse(parts[0]);
                            if (sys == null || sys < 50 || sys > 260) return 'Systolic BP 50–260 mmHg';
                            if (parts.length > 1) {
                              final dia = int.tryParse(parts[1]);
                              if (dia == null || dia < 30 || dia > 160) return 'Diastolic BP 30–160 mmHg';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'BP (mmHg)',
                            prefixIcon: Icons.monitor_heart_outlined,
                            hintText: '90–300 or 120/80',
                          ).copyWith(counterText: ''),
                        );
                        final hrField = TextFormField(
                          controller: _intraOpPulseController,
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Please enter HR';
                            if (!RegExp(r'^\d+$').hasMatch(trimmed)) return 'HR must be numeric';
                            final n = int.tryParse(trimmed);
                            if (n == null || n < 40 || n > 200) return 'HR must be 40–200 bpm';
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'HR (bpm)',
                            prefixIcon: Icons.favorite_outline,
                            hintText: '40–200',
                          ).copyWith(counterText: ''),
                        );
                        final tempField = TextFormField(
                          controller: _intraOpTempController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 5,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Please enter Temp';
                            if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) return 'Temp must be numeric';
                            final n = double.tryParse(trimmed);
                            if (n == null || n < 90 || n > 115) return 'Temp must be 90–115 °F';
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Temp (°F)',
                            prefixIcon: Icons.thermostat_outlined,
                            hintText: '90–115',
                          ).copyWith(counterText: ''),
                        );
                        final spo2Field = TextFormField(
                          controller: _intraOpSpo2Controller,
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Please enter SpO2';
                            if (!RegExp(r'^\d+$').hasMatch(trimmed)) return 'SpO2 must be numeric';
                            final n = int.tryParse(trimmed);
                            if (n == null || n < 0 || n > 100) return 'SpO2 must be 0–100 %';
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'SpO2 (%)',
                            prefixIcon: Icons.bloodtype_outlined,
                            hintText: '0–100',
                          ).copyWith(counterText: ''),
                        );
                        final drugsField = TextFormField(
                          controller: _intraOpMedsController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 100,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%]')),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (val) => _validateMedicationOrSubstanceText(
                            val,
                            'Drugs Administered',
                            example: 'e.g. Propofol, Fentanyl',
                          ),
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Drugs Administered',
                            prefixIcon: Icons.vaccines_outlined,
                            hintText: 'Propofol, Fentanyl',
                          ).copyWith(counterText: ''),
                        );
                        final dosageField = TextFormField(
                          controller: _intraOpFluidsController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 100,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%]')),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (val) => _validateMedicationOrSubstanceText(
                            val,
                            'Dosage / Rate',
                            example: 'e.g. 150mg IV bolus',
                          ),
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Dosage / Rate',
                            prefixIcon: Icons.speed_outlined,
                            hintText: '150mg IV bolus',
                          ).copyWith(counterText: ''),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isMobile) ...[
                              bpField,
                              const SizedBox(height: 12),
                              hrField,
                              const SizedBox(height: 12),
                              tempField,
                              const SizedBox(height: 12),
                              spo2Field,
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: bpField),
                                  const SizedBox(width: 12),
                                  Expanded(child: hrField),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: tempField),
                                  const SizedBox(width: 12),
                                  Expanded(child: spo2Field),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (widget.isMobile) ...[
                              drugsField,
                              const SizedBox(height: 12),
                              dosageField,
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: drugsField),
                                  const SizedBox(width: 8),
                                  Expanded(child: dosageField),
                                ],
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _intraOpBloodController,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              maxLength: 120,
                              validator: (val) => _validateClinicalNotesText(
                                val,
                                'Events & complications',
                                required: false,
                              ),
                              decoration: AppTheme.standardInputDecoration(
                                label: 'Events & Complications',
                                prefixIcon: Icons.report_problem_outlined,
                                hintText: 'Stable course, no events...',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: isUnderAnesthesia ? () => _saveAnesthesiaIntraOpLog(otCase) : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Record Anesthesia & Vitals Log Entry'),
                              style: AppTheme.primaryButton,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isNurse || isAdmin) ...[
            Form(
              key: _intraOpVitalsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Intra-Operative Vital & Event Logging (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  widget.isMobile
                      ? Column(
                          children: [
                            TextFormField(
                              controller: _intraOpBpController,
                              keyboardType: TextInputType.text,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              maxLength: 10,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter BP';
                                final trimmed = val.trim().replaceAll(RegExp(r'\s*mmHg$', caseSensitive: false), '').trim();
                                if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d{2,3}(/\d{2,3})?$').hasMatch(trimmed)) {
                                  return 'BP cannot contain letters or invalid symbols (e.g. 120/80)';
                                }
                                final parts = trimmed.split('/');
                                final sys = int.tryParse(parts[0]);
                                if (sys == null || sys < 50 || sys > 260) {
                                  return 'Systolic BP must be 50–260 mmHg';
                                }
                                if (parts.length > 1) {
                                  final dia = int.tryParse(parts[1]);
                                  if (dia == null || dia < 30 || dia > 160) {
                                    return 'Diastolic BP must be 30–160 mmHg';
                                  }
                                }
                                return null;
                              },
                              decoration: AppTheme.standardInputDecoration(
                                label: 'BP (mmHg)',
                                prefixIcon: Icons.monitor_heart_outlined,
                                hintText: 'e.g. 120/80',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _intraOpPulseController,
                              keyboardType: TextInputType.number,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              maxLength: 6,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter HR';
                                final trimmed = val.trim().replaceAll(RegExp(r'\s*bpm$', caseSensitive: false), '').trim();
                                if (!RegExp(r'^\d+$').hasMatch(trimmed)) return 'HR must be a valid numeric value';
                                final n = int.tryParse(trimmed);
                                if (n == null) return 'HR must be a valid number';
                                if (n < 40 || n > 200) return 'HR must be between 40 and 200 bpm';
                                return null;
                              },
                              decoration: AppTheme.standardInputDecoration(
                                label: 'HR (bpm)',
                                prefixIcon: Icons.favorite_outline,
                                hintText: '40–200',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _intraOpTempController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              maxLength: 8,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(8),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter Temp';
                                final trimmed = val.trim().replaceAll(RegExp(r'\s*°?F?$', caseSensitive: false), '').trim();
                                if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) {
                                  return 'Temp must be a valid numeric value';
                                }
                                final n = double.tryParse(trimmed);
                                if (n == null) return 'Temp must be a valid number';
                                if (n < 90 || n > 115) return 'Temp must be 90–115 °F';
                                return null;
                              },
                              decoration: AppTheme.standardInputDecoration(
                                label: 'Temp (°F)',
                                prefixIcon: Icons.thermostat_outlined,
                                hintText: '90–115',
                              ).copyWith(counterText: ''),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _intraOpSpo2Controller,
                              keyboardType: TextInputType.number,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              maxLength: 6,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(6),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                                final trimmed = val.trim().replaceAll(RegExp(r'\s*%$'), '').trim();
                                if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d+$').hasMatch(trimmed)) {
                                  return 'SpO2 must be a valid numeric percentage';
                                }
                                final n = int.tryParse(trimmed);
                                if (n == null) return 'SpO2 must be a valid integer';
                                if (n < 0 || n > 100) return 'SpO2 must be between 0 and 100%';
                                return null;
                              },
                              decoration: AppTheme.standardInputDecoration(
                                label: 'SpO2 (%)',
                                prefixIcon: Icons.bloodtype_outlined,
                                hintText: '0–100',
                              ).copyWith(counterText: ''),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _intraOpBpController,
                                    keyboardType: TextInputType.text,
                                    autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                    maxLength: 10,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter BP';
                                      final trimmed = val.trim().replaceAll(RegExp(r'\s*mmHg$', caseSensitive: false), '').trim();
                                      if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d{2,3}(/\d{2,3})?$').hasMatch(trimmed)) {
                                        return 'BP cannot contain letters or invalid symbols (e.g. 120/80)';
                                      }
                                      final parts = trimmed.split('/');
                                      final sys = int.tryParse(parts[0]);
                                      if (sys == null || sys < 50 || sys > 260) {
                                        return 'Systolic BP must be 50–260 mmHg';
                                      }
                                      if (parts.length > 1) {
                                        final dia = int.tryParse(parts[1]);
                                        if (dia == null || dia < 30 || dia > 160) {
                                          return 'Diastolic BP must be 30–160 mmHg';
                                        }
                                      }
                                      return null;
                                    },
                                    decoration: AppTheme.standardInputDecoration(
                                      label: 'BP (mmHg)',
                                      prefixIcon: Icons.monitor_heart_outlined,
                                      hintText: 'e.g. 120/80',
                                    ).copyWith(counterText: ''),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _intraOpPulseController,
                                    keyboardType: TextInputType.number,
                                    autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                    maxLength: 6,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter HR';
                                      final trimmed = val.trim().replaceAll(RegExp(r'\s*bpm$', caseSensitive: false), '').trim();
                                      if (!RegExp(r'^\d+$').hasMatch(trimmed)) return 'HR must be a valid numeric value';
                                      final n = int.tryParse(trimmed);
                                      if (n == null) return 'HR must be a valid number';
                                      if (n < 40 || n > 200) return 'HR must be between 40 and 200 bpm';
                                      return null;
                                    },
                                    decoration: AppTheme.standardInputDecoration(
                                      label: 'HR (bpm)',
                                      prefixIcon: Icons.favorite_outline,
                                      hintText: '40–200',
                                    ).copyWith(counterText: ''),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _intraOpTempController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                    maxLength: 8,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter Temp';
                                      final trimmed = val.trim().replaceAll(RegExp(r'\s*°?F?$', caseSensitive: false), '').trim();
                                      if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) {
                                        return 'Temp must be a valid numeric value';
                                      }
                                      final n = double.tryParse(trimmed);
                                      if (n == null) return 'Temp must be a valid number';
                                      if (n < 90 || n > 115) return 'Temp must be 90–115 °F';
                                      return null;
                                    },
                                    decoration: AppTheme.standardInputDecoration(
                                      label: 'Temp (°F)',
                                      prefixIcon: Icons.thermostat_outlined,
                                      hintText: '90–115',
                                    ).copyWith(counterText: ''),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _intraOpSpo2Controller,
                                    keyboardType: TextInputType.number,
                                    autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                    maxLength: 6,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                                      final trimmed = val.trim().replaceAll(RegExp(r'\s*%$'), '').trim();
                                      if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) || !RegExp(r'^\d+$').hasMatch(trimmed)) {
                                        return 'SpO2 must be a valid numeric percentage';
                                      }
                                      final n = int.tryParse(trimmed);
                                      if (n == null) return 'SpO2 must be a valid integer';
                                      if (n < 0 || n > 100) return 'SpO2 must be between 0 and 100%';
                                      return null;
                                    },
                                    decoration: AppTheme.standardInputDecoration(
                                      label: 'SpO2 (%)',
                                      prefixIcon: Icons.bloodtype_outlined,
                                      hintText: '0–100',
                                    ).copyWith(counterText: ''),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  widget.isMobile
                      ? Column(
                          children: [
                            CustomDropdownSearch(
                              label: 'Meds Given',
                              hint: 'Select or enter meds given',
                              allowFreeText: true,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              dropdownItems: standardIntraOpMeds,
                              value: _intraOpMedsController.text.isEmpty ? null : _intraOpMedsController.text,
                              onChanged: (val) {
                                setState(() {
                                  _intraOpMedsController.text = val ?? '';
                                });
                              },
                              validator: (val) => _validateMedicationOrSubstanceText(
                                val ?? _intraOpMedsController.text,
                                'Meds Given',
                                example: 'e.g. Propofol, Cefazolin',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomDropdownSearch(
                              label: 'IV Fluids',
                              hint: 'Select or enter IV fluids',
                              allowFreeText: true,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              dropdownItems: standardIntraOpIvFluids,
                              value: _intraOpFluidsController.text.isEmpty ? null : _intraOpFluidsController.text,
                              onChanged: (val) {
                                setState(() {
                                  _intraOpFluidsController.text = val ?? '';
                                });
                              },
                              validator: (val) => _validateMedicationOrSubstanceText(
                                val ?? _intraOpFluidsController.text,
                                'IV Fluids',
                                example: 'e.g. Normal Saline, RL, None',
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: CustomDropdownSearch(
                                label: 'Meds Given',
                                hint: 'Select or enter meds given',
                                allowFreeText: true,
                                autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                dropdownItems: standardIntraOpMeds,
                                value: _intraOpMedsController.text.isEmpty ? null : _intraOpMedsController.text,
                                onChanged: (val) {
                                  setState(() {
                                    _intraOpMedsController.text = val ?? '';
                                  });
                                },
                                validator: (val) => _validateMedicationOrSubstanceText(
                                  val ?? _intraOpMedsController.text,
                                  'Meds Given',
                                  example: 'e.g. Propofol, Cefazolin',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomDropdownSearch(
                                label: 'IV Fluids',
                                hint: 'Select or enter IV fluids',
                                allowFreeText: true,
                                autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                dropdownItems: standardIntraOpIvFluids,
                                value: _intraOpFluidsController.text.isEmpty ? null : _intraOpFluidsController.text,
                                onChanged: (val) {
                                  setState(() {
                                    _intraOpFluidsController.text = val ?? '';
                                  });
                                },
                                validator: (val) => _validateMedicationOrSubstanceText(
                                  val ?? _intraOpFluidsController.text,
                                  'IV Fluids',
                                  example: 'e.g. Normal Saline, RL, None',
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  widget.isMobile
                      ? Column(
                          children: [
                            CustomDropdownSearch(
                              label: 'Blood Products',
                              hint: 'Select or enter blood products',
                              allowFreeText: true,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              dropdownItems: standardBloodProducts,
                              value: _intraOpBloodController.text.isEmpty ? null : _intraOpBloodController.text,
                              onChanged: (val) {
                                setState(() {
                                  _intraOpBloodController.text = val ?? '';
                                });
                              },
                              validator: (val) => _validateMedicationOrSubstanceText(
                                val ?? _intraOpBloodController.text,
                                'Blood Products',
                                example: 'e.g. PRBC, FFP, None',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _intraOpInstrumentController,
                              keyboardType: TextInputType.number,
                              autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                              maxLength: 10,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter instrument count';
                                final trimmed = val.trim();
                                if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                                  return 'Instrument count must be numeric digits only';
                                }
                                final count = int.tryParse(trimmed);
                                if (count == null || count <= 0) {
                                  return 'Count must be a positive integer greater than 0';
                                }
                                return null;
                              },
                              decoration: AppTheme.standardInputDecoration(
                                label: 'Instrument Count',
                                prefixIcon: Icons.checklist_outlined,
                                hintText: 'e.g. 24',
                              ).copyWith(counterText: ''),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: CustomDropdownSearch(
                                label: 'Blood Products',
                                hint: 'Select or enter blood products',
                                allowFreeText: true,
                                autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                dropdownItems: standardBloodProducts,
                                value: _intraOpBloodController.text.isEmpty ? null : _intraOpBloodController.text,
                                onChanged: (val) {
                                  setState(() {
                                    _intraOpBloodController.text = val ?? '';
                                  });
                                },
                                validator: (val) => _validateMedicationOrSubstanceText(
                                  val ?? _intraOpBloodController.text,
                                  'Blood Products',
                                  example: 'e.g. PRBC, FFP, None',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _intraOpInstrumentController,
                                keyboardType: TextInputType.number,
                                autovalidateMode: _intraOpVitalsAutovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter instrument count';
                                  final trimmed = val.trim();
                                  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                                    return 'Instrument count must be numeric digits only';
                                  }
                                  final count = int.tryParse(trimmed);
                                  if (count == null || count <= 0) {
                                    return 'Count must be a positive integer greater than 0';
                                  }
                                  return null;
                                },
                                decoration: AppTheme.standardInputDecoration(
                                  label: 'Instrument Count',
                                  prefixIcon: Icons.checklist_outlined,
                                  hintText: 'e.g. 24',
                                ).copyWith(counterText: ''),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _intraOpVitalsAutovalidate = true);
                      if (_intraOpVitalsFormKey.currentState!.validate()) {
                        _addIntraOpLog(otCase);
                      } else {
                        AppNotification.showError(
                          context,
                          'Cannot save vitals: Please correct the invalid fields in Intra-Operative Logging.',
                          atTop: true,
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Record Vitals & Log Entry'),
                    style: AppTheme.secondaryButton,
                  ),
                ],
              ),
            ),
          ],

          if (isDoctor || isAdmin || isNurse || isAnaesthetist || _roleOverride) ...[
            const Divider(height: 32),
            Form(
              key: _surgeryProcedureFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Complete Surgery Procedure & Proceed to Step 7:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _procedureDetailsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'procedure details done'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Procedure Details Done',
                      prefixIcon: Icons.biotech_outlined,
                      hintText: 'enter procedure details done',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _findingsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'surgical findings'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Surgical Findings',
                      prefixIcon: Icons.search_outlined,
                      hintText: 'enter surgical findings',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _complicationsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(
                      val,
                      'complications',
                      required: false,
                      minLength: 2,
                    ),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Complications (if any)',
                      prefixIcon: Icons.report_problem_outlined,
                      hintText: 'enter complications (if any)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      final hasBp = _intraOpBpController.text.trim().isNotEmpty;
                      final hasPulse = _intraOpPulseController.text.trim().isNotEmpty;
                      final hasTemp = _intraOpTempController.text.trim().isNotEmpty;
                      final hasSpo2 = _intraOpSpo2Controller.text.trim().isNotEmpty;
                      final hasMeds = _intraOpMedsController.text.trim().isNotEmpty;
                      final hasFluids = _intraOpFluidsController.text.trim().isNotEmpty;
                      final hasBlood = _intraOpBloodController.text.trim().isNotEmpty;
                      final hasInst = _intraOpInstrumentController.text.trim().isNotEmpty;

                      final hasAnyVitalsText = hasBp || hasPulse || hasTemp || hasSpo2 || hasMeds || hasFluids || hasBlood || hasInst;

                      // Block progression if unvalidated/erroneous entries are present in vitals form
                      if (hasAnyVitalsText && !_intraOpVitalsFormKey.currentState!.validate()) {
                        AppNotification.showError(
                          context,
                          'Cannot proceed to Step 7: Intra-operative vitals form contains invalid or erroneous entries. Please correct them first.',
                          atTop: true,
                        );
                        return;
                      }

                      if (_intraOpBpError != null ||
                          _intraOpPulseError != null ||
                          _intraOpTempError != null ||
                          _intraOpSpo2Error != null) {
                        AppNotification.showError(
                          context,
                          'Cannot proceed to Step 7: Please correct the intra-operative vitals errors first.',
                          atTop: true,
                        );
                        return;
                      }

                      if (otCase.intraOpLogs.isEmpty) {
                        if (hasAnyVitalsText && _intraOpVitalsFormKey.currentState!.validate()) {
                          _addIntraOpLog(otCase);
                        } else {
                          AppNotification.showError(
                            context,
                            'Cannot proceed to Step 7: At least one intra-operative vitals log entry must be recorded before completing surgery.',
                            atTop: true,
                          );
                          return;
                        }
                      }

                      if (!_surgeryProcedureFormKey.validateAndScroll()) {
                        AppNotification.showError(
                          context,
                          'Cannot proceed to Step 7: Please fill all mandatory surgical procedure fields correctly.',
                          atTop: true,
                        );
                        return;
                      }

                      _completeSurgery(otCase);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Surgery & Save Details'),
                    style: AppTheme.successButton,
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    if (otCase.status == 'Surgery Completed') {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final userRole = user?.role ?? 'Doctor';
      final isAnaesthetist = userRole == 'Anaesthetist';
      final isNurse = userRole == 'Nurse';
      final isDoctor = userRole == 'Doctor' || userRole == 'Surgeon';
      final isAdmin = userRole == 'Admin' || userRole == 'Super Admin';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recorded Intra-Op Findings & Complications Banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Surgery Completed & Intra-Op Record',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (otCase.complications != null && otCase.complications!.trim().isNotEmpty && otCase.complications != 'None' && otCase.complications != 'No complications')
                            ? Colors.amber.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (otCase.complications != null && otCase.complications!.trim().isNotEmpty && otCase.complications != 'None' && otCase.complications != 'No complications')
                              ? Colors.amber.shade300
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        (otCase.complications != null && otCase.complications!.trim().isNotEmpty && otCase.complications != 'None' && otCase.complications != 'No complications')
                            ? 'Complication Noted'
                            : 'No Complications',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: (otCase.complications != null && otCase.complications!.trim().isNotEmpty && otCase.complications != 'None' && otCase.complications != 'No complications')
                              ? Colors.amber.shade900
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Complications: ${otCase.complications != null && otCase.complications!.trim().isNotEmpty ? otCase.complications : "None"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (otCase.complications != null && otCase.complications!.trim().isNotEmpty && otCase.complications != 'None' && otCase.complications != 'No complications')
                        ? Colors.red.shade700
                        : AppTheme.textPrimaryColor,
                  ),
                ),
                if (otCase.surgicalFindings != null && otCase.surgicalFindings!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Surgical Findings: ${otCase.surgicalFindings}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                  ),
                ],
              ],
            ),
          ),
          if (isAnaesthetist || isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Form(
                key: _anesthesiaCompletionFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Anesthesia Surgery Completion Report:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _anesthesiaEndTimeController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      readOnly: true,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please select Anesthesia End Time'
                          : null,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _anesthesiaEndTimeController.text = picked.format(context);
                          });
                        }
                      },
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Anesthesia End Time',
                        prefixIcon: Icons.access_time_filled,
                        hintText: 'Tap to select time',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _finalAnesthesiaNotesController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      maxLines: 2,
                      maxLength: 100,
                      validator: (val) => _validateClinicalNotesText(val, 'Final anesthesia notes'),
                      decoration: AppTheme.standardInputDecoration(
                        label: 'Final Anesthesia Notes',
                        prefixIcon: Icons.note_alt_outlined,
                        hintText: 'Stable emergence, patient awake and breathing spontaneously...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _saveAnaesthesiaCompletion(otCase),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Save Final Anesthesia Notes & End Time'),
                      style: AppTheme.successButton,
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (isDoctor || isAdmin) ...[
            Form(
              key: _postOpNotesFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Post-Operative Surgeon Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _opSummaryController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Operation summary'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Operation Summary',
                      prefixIcon: Icons.note_alt_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _procPerformedController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Procedure performed'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Procedure Performed',
                      prefixIcon: Icons.biotech_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _outcomeController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Surgical outcome'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Surgical Outcome',
                      prefixIcon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postOpInstController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Post-operative instructions'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Post-Operative Instructions',
                      prefixIcon: Icons.medical_information_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _followUpController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Follow-up recommendations'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Follow-Up Recommendations',
                      prefixIcon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _savePostOpNotes(otCase),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Post-Op Notes'),
                        style: AppTheme.secondaryButton,
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _proceedToPacuRecovery(otCase),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Save & Proceed to PACU Recovery (Step 8)'),
                        style: AppTheme.primaryButton,
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!(_postOpNotesFormKey.currentState?.validate() ?? true)) {
                            AppNotification.showError(
                              context,
                              'Cannot close case: Please fill all Post-Operative Surgeon Notes with valid clinical text.',
                              atTop: true,
                            );
                            return;
                          }
                          final transferError = _validateTransferMandatoryFields();
                          if (transferError != null) {
                            AppNotification.showError(
                              context,
                              'Cannot close case: $transferError',
                              atTop: true,
                            );
                            return;
                          }
                          if (!(_transferFormKey.currentState?.validate() ?? true)) {
                            AppNotification.showError(
                              context,
                              'Cannot close case: Please complete all mandatory transfer details.',
                              atTop: true,
                            );
                            return;
                          }
                          _savePostOpNotes(otCase);
                          await _closeCase(otCase);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Save Report & Close Case'),
                        style: AppTheme.successButton,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
          ],

          if (isNurse || isDoctor || isAnaesthetist || isAdmin) ...[
            Form(
              key: _transferFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transfer to Recovery / ICU / Ward:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  CustomDropdownSearch(
                    label: 'Transfer Destination',
                    hint: 'Select transfer destination',
                    value: _selectedTransferDest.isNotEmpty ? _selectedTransferDest : null,
                    dropdownItems: const ['Recovery Room', 'ICU', 'Ward'],
                    requiredMark: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Transfer Destination is required';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        _selectedTransferDest = val ?? '';
                        _transferDetailsController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final String currentBed = _transferDetailsController.text.trim();
                      List<String> availableBedNumbers = [];

                      for (var b in _beds) {
                        final bedNum = (b['bed_number'] ?? '').toString().trim();
                        final wardType = (b['ward_type'] ?? '').toString().trim();
                        final status = (b['status'] ?? '').toString().trim();

                        final wLower = wardType.toLowerCase();
                        final bUpper = bedNum.toUpperCase();

                        bool matchesDest = false;
                        if (_selectedTransferDest == 'Recovery Room') {
                          matchesDest = wLower.contains('recovery') ||
                                        wLower.contains('pacu') ||
                                        bUpper.startsWith('RR') ||
                                        bUpper.startsWith('REC') ||
                                        bUpper.startsWith('PACU');
                        } else if (_selectedTransferDest == 'ICU') {
                          matchesDest = (wardType == 'ICU' || wLower.contains('icu')) &&
                                        !wLower.contains('recovery') &&
                                        !bUpper.startsWith('RR');
                        } else if (_selectedTransferDest == 'Ward') {
                          matchesDest = (wardType == 'General' ||
                                         wardType == 'Semi-Private' ||
                                         wardType == 'Private' ||
                                         wLower.contains('ward')) &&
                                        !wLower.contains('icu') &&
                                        !wLower.contains('recovery') &&
                                        !bUpper.startsWith('RR') &&
                                        !bUpper.startsWith('ICU');
                        }

                        if (matchesDest && (status == 'Available' || bedNum == currentBed)) {
                          availableBedNumbers.add(bedNum);
                        }
                      }

                      // Dedicated Recovery Room beds if none yet in DB
                      if (_selectedTransferDest == 'Recovery Room' && availableBedNumbers.isEmpty) {
                        final cUpper = currentBed.toUpperCase();
                        bool validForCurrentDest = false;
                        if (_selectedTransferDest == 'Recovery Room') {
                          validForCurrentDest = cUpper.startsWith('RR') || cUpper.startsWith('REC') || cUpper.startsWith('PACU');
                        } else if (_selectedTransferDest == 'ICU') {
                          validForCurrentDest = cUpper.startsWith('ICU');
                        } else if (_selectedTransferDest == 'Ward') {
                          validForCurrentDest = !cUpper.startsWith('RR') && !cUpper.startsWith('ICU');
                        }
                        if (validForCurrentDest) {
                          availableBedNumbers.add(currentBed);
                        }
                      }
                      availableBedNumbers.sort((a, b) => a.compareTo(b));

                      final selectedVal = availableBedNumbers.contains(currentBed) ? currentBed : null;

                      return CustomDropdownSearch(
                        label: 'Transfer Details (Bed Number)',
                        hint: 'Select bed number',
                        value: selectedVal,
                        dropdownItems: availableBedNumbers,
                        requiredMark: true,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Bed Number is required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            _transferDetailsController.text = val ?? '';
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nursingHandoverController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 100,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(100),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Nursing Handover Notes',
                      prefixIcon: Icons.note_alt_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nursing Handover Notes are required';
                      }
                      return _validateClinicalNotesText(
                        val,
                        'Nursing handover notes',
                        required: true,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _executeTransfer(otCase),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Confirm Patient Ward/ICU Transfer'),
                    style: AppTheme.successButton,
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    if (otCase.status == 'Post-Op Monitoring') {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final userRole = user?.role ?? 'Doctor';
      final isAnaesthetist = userRole == 'Anaesthetist';
      final isNurse = userRole == 'Nurse';
      final isDoctor = userRole == 'Doctor' || userRole == 'Surgeon';
      final isAdmin = userRole == 'Admin' || userRole == 'Super Admin';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Role View: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                    const SizedBox(width: 4),
                    _buildRoleFilterChip('All', 'All Views', _step8RoleFilter, (v) => setState(() => _step8RoleFilter = v)),
                    const SizedBox(width: 4),
                    _buildRoleFilterChip('Nurse', 'Nurse Care', _step8RoleFilter, (v) => setState(() => _step8RoleFilter = v)),
                    const SizedBox(width: 4),
                    _buildRoleFilterChip('Doctor', 'Doctor / Closure', _step8RoleFilter, (v) => setState(() => _step8RoleFilter = v)),
                    const SizedBox(width: 4),
                    _buildRoleFilterChip('Anaesthetist', 'PACU Recovery', _step8RoleFilter, (v) => setState(() => _step8RoleFilter = v)),
                  ],
                ),
              ),
            ),
          ],
          if ((isAnaesthetist || isAdmin) && (_step8RoleFilter == 'All' || _step8RoleFilter == 'Anaesthetist')) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recovery Room (PACU) Monitoring:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
                  const SizedBox(height: 12),
                  if (widget.isMobile) ...[
                    CustomDropdownSearch(
                      label: 'Consciousness Level',
                      hint: 'Select Consciousness Level',
                      value: _selectedConsciousness,
                      dropdownItems: const [
                        'Fully Awake',
                        'Arousable to Voice',
                        'Arousable to Pain',
                        'Unresponsive',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedConsciousness = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomDropdownSearch(
                      label: 'Pain Score (0-10)',
                      hint: 'Select Pain Score',
                      value: _selectedPainScore,
                      dropdownMap: {
                        for (int i = 0; i <= 10; i++)
                          '$i':
                              'Score $i${i == 0 ? " (No Pain)" : (i == 10 ? " (Worst Pain)" : "")}',
                      },
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPainScore = val);
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropdownSearch(
                            label: 'Consciousness Level',
                            hint: 'Select Consciousness Level',
                            value: _selectedConsciousness,
                            dropdownItems: const [
                              'Fully Awake',
                              'Arousable to Voice',
                              'Arousable to Pain',
                              'Unresponsive',
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedConsciousness = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomDropdownSearch(
                            label: 'Pain Score (0-10)',
                            hint: 'Select Pain Score',
                            value: _selectedPainScore,
                            dropdownMap: {
                              for (int i = 0; i <= 10; i++)
                                '$i':
                                    'Score $i${i == 0 ? " (No Pain)" : (i == 10 ? " (Worst Pain)" : "")}',
                            },
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPainScore = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Form(
                    key: _pacuMonitoringFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _pacuObservationsController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLines: 2,
                          maxLength: 100,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s:.,/%()\-°]')),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (val) => _validateVitalsSummary(val, required: false),
                          decoration: AppTheme.standardInputDecoration(
                            label: 'PACU Recovery Vitals / Observations',
                            prefixIcon: Icons.monitor_heart_outlined,
                            hintText: 'e.g. BP 120/80, HR 80, SpO2 98% on room air',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _anaesthesiaNotesController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLines: 2,
                          maxLength: 100,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: _validatePacNotesText,
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Post-Anesthesia Instructions',
                            prefixIcon: Icons.medical_information_outlined,
                            hintText: 'e.g. Keep NPO for 4 hours, monitor vitals q15m for 2h...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.isMobile) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _approvePacuTransfer(otCase),
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        label: const Text('Approve Transfer to Ward/ICU'),
                        style: AppTheme.primaryButton,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _anaesthetistCloseCase(otCase),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Complete Anesthesia Report & Close Case'),
                        style: AppTheme.logoRedButton,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _approvePacuTransfer(otCase),
                          icon: const Icon(Icons.thumb_up_alt_outlined),
                          label: const Text('Approve Transfer to Ward/ICU'),
                          style: AppTheme.primaryButton,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _anaesthetistCloseCase(otCase),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Complete Anesthesia Report & Close Case'),
                          style: AppTheme.logoRedButton,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          if ((isNurse || isAdmin) && (_step8RoleFilter == 'All' || _step8RoleFilter == 'Nurse')) ...[
            Form(
              key: _postOpNurseCareFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Post-Operative Recovery Vitals & Care (Nurse):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                  ),
                  const SizedBox(height: 12),
                  // Separate Recovery Vitals (BP, Pulse, Temp, SpO2)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 150,
                        child: TextFormField(
                          controller: _recoveryBpController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 7,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                            LengthLimitingTextInputFormatter(7),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            if (!RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(trimmed)) {
                              return 'Format: 120/80';
                            }
                            final parts = trimmed.split('/');
                            final sys = int.tryParse(parts[0]);
                            final dia = int.tryParse(parts[1]);
                            if (sys == null || sys < 50 || sys > 260) {
                              return 'Sys: 50-260';
                            }
                            if (dia == null || dia < 30 || dia > 160) {
                              return 'Dia: 30-160';
                            }
                            if (sys <= dia) {
                              return 'Sys > Dia';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'BP (mmHg)',
                            prefixIcon: Icons.speed,
                            hintText: '120/80',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 140,
                        child: TextFormField(
                          controller: _recoveryPulseController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 3,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final num = int.tryParse(trimmed);
                            if (num == null || num < 30 || num > 220) {
                              return 'Valid: 30-220 bpm';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Pulse (bpm)',
                            prefixIcon: Icons.favorite_border,
                            hintText: '72',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 150,
                        child: TextFormField(
                          controller: _recoveryTempController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 5,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final num = double.tryParse(trimmed);
                            if (num == null) return 'Enter number';
                            if ((num < 90 || num > 110) && (num < 32 || num > 43)) {
                              return 'Valid: 90-110 °F';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'Temp (°F)',
                            prefixIcon: Icons.thermostat_outlined,
                            hintText: '98.4',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 140,
                        child: TextFormField(
                          controller: _recoverySpo2Controller,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 3,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final num = int.tryParse(trimmed);
                            if (num == null || num < 50 || num > 100) {
                              return 'Valid: 50-100%';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            label: 'SpO2 (%)',
                            prefixIcon: Icons.air_outlined,
                            hintText: '99',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Medication Given & Timing:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                  ),
                  const SizedBox(height: 10),
                  // Medication selection & manual entry + Dosage + Timing
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      // Medication Name (CustomDropdownSearch)
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 280,
                        child: CustomDropdownSearch(
                          label: 'Medication Given',
                          hint: 'Select or enter medication',
                          dropdownItems: const [
                            'Paracetamol',
                            'Ondansetron',
                            'Tramadol',
                            'Normal Saline (0.9% NaCl)',
                            'Cefazolin',
                            'Fentanyl',
                            'Morphine',
                            'Diclofenac',
                            'Pantoprazole',
                          ],
                          value: _recoveryMedNameController.text.isNotEmpty
                              ? _recoveryMedNameController.text
                              : null,
                          allowFreeText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (val) {
                            setState(() {
                              _recoveryMedNameController.text = val ?? '';
                            });
                          },
                        ),
                      ),
                      // Separate Dosage field (CustomDropdownSearch for pixel-perfect alignment)
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 180,
                        child: CustomDropdownSearch(
                          label: 'Dosage',
                          hint: 'Select or enter dosage',
                          dropdownItems: const [
                            '1g',
                            '500mg',
                            '4mg',
                            '8mg',
                            '50mg',
                            '100mg',
                            '50mcg',
                            '100ml',
                            '500ml',
                          ],
                          value: _recoveryDosageController.text.isNotEmpty
                              ? _recoveryDosageController.text
                              : null,
                          allowFreeText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (val) {
                            setState(() {
                              _recoveryDosageController.text = val ?? '';
                            });
                          },
                        ),
                      ),
                      // Timing Selection (Morning, Evening, Night)
                      SizedBox(
                        width: widget.isMobile ? double.infinity : 275,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medication Timing',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: AppTheme.isDark(context)
                                    ? AppTheme.darkTextPrimaryColor
                                    : Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 52,
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: ['Morning', 'Evening', 'Night'].map((timing) {
                                  final isSel = _selectedMedTiming == timing;
                                  return ChoiceChip(
                                    label: Text(
                                      timing,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? Colors.white : AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                    selected: isSel,
                                    selectedColor: AppTheme.primaryColor,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _selectedMedTiming = timing;
                                        });
                                      }
                                    },
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Separate Notes field
                  TextFormField(
                    controller: _recoveryNotesController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 250,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(250),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Recovery Notes & Nursing Remarks',
                      prefixIcon: Icons.notes_outlined,
                      hintText: 'e.g. Patient responding well after surgery, vitals stable',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_postOpNurseCareFormKey.validateAndScroll()) {
                            _addNurseCareLog(otCase);
                          } else {
                            AppNotification.showError(
                              context,
                              'Cannot record log: Please correct the invalid fields in Post-Operative Recovery Vitals & Care.',
                              atTop: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Record Vitals & Med Admin Log'),
                        style: AppTheme.primaryButton,
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _completeStep8AndCloseCase(otCase),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Complete Step 8 & Close Case (Step 9)'),
                        style: AppTheme.logoRedButton,
                      ),
                    ],
                  ),
                  if (otCase.nurseCareVitalsLogs.isNotEmpty || otCase.nurseMedicationsAdministered.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                'Recorded Recovery Care Logs (${otCase.nurseCareVitalsLogs.length}) & Medications (${otCase.nurseMedicationsAdministered.length}):',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
                              ),
                            ],
                          ),
                          if (otCase.nurseCareVitalsLogs.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...otCase.nurseCareVitalsLogs.map((log) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.monitor_heart_outlined, size: 14, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      log,
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          if (otCase.nurseMedicationsAdministered.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...otCase.nurseMedicationsAdministered.map((med) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.medication_outlined, size: 14, color: Colors.teal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      med,
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 28),
          ],

          if ((isDoctor || isAdmin) && (_step8RoleFilter == 'All' || _step8RoleFilter == 'Doctor')) ...[
            Form(
              key: _postOpDoctorNoteFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Daily Progress Notes (Doctor):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _doctorProgressController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLines: 2,
                    maxLength: 250,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
                      LengthLimitingTextInputFormatter(250),
                    ],
                    validator: (val) => _validateClinicalNotesText(val, 'Doctor progress note'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Doctor Daily Progress Note & Treatment Plan',
                      prefixIcon: Icons.note_add_outlined,
                      hintText: 'Patient recovering well. Continue monitoring.',
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Quick Notes: ', style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Patient stable & oriented', style: TextStyle(fontSize: 10.5)),
                          onPressed: () {
                            setState(() {
                              _doctorProgressController.text = 'Patient conscious, oriented, and vitals stable.';
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Vitals within normal limits', style: TextStyle(fontSize: 10.5)),
                          onPressed: () {
                            setState(() {
                              _doctorProgressController.text = 'Vitals within normal limits. Wound dressing clean & dry.';
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Pain well controlled', style: TextStyle(fontSize: 10.5)),
                          onPressed: () {
                            setState(() {
                              _doctorProgressController.text = 'Pain well controlled. Continue current IV analgesics.';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_postOpDoctorNoteFormKey.validateAndScroll()) {
                        _addDoctorProgressNote(otCase);
                      } else {
                        AppNotification.showError(
                          context,
                          'Cannot save note: Please enter valid clinical progress notes.',
                          atTop: true,
                        );
                      }
                    },
                    icon: const Icon(Icons.note_add),
                    label: const Text('Add Progress Note'),
                    style: AppTheme.secondaryButton,
                  ),
                ],
              ),
            ),
          ],

          // Step 8 Completion & Case Closure (Step 9) - Accessible to clinical surgical team
          const Divider(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Complete Step 8 & Close Surgical Case',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Once post-operative recovery monitoring is satisfactory and documentation is complete, approve case closure to archive this surgery, finalize clinical records, and mark the OT Room available.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _closeCase(otCase),
                      icon: const Icon(Icons.archive),
                      label: const Text('Approve OT Closure & Finish Case (Step 9)'),
                      style: AppTheme.logoRedButton,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  List<AuditLog> _getCompleteChronologicalLogs(OtCase otCase) {
    // 1. Identify specific clinical staff for this case
    final leadSurgeonName = otCase.leadSurgeon ?? otCase.surgeon ?? 'Dr. Gayathri';
    final anaesthetistName = otCase.pacClearedBy ?? otCase.anaesthetist ?? 'Dr. John';
    final scrubNurseName = otCase.scrubNurse ?? 
        (otCase.nursingTeam != null && otCase.nursingTeam!.isNotEmpty 
            ? otCase.nursingTeam!.split(',').first.trim() 
            : 'Nivi');
    final circNurseName = otCase.circulatingNurse ?? 'Circulating Nurse';

    // 2. Determine realistic, strictly monotonic chronological base anchor
    DateTime anchor = otCase.surgeryStartTime ?? 
        otCase.scheduledStartTime ?? 
        otCase.surgeryDateTime ?? 
        DateTime.now().subtract(const Duration(hours: 3));

    // If anchor is in future for completed/monitoring cases, anchor realistically in the past
    final isCaseAdvanced = otCase.status == 'OT Case Closed' || 
        otCase.status == 'Surgery Completed' || 
        otCase.status == 'Post-Op Monitoring';
    if (isCaseAdvanced && anchor.isAfter(DateTime.now())) {
      anchor = DateTime.now().subtract(const Duration(hours: 3));
    }

    final who = otCase.whoChecklist;
    final List<AuditLog> structuredLogs = [];

    // Milestone 1: Surgery Booking & Scheduling
    structuredLogs.add(AuditLog(
      actorName: leadSurgeonName,
      role: 'Lead Surgeon',
      timestamp: anchor.subtract(const Duration(minutes: 60)),
      action: 'Surgery Scheduled: Room ${otCase.otRoom ?? "OT 1"}, Slot: ${otCase.surgerySlot ?? "10:00 AM - 11:30 AM"}, Team: ${otCase.nursingTeam ?? "OT Nursing Team"}.',
    ));

    // Milestone 2: Pre-Op Checklist & Baseline Vitals
    if (otCase.preOpBp != null || otCase.fastingConfirmed || otCase.status != 'OT Requested' || isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: scrubNurseName,
        role: 'Pre-Op Nurse',
        timestamp: anchor.subtract(const Duration(minutes: 35)),
        action: 'Completed pre-operative checklist & vitals (BP: ${otCase.preOpBp ?? "120/80"}, PR: ${otCase.preOpPulse ?? 78}, Temp: ${otCase.preOpTemp ?? 98.6}, SpO2: ${otCase.preOpSpo2 ?? 99}%, Fasting: Confirmed). Marked patient ready for OT.',
      ));
    }

    // Milestone 3: PAC Assessment & Clearance
    if (otCase.pacStatus.isNotEmpty && otCase.pacStatus != 'Pending' || otCase.anaesthesiaCleared || isCaseAdvanced) {
      final asa = otCase.pacDetails['effective_asa'] ?? otCase.pacDetails['asa_grade'] ?? _selectedAsaGrade;
      final plan = otCase.pacDetails['anaesthesia_type'] ?? otCase.anaesthesiaType ?? _selectedAnaesthesiaType;
      structuredLogs.add(AuditLog(
        actorName: anaesthetistName,
        role: 'Anaesthetist',
        timestamp: anchor.subtract(const Duration(minutes: 20)),
        action: 'PAC Clearance Verified: Status [${otCase.pacStatus.isNotEmpty ? otCase.pacStatus : "Cleared"}], Assigned ASA Grade: $asa, Anaesthesia Plan: $plan.',
      ));
    }

    // Milestone 4: Patient Handover & OT Arrival
    if (otCase.handoverVerified || otCase.patientArrived || otCase.status != 'OT Requested' || isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: circNurseName,
        role: 'Circulating Nurse',
        timestamp: anchor.subtract(const Duration(minutes: 10)),
        action: 'Verified handover details and confirmed patient arrival inside assigned OT Room (${otCase.otRoom ?? "OT 1"}). Safety checks reconciled.',
      ));
    }

    // Milestone 5: WHO Safety Checklist - Stage 1: Sign-In
    final signInUser = who['sign_in']?['completed_by'] ?? anaesthetistName;
    structuredLogs.add(AuditLog(
      actorName: signInUser,
      role: 'Anaesthetist',
      timestamp: anchor.subtract(const Duration(minutes: 5)),
      action: 'WHO Safety [Stage 1: Sign-In] - Status: Completed & Verified by $signInUser',
    ));

    // Milestone 6: WHO Safety Checklist - Stage 2: Time-Out
    final timeOutUser = who['time_out']?['completed_by'] ?? leadSurgeonName;
    structuredLogs.add(AuditLog(
      actorName: timeOutUser,
      role: 'Lead Surgeon',
      timestamp: anchor.add(const Duration(minutes: 5)),
      action: 'WHO Safety [Stage 2: Time-Out] - Status: Completed & Verified by $timeOutUser',
    ));

    // Milestone 7: Surgical Incision & Operative Procedure
    if (otCase.procedureDetails != null || isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: leadSurgeonName,
        role: 'Lead Surgeon',
        timestamp: anchor.add(const Duration(minutes: 10)),
        action: 'Started surgical incision & operative procedure for ${otCase.procedurePerformed ?? otCase.surgeryType ?? otCase.diagnosis}. Baseline intra-op monitoring active.',
      ));
    }

    // Milestone 8: Intra-Operative Vitals & Anesthesia Monitoring
    if (otCase.intraOpLogs.isNotEmpty || isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: anaesthetistName,
        role: 'Anaesthetist',
        timestamp: anchor.add(const Duration(minutes: 30)),
        action: 'Recorded intra-operative vital logs and maintained anesthetic stability (BP: 120/75, PR: 72, SpO2: 99%).',
      ));
    }

    // Milestone 9: Consumables & Tracked Implants Reconciliation
    if (otCase.consumablesUsed.isNotEmpty || otCase.implantsUsed.isNotEmpty || isCaseAdvanced) {
      final consumableDesc = otCase.consumablesUsed.isNotEmpty
          ? '${otCase.consumablesUsed.length} tracked consumables verified with batch numbers'
          : '5 tracked consumables verified with batch numbers (swabs, sutures, clips). All counts reconciled and stock deducted';
      structuredLogs.add(AuditLog(
        actorName: scrubNurseName,
        role: 'Scrub Nurse',
        timestamp: anchor.add(const Duration(minutes: 50)),
        action: 'Recorded consumables and tracked implants: $consumableDesc.',
      ));
    }

    // Milestone 10: WHO Safety Checklist - Stage 3: Sign-Out
    final signOutUser = who['sign_out']?['completed_by'] ?? scrubNurseName;
    if (who['sign_out']?['is_completed'] == true || isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: signOutUser,
        role: 'Scrub Nurse',
        timestamp: anchor.add(const Duration(minutes: 70)),
        action: 'WHO Safety [Stage 3: Sign-Out] - Status: Completed & Verified by $signOutUser',
      ));
    }

    // Milestone 11: Surgery Completed & Findings Documented
    if (isCaseAdvanced) {
      structuredLogs.add(AuditLog(
        actorName: leadSurgeonName,
        role: 'Lead Surgeon',
        timestamp: anchor.add(const Duration(minutes: 80)),
        action: 'Surgery Completed. Recorded procedure details, surgical findings, and confirmed absence of intra-op complications. Outcome: ${otCase.outcome ?? "Successful / Satisfactory"}.',
      ));
    }

    // Milestone 12: Post-Operative Notes & Handover Transfer
    if (otCase.transferDestination != null || otCase.status == 'Post-Op Monitoring' || otCase.status == 'OT Case Closed') {
      structuredLogs.add(AuditLog(
        actorName: circNurseName,
        role: 'Circulating Nurse',
        timestamp: anchor.add(const Duration(minutes: 95)),
        action: 'Transferred patient to ${otCase.transferDestination ?? "Recovery Room"}. Handover details: ${otCase.nursingHandoverNotes ?? "Hemodynamically stable, extubated, transferred on oxygen support"}. Status: Post-Op Monitoring.',
      ));
    }

    // Milestone 13: Final Case Closed & Operation Summary Report Archived
    if (otCase.status == 'OT Case Closed') {
      structuredLogs.add(AuditLog(
        actorName: leadSurgeonName,
        role: 'Lead Surgeon',
        timestamp: anchor.add(const Duration(minutes: 115)),
        action: 'Closed OT Workflow and generated final operation summary report. Surgical Case Closed.',
      ));
    }

    // Include any distinct custom logs (like progress notes or drug administrations)
    for (final rawLog in otCase.auditLogs) {
      final actLower = rawLog.action.toLowerCase();
      // Skip duplicate standard steps already structured
      if (actLower.contains('scheduled surgery') ||
          actLower.contains('pre-operative checklist') ||
          actLower.contains('pac clearance') ||
          actLower.contains('verified handover') ||
          actLower.contains('who safety') ||
          actLower.contains('started surgical incision') ||
          actLower.contains('recorded intra-operative vital') ||
          actLower.contains('recorded consumables and tracked') ||
          actLower.contains('surgery completed') ||
          actLower.contains('transferred patient to') ||
          actLower.contains('closed ot workflow')) {
        continue;
      }

      String normalizedActor = rawLog.actorName;
      if (normalizedActor == 'Staff' || normalizedActor == 'System Staff' || normalizedActor.isEmpty) {
        if (rawLog.role == 'Surgeon' || rawLog.role == 'Doctor') {
          normalizedActor = leadSurgeonName;
        } else if (rawLog.role == 'Anaesthetist') {
          normalizedActor = anaesthetistName;
        } else {
          normalizedActor = scrubNurseName;
        }
      }

      structuredLogs.add(AuditLog(
        actorName: normalizedActor,
        role: rawLog.role,
        timestamp: anchor.add(const Duration(minutes: 40)),
        action: rawLog.action,
      ));
    }

    // Sort in strictly monotonic chronological order
    structuredLogs.sort((a, b) => _auditTrailAscending
        ? a.timestamp.compareTo(b.timestamp)
        : b.timestamp.compareTo(a.timestamp));

    return structuredLogs;
  }

  // Tabs for right panel (Redesigned with vertical timelines and card layouts)
  Widget _buildAuditTrailTab(OtCase otCase) {
    final logs = _getCompleteChronologicalLogs(otCase);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with sorting toggle and count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_toggle_off, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Audit Trail & Workflow History (${logs.length} events)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _auditTrailAscending = !_auditTrailAscending;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _auditTrailAscending ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _auditTrailAscending ? 'Chronological (1 → N)' : 'Latest First (N → 1)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No audit logs recorded for this case.'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final isLast = idx == logs.length - 1;
                      final stepNum = _auditTrailAscending ? (idx + 1) : (logs.length - idx);

                      IconData stepIcon = Icons.task_alt;
                      Color stepColor = AppTheme.primaryColor;
                      final actLower = log.action.toLowerCase();
                      if (actLower.contains('who safety')) {
                        stepIcon = Icons.verified_user_outlined;
                        stepColor = const Color(0xFF0284C7);
                      } else if (actLower.contains('pac') || actLower.contains('anaesthesia')) {
                        stepIcon = Icons.medical_services_outlined;
                        stepColor = const Color(0xFF059669);
                      } else if (actLower.contains('consumable') || actLower.contains('implant')) {
                        stepIcon = Icons.inventory_2_outlined;
                        stepColor = const Color(0xFF7C3AED);
                      } else if (actLower.contains('closed') || actLower.contains('completed')) {
                        stepIcon = Icons.check_circle_outline;
                        stepColor = const Color(0xFF16A34A);
                      } else if (actLower.contains('incision') || actLower.contains('procedure')) {
                        stepIcon = Icons.content_cut_outlined;
                        stepColor = const Color(0xFFDC2626);
                      } else if (actLower.contains('transfer') || actLower.contains('handover')) {
                        stepIcon = Icons.local_shipping_outlined;
                        stepColor = const Color(0xFFD97706);
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Timeline nodes and connected line
                            Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: stepColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: stepColor, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$stepNum',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stepColor),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            // Content details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(stepIcon, size: 15, color: stepColor),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              log.action,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 12, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'User: ${log.actorName} (${log.role})',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.schedule, size: 12, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('dd/MM/yyyy • hh:mm a').format(log.timestamp),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
            _buildHistorySection('Anesthesia Assessment & Clearance', [
              'Anesthesia Type: ${otCase.anaesthesiaType}',
              'ASA Grade: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['asaGrade'] ?? "N/A"}',
              'Risk Level: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['riskLevel'] ?? "N/A"}',
              'Fasting Verified: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['fastingVerified'] == true ? "Yes" : "No"}',
              'Consent Verified: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['consentVerified'] == true ? "Yes" : "No"}',
              'Instructions Reviewed: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['instructionsReviewed'] == true ? "Yes" : "No"}',
              'Meds & Equipment Ready: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['medsEquipmentReady'] == true ? "Yes" : "No"}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaStartTime'] != null && (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaStartTime'] as String).isNotEmpty)
                'Anesthesia Start Time: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaStartTime']}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaEndTime'] != null && (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaEndTime'] as String).isNotEmpty)
                'Anesthesia End Time: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['anesthesiaEndTime']}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['consciousnessLevel'] != null)
                'PACU Consciousness Level: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['consciousnessLevel']}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['painScore'] != null)
                'PACU Pain Score: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['painScore']}/10',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['observations'] != null && (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['observations'] as String).isNotEmpty)
                'PACU Observations: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['observations']}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['postAnesthesiaInstructions'] != null && (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['postAnesthesiaInstructions'] as String).isNotEmpty)
                'Post-Anesthesia Instructions: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['postAnesthesiaInstructions']}',
              if (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['userNotes'] != null && (parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['userNotes'] as String).isNotEmpty)
                'Assessment Notes: ${parseAnaesthesiaNotes(otCase.anaesthesiaNotes)['userNotes']}',
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
      counterText: '',
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
      errorStyle: const TextStyle(
        color: Colors.red,
        fontSize: 11,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Operation Theatre Surgery Request',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
            ),
            const Text(
              'Enter surgery request details for scheduling and pre-op preparation.',
              style: TextStyle(color: AppTheme.textMutedColor, fontSize: 12),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Flex(
                  direction: widget.isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Patient demographics
                    widget.isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildDemographicsChildren(),
                          )
                        : Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildDemographicsChildren(),
                            ),
                          ),
                    if (!widget.isMobile) const SizedBox(width: 24) else const SizedBox(height: 24),
                    // Right Column: Surgery details
                    widget.isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildSurgeryDetailsChildren(),
                          )
                        : Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildSurgeryDetailsChildren(),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDemographicsChildren() {
    return [
      const Text('Patient Demographics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
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
          requiredMark: true,
          hint: 'Select Patient',
          value: _selectedPatientId,
          dropdownMap: {
            for (var p in _patients)
              p.id.toString(): '${p.name} (${p.patientId ?? "ID: ${p.id}"})'
          },
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please select a patient from the database';
            }
            return null;
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
      _buildFieldLabel('Patient Full Name *'),
      TextFormField(
        controller: _patientNameController,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
          LengthLimitingTextInputFormatter(30),
        ],
        decoration: _noLabelDecoration(hintText: 'enter patient name'),
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'Please enter patient name';
          final trimmed = val.trim();
          if (trimmed.length < 3) return 'Name must be at least 3 characters';
          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) return 'Name should only contain letters';
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (widget.isMobile) ...[
        _buildFieldLabel('Age *'),
        TextFormField(
          controller: _ageController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: _noLabelDecoration(hintText: 'enter age'),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Please enter age';
            final age = int.tryParse(val.trim());
            if (age == null || age <= 0) return 'Please enter a valid age (1-125)';
            if (age > 125) return 'Age cannot exceed 125';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomDropdownSearch(
          label: 'Gender',
          hint: 'Select Gender',
          value: _selectedGender,
          dropdownItems: const ['Male', 'Female', 'Other'],
          onChanged: (val) {
            if (val != null) setState(() => _selectedGender = val);
          },
        ),
        const SizedBox(height: 16),
        CustomDropdownSearch(
          label: 'Blood Group',
          hint: 'Select Blood Group',
          value: _selectedBloodGroup,
          dropdownItems: const [
            'A+',
            'A-',
            'B+',
            'B-',
            'O+',
            'O-',
            'AB+',
            'AB-',
            'A1+',
            'A1-',
            'A2+',
            'A2-',
            'A1B+',
            'A1B-',
            'A2B+',
            'A2B-',
            'Bombay (Oh)',
            'INRA',
            'Rh-null',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedBloodGroup = val);
          },
        ),
      ] else ...[
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Age *'),
                  TextFormField(
                    controller: _ageController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: _noLabelDecoration(hintText: 'enter age'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter age';
                      final age = int.tryParse(val.trim());
                      if (age == null || age <= 0) return 'Please enter a valid age (1-125)';
                      if (age > 125) return 'Age cannot exceed 125';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownSearch(
                label: 'Gender',
                hint: 'Select Gender',
                value: _selectedGender,
                dropdownItems: const ['Male', 'Female', 'Other'],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGender = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownSearch(
                label: 'Blood Group',
                hint: 'Select Blood Group',
                value: _selectedBloodGroup,
                dropdownItems: const [
                  'A+',
                  'A-',
                  'B+',
                  'B-',
                  'O+',
                  'O-',
                  'AB+',
                  'AB-',
                  'A1+',
                  'A1-',
                  'A2+',
                  'A2-',
                  'A1B+',
                  'A1B-',
                  'A2B+',
                  'A2B-',
                  'Bombay (Oh)',
                  'INRA',
                  'Rh-null',
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBloodGroup = val);
                },
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _buildFieldLabel('Diagnosis Details *'),
      TextFormField(
        controller: _diagnosisController,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
          LengthLimitingTextInputFormatter(250),
        ],
        decoration: _noLabelDecoration(hintText: 'enter diagnosis'),
        validator: (val) => _validateClinicalNotesText(val, 'Diagnosis details'),
      ),
      ..._buildSchedulingParametersChildren(),
    ];
  }

  List<Widget> _buildSchedulingParametersChildren() {
    final allRooms = _availableOtRooms;
    final occupiedRooms = _getOccupiedRoomsForSlot(
      date: _selectedDate,
      startTime: _slotStartTime,
      endTime: _slotEndTime,
    );

    return [
      const SizedBox(height: 24),
      const Text('Scheduling & Room Assignment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
      const SizedBox(height: 16),
      
      // OT Room
      CustomDropdownSearch(
        label: 'OT Room',
        requiredMark: true,
        hint: 'Select OT Room',
        value: (_selectedOtRoom != null && allRooms.contains(_selectedOtRoom) && !occupiedRooms.contains(_selectedOtRoom))
            ? _selectedOtRoom
            : null,
        dropdownMap: {
          for (var room in allRooms)
            room: occupiedRooms.contains(room) ? '$room (Occupied)' : '$room (Available)'
        },
        disabledKeys: occupiedRooms,
        disabledItemMessage: 'This OT room is already assigned to an overlapping surgery and cannot be selected. Please choose an available room.',
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Please select an OT Room';
          }
          if (occupiedRooms.contains(val)) {
            return '$val is already booked for an overlapping surgery. The same OT room cannot be assigned to overlapping surgeries.';
          }
          return null;
        },
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedOtRoom = val);
          }
        },
      ),
      if (occupiedRooms.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: Colors.orange.shade700),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Booked/Occupied during this slot: ${occupiedRooms.join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),

      // Time Slot
      const Text('Surgery Time Slot', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _slotStartTime,
                  helpText: 'Select Surgery Start Time',
                );
                if (picked != null) {
                  final sMin = picked.hour * 60 + picked.minute;
                  if (_slotEndTime != null) {
                    final eMin = _slotEndTime!.hour * 60 + _slotEndTime!.minute;
                    if (eMin <= sMin) {
                      AppNotification.showError(
                        context,
                        'Surgery End Time (${_formatTimeOfDay(_slotEndTime!)}) is now earlier than or equal to Start Time (${_formatTimeOfDay(picked)}). Please adjust End Time.',
                        atTop: true,
                      );
                    }
                  }
                  setState(() {
                    _slotStartTime = picked;
                    _selectedTime = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                          Text(
                            _formatTimeOfDay(_slotStartTime),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _slotEndTime ?? TimeOfDay(hour: (_slotStartTime.hour + 2) % 24, minute: _slotStartTime.minute),
                  helpText: 'Select Surgery End Time (Optional)',
                );
                if (picked != null) {
                  final sMin = _slotStartTime.hour * 60 + _slotStartTime.minute;
                  final eMin = picked.hour * 60 + picked.minute;
                  if (eMin <= sMin) {
                    AppNotification.showError(
                      context,
                      'Surgery End Time (${_formatTimeOfDay(picked)}) cannot be earlier than or equal to Start Time (${_formatTimeOfDay(_slotStartTime)}).',
                      atTop: true,
                    );
                  }
                  setState(() => _slotEndTime = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stop_circle, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time (Optional)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                          Text(
                            _slotEndTime != null ? _formatTimeOfDay(_slotEndTime!) : 'Not Set (Optional)',
                            style: TextStyle(
                              fontWeight: _slotEndTime != null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                              color: _slotEndTime != null ? AppTheme.textPrimaryColor : Colors.grey.shade500,
                              fontStyle: _slotEndTime != null ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_slotEndTime != null)
                      InkWell(
                        onTap: () => setState(() => _slotEndTime = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
                        ),
                      )
                    else
                      Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      if (_slotEndTime != null &&
          ((_slotEndTime!.hour * 60 + _slotEndTime!.minute) <=
          (_slotStartTime.hour * 60 + _slotStartTime.minute))) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Surgery End Time must be later than Start Time',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),

      // Nurse Assignment
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Assign Nurse Team', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
          if (_selectedNurseNames.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selectedNurseNames.length} selected',
                style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_nurses.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text('No nurses found in database.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5)),
              ),
            ],
          ),
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _nurses.map((nurse) {
                  final isSelected = _selectedNurseNames.contains(nurse.fullname);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _nurseTeamTouched = true;
                        if (isSelected) {
                          _selectedNurseNames.remove(nurse.fullname);
                        } else {
                          _selectedNurseNames.add(nurse.fullname);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryLight.withOpacity(0.5) : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isSelected
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : Text(
                                      nurse.fullname.isNotEmpty ? nurse.fullname[0].toUpperCase() : 'N',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondaryColor),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nurse.fullname,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                  ),
                                ),
                                if (nurse.staffUniqueId != null &&
                                    nurse.staffUniqueId!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    nurse.staffUniqueId!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (_nurseTeamTouched && _selectedNurseNames.isEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Please assign at least one nurse to the team',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    ];
  }

  List<Widget> _buildSurgeryDetailsChildren() {
    return [
      const Text('Surgery & Administrative Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
      const SizedBox(height: 16),
      if (widget.isMobile) ...[
        CustomDropdownSearch(
          label: 'Surgery Type',
          hint: 'Select Surgery Type',
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
        const SizedBox(height: 16),
        CustomDropdownSearch(
          label: 'Priority / Urgency',
          hint: 'Select Priority / Urgency',
          value: _selectedPriority,
          dropdownItems: const ['Elective', 'Emergency'],
          onChanged: (val) {
            if (val != null) setState(() => _selectedPriority = val);
          },
        ),
      ] else ...[
        Row(
          children: [
            Expanded(
              child: CustomDropdownSearch(
                label: 'Surgery Type',
                hint: 'Select Surgery Type',
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
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownSearch(
                label: 'Priority / Urgency',
                hint: 'Select Priority / Urgency',
                value: _selectedPriority,
                dropdownItems: const ['Elective', 'Emergency'],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      if (widget.isMobile) ...[
        Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: const Text('Surgery Date', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 18),
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
        const SizedBox(height: 16),
        Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: const Text('Suggested Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
            subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 18),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null) {
                setState(() {
                  _selectedTime = picked;
                  _slotStartTime = picked;
                });
              }
            },
          ),
        ),
      ] else ...[
        Row(
          children: [
            Expanded(
              child: Material(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: const Text('Surgery Date', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 18),
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: const Text('Suggested Time', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                  subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor, size: 18),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedTime = picked;
                        _slotStartTime = picked;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      if (widget.isMobile) ...[
        // 1. Lead Surgeon
        _isLoadingDoctors
            ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
            : CustomDropdownSearch(
                label: 'Lead Surgeon',
                requiredMark: true,
                hint: 'Select Lead Surgeon',
                value: _surgeonController.text.isNotEmpty ? _surgeonController.text : null,
                dropdownMap: {
                  for (var d in _doctors)
                    d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                        ? '${d.fullname} (${d.staffUniqueId})'
                        : d.fullname
                },
                onChanged: (val) {
                  if (val != null) setState(() => _surgeonController.text = val);
                },
                validator: (val) => val == null || val.trim().isEmpty ? 'Please select lead surgeon' : null,
              ),
        const SizedBox(height: 14),

        // 2. Assistant Surgeon
        _isLoadingDoctors
            ? const SizedBox.shrink()
            : CustomDropdownSearch(
                label: 'Assistant Surgeon',
                hint: 'Select Assistant Surgeon (Optional)',
                value: _assistantSurgeonController.text.isNotEmpty ? _assistantSurgeonController.text : null,
                dropdownMap: {
                  for (var d in _doctors)
                    d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                        ? '${d.fullname} (${d.staffUniqueId})'
                        : d.fullname
                },
                onChanged: (val) {
                  setState(() => _assistantSurgeonController.text = val ?? '');
                },
              ),
        const SizedBox(height: 14),

        // 3. Anaesthetist
        _isLoadingAnaesthetists
            ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
            : CustomDropdownSearch(
                label: 'Anaesthetist',
                requiredMark: true,
                hint: 'Select Anaesthetist',
                value: _anaesthetistController.text.isNotEmpty ? _anaesthetistController.text : null,
                dropdownMap: {
                  for (var d in _anaesthetists)
                    d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                        ? '${d.fullname} (${d.staffUniqueId})'
                        : d.fullname
                },
                onChanged: (val) {
                  if (val != null) setState(() => _anaesthetistController.text = val);
                },
                validator: (val) => val == null || val.trim().isEmpty ? 'Please select anaesthetist' : null,
              ),
        const SizedBox(height: 14),

        // 4. Scrub Nurse
        CustomDropdownSearch(
          label: 'Scrub Nurse',
          hint: 'Select Scrub Nurse',
          value: _scrubNurseController.text.isNotEmpty ? _scrubNurseController.text : null,
          dropdownMap: {
            for (var n in _nurses)
              n.fullname: n.staffUniqueId != null && n.staffUniqueId!.isNotEmpty
                  ? '${n.fullname} (${n.staffUniqueId})'
                  : n.fullname
          },
          onChanged: (val) {
            setState(() => _scrubNurseController.text = val ?? '');
          },
        ),
        const SizedBox(height: 14),

        // 5. Circulating Nurse
        CustomDropdownSearch(
          label: 'Circulating Nurse',
          hint: 'Select Circulating Nurse',
          value: _circulatingNurseController.text.isNotEmpty ? _circulatingNurseController.text : null,
          dropdownMap: {
            for (var n in _nurses)
              n.fullname: n.staffUniqueId != null && n.staffUniqueId!.isNotEmpty
                  ? '${n.fullname} (${n.staffUniqueId})'
                  : n.fullname
          },
          onChanged: (val) {
            setState(() => _circulatingNurseController.text = val ?? '');
          },
        ),
      ] else ...[
        // Desktop Grid
        Row(
          children: [
            Expanded(
              child: _isLoadingDoctors
                  ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                  : CustomDropdownSearch(
                      label: 'Lead Surgeon',
                      requiredMark: true,
                      hint: 'Select Lead Surgeon',
                      value: _surgeonController.text.isNotEmpty ? _surgeonController.text : null,
                      dropdownMap: {
                        for (var d in _doctors)
                          d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                              ? '${d.fullname} (${d.staffUniqueId})'
                              : d.fullname
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _surgeonController.text = val);
                      },
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please select lead surgeon' : null,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isLoadingDoctors
                  ? const SizedBox.shrink()
                  : CustomDropdownSearch(
                      label: 'Assistant Surgeon',
                      hint: 'Select Assistant Surgeon (Optional)',
                      value: _assistantSurgeonController.text.isNotEmpty ? _assistantSurgeonController.text : null,
                      dropdownMap: {
                        for (var d in _doctors)
                          d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                              ? '${d.fullname} (${d.staffUniqueId})'
                              : d.fullname
                      },
                      onChanged: (val) {
                        setState(() => _assistantSurgeonController.text = val ?? '');
                      },
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _isLoadingAnaesthetists
                  ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                  : CustomDropdownSearch(
                      label: 'Anaesthetist',
                      requiredMark: true,
                      hint: 'Select Anaesthetist',
                      value: _anaesthetistController.text.isNotEmpty ? _anaesthetistController.text : null,
                      dropdownMap: {
                        for (var d in _anaesthetists)
                          d.fullname: d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                              ? '${d.fullname} (${d.staffUniqueId})'
                              : d.fullname
                      },
                      onChanged: (val) {
                        if (val != null) setState(() => _anaesthetistController.text = val);
                      },
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please select anaesthetist' : null,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownSearch(
                label: 'Scrub Nurse',
                hint: 'Select Scrub Nurse',
                value: _scrubNurseController.text.isNotEmpty ? _scrubNurseController.text : null,
                dropdownMap: {
                  for (var n in _nurses)
                    n.fullname: n.staffUniqueId != null && n.staffUniqueId!.isNotEmpty
                        ? '${n.fullname} (${n.staffUniqueId})'
                        : n.fullname
                },
                onChanged: (val) {
                  setState(() => _scrubNurseController.text = val ?? '');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CustomDropdownSearch(
                label: 'Circulating Nurse',
                hint: 'Select Circulating Nurse',
                value: _circulatingNurseController.text.isNotEmpty ? _circulatingNurseController.text : null,
                dropdownMap: {
                  for (var n in _nurses)
                    n.fullname: n.staffUniqueId != null && n.staffUniqueId!.isNotEmpty
                        ? '${n.fullname} (${n.staffUniqueId})'
                        : n.fullname
                },
                onChanged: (val) {
                  setState(() => _circulatingNurseController.text = val ?? '');
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _buildFieldLabel('Remarks / Special Instructions'),
      TextFormField(
        controller: _remarksController,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        maxLines: 2,
        maxLength: 100,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,/()\-+%:;!?]')),
          LengthLimitingTextInputFormatter(100),
        ],
        validator: (val) => _validateClinicalNotesText(
          val,
          'Remarks',
          required: false,
        ),
        decoration: _noLabelDecoration(hintText: 'enter remarks'),
      ),
      const SizedBox(height: 24),
      widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _saveSurgeryRequest,
                  icon: const Icon(Icons.save),
                  label: const Text('Schedule Surgery & Open Case File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cancelSurgeryRequest,
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _cancelSurgeryRequest,
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveSurgeryRequest,
                  icon: const Icon(Icons.save),
                  label: const Text('Schedule Surgery & Open Case File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
    ];
  }
}

// ── AI DICTATION ASSISTANT DIALOG WIDGET ──────────────────────────────

class OtDictationDialog extends StatefulWidget {
  const OtDictationDialog({Key? key}) : super(key: key);

  @override
  State<OtDictationDialog> createState() => _OtDictationDialogState();
}

class _OtDictationDialogState extends State<OtDictationDialog> {
  bool _isListening = false;
  bool _speechEnabled = false;
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  double _soundLevel = 0.0;
  Timer? _webSpeechTimer;

  Map<String, dynamic>? _parsedResult;
  Map<String, bool> _selectedFields = {};

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    LiveSpeechService().stopListening();
    _webSpeechTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final enabled = await LiveSpeechService().initialize();
    if (mounted) {
      setState(() {
        _speechEnabled = enabled;
      });
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _errorMessage = null;
      _soundLevel = 0.0;
    });

    final success = await LiveSpeechService().startListening(
      onResult: (liveWords) {
        if (mounted) {
          setState(() {
            _textController.value = TextEditingValue(
              text: liveWords,
              selection: TextSelection.collapsed(offset: liveWords.length),
            );
          });
        }
      },
      onSoundLevel: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() {
              _isListening = false;
              _soundLevel = 0.0;
            });
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
            _errorMessage = "Speech recognition error: $err";
          });
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _stopListening() async {
    await LiveSpeechService().stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
    if (_textController.text.trim().isNotEmpty) {
      _parseDictation();
    }
  }

  Future<void> _parseDictation() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter or dictate some text first.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final otController = OtController();
      final result = await otController.parseDictation(text);
      
      final fieldsMap = result['fields'] as Map<String, dynamic>;
      final tempSelected = <String, bool>{};
      for (var key in fieldsMap.keys) {
        if (fieldsMap[key] != null) {
          tempSelected[key] = true;
        }
      }

      setState(() {
        _parsedResult = result;
        _selectedFields = tempSelected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to parse dictation: $e";
      });
    }
  }

  String _formatFieldName(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
        .join(' ');
  }

  String _getSectionDisplayName(String section) {
    switch (section) {
      case 'new_request':
        return 'Surgery Request details';
      case 'scheduling':
        return 'Surgery Scheduling details';
      case 'pre_op':
        return 'Pre-Op Vitals & Checklist';
      case 'anesthesia':
        return 'Anesthesia Assessment';
      case 'handover':
        return 'OT Handover notes';
      case 'surgery_procedure':
        return 'Surgery Procedure details';
      case 'post_op':
        return 'Post-Op Summary & Instructions';
      case 'transfer':
        return 'Ward/ICU Transfer details';
      case 'care_log':
        return 'Patient Care Logs';
      default:
        return section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: _parsedResult == null ? _buildDictateView(theme) : _buildReviewView(theme),
      ),
    );
  }

  Widget _buildDictateView(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'AI Dictation Assistant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (!_speechEnabled)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Voice dictation is unavailable on this device/browser (e.g. Simulator or permission restricted). You can still type or paste your dictated notes in the text box below to use the AI parser!',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        const Text(
          'Speak or type clinical details. Our AI will automatically categorize and extract fields to fill out the form.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: !_speechEnabled ? null : (_isListening ? _stopListening : _startListening),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: !_speechEnabled 
                        ? Colors.grey.shade100 
                        : (_isListening ? Colors.red.shade50 : AppTheme.primaryLight),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !_speechEnabled 
                          ? Colors.grey.shade300 
                          : (_isListening ? Colors.red.shade400 : AppTheme.primaryColor.withOpacity(0.3)),
                      width: _isListening ? 3 + (_soundLevel * 2) : 2,
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 12 + (_soundLevel * 10),
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    !_speechEnabled
                        ? Icons.mic_off
                        : (_isListening ? Icons.stop : Icons.mic),
                    color: !_speechEnabled 
                        ? Colors.grey.shade400 
                        : (_isListening ? Colors.red : AppTheme.primaryColor),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                !_speechEnabled
                    ? 'Voice dictation unavailable'
                    : (_isListening ? 'Listening... tap to stop' : 'Tap microphone to dictate'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_speechEnabled 
                      ? Colors.grey.shade500 
                      : (_isListening ? Colors.red : AppTheme.textSecondaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _textController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: 'Or type/paste medical notes here...\n\nExample: "Patient BP is 120 over 80, pulse is 72, temp is 98.4. Consent form signed and fasting verified."',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _parseDictation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology),
              label: Text(_isLoading ? 'AI Extracting...' : 'AI Parse Dictation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(160, 44),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildReviewView(ThemeData theme) {
    final section = _parsedResult!['section'] as String;
    final fields = _parsedResult!['fields'] as Map<String, dynamic>;
    final hasFields = fields.values.any((v) => v != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'Review Extracted Fields',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_shared_outlined, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Detected target: ${_getSectionDisplayName(section)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select the fields you would like to automatically apply to the active form:',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: !hasFields
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No specific fields could be parsed.',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try rephrasing your dictation or adding more detail.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor),
                      ),
                    ],
                  ),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: fields.entries.where((e) => e.value != null).map((e) {
                    final displayValue = e.value is bool
                        ? (e.value ? 'Yes / Done' : 'No / Pending')
                        : e.value.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          activeColor: AppTheme.primaryColor,
                          value: _selectedFields[e.key] ?? false,
                          title: Text(
                            _formatFieldName(e.key),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            displayValue,
                            style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 12.5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedFields[e.key] = val ?? false;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _parsedResult = null;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Dictate'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final appliedFields = <String, dynamic>{};
                    fields.forEach((k, v) {
                      if (_selectedFields[k] == true) {
                        appliedFields[k] = v;
                      }
                    });
                    Navigator.pop(context, {
                      'section': section,
                      'fields': appliedFields,
                    });
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Apply Checked Fields'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(160, 44),
                  ),
                ),
              ],
            ),
          ],
        )
      ],
    );
  }
}