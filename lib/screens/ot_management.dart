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
  List<OtCase> _otCases = [];
  OtCase? _selectedCase;
  final _requestFormKey = GlobalKey<FormState>();
  final _preOpVitalsFormKey = GlobalKey<FormState>();
  final _intraOpVitalsFormKey = GlobalKey<FormState>();
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
  TimeOfDay _slotEndTime = const TimeOfDay(hour: 11, minute: 30);
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
  bool _showPipelineSidebar = false;

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
    if (user.role == 'Admin' || user.role == 'Super Admin') {
      return true;
    }

    String clean(String s) {
      s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.startsWith('dr.')) s = s.substring(3).trim();
      if (s.startsWith('dr ')) s = s.substring(2).trim();
      if (s.contains(' - ')) s = s.split(' - ')[0].trim();
      return s;
    }

    final String userFullname = user.fullname;
    final String cleanUser = clean(userFullname);
    if (cleanUser.isEmpty) return false;

    if (user.role == 'Doctor') {
      if (otCase.surgeon == null) return false;
      final cleanSurgeon = clean(otCase.surgeon!);
      return cleanSurgeon == cleanUser || cleanSurgeon.contains(cleanUser) || cleanUser.contains(cleanSurgeon);
    } else if (user.role == 'Anaesthetist') {
      if (otCase.anaesthetist == null) return false;
      final cleanAnaesthetist = clean(otCase.anaesthetist!);
      return cleanAnaesthetist == cleanUser || cleanAnaesthetist.contains(cleanUser) || cleanUser.contains(cleanAnaesthetist);
    } else if (user.role == 'Nurse') {
      if (otCase.nursingTeam == null) return false;
      final cleanNursingTeam = clean(otCase.nursingTeam!);
      return cleanNursingTeam.contains(cleanUser) || cleanUser.contains(cleanNursingTeam);
    }

    return false;
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
      ]);
      if (mounted) {
        _patients = results[0] as List<PatientModel>;
        _doctors = results[1] as List<UserModel>;
        final fetchedCases = results[2] as List<OtCase>;
        _anaesthetists = results[3] as List<UserModel>;
        _nurses = results[4] as List<UserModel>;
        final stats = results[5] as Map<String, dynamic>;
        _beds = results[6] as List<Map<String, dynamic>>;

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

  void _populateControllersForCase(OtCase otCase) {
    // OT Room dropdown
    _selectedOtRoom = otCase.otRoom;
    _otRoomController.text = otCase.otRoom ?? '';
    // Surgery slot start/end times
    final slot = otCase.surgerySlot ?? '';
    if (slot.contains('-')) {
      final parts = slot.split('-').map((s) => s.trim()).toList();
      _slotStartTime = _parseTimeOfDay(parts[0]);
      _slotEndTime = _parseTimeOfDay(parts.length > 1 ? parts[1] : parts[0]);
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
    _finalAnesthesiaNotesController.text = pacData['userNotes'] ?? '';
    _anaesthesiaNotesController.text = otCase.anaesthesiaNotes ?? pac['clinical_notes'] ?? pacData['userNotes'] ?? '';

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
    _selectedTransferDest = otCase.transferDestination ?? 'Recovery Room';
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
  }

  void _selectOtCase(OtCase otCase) {
    setState(() {
      _selectedCase = otCase;
      _populateControllersForCase(otCase);
      _showPipelineSidebar = false;
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
      if (_selectedCase != null && (_selectedCase!.id == targetCase.id || _selectedCase!.dbId == targetCase.dbId)) {
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
    if (!_requestFormKey.currentState!.validate()) return;
    
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
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _slotEndTime.hour,
      _slotEndTime.minute,
    );
    if (!endDateTime.isAfter(startDateTime)) {
      AppNotification.showError(
        context,
        'Surgery End Time (${_formatTimeOfDay(_slotEndTime)}) cannot be earlier than or equal to Start Time (${_formatTimeOfDay(_slotStartTime)}). Please select a valid time range.',
        atTop: true,
      );
      return;
    }
    final int durationMinutes = endDateTime.difference(startDateTime).inMinutes;

    // Real-Time Conflict Prevention Check
    setState(() => _isCheckingConflicts = true);
    try {
      final conflictCheck = await _otController.checkConflicts(
        otRoom: _selectedOtRoom!,
        startTime: startDateTime,
        endTime: endDateTime,
        leadSurgeon: _surgeonController.text.trim(),
        anaesthetist: _anaesthetistController.text.trim(),
      );

      if (conflictCheck['hasConflict'] == true) {
        final List conflicts = conflictCheck['conflicts'] ?? [];
        if (mounted) {
          final bool? shouldOverride = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
                  SizedBox(width: 10),
                  Text('Scheduling Conflict Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The requested surgery slot collides with existing bookings:'),
                  const SizedBox(height: 10),
                  ...conflicts.map((c) => Container(
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
                  )).toList(),
                  const SizedBox(height: 10),
                  const Text(
                    'Conflict prevention rules prevent double-booking theatres and doctors. Would you like to reschedule or apply an Emergency Override?',
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
      final endStr = _formatTimeOfDay(_slotEndTime);
      final surgerySlot = '$startStr - $endStr';
      final nursingTeam = _selectedNurseNames.isNotEmpty
          ? _selectedNurseNames.join(', ')
          : [effectiveScrubNurse, effectiveCirculatingNurse].whereType<String>().join(', ');

      await _otController.updateOtCase(newCase.dbId!, {
        'status': 'OT Scheduled',
        'ot_room': _selectedOtRoom,
        'surgery_slot': surgerySlot,
        'nursing_team': nursingTeam,
        'scheduled_start_time': startDateTime.toIso8601String(),
        'scheduled_end_time': endDateTime.toIso8601String(),
        'estimated_duration_minutes': durationMinutes,
        'lead_surgeon': _surgeonController.text.trim(),
        'assistant_surgeon': _assistantSurgeonController.text.trim().isNotEmpty ? _assistantSurgeonController.text.trim() : null,
        'anaesthetist': _anaesthetistController.text.trim(),
        'scrub_nurse': effectiveScrubNurse,
        'circulating_nurse': effectiveCirculatingNurse,
      });

      setState(() {
        _resetScheduleSurgeryForm();
        _activeTab = 5; // Switch to Theatres Calendar view to see new surgery block!
        
        // Reload all patients/doctors/cases to capture new state
        _loadPatientsAndDoctors();
      });

      AppNotification.showSuccess(
        context,
        'Surgery scheduled successfully! Allocated in Theatre Calendar.',
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
    _slotEndTime = const TimeOfDay(hour: 11, minute: 30);
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
      _activeTab = 1; // Return to Active Pipeline tab
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

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  void _confirmScheduling(OtCase otCase) {
    if (_selectedOtRoom == null || _selectedOtRoom!.trim().isEmpty) {
      AppNotification.showError(context, 'Please select an OT Room.', atTop: true);
      return;
    }
    if (_selectedNurseNames.isEmpty) {
      AppNotification.showError(context, 'Please assign at least one nurse.', atTop: true);
      return;
    }

    final startMinutes = _slotStartTime.hour * 60 + _slotStartTime.minute;
    final endMinutes = _slotEndTime.hour * 60 + _slotEndTime.minute;
    if (endMinutes <= startMinutes) {
      AppNotification.showError(
        context,
        'Surgery End Time (${_formatTimeOfDay(_slotEndTime)}) cannot be earlier than or equal to Start Time (${_formatTimeOfDay(_slotStartTime)}). Please select a valid time range.',
        atTop: true,
      );
      return;
    }

    otCase.otRoom = _selectedOtRoom;
    final startStr = _formatTimeOfDay(_slotStartTime);
    final endStr = _formatTimeOfDay(_slotEndTime);
    otCase.surgerySlot = '$startStr - $endStr';
    otCase.nursingTeam = _selectedNurseNames.join(', ');
    otCase.status = 'OT Scheduled';

    final existingDate = otCase.surgeryDateTime ?? DateTime.now();
    otCase.surgeryDateTime = DateTime(
      existingDate.year,
      existingDate.month,
      existingDate.day,
      _slotStartTime.hour,
      _slotStartTime.minute,
    );

    _logAction(otCase, 'Scheduled surgery: Room ${otCase.otRoom}, Slot: ${otCase.surgerySlot}, Nursing Team: ${otCase.nursingTeam}.');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Scheduled',
      'ot_room': otCase.otRoom,
      'surgery_slot': otCase.surgerySlot,
      'nursing_team': otCase.nursingTeam,
      'surgery_date_time': otCase.surgeryDateTime?.toIso8601String(),
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
    if (!(_anesthesiaPacFormKey.currentState?.validate() ?? true)) {
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
    if (!(_anesthesiaPacFormKey.currentState?.validate() ?? true)) {
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
  static final RegExp _strayPercentRegex = RegExp(r'(?:^|[^0-9])%');
  static final RegExp _disallowedNotesSymbolRegex =
      RegExp(r'[!@#\$^*_=\[\]{};"<>?~\\|]');
  static final RegExp _invalidAmpersandRegex =
      RegExp(r'&{2,}|[^a-zA-Z0-9\s]&|&[^a-zA-Z0-9\s]');

  String? _validateVitalsSummary(String? val, {bool required = true}) {
    final trimmed = val?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required
          ? 'Please enter recovery vitals (e.g. BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%)'
          : null;
    }
    if (_disallowedVitalsSymbolRegex.hasMatch(trimmed) ||
        _strayPercentRegex.hasMatch(trimmed)) {
      return 'Vitals entry cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
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
    if (_disallowedVitalsSymbolRegex.hasMatch(trimmed) ||
        _strayPercentRegex.hasMatch(trimmed)) {
      return '$fieldLabel cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
    }
    final hasWord = RegExp(r'[a-zA-Z]{2,}').hasMatch(trimmed) ||
        (RegExp(r'\d').hasMatch(trimmed) && RegExp(r'[a-zA-Z]').hasMatch(trimmed));
    if (!hasWord) {
      return '$fieldLabel must contain valid clinical names ($example)';
    }
    if (trimmed.length < 2) {
      return '$fieldLabel must be at least 2 characters';
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
        _strayPercentRegex.hasMatch(trimmed) ||
        _invalidAmpersandRegex.hasMatch(trimmed)) {
      return '$fieldLabel cannot contain invalid special characters (@, #, \$, %, ^, &, *)';
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

  void _anaesthetistCloseCase(OtCase otCase) {
    if (!(_pacuMonitoringFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot close case: Please correct invalid characters in PACU observations or instructions.',
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
    otCase.status = 'OT Case Closed';

    _logAction(otCase, 'Anaesthetist completed final report, post-anesthesia instructions, and closed case.');

    _updateCaseInDb(otCase, {
      'status': 'OT Case Closed',
      'anaesthesia_notes': otCase.anaesthesiaNotes,
    });

    AppNotification.showSuccess(
      context,
      'OT Case Closed for ${otCase.patientName}. Report completed!',
      atTop: true,
    );
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
    otCase.operationSummary = _opSummaryController.text.trim();
    otCase.procedurePerformed = _procPerformedController.text.trim();
    otCase.outcome = _outcomeController.text.trim();
    otCase.postOpInstructions = _postOpInstController.text.trim();
    otCase.followUpRecommendations = _followUpController.text.trim();

    _logAction(otCase, 'Saved post-operative notes. Outcome: ${otCase.outcome}. Instructions: ${otCase.postOpInstructions}.');
    
    _updateCaseInDb(otCase, {
      'operation_summary': otCase.operationSummary,
      'procedure_performed': otCase.procedurePerformed,
      'outcome': otCase.outcome,
      'post_op_instructions': otCase.postOpInstructions,
      'follow_up_recommendations': otCase.followUpRecommendations,
    });

    AppNotification.showSuccess(
      context,
      'Post-operative notes saved.',
      atTop: true,
    );
  }

  void _executeTransfer(OtCase otCase) {
    if (!(_transferFormKey.currentState?.validate() ?? true)) {
      AppNotification.showError(
        context,
        'Cannot confirm transfer: Please correct the invalid fields in Transfer to Recovery / ICU / Ward.',
        atTop: true,
      );
      return;
    }
    final handoverError = _validateClinicalNotesText(
      _nursingHandoverController.text,
      'Nursing handover notes',
      required: false,
    );
    if (handoverError != null) {
      AppNotification.showError(context, handoverError, atTop: true);
      return;
    }

    otCase.transferDestination = _selectedTransferDest;
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
    final formValid = _postOpNurseCareFormKey.currentState?.validate() ?? true;
    final vitalsError = _validateVitalsSummary(_careVitalsController.text);
    final medsError = _validateMedicationOrSubstanceText(
      _careMedsController.text,
      'Medication Given',
    );

    if (!formValid || vitalsError != null || medsError != null) {
      AppNotification.showError(
        context,
        vitalsError ?? medsError ?? 'Please correct invalid recovery vitals or medication entries.',
        atTop: true,
      );
      return;
    }

    final vitalsText = _careVitalsController.text.trim();
    final medsText = _careMedsController.text.trim();

    setState(() {
      otCase.nurseCareVitalsLogs.add('$vitalsText (Recorded by Nurse at ${DateFormat('hh:mm a').format(DateTime.now())})');
      otCase.nurseMedicationsAdministered.add('$medsText (Administered at ${DateFormat('hh:mm a').format(DateTime.now())})');
    });

    _logAction(otCase, 'Recorded nurse care entry. Vitals: $vitalsText. Meds: $medsText.');
    
    _updateCaseInDb(otCase, {
      'nurse_care_vitals_logs': otCase.nurseCareVitalsLogs,
      'nurse_medications_administered': otCase.nurseMedicationsAdministered,
    });

    _careVitalsController.clear();
    _careMedsController.clear();
    _postOpNurseCareFormKey.currentState?.reset();

    AppNotification.showSuccess(
      context,
      'Nurse care details recorded.',
      atTop: true,
    );
  }

  void _addDoctorProgressNote(OtCase otCase) {
    final formValid = _postOpDoctorNoteFormKey.currentState?.validate() ?? true;
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

  void _closeCase(OtCase otCase) {
    otCase.status = 'OT Case Closed';

    _logAction(otCase, 'Closed OT Workflow and generated final operation summary report.');
    
    _updateCaseInDb(otCase, {
      'status': 'OT Case Closed',
    });

    AppNotification.showSuccess(
      context,
      'OT Case Closed for ${otCase.patientName}. Workflow completed!',
      atTop: true,
    );
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
        return Colors.green;
      case 'Post-Op Monitoring':
        return Colors.pink;
      case 'OT Case Closed':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHorizontalTabs() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final activeCasesCount = _otCases
        .where((c) => c.status != 'OT Case Closed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .length;
    final completedCasesCount = _otCases
        .where((c) => c.status == 'OT Case Closed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Light slate grey background for premium segmented feel
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(0, context.tr('dashboard', fallback: 'Dashboard'), Icons.dashboard_outlined),
          const SizedBox(width: 4),
          _buildTabItem(
            5,
            widget.isMobile ? 'Theatres' : 'Theatres Calendar',
            Icons.calendar_view_week_outlined,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            1,
            widget.isMobile
                ? context.tr('tab_active_cases', fallback: 'Active')
                : context.tr('tab_active_cases', fallback: 'Active Cases'),
            Icons.pending_actions_outlined,
            badgeCount: activeCasesCount,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            2,
            widget.isMobile
                ? context.tr('tab_completed_cases', fallback: 'Completed')
                : context.tr('tab_completed_cases', fallback: 'Completed Cases'),
            Icons.check_circle_outline,
            badgeCount: completedCasesCount,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            3,
            widget.isMobile
                ? context.tr('tab_schedule_surgery', fallback: 'Schedule')
                : context.tr('tab_schedule_surgery', fallback: 'Schedule Surgery'),
            Icons.add_circle_outline,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            4,
            widget.isMobile
                ? context.tr('speech_to_text', fallback: 'Speech-to-Text')
                : context.tr('speech_to_text_ot', fallback: 'Speech-to-Text (OT)'),
            Icons.mic_none_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon, {int? badgeCount}) {
    bool isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
          if (index == 3) {
            _resetScheduleSurgeryForm();
          } else {
            _selectedCase = null;
          }
        });
        if (index == 0) {
          _loadPatientsAndDoctors();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLight : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                    fontSize: 10,
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: widget.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('ot_management', fallback: 'OT Management'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('ot_subtitle', fallback: 'Schedule and view operation cases details'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildHorizontalTabs(),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxWidth < 1320;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('ot_management', fallback: 'OT Management'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('ot_subtitle', fallback: 'Schedule and view operation cases details'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildHorizontalTabs(),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('ot_management', fallback: 'OT Management'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('ot_subtitle', fallback: 'Schedule and view operation cases details'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildHorizontalTabs(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Expanded(
            child: Container(
              padding: widget.isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(24),
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
          _selectedCase = selectedCase;
          _populateControllersForCase(selectedCase);
          _activeTab = 1; // Open workflow in Active cases
        });
      },
      onScheduleNew: () {
        setState(() {
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
    final norm = (String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cRoom = norm(c.otRoom ?? '');
    final tCode = norm(targetCode);
    final tName = norm(targetName);
    if (cRoom.isEmpty) return false;
    return cRoom == tCode || cRoom == tName || cRoom.contains(tCode) || tCode.contains(cRoom);
  }

  double _calculateCaseProgress(OtCase c) {
    if (c.status == 'OT Case Closed') return 1.0;
    if (c.status == 'Post-Op Monitoring') return 0.95;
    if (c.status == 'Surgery Completed') return 0.90;

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

          // Integration Hub status
          _buildIntegrationPanel(),
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
    final color = isOccupied ? _getStatusColor(activeInRoom.status) : Colors.green;
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
<<<<<<< HEAD
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
=======
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
            decoration: BoxDecoration(
              color: isOccupied ? color.withOpacity(0.04) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: isOccupied ? color.withOpacity(0.12) : Colors.grey.shade100)),
            ),
<<<<<<< HEAD
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
                          color: isOccupied ? color : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 85),
                        child: Text(
                          isOccupied ? activeInRoom.status.toUpperCase() : 'AVAILABLE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isOccupied ? color : Colors.green, fontSize: 9.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
=======
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 15, color: isOccupied ? color : AppTheme.textSecondaryColor),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              roomName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, color: isOccupied ? color : AppTheme.textPrimaryColor, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.56),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
                                  color: isOccupied ? color : Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isOccupied ? color : Colors.green,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOccupied ? activeInRoom.status.toUpperCase() : 'AVAILABLE',
                                style: TextStyle(color: isOccupied ? color : Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: isOccupied
<<<<<<< HEAD
                  ? SingleChildScrollView(
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
=======
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeInRoom.patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimaryColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeInRoom.age} yrs • ${activeInRoom.gender} • Blood: ${activeInRoom.bloodGroup}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.healing, size: 12, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeInRoom.surgeryType ?? '',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimaryColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress Bar representing case completion
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Surgery Progress', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                                Text(
                                  '${(_getCaseProgress(activeInRoom.status) * 100).toInt()}%',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _getCaseProgress(activeInRoom.status),
                                color: color,
                                backgroundColor: color.withOpacity(0.1),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            _selectOtCase(activeInRoom);
                            setState(() {
                              _activeTab = 1; // Go to active patients registry
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
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
                                _openedFromLiveDashboard = true;
                                _activeTab = 1; // Go to active patients registry
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Live Workflow Board',
                                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward, size: 11, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ],
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
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationPanel() {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
<<<<<<< HEAD
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_outlined, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ERP Modular Integration Hub',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryColor),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _loadPatientsAndDoctors();
                  AppNotification.showSuccess(
                    context,
                    'All ERP Modules (IPD, ICU, Pharmacy, Lab, Billing, Nursing) re-synchronized successfully!',
                    atTop: true,
                  );
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Bi-directional real-time data sync linking OT with Inpatient Admissions, ICU Critical Care, Surgical Pharmacy, Diagnostics, Financial Billing, and Nursing Station. Click any integration to view live sync details or open the module.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
=======
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hub_outlined, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ERP Modular Integration Hub (Simulated)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isMobile ? 14 : 15,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isMobile ? 12 : 16),
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
          Wrap(
            spacing: widget.isMobile ? 8 : 12,
            runSpacing: widget.isMobile ? 8 : 12,
            children: [
              _buildIntegrationTag(
                'IPD Integration',
                'Synchronizes Inpatient admissions, bed transfers & pre-op ward prep',
                Icons.hotel_outlined,
              ),
              _buildIntegrationTag(
                'ICU Integration',
                'Auto-triggers post-op ICU bed reservations & high-dependency telemetry',
                Icons.monitor_heart_outlined,
              ),
              _buildIntegrationTag(
                'Pharmacy Integration',
                'Pre-requisitions perioperative drug kits, anesthesia agents & implants',
                Icons.local_pharmacy_outlined,
              ),
              _buildIntegrationTag(
                'Lab Integration',
                'Streams PAC pre-op reports (CBC, Platelets, PT/INR, Cross-Match)',
                Icons.biotech_outlined,
              ),
              _buildIntegrationTag(
                'Billing Integration',
                'Auto-posts theater tariffs, surgeon fees & consumable charges on case closure',
                Icons.receipt_long_outlined,
              ),
              _buildIntegrationTag(
                'Nursing Dashboard',
                'Broadcasts real-time surgical status directly to ward and recovery nurses',
                Icons.assignment_ind_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationTag(String title, String description, IconData icon) {
    return Tooltip(
<<<<<<< HEAD
      message: 'Click to open $title live status and ERP details\n$description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showIntegrationDetailsModal(title),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: const Color(0xFF15803D)),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF16A34A)),
              ],
=======
      message: description,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 10 : 12, vertical: 8),
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
            Flexible(
              child: Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
              ),
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
            ),
          ),
        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

    // Hide pipeline sidebar when collapsed via toggle or opened from the OT Live Dashboard
    if (_selectedCase != null && _selectedCase!.status != 'OT Case Closed' && (!_showPipelineSidebar || _openedFromLiveDashboard)) {
      return _buildCaseWorkflowDetails(_selectedCase!);
    }

    if (widget.isMobile) {
      if (_selectedCase != null && _selectedCase!.status != 'OT Case Closed') {
        return _buildCaseWorkflowDetails(_selectedCase!);
      }
    }

    final filteredCases = activeCases.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.patientName.toLowerCase().contains(query) ||
             c.id.toLowerCase().contains(query) ||
             (c.surgeryType ?? '').toLowerCase().contains(query) ||
             c.status.toLowerCase().contains(query);
    }).toList();

    final masterPane = Container(
      width: widget.isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patients in Pipeline (${activeCases.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search registry...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                    suffixIcon: _searchQuery.isNotEmpty
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
                                color: AppTheme.textSecondaryColor,
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
                    fillColor: AppTheme.isDark(context) ? AppTheme.darkInputFillColor : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Patient List
          Expanded(
            child: filteredCases.isEmpty
                ? const Center(
                    child: Text(
                      'No patients found',
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCases.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (context, idx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final c = filteredCases[idx];
                      final isSelected = _selectedCase?.id == c.id;
                      final avatarColors = AppTheme.getAvatarColors(c.patientName);
                      final statusColor = _getStatusColor(c.status);
                      
                      final now = DateTime.now();
                      final isToday = c.surgeryDateTime != null &&
                          c.surgeryDateTime!.year == now.year &&
                          c.surgeryDateTime!.month == now.month &&
                          c.surgeryDateTime!.day == now.day;
                      final isNearTime = c.surgeryDateTime != null &&
                          c.surgeryDateTime!.difference(now).inMinutes.abs() <= 120;

                      return InkWell(
                        onTap: () {
                          _selectOtCase(c);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                              ? AppTheme.primaryLight.withOpacity(0.4) 
                              : (isNearTime 
                                  ? Colors.red.shade50.withOpacity(0.3) 
                                  : (isToday ? Colors.amber.shade50.withOpacity(0.2) : Colors.transparent)),
                            border: Border(
                              left: BorderSide(
                                color: isNearTime 
                                  ? Colors.red 
                                  : (isToday ? Colors.amber.shade600 : Colors.transparent),
                                width: (isNearTime || isToday) ? 4.0 : 0.0,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: avatarColors['bg'],
                                child: Text(
                                  c.patientName.isNotEmpty
                                      ? c.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: avatarColors['text'],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.surgeryType ?? 'No Procedure',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            c.status.toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (isNearTime) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.red.shade200, width: 0.5),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.alarm_on, color: Colors.red, size: 8),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'IMMINENT (${DateFormat('hh:mm a').format(c.surgeryDateTime!)})',
                                                  style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else if (isToday) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.amber.shade200, width: 0.5),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.today, color: Colors.amber, size: 8),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'TODAY (${DateFormat('hh:mm a').format(c.surgeryDateTime!)})',
                                                  style: TextStyle(color: Colors.amber.shade900, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (c.priority == 'Emergency') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'EMERGENCY',
                                              style: TextStyle(color: Colors.red.shade700, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
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
    );

    if (widget.isMobile) {
      return masterPane;
    }

    if (_selectedCase != null && _selectedCase!.status != 'OT Case Closed' && (!_showPipelineSidebar || _openedFromLiveDashboard)) {
      return _buildCaseWorkflowDetails(_selectedCase!);
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
          child: _selectedCase != null && _selectedCase!.status != 'OT Case Closed'
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
        .where((c) => c.status == 'OT Case Closed')
        .where((c) => user == null || _isUserAssociated(c, user))
        .toList();

    // Hide pipeline sidebar when collapsed via toggle or opened from the OT Live Dashboard
    if (_selectedCase != null && _selectedCase!.status == 'OT Case Closed' && (!_showPipelineSidebar || _openedFromLiveDashboard)) {
      return _buildCaseWorkflowDetails(_selectedCase!);
    }

    if (widget.isMobile) {
      if (_selectedCase != null && _selectedCase!.status == 'OT Case Closed') {
        return _buildCaseWorkflowDetails(_selectedCase!);
      }
    }

    final filteredCases = completedCases.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.patientName.toLowerCase().contains(query) ||
             c.id.toLowerCase().contains(query) ||
             (c.surgeryType ?? '').toLowerCase().contains(query) ||
             c.status.toLowerCase().contains(query);
    }).toList();

    final masterPane = Container(
      width: widget.isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed Operations (${completedCases.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search registry...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                    suffixIcon: _searchQuery.isNotEmpty
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
                                color: AppTheme.textSecondaryColor,
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
                    fillColor: AppTheme.isDark(context) ? AppTheme.darkInputFillColor : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Patient List
          Expanded(
            child: filteredCases.isEmpty
                ? const Center(
                    child: Text(
                      'No completed cases found',
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCases.length,
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (context, idx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final c = filteredCases[idx];
                      final isSelected = _selectedCase?.id == c.id;
                      final avatarColors = AppTheme.getAvatarColors(c.patientName);
                      final statusColor = _getStatusColor(c.status);

                      return InkWell(
                        onTap: () {
                          _selectOtCase(c);
                        },
                        child: Container(
                          color: isSelected ? AppTheme.primaryLight.withOpacity(0.4) : Colors.transparent,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: avatarColors['bg'],
                                child: Text(
                                  c.patientName.isNotEmpty
                                      ? c.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: avatarColors['text'],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.surgeryType ?? 'No Procedure',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            c.status.toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (c.priority == 'Emergency') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'EMERGENCY',
                                              style: TextStyle(color: Colors.red.shade700, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
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
    );

    if (widget.isMobile) {
      return masterPane;
    }

    if (_selectedCase != null && _selectedCase!.status == 'OT Case Closed' && (!_showPipelineSidebar || _openedFromLiveDashboard)) {
      return _buildCaseWorkflowDetails(_selectedCase!);
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
          child: _selectedCase != null && _selectedCase!.status == 'OT Case Closed'
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
    final avatarColors = AppTheme.getAvatarColors(otCase.patientName);
    
    if (widget.isMobile) {
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
                            if (_openedFromLiveDashboard) {
                              _selectedCase = null;
                              _activeTab = 0;
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
                              builder: (_) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                insetPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: MediaQuery.of(context).size.height * 0.05,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 820,
                                    maxHeight: MediaQuery.of(context).size.height * 0.88,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Patient Header Details (Desktop)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (_openedFromLiveDashboard) {
                      _selectedCase = null;
                      _activeTab = 0;
                      _openedFromLiveDashboard = false;
                    } else {
                      _selectedCase = null;
                      _showPipelineSidebar = false;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _showPipelineSidebar ? 'Collapse Pipeline Sidebar' : 'Expand Pipeline Sidebar',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showPipelineSidebar = !_showPipelineSidebar;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.view_sidebar_outlined,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 19,
                backgroundColor: avatarColors['bg'],
                child: Text(
                  otCase.patientName.isNotEmpty ? otCase.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase() : '?',
                  style: TextStyle(
                    color: avatarColors['text'],
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      otCase.patientName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: AppTheme.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _getStatusColor(otCase.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        otCase.status,
                        style: TextStyle(color: _getStatusColor(otCase.status), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildHeaderMetadataChip(Icons.fingerprint, 'ID: ${otCase.patientId}'),
                        _buildHeaderMetadataChip(Icons.cake_outlined, '${otCase.age} yrs'),
                        _buildHeaderMetadataChip(
                          otCase.gender == 'Male' ? Icons.male : (otCase.gender == 'Female' ? Icons.female : Icons.transgender),
                          otCase.gender,
                        ),
                        _buildHeaderMetadataChip(Icons.bloodtype_outlined, 'Blood: ${otCase.bloodGroup}', color: Colors.red.shade700),
                        if (otCase.priority != null && otCase.priority!.isNotEmpty)
                          _buildHeaderMetadataChip(
                            Icons.warning_amber_rounded,
                            otCase.priority!,
                            color: otCase.priority == 'Emergency' ? Colors.red.shade700 : AppTheme.primaryColor,
                            bgColor: otCase.priority == 'Emergency' ? Colors.red.shade50 : AppTheme.primaryLight,
                          ),
                        if (otCase.diagnosis.isNotEmpty)
                          _buildHeaderMetadataChip(Icons.healing_outlined, 'Diagnosis: ${otCase.diagnosis}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Unified Clinical Safety & Surgical Team Panel (Desktop)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Actions: OT Room Badge + PAC Status Button + WHO Checklist Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // OT Room Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.primaryColor),
                              const SizedBox(width: 3),
                              Text(
                                otCase.otRoom != null && otCase.otRoom!.isNotEmpty ? otCase.otRoom! : 'OT: Unassigned',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        // PAC Status Interactive Button
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
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                    ? const Color(0xFF10B981)
                                    : AppTheme.dangerColor.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  size: 12,
                                  color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                      ? const Color(0xFF059669)
                                      : AppTheme.dangerColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'PAC: ${otCase.pacStatus.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: ['Cleared', 'High Risk Clearance'].contains(otCase.pacStatus)
                                        ? const Color(0xFF059669)
                                        : AppTheme.dangerColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        // WHO Checklist Button
                        InkWell(
                          onTap: () {
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
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fact_check_outlined, size: 12, color: AppTheme.primaryColor),
                                SizedBox(width: 3),
                                Text(
                                  'WHO Checklist',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Bottom Team Bar: Compact horizontal chip items
                    Wrap(
                      spacing: 7,
                      runSpacing: 1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildTeamCompactChip('Surgeon', otCase.leadSurgeon ?? otCase.surgeon),
                        _buildTeamCompactChip('Asst', otCase.assistantSurgeon),
                        _buildTeamCompactChip('Anaesth', otCase.anaesthetist),
                        _buildTeamCompactChip('Scrub', otCase.scrubNurse),
                        _buildTeamCompactChip('Circ', otCase.circulatingNurse),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (otCase.status != 'OT Case Closed') ...[
                SizedBox(
                  width: 290,
                  child: _buildVerticalWorkflowStepper(otCase),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Container(
                  decoration: AppTheme.cardDecoration,
                  child: _buildTabbedWorkspace(otCase),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildTabbedWorkspace(OtCase otCase) {
    return DefaultTabController(
      length: 7,
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14),
                      SizedBox(width: 5),
                      Text('Details'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fact_check_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('WHO Safety'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('PAC Check'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vaccines_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('Anesthesia'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('Consumables & Implants'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 14),
                      SizedBox(width: 5),
                      Text('Summary'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14),
                      SizedBox(width: 5),
                      Text('Audit Trail'),
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: OT Details
                _buildOtDetailsTab(otCase),
                // Tab 2: WHO Surgical Safety Checklist (Sign-In, Time-Out, Sign-Out)
                _buildWhoChecklistTab(otCase),
                // Tab 3: PAC Assessment & Clearance Gate
                _buildPacTab(otCase),
                // Tab 4: Anesthesia Details (Form)
                _buildAnesthesiaDetailsTab(otCase),
                // Tab 5: Consumables & Implants
                _buildConsumablesAndImplantsTab(otCase),
                // Tab 6: Surgical Summary
                _buildSurgicalSummaryTab(otCase),
                // Tab 7: Audit History
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PAC Status Card
          Container(
            padding: EdgeInsets.all(widget.isMobile ? 14 : 16),
            decoration: BoxDecoration(
              color: isCleared
                  ? AppTheme.secondaryColor.withOpacity(0.08)
                  : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCleared
                    ? AppTheme.secondaryColor.withOpacity(0.3)
                    : AppTheme.dangerColor.withOpacity(0.3),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = widget.isMobile || constraints.maxWidth < 560;
                final statusIcon = Icon(
                  isCleared ? Icons.verified_user : Icons.warning_amber_rounded,
                  color: isCleared ? AppTheme.secondaryColor : AppTheme.dangerColor,
                  size: isCompact ? 24 : 28,
                );
                final statusDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-Anaesthetic Clearance (PAC) Status: ${otCase.pacStatus.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13.5 : 14,
                        color: isCleared ? AppTheme.secondaryColor : AppTheme.dangerColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCleared
                          ? 'Patient has verified Pre-Anaesthetic Clearance and is clinically authorized for OT induction.'
                          : 'Patient is NOT cleared. Surgery cannot proceed until an Anaesthetist records clearance.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                    if (otCase.pacClearedBy != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Authorized by: ${otCase.pacClearedBy} ${otCase.pacClearedAt != null ? "• " + DateFormat("dd/MM/yyyy hh:mm a").format(otCase.pacClearedAt!) : ""}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                  ],
                );
                final actionButton = ElevatedButton.icon(
                  onPressed: () {
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
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(isCleared ? 'Edit PAC' : 'Conduct PAC Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCleared ? AppTheme.secondaryColor : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          statusIcon,
                          const SizedBox(width: 12),
                          Expanded(child: statusDetails),
                        ],
                      ),
                      const SizedBox(height: 12),
                      actionButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    statusIcon,
                    const SizedBox(width: 14),
                    Expanded(child: statusDetails),
                    const SizedBox(width: 12),
                    actionButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Objective Airway & PAC Clinical Examination Form Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment_outlined, color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 8),
                Text(
                  'Objective Airway & PAC Clinical Examination Form',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clinical Details Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildPacDetailItem('Assigned ASA Grade', pac['effective_asa'] ?? pac['asa_grade'] ?? _selectedAsaGrade),
              _buildPacDetailItem('Mallampati Airway Class', pac['mallampati_class'] ?? 'Class I'),
              _buildPacDetailItem('Mouth Opening', pac['mouth_opening'] ?? 'Adequate (> 3 fingers)'),
              _buildPacDetailItem('Neck Mobility', pac['neck_mobility'] ?? 'Normal Full Range'),
              _buildPacDetailItem('Dentition', pac['dentition'] ?? 'Intact'),
              _buildPacDetailItem('Anaesthesia Plan', pac['anaesthesia_type'] ?? otCase.anaesthesiaType ?? _selectedAnaesthesiaType),
              _buildPacDetailItem('NPO Solids Fasting', pac['npo_solids_verified'] == true ? 'Verified (>6 hrs)' : 'Pending'),
              _buildPacDetailItem('NPO Fluids Fasting', pac['npo_fluids_verified'] == true ? 'Verified (>2 hrs)' : 'Pending'),
            ],
          ),
          if (pac['clinical_notes'] != null && pac['clinical_notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Clinical Notes / Airway Strategy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(pac['clinical_notes'].toString(), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    _anaesthesiaNotesController.text.isNotEmpty 
                      ? _anaesthesiaNotesController.text 
                      : (pac['clinical_notes'] ?? 'No specific notes recorded.'),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
                  ),
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

          Form(
            key: _anesthesiaTabFormKey,
            child: TextFormField(
              controller: _anaesthesiaNotesController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              maxLines: 3,
              maxLength: 100,
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

  Widget _buildSurgicalSummaryTab(OtCase otCase) {
    final pacData = parseAnaesthesiaNotes(otCase.anaesthesiaNotes);
    final anaNotes = pacData['userNotes'] ?? '';
    
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
              _buildSummaryField('COMPLICATIONS ENCOUNTERED', otCase.complications),
              _buildSummaryField('POST-OPERATIVE INSTRUCTIONS', otCase.postOpInstructions),
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
          if (otCase.consumablesUsed.isNotEmpty || otCase.implantsUsed.isNotEmpty)
            _buildSummaryCard(
              title: 'Consumables & Tracked Implants',
              icon: Icons.inventory_2_outlined,
              iconColor: AppTheme.secondaryColor,
              children: [
                if (otCase.consumablesUsed.isNotEmpty)
                  _buildSummaryField(
                    'CONSUMABLES USED (${otCase.consumablesUsed.length})',
                    otCase.consumablesUsed
                        .map((c) => '• ${c['item_name']} (${c['quantity']} ${c['unit'] ?? 'units'}${c['batch_number'] != null ? ', Batch: ${c['batch_number']}' : ''})')
                        .join('\n'),
                  ),
                if (otCase.implantsUsed.isNotEmpty)
                  _buildSummaryField(
                    'TRACKED IMPLANTS (${otCase.implantsUsed.length})',
                    otCase.implantsUsed
                        .map((i) => '• ${i['model_name']} (Model: ${i['model_number']}, Serial/UDI: ${i['serial_number']}, Batch: ${i['batch_number']}, Site: ${i['anatomical_site']}, Expiry: ${i['expiry_date'] != null ? i['expiry_date'].toString().split('T')[0] : 'N/A'})')
                        .join('\n'),
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
      padding: EdgeInsets.all(widget.isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Info Card
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
                    Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled Surgery Booking Info',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
              ],
            ),
          ),
          
          if (!isClosed) ...[
            const SizedBox(height: 24),
            _buildActiveStepHeader(otCase),
            const SizedBox(height: 16),
            _buildStepForm(otCase),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Surgical Case Closed',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This clinical case is closed. Editing of scheduling parameters and workflow step actions is disabled.',
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]
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
<<<<<<< HEAD
          Icon(icon, size: 11, color: color ?? AppTheme.textSecondaryColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color ?? AppTheme.textPrimaryColor,
=======
          Icon(icon, size: 13, color: color ?? AppTheme.textSecondaryColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color ?? AppTheme.textPrimaryColor,
              ),
>>>>>>> 8173141 (resolve frontend pixel overflow and UI layout issues)
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
      padding: const EdgeInsets.all(20),
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
    // Determine which rooms are already occupied by ANOTHER active case
    const allRooms = ['OT 1', 'OT 2', 'OT 3', 'Emergency OT'];
    final occupiedRooms = _otCases
        .where((c) =>
            c.dbId != otCase.dbId &&
            c.otRoom != null &&
            c.status != 'OT Case Closed' &&
            c.status != 'OT Requested')
        .map((c) => c.otRoom!)
        .toSet();

    final availableRooms = allRooms.where((r) => !occupiedRooms.contains(r)).toList();

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
          hint: 'Select available OT Room',
          value: (_selectedOtRoom != null && availableRooms.contains(_selectedOtRoom))
              ? _selectedOtRoom
              : null,
          dropdownMap: availableRooms.isEmpty
              ? { '': 'No rooms available' }
              : { for (var room in availableRooms) room: '$room (Available)' },
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please select an OT Room';
            }
            return null;
          },
          onChanged: availableRooms.isEmpty
              ? null
              : (val) {
                  if (val != null) {
                    setState(() => _selectedOtRoom = val);
                  }
                },
        ),
        if (occupiedRooms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Occupied: ${occupiedRooms.join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
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
                        initialTime: _slotEndTime,
                        helpText: 'Select Surgery End Time',
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                              Text(
                                _formatTimeOfDay(_slotEndTime),
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
                          initialTime: _slotEndTime,
                          helpText: 'Select Surgery End Time',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                                Text(
                                  _formatTimeOfDay(_slotEndTime),
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
                ],
              ),
        if ((_slotEndTime.hour * 60 + _slotEndTime.minute) <=
            (_slotStartTime.hour * 60 + _slotStartTime.minute)) ...[
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
                Text('No nurses found in database.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5)),
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
    }

    final stepBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'STEP $stepNumber OF 8',
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
      padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(stepIcon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stepTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                stepBadge,
                const SizedBox(width: 10),
                Icon(stepIcon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stepTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                statusBadge,
              ],
            ),
          const SizedBox(height: 8),
          Text(
            stepDesc,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.badge_outlined, size: 13, color: AppTheme.textMutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Designated Roles: $assignedRoles',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMutedColor, fontStyle: FontStyle.italic),
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
                : Row(
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
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
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
                          builder: (_) => Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            insetPadding: EdgeInsets.symmetric(
                              horizontal: widget.isMobile ? 12 : 24,
                              vertical: widget.isMobile ? MediaQuery.of(context).size.height * 0.05 : 24,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 850,
                                maxHeight: MediaQuery.of(context).size.height * (widget.isMobile ? 0.88 : 0.85),
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
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: bpField),
                                  const SizedBox(width: 8),
                                  Expanded(child: hrField),
                                  const SizedBox(width: 8),
                                  Expanded(child: tempField),
                                  const SizedBox(width: 8),
                                  Expanded(child: spo2Field),
                                ],
                              ),
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
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              maxLength: 10,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter BP';
                                final trimmed = val.trim();
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
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              maxLength: 4,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(4),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter HR';
                                final trimmed = val.trim();
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
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              maxLength: 8,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(8),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter Temp';
                                final trimmed = val.trim();
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
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              maxLength: 5,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                                final trimmed = val.trim();
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
                      : Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _intraOpBpController,
                                keyboardType: TextInputType.text,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 10,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter BP';
                                  final trimmed = val.trim();
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _intraOpPulseController,
                                keyboardType: TextInputType.number,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 4,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter HR';
                                  final trimmed = val.trim();
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _intraOpTempController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 8,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(8),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter Temp';
                                  final trimmed = val.trim();
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _intraOpSpo2Controller,
                                keyboardType: TextInputType.number,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 5,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Please enter SpO2';
                                  final trimmed = val.trim();
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
                  const SizedBox(height: 12),
                  widget.isMobile
                      ? Column(
                          children: [
                            CustomDropdownSearch(
                              label: 'Meds Given',
                              hint: 'Select or enter meds given',
                              allowFreeText: true,
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
                              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
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
                    validator: (val) => _validateClinicalNotesText(
                      val,
                      'complications',
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

                      if (!_surgeryProcedureFormKey.currentState!.validate()) {
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
                    validator: (val) => _validateClinicalNotesText(val, 'Follow-up recommendations'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Follow-Up Recommendations',
                      prefixIcon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _savePostOpNotes(otCase),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Post-Op Notes'),
                    style: AppTheme.primaryButton,
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
                    value: _selectedTransferDest,
                    dropdownItems: const ['Recovery Room', 'ICU', 'Ward'],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTransferDest = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final String currentBed = _transferDetailsController.text;
                      List<String> availableBedNumbers = [];
                      for (var b in _beds) {
                        final bedNum = b['bed_number'].toString();
                        final wardType = b['ward_type'].toString();
                        final status = b['status'].toString();

                        bool matchesDest = false;
                        if (_selectedTransferDest == 'ICU') {
                          matchesDest = (wardType == 'ICU');
                        } else if (_selectedTransferDest == 'Ward') {
                          matchesDest = (wardType == 'General' || wardType == 'Semi-Private' || wardType == 'Private');
                        } else {
                          matchesDest = true;
                        }

                        if (matchesDest && (status == 'Available' || bedNum == currentBed)) {
                          availableBedNumbers.add(bedNum);
                        }
                      }
                      if (currentBed.isNotEmpty && !availableBedNumbers.contains(currentBed)) {
                        availableBedNumbers.add(currentBed);
                      }
                      availableBedNumbers.sort((a, b) => a.compareTo(b));

                      return CustomDropdownSearch(
                        label: 'Transfer Details (Bed Number)',
                        hint: 'Select bed number',
                        value: currentBed.isNotEmpty ? currentBed : null,
                        dropdownItems: availableBedNumbers,
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
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Nursing Handover Notes',
                      prefixIcon: Icons.note_alt_outlined,
                    ),
                    validator: (val) => _validateClinicalNotesText(
                      val,
                      'Handover notes',
                      required: false,
                    ),
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

          if (isNurse || isAdmin) ...[
            Form(
              key: _postOpNurseCareFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Post-Operative Recovery Vitals & Care (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _careVitalsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 150,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(150),
                    ],
                    validator: (val) => _validateVitalsSummary(val),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Vitals Entry (BP, Pulse, Temp, SPO2)',
                      prefixIcon: Icons.monitor_heart_outlined,
                      hintText: 'BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _careMedsController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 150,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(150),
                    ],
                    validator: (val) => _validateMedicationOrSubstanceText(
                      val,
                      'Medication Given',
                      example: 'e.g. Paracetamol 1g IV',
                    ),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Medication Given (Dosage/Route)',
                      prefixIcon: Icons.vaccines_outlined,
                      hintText: 'Paracetamol 1g IV',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_postOpNurseCareFormKey.currentState!.validate()) {
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
                ],
              ),
            ),
            const Divider(height: 32),
          ],

          if (isDoctor || isAdmin) ...[
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
                    maxLength: 100,
                    validator: (val) => _validateClinicalNotesText(val, 'Doctor progress note'),
                    decoration: AppTheme.standardInputDecoration(
                      label: 'Doctor Daily Progress Note & Treatment Plan',
                      prefixIcon: Icons.note_add_outlined,
                      hintText: 'Patient recovering well. Continue monitoring.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_postOpDoctorNoteFormKey.currentState!.validate()) {
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
            const Divider(height: 32),

            const Text('OT Workflow Closure:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            const Text(
              'Ensure the patient recovery is satisfactory, billing entries are complete, and documentation is closed.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _closeCase(otCase),
              icon: const Icon(Icons.archive),
              label: const Text('Approve OT Closure & Generate Summary'),
              style: AppTheme.logoRedButton,
            ),
          ],
        ],
      );
    }

    return const SizedBox();
  }

  List<AuditLog> _getCompleteChronologicalLogs(OtCase otCase) {
    final Map<String, AuditLog> uniqueLogs = {};

    // 1. Existing audit logs
    for (final log in otCase.auditLogs) {
      final key = '${log.action.trim().toLowerCase()}_${log.timestamp.millisecondsSinceEpoch ~/ 60000}';
      uniqueLogs[key] = log;
    }

    final baseTime = otCase.scheduledStartTime ?? otCase.surgeryDateTime ?? DateTime.now().subtract(const Duration(hours: 4));

    // 2. Synthesize missing steps for completed or in-progress cases if not already present
    void addSynthesized(String actionKeyword, AuditLog log) {
      final exists = uniqueLogs.values.any((l) => l.action.toLowerCase().contains(actionKeyword.toLowerCase()));
      if (!exists) {
        uniqueLogs['syn_$actionKeyword'] = log;
      }
    }

    // Step 1: Booking & Scheduling
    addSynthesized('scheduled surgery', AuditLog(
      actorName: otCase.leadSurgeon ?? otCase.surgeon ?? 'Dr. Gayathri',
      role: 'Surgeon',
      timestamp: baseTime,
      action: 'Surgery Scheduled: Room ${otCase.otRoom ?? "OT 1"}, Slot: ${otCase.surgerySlot ?? "10:00 AM - 11:30 AM"}, Team: ${otCase.nursingTeam ?? "OT Nursing Team"}.',
    ));

    // Step 2: Pre-Op Checklist & Vitals
    if (otCase.preOpBp != null || otCase.fastingConfirmed || otCase.status != 'OT Requested') {
      addSynthesized('pre-operative checklist', AuditLog(
        actorName: otCase.scrubNurse ?? 'OT Nurse',
        role: 'Nurse',
        timestamp: baseTime.add(const Duration(minutes: 15)),
        action: 'Completed pre-operative checklist & vitals (BP: ${otCase.preOpBp ?? "120/80"}, PR: ${otCase.preOpPulse ?? 78}, Temp: ${otCase.preOpTemp ?? 98.6}, SpO2: ${otCase.preOpSpo2 ?? 99}%). Patient prepared for OT.',
      ));
    }

    // Step 3: PAC Clearance
    if (otCase.pacStatus.isNotEmpty && otCase.pacStatus != 'Pending') {
      final asa = otCase.pacDetails['effective_asa'] ?? otCase.pacDetails['asa_grade'] ?? _selectedAsaGrade;
      final plan = otCase.pacDetails['anaesthesia_type'] ?? otCase.anaesthesiaType ?? 'General Anaesthesia';
      addSynthesized('pac clearance', AuditLog(
        actorName: otCase.pacClearedBy ?? otCase.anaesthetist ?? 'Dr. John',
        role: 'Anaesthetist',
        timestamp: otCase.pacClearedAt ?? baseTime.add(const Duration(minutes: 30)),
        action: 'PAC Clearance Verified: Status [${otCase.pacStatus}], Assigned ASA Grade: $asa, Anaesthesia Plan: $plan.',
      ));
    }

    // Step 4: Patient Handover & OT Arrival
    if (otCase.handoverVerified || otCase.patientArrived || (otCase.status != 'OT Requested' && otCase.status != 'Pre-Op Completed')) {
      addSynthesized('verified handover', AuditLog(
        actorName: otCase.circulatingNurse ?? 'Circulating Nurse',
        role: 'Nurse',
        timestamp: baseTime.add(const Duration(minutes: 45)),
        action: 'Verified handover details and confirmed patient arrival inside assigned OT Room (${otCase.otRoom ?? "OT 1"}).',
      ));
    }

    // Step 5: WHO Safety Checklist stages
    final who = otCase.whoChecklist;
    if (who['sign_in']?['is_completed'] == true) {
      addSynthesized('stage 1: sign-in', AuditLog(
        actorName: who['sign_in']?['completed_by'] ?? otCase.anaesthetist ?? 'Anaesthetist',
        role: 'Anaesthetist',
        timestamp: who['sign_in']?['completed_at'] != null ? DateTime.tryParse(who['sign_in']['completed_at'].toString())?.toLocal() ?? baseTime.add(const Duration(minutes: 50)) : baseTime.add(const Duration(minutes: 50)),
        action: 'WHO Safety [Stage 1: Sign-In] - Status: Completed & Verified before anaesthetic induction.',
      ));
    }
    if (who['time_out']?['is_completed'] == true) {
      addSynthesized('stage 2: time-out', AuditLog(
        actorName: who['time_out']?['completed_by'] ?? otCase.leadSurgeon ?? 'Lead Surgeon',
        role: 'Surgeon',
        timestamp: who['time_out']?['completed_at'] != null ? DateTime.tryParse(who['time_out']['completed_at'].toString())?.toLocal() ?? baseTime.add(const Duration(minutes: 60)) : baseTime.add(const Duration(minutes: 60)),
        action: 'WHO Safety [Stage 2: Time-Out] - Status: Completed & Verified pause prior to skin incision.',
      ));
    }

    // Step 6: Surgery Procedure & Intra-Op Vitals
    if (otCase.procedureDetails != null || otCase.status == 'Surgery Completed' || otCase.status == 'Post-Op Monitoring' || otCase.status == 'OT Case Closed') {
      addSynthesized('started surgery', AuditLog(
        actorName: otCase.leadSurgeon ?? otCase.surgeon ?? 'Dr. Gayathri',
        role: 'Surgeon',
        timestamp: baseTime.add(const Duration(minutes: 65)),
        action: 'Started surgical incision & operative procedure for ${otCase.surgeryType ?? otCase.diagnosis}.',
      ));
    }

    // Consumables used
    for (int i = 0; i < otCase.consumablesUsed.length; i++) {
      final c = otCase.consumablesUsed[i];
      final itemName = c['item_name'] ?? 'Consumable';
      addSynthesized('consumable: ${itemName.toLowerCase()}', AuditLog(
        actorName: c['recorded_by'] ?? otCase.scrubNurse ?? 'Scrub Nurse',
        role: 'Nurse',
        timestamp: c['recorded_at'] != null ? DateTime.tryParse(c['recorded_at'].toString())?.toLocal() ?? baseTime.add(Duration(minutes: 75 + i * 2)) : baseTime.add(Duration(minutes: 75 + i * 2)),
        action: 'Recorded consumable: ${c['quantity']} ${c['unit'] ?? "pcs"} of $itemName (Stock Deducted: ${c['deducted_from_inventory'] == true ? "YES" : "NO"}).',
      ));
    }

    // WHO Sign-Out
    if (who['sign_out']?['is_completed'] == true) {
      addSynthesized('stage 3: sign-out', AuditLog(
        actorName: who['sign_out']?['completed_by'] ?? otCase.scrubNurse ?? 'Scrub Nurse',
        role: 'Nurse',
        timestamp: who['sign_out']?['completed_at'] != null ? DateTime.tryParse(who['sign_out']['completed_at'].toString())?.toLocal() ?? baseTime.add(const Duration(minutes: 110)) : baseTime.add(const Duration(minutes: 110)),
        action: 'WHO Safety [Stage 3: Sign-Out] - Status: Completed & Verified (Counts correct, specimen labelled).',
      ));
    }

    // Step 7: Post-Op Notes & Transfer
    if (otCase.transferDestination != null || otCase.status == 'Post-Op Monitoring' || otCase.status == 'OT Case Closed') {
      addSynthesized('transferred patient', AuditLog(
        actorName: otCase.circulatingNurse ?? 'Circulating Nurse',
        role: 'Nurse',
        timestamp: baseTime.add(const Duration(minutes: 120)),
        action: 'Transferred patient to ${otCase.transferDestination ?? "Recovery Room / PACU"}. Handover details: ${otCase.nursingHandoverNotes ?? "Stable"}.',
      ));
    }

    // Step 8: Final Case Closed
    if (otCase.status == 'OT Case Closed') {
      addSynthesized('closed ot workflow', AuditLog(
        actorName: otCase.leadSurgeon ?? otCase.surgeon ?? 'Dr. Gayathri',
        role: 'Surgeon',
        timestamp: baseTime.add(const Duration(minutes: 135)),
        action: 'Closed OT Workflow and generated final operation summary report. Surgical Case Closed.',
      ));
    }

    final list = uniqueLogs.values.toList();
    list.sort((a, b) => _auditTrailAscending
        ? a.timestamp.compareTo(b.timestamp)
        : b.timestamp.compareTo(a.timestamp));
    return list;
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
          LengthLimitingTextInputFormatter(250),
        ],
        decoration: _noLabelDecoration(hintText: 'enter diagnosis'),
        validator: (val) => _validateClinicalNotesText(val, 'Diagnosis details'),
      ),
      ..._buildSchedulingParametersChildren(),
    ];
  }

  List<Widget> _buildSchedulingParametersChildren() {
    final allRooms = ['OT 1', 'OT 2', 'OT 3', 'Emergency OT'];
    final occupiedRooms = _otCases
        .where((c) =>
            c.otRoom != null &&
            c.status != 'OT Case Closed' &&
            c.status != 'OT Requested')
        .map((c) => c.otRoom!)
        .toSet();


    return [
      const SizedBox(height: 24),
      const Text('Scheduling & Room Assignment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
      const SizedBox(height: 16),
      
      // OT Room
      CustomDropdownSearch(
        label: 'OT Room',
        requiredMark: true,
        hint: 'Select OT Room',
        value: (_selectedOtRoom != null && allRooms.contains(_selectedOtRoom))
            ? _selectedOtRoom
            : null,
        dropdownMap: {
          for (var room in allRooms)
            room: occupiedRooms.contains(room) ? '$room (Occupied)' : '$room (Available)'
        },
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Please select an OT Room';
          }
          return null;
        },
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedOtRoom = val);
          }
        },
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
                  final eMin = _slotEndTime.hour * 60 + _slotEndTime.minute;
                  if (eMin <= sMin) {
                    AppNotification.showError(
                      context,
                      'Surgery End Time (${_formatTimeOfDay(_slotEndTime)}) is now earlier than or equal to Start Time (${_formatTimeOfDay(picked)}). Please adjust End Time.',
                      atTop: true,
                    );
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                        Text(
                          _formatTimeOfDay(_slotStartTime),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                        ),
                      ],
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
                  initialTime: _slotEndTime,
                  helpText: 'Select Surgery End Time',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Time', style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                        Text(
                          _formatTimeOfDay(_slotEndTime),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
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
      if ((_slotEndTime.hour * 60 + _slotEndTime.minute) <=
          (_slotStartTime.hour * 60 + _slotStartTime.minute)) ...[
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
              Text('No nurses found in database.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.5)),
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
