import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../models/patient_model.dart';

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
  String _simulatedRole = 'Doctor'; // Doctor, Nurse, Anaesthetist, Surgeon, OT Coordinator
  List<OtCase> _otCases = [];
  OtCase? _selectedCase;
  final _requestFormKey = GlobalKey<FormState>();

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
  final _otRoomController = TextEditingController(text: 'OT 1');
  final _slotController = TextEditingController(text: '09:00 AM - 11:30 AM');
  final _nursingTeamController = TextEditingController(text: 'Team A (Nurse Sarah, Nurse John)');

  // Pre-Op vitals
  final _preOpBpController = TextEditingController(text: '120/80');
  final _preOpPulseController = TextEditingController(text: '72');
  final _preOpTempController = TextEditingController(text: '98.4');
  final _preOpSpo2Controller = TextEditingController(text: '99');

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
  final _intraOpBpController = TextEditingController(text: '122/82');
  final _intraOpPulseController = TextEditingController(text: '74');
  final _intraOpTempController = TextEditingController(text: '98.5');
  final _intraOpSpo2Controller = TextEditingController(text: '98');
  final _intraOpMedsController = TextEditingController(text: 'Propofol 100mg, Fentanyl 50mcg');
  final _intraOpFluidsController = TextEditingController(text: 'Ringer Lactate 500ml');
  final _intraOpBloodController = TextEditingController(text: 'N/A');
  final _intraOpInstrumentController = TextEditingController(text: '24/24 Checked');

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
  final _careVitalsController = TextEditingController(text: 'BP: 118/76, PR: 70, Temp: 98.2, SpO2: 99%');
  final _careMedsController = TextEditingController(text: 'Paracetamol 1g IV');
  final _doctorProgressController = TextEditingController(text: 'Patient recovering well. Continue monitoring.');

  @override
  void initState() {
    super.initState();
    _initializeMockData();
    // Default surgeon/anaesthetist for forms
    _surgeonController.text = 'Dr. Vikram Sen';
    _anaesthetistController.text = 'Dr. Rajesh Shah';
  }

  void _initializeMockData() {
    // Rajesh Kumar - OT Requested
    final c1 = OtCase(
      id: 'OT-2026-001',
      patientId: 'PT-10822',
      patientName: 'Rajesh Kumar',
      age: 45,
      gender: 'Male',
      bloodGroup: 'O+',
      diagnosis: 'Chronic Calculous Cholecystitis',
      status: 'OT Requested',
    )..surgeryType = 'Laparoscopic Cholecystectomy'
      ..priority = 'Elective'
      ..surgeryDateTime = DateTime.now().add(const Duration(days: 1, hours: 2))
      ..surgeon = 'Dr. Vikram Sen'
      ..anaesthetist = 'Dr. Rajesh Shah'
      ..remarks = 'Patient has stable vitals. Scheduled for elective gallbladder removal.';
    c1.auditLogs.add(AuditLog(
      actorName: 'Dr. Vikram Sen',
      role: 'Surgeon',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      action: 'Created Surgery Request: Laparoscopic Cholecystectomy (Priority: Elective).',
    ));

    // Priya Sharma - Pre-Op Completed
    final c2 = OtCase(
      id: 'OT-2026-002',
      patientId: 'PT-11209',
      patientName: 'Priya Sharma',
      age: 32,
      gender: 'Female',
      bloodGroup: 'A+',
      diagnosis: 'Acute Appendicitis',
      status: 'Pre-Op Completed',
    )..surgeryType = 'Appendectomy'
      ..priority = 'Emergency'
      ..surgeryDateTime = DateTime.now().add(const Duration(hours: 1))
      ..surgeon = 'Dr. Vikram Sen'
      ..anaesthetist = 'Dr. Sunita Mehta'
      ..remarks = 'Acute symptoms. Immediate surgery requested.'
      ..otRoom = 'OT 2'
      ..surgerySlot = '10:30 AM - 12:00 PM'
      ..nursingTeam = 'Nursing Team B (Nurse Maria, Nurse Kevin)'
      ..idVerified = true
      ..consentSigned = true
      ..fastingConfirmed = true
      ..labVerified = true
      ..bloodAvailable = true
      ..preOpBp = '118/75'
      ..preOpPulse = 82
      ..preOpTemp = 99.1
      ..preOpSpo2 = 98;
    c2.auditLogs.add(AuditLog(
      actorName: 'Dr. Vikram Sen',
      role: 'Surgeon',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      action: 'Created Emergency Surgery Request for Appendectomy.',
    ));
    c2.auditLogs.add(AuditLog(
      actorName: 'Nurse Maria',
      role: 'Nurse Coordinator',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      action: 'Scheduled OT 2 and slot 10:30 AM - 12:00 PM.',
    ));
    c2.auditLogs.add(AuditLog(
      actorName: 'Nurse Kevin',
      role: 'Pre-Op Nurse',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      action: 'Completed pre-operative checklist and recorded vitals. Patient ready for transfer.',
    ));

    // John Miller - Patient in OT
    final c3 = OtCase(
      id: 'OT-2026-003',
      patientId: 'PT-09871',
      patientName: 'John Miller',
      age: 58,
      gender: 'Male',
      bloodGroup: 'B+',
      diagnosis: 'Triple Vessel Coronary Artery Disease',
      status: 'Patient In OT',
    )..surgeryType = 'Coronary Artery Bypass Graft (CABG)'
      ..priority = 'Elective'
      ..surgeryDateTime = DateTime.now().subtract(const Duration(minutes: 30))
      ..surgeon = 'Dr. Sanjay Gupta'
      ..anaesthetist = 'Dr. Sunita Mehta'
      ..remarks = 'Double check heparin availability.'
      ..otRoom = 'OT 1'
      ..surgerySlot = '08:00 AM - 12:00 PM'
      ..nursingTeam = 'Cardiac Nurse Team (Nurse Albert, Nurse Stella)'
      ..idVerified = true
      ..consentSigned = true
      ..fastingConfirmed = true
      ..labVerified = true
      ..bloodAvailable = true
      ..preOpBp = '130/82'
      ..preOpPulse = 68
      ..preOpTemp = 98.4
      ..preOpSpo2 = 97
      ..anaesthesiaNotes = 'Patient cleared. No difficult airway predicted.'
      ..anaesthesiaType = 'General Anaesthesia'
      ..anaesthesiaCleared = true
      ..patientArrived = true
      ..handoverVerified = true
      ..handoverNotes = 'All parameters stable. Skin prep complete.';
    c3.auditLogs.addAll([
      AuditLog(actorName: 'Dr. Sanjay Gupta', role: 'Surgeon', timestamp: DateTime.now().subtract(const Duration(days: 2)), action: 'Scheduled Elective CABG.'),
      AuditLog(actorName: 'Nurse Stella', role: 'OT Coordinator', timestamp: DateTime.now().subtract(const Duration(days: 1)), action: 'Allocated OT 1.'),
      AuditLog(actorName: 'Nurse Stella', role: 'Pre-Op Nurse', timestamp: DateTime.now().subtract(const Duration(hours: 2)), action: 'Completed pre-op verification.'),
      AuditLog(actorName: 'Dr. Sunita Mehta', role: 'Anaesthetist', timestamp: DateTime.now().subtract(const Duration(hours: 1)), action: 'Completed assessment and cleared patient under General Anaesthesia.'),
      AuditLog(actorName: 'Nurse Albert', role: 'OT Nurse', timestamp: DateTime.now().subtract(const Duration(minutes: 20)), action: 'Verified handover checklist and confirmed patient arrival in OT 1.'),
    ]);

    // Amina Bibi - Post-Op Monitoring
    final c4 = OtCase(
      id: 'OT-2026-004',
      patientId: 'PT-14220',
      patientName: 'Amina Bibi',
      age: 67,
      gender: 'Female',
      bloodGroup: 'O-',
      diagnosis: 'Osteoarthritis Left Knee',
      status: 'Post-Op Monitoring',
    )..surgeryType = 'Total Knee Replacement'
      ..priority = 'Elective'
      ..surgeryDateTime = DateTime.now().subtract(const Duration(hours: 4))
      ..surgeon = 'Dr. Amit Singhal'
      ..anaesthetist = 'Dr. Rajesh Shah'
      ..remarks = 'Knee implants checked and sterilized.'
      ..otRoom = 'OT 3'
      ..surgerySlot = '08:30 AM - 10:30 AM'
      ..nursingTeam = 'Orthopaedic Nurse Team'
      ..idVerified = true
      ..consentSigned = true
      ..fastingConfirmed = true
      ..labVerified = true
      ..bloodAvailable = true
      ..preOpBp = '142/88'
      ..preOpPulse = 78
      ..preOpTemp = 98.6
      ..preOpSpo2 = 96
      ..anaesthesiaNotes = 'Spinal anaesthesia given without complications.'
      ..anaesthesiaType = 'Spinal Anaesthesia'
      ..anaesthesiaCleared = true
      ..patientArrived = true
      ..handoverVerified = true
      ..handoverNotes = 'Handover complete from Ortho ward.'
      ..surgeryStartTime = DateTime.now().subtract(const Duration(hours: 3, minutes: 30))
      ..surgeryEndTime = DateTime.now().subtract(const Duration(hours: 1, minutes: 30))
      ..procedureDetails = 'Standard medial parapatellar approach. Tricompartmental cemented replacement done.'
      ..surgicalFindings = 'Severe cartilage loss in medial and patellofemoral compartments. Bone quality good.'
      ..complications = 'None'
      ..intraOpLogs = [
        IntraOpLog(timestamp: DateTime.now().subtract(const Duration(hours: 3)), bp: '135/80', pulse: 75, temp: 98.5, spo2: 99, medications: 'Propofol, Bupivacaine Spinal', fluids: 'RL 1000ml', blood: 'None', instrumentCount: 30),
        IntraOpLog(timestamp: DateTime.now().subtract(const Duration(hours: 2)), bp: '130/78', pulse: 72, temp: 98.3, spo2: 98, medications: 'Fentanyl 50mcg', fluids: 'NS 500ml', blood: 'None', instrumentCount: 30),
      ]
      ..operationSummary = 'Left total knee replacement completed successfully. Sterile dressing applied. Tourniquet time: 55 minutes.'
      ..procedurePerformed = 'Left Total Knee Arthroplasty (Replacement)'
      ..outcome = 'Successful, alignment restored.'
      ..postOpInstructions = 'Keep limb elevated. Ice packs periodically. Start gentle active movements on Day 1. Pain management via epidural infusion.'
      ..followUpRecommendations = 'Review in 2 weeks for staple removal.'
      ..transferDestination = 'Recovery Room'
      ..transferDetails = 'Patient alert, pain score 2/10, spinal block receding.'
      ..nursingHandoverNotes = 'Vitals stable. Bleeding checked. Drip running at 80ml/hr.'
      ..nurseCareVitalsLogs = ['BP: 120/78, PR: 72, SPO2: 99% (2 hours ago)', 'BP: 122/80, PR: 70, SPO2: 99% (1 hour ago)']
      ..nurseMedicationsAdministered = ['Cefuroxime 1.5g IV (1 hour ago)']
      ..doctorProgressNotes = ['Post-op check: Patient comfortable. Drains check ok. - Dr. Amit'];
    c4.auditLogs.addAll([
      AuditLog(actorName: 'Dr. Amit Singhal', role: 'Surgeon', timestamp: DateTime.now().subtract(const Duration(days: 3)), action: 'Scheduled Total Knee Replacement.'),
      AuditLog(actorName: 'Dr. Rajesh Shah', role: 'Anaesthetist', timestamp: DateTime.now().subtract(const Duration(hours: 5)), action: 'Approved under Spinal Anaesthesia.'),
      AuditLog(actorName: 'Nurse Janet', role: 'OT Nurse', timestamp: DateTime.now().subtract(const Duration(hours: 4)), action: 'Confirmed arrival and started surgery.'),
      AuditLog(actorName: 'Dr. Amit Singhal', role: 'Surgeon', timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), action: 'Completed surgery and entered operation notes.'),
      AuditLog(actorName: 'Nurse Janet', role: 'OT Nurse', timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)), action: 'Transferred patient to Recovery Room and completed nursing handover.'),
    ]);

    // Devendra Singh - OT Case Closed
    final c5 = OtCase(
      id: 'OT-2026-005',
      patientId: 'PT-13098',
      patientName: 'Devendra Singh',
      age: 50,
      gender: 'Male',
      bloodGroup: 'B-',
      diagnosis: 'Right Inguinal Hernia',
      status: 'OT Case Closed',
    )..surgeryType = 'Hernioplasty (Mesh Repair)'
      ..priority = 'Elective'
      ..surgeryDateTime = DateTime.now().subtract(const Duration(days: 2))
      ..surgeon = 'Dr. Vikram Sen'
      ..anaesthetist = 'Dr. Sunita Mehta'
      ..remarks = 'Standard mesh repair.'
      ..otRoom = 'OT 2'
      ..surgerySlot = '02:00 PM - 03:30 PM'
      ..nursingTeam = 'Nursing Team A'
      ..idVerified = true
      ..consentSigned = true
      ..fastingConfirmed = true
      ..labVerified = true
      ..bloodAvailable = true
      ..preOpBp = '124/80'
      ..preOpPulse = 74
      ..preOpTemp = 98.2
      ..preOpSpo2 = 99
      ..anaesthesiaNotes = 'Cleared'
      ..anaesthesiaType = 'Local with Sedation'
      ..anaesthesiaCleared = true
      ..patientArrived = true
      ..handoverVerified = true
      ..handoverNotes = 'Prepared right groin.'
      ..surgeryStartTime = DateTime.now().subtract(const Duration(days: 2, hours: 2))
      ..surgeryEndTime = DateTime.now().subtract(const Duration(days: 2, hours: 1))
      ..procedureDetails = 'Right inguinal incision. Sac dissected and reduced. Prolene mesh fixed.'
      ..surgicalFindings = 'Direct inguinal hernia. Sac contents omentum, viable.'
      ..complications = 'None'
      ..operationSummary = 'Hernioplasty done. Stitched in layers.'
      ..procedurePerformed = 'Right Inguinal Hernioplasty'
      ..outcome = 'Successful mesh placement.'
      ..postOpInstructions = 'Avoid heavy lifting for 6 weeks. High fiber diet.'
      ..followUpRecommendations = 'Review in OPD after 1 week.'
      ..transferDestination = 'Ward'
      ..transferDetails = 'Transferred to Male Surgical Ward, Bed 12.'
      ..nursingHandoverNotes = 'Fully conscious. Stitches dry.'
      ..doctorProgressNotes = ['Discharged home on Day 1. - Dr. Sen'];
    c5.auditLogs.add(AuditLog(
      actorName: 'Dr. Vikram Sen',
      role: 'Surgeon',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      action: 'Case closed and operation summary generated.',
    ));

    _otCases = [c1, c2, c3, c4, c5];
  }

  void _logAction(OtCase otCase, String action) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final log = AuditLog(
      actorName: user?.fullname ?? 'Simulated $_simulatedRole',
      role: _simulatedRole,
      timestamp: DateTime.now(),
      action: action,
    );
    setState(() {
      otCase.auditLogs.insert(0, log);
    });
  }

  // --- ACTIONS ---

  void _saveSurgeryRequest() {
    if (!_requestFormKey.currentState!.validate()) return;
    
    final newCase = OtCase(
      id: 'OT-2026-0${_otCases.length + 1}',
      patientId: 'PT-${10000 + _otCases.length * 137}',
      patientName: _patientNameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 35,
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
      diagnosis: _diagnosisController.text.trim(),
      status: 'OT Requested',
    )
      ..surgeryType = _selectedSurgeryType
      ..priority = _selectedPriority
      ..surgeryDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      )
      ..surgeon = _surgeonController.text.trim()
      ..anaesthetist = _anaesthetistController.text.trim()
      ..remarks = _remarksController.text.trim();

    _logAction(newCase, 'Created Surgery Request: ${newCase.surgeryType} (Priority: ${newCase.priority}).');

    setState(() {
      _otCases.insert(0, newCase);
      _activeTab = 1; // Switch to list
      _selectedCase = newCase;
    });

    // Clear controllers
    _patientNameController.clear();
    _ageController.clear();
    _diagnosisController.clear();
    _remarksController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Surgery requested successfully! Status: OT Requested'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmScheduling(OtCase otCase) {
    setState(() {
      otCase.otRoom = _otRoomController.text;
      otCase.surgerySlot = _slotController.text;
      otCase.nursingTeam = _nursingTeamController.text;
      otCase.status = 'OT Scheduled';
    });
    _logAction(otCase, 'Scheduled surgery: Room ${otCase.otRoom}, Slot: ${otCase.surgerySlot}, Nursing Team: ${otCase.nursingTeam}.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Surgery scheduled for ${otCase.patientName}. Status: OT Scheduled')),
    );
  }

  void _savePreOpPrep(OtCase otCase) {
    setState(() {
      otCase.preOpBp = _preOpBpController.text;
      otCase.preOpPulse = int.tryParse(_preOpPulseController.text);
      otCase.preOpTemp = double.tryParse(_preOpTempController.text);
      otCase.preOpSpo2 = int.tryParse(_preOpSpo2Controller.text);
      otCase.status = 'Pre-Op Completed';
    });
    _logAction(otCase, 'Completed pre-operative checklist & vitals (BP: ${otCase.preOpBp}, PR: ${otCase.preOpPulse}, Temp: ${otCase.preOpTemp}, SpO2: ${otCase.preOpSpo2}). Marked patient as ready.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pre-operative preparation completed. Ready for anaesthesia.')),
    );
  }

  void _saveAnaesthesia(OtCase otCase) {
    setState(() {
      otCase.anaesthesiaNotes = _anaesthesiaNotesController.text;
      otCase.anaesthesiaType = _selectedAnaesthesiaType;
      otCase.anaesthesiaCleared = true;
      otCase.status = 'Anaesthesia Cleared';
    });
    _logAction(otCase, 'Cleared patient for surgery. Anaesthesia type: ${otCase.anaesthesiaType}. Notes: ${otCase.anaesthesiaNotes}.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient cleared by Anaesthetist. Status: Anaesthesia Cleared')),
    );
  }

  void _confirmHandover(OtCase otCase) {
    setState(() {
      otCase.patientArrived = true;
      otCase.handoverVerified = true;
      otCase.handoverNotes = _handoverNotesController.text;
      otCase.status = 'Patient In OT';
    });
    _logAction(otCase, 'Verified handover details and confirmed patient arrival inside the assigned OT Room (${otCase.otRoom}).');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient transferred to OT. Status: Patient In OT')),
    );
  }

  void _startSurgery(OtCase otCase) {
    setState(() {
      otCase.surgeryStartTime = DateTime.now();
      otCase.status = 'Surgery In Progress';
    });
    _logAction(otCase, 'Started Surgery Procedure.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Surgery Started! Status: Surgery In Progress')),
    );
  }

  void _addIntraOpLog(OtCase otCase) {
    final log = IntraOpLog(
      timestamp: DateTime.now(),
      bp: _intraOpBpController.text,
      pulse: int.tryParse(_intraOpPulseController.text) ?? 72,
      temp: double.tryParse(_intraOpTempController.text) ?? 98.4,
      spo2: int.tryParse(_intraOpSpo2Controller.text) ?? 99,
      medications: _intraOpMedsController.text,
      fluids: _intraOpFluidsController.text,
      blood: _intraOpBloodController.text,
      instrumentCount: int.tryParse(_intraOpInstrumentController.text.split('/')[0]) ?? 24,
    );
    setState(() {
      otCase.intraOpLogs.add(log);
    });
    _logAction(otCase, 'Recorded intra-operative vital log (BP: ${log.bp}, PR: ${log.pulse}, SpO2: ${log.spo2}%, Instrument Count: ${log.instrumentCount}).');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intra-operative monitoring log entry saved.')),
    );
  }

  void _completeSurgery(OtCase otCase) {
    setState(() {
      otCase.surgeryEndTime = DateTime.now();
      otCase.procedureDetails = _procedureDetailsController.text;
      otCase.surgicalFindings = _findingsController.text;
      otCase.complications = _complicationsController.text;
      otCase.status = 'Surgery Completed';
    });
    _logAction(otCase, 'Surgery Completed. Recorded procedure details, surgical findings, and complications: "${otCase.complications}".');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Surgery Completed! Status: Surgery Completed')),
    );
  }

  void _savePostOpNotes(OtCase otCase) {
    setState(() {
      otCase.operationSummary = _opSummaryController.text;
      otCase.procedurePerformed = _procPerformedController.text;
      otCase.outcome = _outcomeController.text;
      otCase.postOpInstructions = _postOpInstController.text;
      otCase.followUpRecommendations = _followUpController.text;
    });
    _logAction(otCase, 'Saved post-operative notes. Outcome: ${otCase.outcome}. Instructions: ${otCase.postOpInstructions}.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post-operative notes saved.')),
    );
  }

  void _executeTransfer(OtCase otCase) {
    setState(() {
      otCase.transferDestination = _selectedTransferDest;
      otCase.transferDetails = _transferDetailsController.text;
      otCase.nursingHandoverNotes = _nursingHandoverController.text;
      otCase.status = 'Post-Op Monitoring';
    });
    _logAction(otCase, 'Transferred patient to ${otCase.transferDestination}. Handover details: ${otCase.nursingHandoverNotes}. Status: Post-Op Monitoring.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Patient transferred to ${otCase.transferDestination}. Status: Post-Op Monitoring')),
    );
  }

  void _addNurseCareLog(OtCase otCase) {
    setState(() {
      if (_careVitalsController.text.isNotEmpty) {
        otCase.nurseCareVitalsLogs.add('${_careVitalsController.text} (Recorded by Nurse at ${DateFormat('hh:mm a').format(DateTime.now())})');
      }
      if (_careMedsController.text.isNotEmpty) {
        otCase.nurseMedicationsAdministered.add('${_careMedsController.text} (Administered at ${DateFormat('hh:mm a').format(DateTime.now())})');
      }
    });
    _logAction(otCase, 'Recorded nurse care entry. Vitals: ${_careVitalsController.text}. Meds: ${_careMedsController.text}.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nurse care details recorded.')),
    );
  }

  void _addDoctorProgressNote(OtCase otCase) {
    setState(() {
      if (_doctorProgressController.text.isNotEmpty) {
        otCase.doctorProgressNotes.add('${_doctorProgressController.text} (Added at ${DateFormat('hh:mm a').format(DateTime.now())})');
      }
    });
    _logAction(otCase, 'Doctor added progress note: "${_doctorProgressController.text}".');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doctor progress note saved.')),
    );
  }

  void _closeCase(OtCase otCase) {
    setState(() {
      otCase.status = 'OT Case Closed';
    });
    _logAction(otCase, 'Closed OT Workflow and generated final operation summary report.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('OT Case Closed for ${otCase.patientName}. Workflow completed!')),
    );
  }

  // Helper to check if step belongs to current role
  bool _canPerformAction(String requiredRole) {
    if (_simulatedRole == 'Admin' || _simulatedRole == 'Super Admin') return true;
    if (requiredRole == 'Doctor' && (_simulatedRole == 'Doctor' || _simulatedRole == 'Surgeon')) return true;
    if (requiredRole == 'Surgeon' && (_simulatedRole == 'Surgeon' || _simulatedRole == 'Doctor')) return true;
    if (requiredRole == 'Nurse' && (_simulatedRole == 'Nurse' || _simulatedRole == 'OT Coordinator')) return true;
    if (requiredRole == 'OT Coordinator' && (_simulatedRole == 'OT Coordinator' || _simulatedRole == 'Nurse')) return true;
    if (requiredRole == 'Anaesthetist' && _simulatedRole == 'Anaesthetist') return true;
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
          // ── Top Header Section (Role Swapper + Title) ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                // Simulator Widget
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology_outlined, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Active Role SIM:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _simulatedRole,
                        elevation: 3,
                        underline: const SizedBox(),
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _simulatedRole = val;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'Doctor', child: Text('Doctor / Surgeon')),
                          DropdownMenuItem(value: 'Nurse', child: Text('Nurse / Coordinator')),
                          DropdownMenuItem(value: 'Anaesthetist', child: Text('Anaesthetist')),
                        ],
                      ),
                    ],
                  ),
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
                _buildTabButton(1, 'Active Workflow Cases (${_otCases.where((c) => c.status != 'OT Case Closed').length})', Icons.assignment_outlined),
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
        return _buildWorkflowView();
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
                          setState(() {
                            _selectedCase = activeInRoom;
                            _activeTab = 1; // Go to workflow
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

  Widget _buildWorkflowView() {
    if (_otCases.isEmpty) {
      return const Center(child: Text('No active OT cases. Try requesting a new surgery.'));
    }

    // Set default selected case if none is active
    _selectedCase ??= _otCases.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar patient selector
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
                  ),
                  child: const Text(
                    'Active Patients',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _otCases.length,
                    separatorBuilder: (context, idx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final c = _otCases[idx];
                      bool isSelected = _selectedCase?.id == c.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppTheme.primaryColor.withOpacity(0.05),
                        onTap: () => setState(() => _selectedCase = c),
                        title: Text(
                          c.patientName,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c.id} \u2022 ${c.surgeryType ?? "TBD"}', style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(c.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c.status,
                                style: TextStyle(color: _getStatusColor(c.status), fontSize: 9, fontWeight: FontWeight.bold),
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
          ),
        ),
        const SizedBox(width: 16),
        // Workflow tracker and form actions
        Expanded(
          flex: 3,
          child: _selectedCase == null
              ? const Center(child: Text('Select a patient from the list'))
              : _buildCaseWorkflowDetails(_selectedCase!),
        ),
      ],
    );
  }

  Widget _buildCaseWorkflowDetails(OtCase otCase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Patient Header Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        otCase.patientName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(otCase.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          otCase.status,
                          style: TextStyle(color: _getStatusColor(otCase.status), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${otCase.patientId} \u2022 Age: ${otCase.age} \u2022 Gender: ${otCase.gender} \u2022 Blood Group: ${otCase.bloodGroup} \u2022 Diagnosis: ${otCase.diagnosis}',
                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('OT Room: ${otCase.otRoom ?? "Not Assigned"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Surgeon: ${otCase.surgeon ?? "Not Assigned"}', style: const TextStyle(fontSize: 12)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal Timeline stepper
        _buildWorkflowStepper(otCase),
        const SizedBox(height: 16),

        // Core workflow form action area
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Flow Action Forms
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Interactive Step Panel',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                            ),
                            Text(
                              'Required: ${_getStepOperator(otCase.status)}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildStepForm(otCase),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Audit Log & History Tab view
              Expanded(
                flex: 1,
                child: Container(
                  decoration: AppTheme.cardDecoration,
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Audit Trail'),
                            Tab(text: 'Case History'),
                          ],
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: AppTheme.textSecondaryColor,
                          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildAuditTrailTab(otCase),
                              _buildCaseHistoryTab(otCase),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildWorkflowStepper(OtCase otCase) {
    final steps = [
      'Requested',
      'Scheduled',
      'Pre-Op',
      'Anaesthesia',
      'In OT',
      'Procedure',
      'Monitoring',
      'Post-Op Notes',
      'Care & Close'
    ];

    int activeIndex = 0;
    if (otCase.status == 'OT Scheduled') activeIndex = 1;
    if (otCase.status == 'Pre-Op Completed') activeIndex = 2;
    if (otCase.status == 'Anaesthesia Cleared') activeIndex = 3;
    if (otCase.status == 'Patient In OT') activeIndex = 4;
    if (otCase.status == 'Surgery In Progress') activeIndex = 5;
    if (otCase.status == 'Surgery Completed') activeIndex = 7; // Surgery completes, triggers notes
    if (otCase.status == 'Post-Op Monitoring') activeIndex = 8;
    if (otCase.status == 'OT Case Closed') activeIndex = 9;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          bool isCompleted = index < activeIndex;
          bool isActive = index == activeIndex;
          Color stepColor = isCompleted
              ? Colors.green
              : (isActive ? AppTheme.primaryColor : Colors.grey.shade300);

          return Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: stepColor,
                      child: isCompleted
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : Text(
                              (index + 1).toString(),
                              style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < activeIndex - 1 ? Colors.green : Colors.grey.shade300,
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Render the proper step action panels
  Widget _buildStepForm(OtCase otCase) {
    // If not role matching, show warning but allow bypass button for review
    bool canAct = true;
    String requiredText = '';

    if (otCase.status == 'OT Requested') {
      canAct = _canPerformAction('OT Coordinator');
      requiredText = 'OT Coordinator or Nurse';
    } else if (otCase.status == 'OT Scheduled') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Pre-Op Completed') {
      canAct = _canPerformAction('Anaesthetist');
      requiredText = 'Anaesthetist Doctor';
    } else if (otCase.status == 'Anaesthesia Cleared') {
      canAct = _canPerformAction('Nurse');
      requiredText = 'Nurse';
    } else if (otCase.status == 'Patient In OT') {
      canAct = _canPerformAction('Surgeon');
      requiredText = 'Doctor / Surgeon';
    } else if (otCase.status == 'Surgery In Progress') {
      canAct = _canPerformAction('Surgeon') || _canPerformAction('Nurse');
      requiredText = 'Surgeon or Nurse';
    } else if (otCase.status == 'Surgery Completed') {
      canAct = _canPerformAction('Doctor');
      requiredText = 'Doctor';
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
                  decoration: const InputDecoration(labelText: 'Assign OT Room'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _slotController,
                  decoration: const InputDecoration(labelText: 'Surgery Slot'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nursingTeamController,
            decoration: const InputDecoration(labelText: 'Assign Nursing Team'),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pre-Operative Preparation Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Patient Identity Verified', style: TextStyle(fontSize: 13)),
            value: otCase.idVerified,
            onChanged: (val) => setState(() => otCase.idVerified = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Consent Form Signed', style: TextStyle(fontSize: 13)),
            value: otCase.consentSigned,
            onChanged: (val) => setState(() => otCase.consentSigned = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Fasting (NPO) Confirmed', style: TextStyle(fontSize: 13)),
            value: otCase.fastingConfirmed,
            onChanged: (val) => setState(() => otCase.fastingConfirmed = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Lab & Investigation Reports Verified', style: TextStyle(fontSize: 13)),
            value: otCase.labVerified,
            onChanged: (val) => setState(() => otCase.labVerified = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Blood Availability Checked', style: TextStyle(fontSize: 13)),
            value: otCase.bloodAvailable,
            onChanged: (val) => setState(() => otCase.bloodAvailable = val ?? false),
          ),
          const SizedBox(height: 16),
          const Text('Record Pre-Operative Vitals:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _preOpBpController,
                  decoration: const InputDecoration(labelText: 'BP (mmHg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _preOpPulseController,
                  decoration: const InputDecoration(labelText: 'Pulse (bpm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _preOpTempController,
                  decoration: const InputDecoration(labelText: 'Temp (°F)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _preOpSpo2Controller,
                  decoration: const InputDecoration(labelText: 'SpO2 (%)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: (otCase.idVerified && otCase.consentSigned && otCase.fastingConfirmed && otCase.labVerified && otCase.bloodAvailable)
                ? () => _savePreOpPrep(otCase)
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
            decoration: const InputDecoration(labelText: 'Anaesthesia Type'),
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
            decoration: const InputDecoration(labelText: 'Assessment Notes & Warnings', hintText: 'Enter patient history, airway, risk details...'),
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
          CheckboxListTile(
            title: const Text('Transfer to Assigned OT Room Complete', style: TextStyle(fontSize: 13)),
            value: otCase.patientArrived,
            onChanged: (val) => setState(() => otCase.patientArrived = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Confirm Identity, Consent & Markings on Arrival', style: TextStyle(fontSize: 13)),
            value: otCase.handoverVerified,
            onChanged: (val) => setState(() => otCase.handoverVerified = val ?? false),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _handoverNotesController,
            decoration: const InputDecoration(labelText: 'OT Handover Remarks', hintText: 'Note any checklist variances or prep details...'),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.sensors, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          const Text('Ready to Start Surgical Procedure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Ensure the surgical team is scrubbed, and all preoperative parameters are cleared.',
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
          const Text('Intra-Operative Vital & Event Logging:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _intraOpBpController, decoration: const InputDecoration(labelText: 'BP'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _intraOpPulseController, decoration: const InputDecoration(labelText: 'HR'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _intraOpTempController, decoration: const InputDecoration(labelText: 'Temp'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _intraOpSpo2Controller, decoration: const InputDecoration(labelText: 'SpO2'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _intraOpMedsController, decoration: const InputDecoration(labelText: 'Meds Given'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _intraOpFluidsController, decoration: const InputDecoration(labelText: 'IV Fluids'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _intraOpBloodController, decoration: const InputDecoration(labelText: 'Blood Products'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _intraOpInstrumentController, decoration: const InputDecoration(labelText: 'Instrument Count'))),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _addIntraOpLog(otCase),
            icon: const Icon(Icons.add),
            label: const Text('Record Vitals & Log Entry'),
            style: AppTheme.secondaryButton,
          ),
          const Divider(height: 32),

          const Text('Complete Surgery Procedure (Doctor):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _procedureDetailsController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Procedure Details Done'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _findingsController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Surgical Findings'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _complicationsController,
            decoration: const InputDecoration(labelText: 'Complications (if any)', hintText: 'None, hemorrhage, etc.'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _completeSurgery(otCase),
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete Surgery & Save Details'),
            style: AppTheme.successButton,
          ),
        ],
      );
    }

    if (otCase.status == 'Surgery Completed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post-Operative Surgeon Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: _opSummaryController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Operation Summary'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _procPerformedController,
            decoration: const InputDecoration(labelText: 'Procedure Performed'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outcomeController,
            decoration: const InputDecoration(labelText: 'Surgical Outcome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postOpInstController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Post-Operative Instructions'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _followUpController,
            decoration: const InputDecoration(labelText: 'Follow-Up Recommendations'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _savePostOpNotes(otCase),
            icon: const Icon(Icons.save),
            label: const Text('Save Post-Op Notes'),
            style: AppTheme.primaryButton,
          ),
          const Divider(height: 32),

          const Text('Transfer to Recovery / ICU / Ward (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTransferDest,
            decoration: const InputDecoration(labelText: 'Transfer Destination'),
            items: const [
              DropdownMenuItem(value: 'Recovery Room', child: Text('Recovery Room')),
              DropdownMenuItem(value: 'ICU', child: Text('ICU')),
              DropdownMenuItem(value: 'Ward', child: Text('General Ward')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedTransferDest = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transferDetailsController,
            decoration: const InputDecoration(labelText: 'Transfer Details (e.g. Bed Number)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nursingHandoverController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Nursing Handover Notes'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _executeTransfer(otCase),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Confirm Patient Ward/ICU Transfer'),
            style: AppTheme.successButton,
          ),
        ],
      );
    }

    if (otCase.status == 'Post-Op Monitoring') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Post-Operative Recovery Vitals & Care (Nurse):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _careVitalsController,
            decoration: const InputDecoration(labelText: 'Vitals Entry (BP, Pulse, Temp, SPO2)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _careMedsController,
            decoration: const InputDecoration(labelText: 'Medication Given (Dosage/Route)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _addNurseCareLog(otCase),
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
            decoration: const InputDecoration(labelText: 'Doctor Daily Progress Note & Treatment Plan'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _addDoctorProgressNote(otCase),
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
            onPressed: () => _closeCase(otCase),
            icon: const Icon(Icons.archive),
            label: const Text('Approve OT Closure & Generate Summary'),
            style: AppTheme.logoRedButton,
          ),
        ],
      );
    }

    return const SizedBox();
  }

  // Tabs for right panel
  Widget _buildAuditTrailTab(OtCase otCase) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: otCase.auditLogs.isEmpty
          ? const Center(child: Text('No audit logs yet.'))
          : ListView.builder(
              itemCount: otCase.auditLogs.length,
              itemBuilder: (context, idx) {
                final log = otCase.auditLogs[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history, size: 16, color: AppTheme.primaryColor.withOpacity(0.5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.action,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By: ${log.actorName} (${log.role}) \u2022 ${DateFormat('hh:mm a').format(log.timestamp)}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor),
                            ),
                          ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) => Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2),
              child: Text('\u2022 $l', style: const TextStyle(fontSize: 12)),
            )).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
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
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _patientNameController,
                      decoration: const InputDecoration(labelText: 'Patient Full Name *'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age *'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBloodGroup,
                      decoration: const InputDecoration(labelText: 'Blood Group'),
                      items: const [
                        DropdownMenuItem(value: 'O+', child: Text('O+')),
                        DropdownMenuItem(value: 'A+', child: Text('A+')),
                        DropdownMenuItem(value: 'B+', child: Text('B+')),
                        DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                        DropdownMenuItem(value: 'O-', child: Text('O-')),
                        DropdownMenuItem(value: 'A-', child: Text('A-')),
                        DropdownMenuItem(value: 'B-', child: Text('B-')),
                        DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBloodGroup = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(labelText: 'Diagnosis Details *', hintText: 'Enter clinical diagnosis summary'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 32),
              const Text('Surgery Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSurgeryType,
                      decoration: const InputDecoration(labelText: 'Surgery Type'),
                      items: const [
                        DropdownMenuItem(value: 'Laparoscopic Cholecystectomy', child: Text('Laparoscopic Cholecystectomy')),
                        DropdownMenuItem(value: 'Appendectomy', child: Text('Appendectomy')),
                        DropdownMenuItem(value: 'Hernioplasty (Mesh Repair)', child: Text('Hernioplasty (Mesh Repair)')),
                        DropdownMenuItem(value: 'Total Knee Replacement', child: Text('Total Knee Replacement')),
                        DropdownMenuItem(value: 'CABG (Heart Bypass)', child: Text('CABG (Heart Bypass)')),
                        DropdownMenuItem(value: 'Cataract Surgery', child: Text('Cataract Surgery')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSurgeryType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(labelText: 'Priority / Urgency'),
                      items: const [
                        DropdownMenuItem(value: 'Elective', child: Text('Elective (Scheduled)')),
                        DropdownMenuItem(value: 'Emergency', child: Text('Emergency (Immediate)')),
                      ],
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
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _surgeonController,
                      decoration: const InputDecoration(labelText: 'Primary Surgeon Name *'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _anaesthetistController,
                      decoration: const InputDecoration(labelText: 'Suggested Anaesthetist *'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks / Special Instructions'),
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
