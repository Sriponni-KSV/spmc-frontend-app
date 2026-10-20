import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../services/api_service.dart';
import '../screens/ot_management.dart';

import '../config/api_config.dart';

class OtController {
  String get baseUrl => ApiEndpoints.baseUrl;

  /// Fetch all OT Cases from the database
  Future<List<OtCase>> fetchOtCases() async {
    try {
      final response = await ApiService.get('$baseUrl/ot/cases');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch OT cases');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown error');
      }

      final List data = body['data'] ?? [];
      return data.map((json) => _mapJsonToOtCase(json)).toList();
    } catch (e) {
      print('Error in fetchOtCases: $e');
      rethrow;
    }
  }

  /// Fetch OT statistics from the database
  Future<Map<String, dynamic>> fetchOtStats() async {
    try {
      final response = await ApiService.get('$baseUrl/ot/stats');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch OT stats');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown error');
      }

      return Map<String, dynamic>.from(body['data'] ?? {});
    } catch (e) {
      print('Error in fetchOtStats: $e');
      rethrow;
    }
  }

  /// Create a new OT Case (Surgery Request)
  Future<OtCase> createOtCase({
    required int patientDbId,
    required String diagnosis,
    required String surgeryType,
    required String priority,
    required DateTime surgeryDateTime,
    required String surgeon,
    String? leadSurgeon,
    String? assistantSurgeon,
    required String anaesthetist,
    String? scrubNurse,
    String? circulatingNurse,
    String? otRoom,
    int? theatreId,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    int? estimatedDurationMinutes,
    Map<String, dynamic>? whoChecklist,
    String? pacStatus,
    Map<String, dynamic>? pacDetails,
    required String remarks,
    required List<AuditLog> auditLogs,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'patient_id': patientDbId,
        'diagnosis': diagnosis,
        'surgery_type': surgeryType,
        'priority': priority,
        'surgery_date_time': surgeryDateTime.toIso8601String(),
        'surgeon': leadSurgeon ?? surgeon,
        'lead_surgeon': leadSurgeon ?? surgeon,
        'assistant_surgeon': assistantSurgeon,
        'anaesthetist': anaesthetist,
        'scrub_nurse': scrubNurse,
        'circulating_nurse': circulatingNurse,
        'ot_room': otRoom,
        'theatre_id': theatreId,
        'scheduled_start_time': (scheduledStartTime ?? surgeryDateTime).toIso8601String(),
        'scheduled_end_time': scheduledEndTime != null ? scheduledEndTime.toIso8601String() : null,
        'estimated_duration_minutes': estimatedDurationMinutes ?? 90,
        'who_checklist': whoChecklist ?? {},
        'pac_status': pacStatus ?? 'Pending',
        'pac_details': pacDetails ?? {},
        'remarks': remarks,
        'audit_logs': auditLogs.map((log) => {
          'actorName': log.actorName,
          'role': log.role,
          'timestamp': log.timestamp.toIso8601String(),
          'action': log.action,
        }).toList(),
      };

      final response = await ApiService.post('$baseUrl/ot/cases', requestBody);
      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to create OT request');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in createOtCase: $e');
      rethrow;
    }
  }

  /// Update an existing OT case in the database
  Future<OtCase> updateOtCase(int dbId, Map<String, dynamic> updates) async {
    try {
      final response = await ApiService.put('$baseUrl/ot/cases/$dbId', updates);
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update OT case');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in updateOtCase: $e');
      rethrow;
    }
  }

  /// Fetch all Operation Theatres
  Future<List<Map<String, dynamic>>> fetchTheatres() async {
    try {
      final response = await ApiService.get('$baseUrl/ot/theatres');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch OT theatres');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown error');
      }

      final List data = body['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error in fetchTheatres: $e');
      return [];
    }
  }

  /// Check for scheduling conflicts (Theatre overlap, Lead Surgeon & Anaesthetist double-booking)
  Future<Map<String, dynamic>> checkConflicts({
    required String otRoom,
    required DateTime startTime,
    required DateTime endTime,
    String? leadSurgeon,
    String? anaesthetist,
    dynamic excludeCaseId,
  }) async {
    try {
      final response = await ApiService.post('$baseUrl/ot/check-conflicts', {
        'ot_room': otRoom,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'lead_surgeon': leadSurgeon,
        'anaesthetist': anaesthetist,
        'exclude_case_id': excludeCaseId,
      });

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Conflict check failed');
      }

      final body = jsonDecode(response.body);
      return Map<String, dynamic>.from(body);
    } catch (e) {
      print('Error in checkConflicts: $e');
      return {'success': false, 'hasConflict': false, 'conflicts': []};
    }
  }

  /// Update WHO Surgical Safety Checklist (Sign-In, Time-Out, Sign-Out)
  Future<OtCase> updateWhoChecklist(
    int caseDbId, {
    required String stage, // 'sign_in', 'time_out', 'sign_out'
    required Map<String, dynamic> checklistData,
    required String updatedBy,
  }) async {
    try {
      final response = await ApiService.put('$baseUrl/ot/cases/$caseDbId/who-checklist', {
        'stage': stage,
        'checklistData': checklistData,
        'updatedBy': updatedBy,
      });

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update WHO checklist');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in updateWhoChecklist: $e');
      rethrow;
    }
  }

  /// Update Pre-Anaesthetic Checkup (PAC) assessment & mandatory clearance
  Future<OtCase> updatePacClearance(
    int caseDbId, {
    required String pacStatus, // 'Cleared', 'High Risk Clearance', 'Deferred', 'Rejected', 'Pending'
    required Map<String, dynamic> pacDetails,
    required String pacClearedBy,
    String? anaesthesiaNotes,
    String? anaesthesiaType,
  }) async {
    try {
      final response = await ApiService.put('$baseUrl/ot/cases/$caseDbId/pac-clearance', {
        'pac_status': pacStatus,
        'pac_details': pacDetails,
        'pac_cleared_by': pacClearedBy,
        'anaesthesia_notes': anaesthesiaNotes,
        'anaesthesia_type': anaesthesiaType,
      });

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update PAC clearance');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in updatePacClearance: $e');
      rethrow;
    }
  }

  /// Parse dictation text into structured section and fields
  Future<Map<String, dynamic>> parseDictation(String dictationText) async {
    try {
      final response = await ApiService.post('$baseUrl/ot/dictate', {
        'dictationText': dictationText,
      });
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to parse dictation');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown parse error');
      }

      return body['data'] as Map<String, dynamic>;
    } catch (e) {
      print('Error in parseDictation: $e');
      rethrow;
    }
  }

  /// Parse base64 audio dictation into structured section and fields
  Future<Map<String, dynamic>> parseAudioDictation(String base64Audio) async {
    try {
      final response = await ApiService.post('$baseUrl/ot/dictate-audio', {
        'base64Audio': base64Audio,
      });
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to parse audio dictation');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown parse error');
      }

      return body['data'] as Map<String, dynamic>;
    } catch (e) {
      print('Error in parseAudioDictation: $e');
      rethrow;
    }
  }

  /// Fetch surgical and medical inventory items
  Future<List<Map<String, dynamic>>> fetchOtInventoryItems({String? search, String? category}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      
      final uri = Uri.parse('$baseUrl/ot/inventory-items').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await ApiService.get(uri.toString());
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch OT inventory items');
      }

      final body = jsonDecode(response.body);
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown error fetching inventory items');
      }

      final List items = body['data'] ?? [];
      return items.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error in fetchOtInventoryItems: $e');
      rethrow;
    }
  }

  /// Add a surgical consumable to an OT case with optional inventory deduction
  Future<OtCase> addCaseConsumable(int caseDbId, Map<String, dynamic> consumableData) async {
    try {
      final response = await ApiService.post('$baseUrl/ot/cases/$caseDbId/consumables', consumableData);
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to add consumable');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in addCaseConsumable: $e');
      rethrow;
    }
  }

  /// Remove a surgical consumable from an OT case and restore inventory
  Future<OtCase> removeCaseConsumable(int caseDbId, int index) async {
    try {
      final response = await ApiService.delete('$baseUrl/ot/cases/$caseDbId/consumables/$index');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to remove consumable');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in removeCaseConsumable: $e');
      rethrow;
    }
  }

  /// Add a tracked implant with UDI, serial, batch, and expiry validation
  Future<OtCase> addCaseImplant(int caseDbId, Map<String, dynamic> implantData) async {
    try {
      final response = await ApiService.post('$baseUrl/ot/cases/$caseDbId/implants', implantData);
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to record implant');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in addCaseImplant: $e');
      rethrow;
    }
  }

  /// Remove a recorded implant from an OT case
  Future<OtCase> removeCaseImplant(int caseDbId, int index) async {
    try {
      final response = await ApiService.delete('$baseUrl/ot/cases/$caseDbId/implants/$index');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to remove implant');
      }

      final body = jsonDecode(response.body);
      return _mapJsonToOtCase(body['data']);
    } catch (e) {
      print('Error in removeCaseImplant: $e');
      rethrow;
    }
  }

  /// Helper to convert backend JSON to frontend OtCase model
  OtCase _mapJsonToOtCase(Map<String, dynamic> json) {
    final otCase = OtCase(
      id: json['ot_case_id'] ?? 'OT-CASE',
      patientId: json['patient_display_id'] ?? 'PT-${json['patient_id']}',
      patientName: json['patient_name'] ?? 'Unknown',
      age: json['patient_age'] ?? 35,
      gender: json['patient_gender'] ?? 'Other',
      bloodGroup: json['patient_blood_group'] ?? 'O+',
      diagnosis: json['diagnosis'] ?? '',
      status: json['status'] ?? 'OT Requested',
    );

    otCase.dbId = json['id'];
    otCase.patientDbId = json['patient_id'];

    otCase.surgeryType = json['surgery_type'];
    otCase.priority = json['priority'];
    otCase.surgeryDateTime = json['surgery_date_time'] != null ? DateTime.parse(json['surgery_date_time']).toLocal() : null;
    otCase.surgeon = json['surgeon'];
    otCase.leadSurgeon = json['lead_surgeon'] ?? json['surgeon'];
    otCase.assistantSurgeon = json['assistant_surgeon'];
    otCase.anaesthetist = json['anaesthetist'];
    otCase.scrubNurse = json['scrub_nurse'];
    otCase.circulatingNurse = json['circulating_nurse'];
    otCase.remarks = json['remarks'];

    otCase.otRoom = json['ot_room'];
    otCase.theatreId = json['theatre_id'];
    otCase.theatreName = json['theatre_name'];
    otCase.scheduledStartTime = json['scheduled_start_time'] != null 
        ? DateTime.parse(json['scheduled_start_time']).toLocal() 
        : otCase.surgeryDateTime;
    otCase.scheduledEndTime = json['scheduled_end_time'] != null 
        ? DateTime.parse(json['scheduled_end_time']).toLocal() 
        : null;
    otCase.estimatedDurationMinutes = json['estimated_duration_minutes'] ?? 90;
    otCase.surgerySlot = json['surgery_slot'];
    otCase.nursingTeam = json['nursing_team'];

    // Pre-Op
    otCase.idVerified = json['id_verified'] ?? false;
    otCase.consentSigned = json['consent_signed'] ?? false;
    otCase.fastingConfirmed = json['fasting_confirmed'] ?? false;
    otCase.labVerified = json['lab_verified'] ?? false;
    otCase.bloodAvailable = json['blood_available'] ?? false;
    otCase.preOpBp = json['pre_op_bp'];
    otCase.preOpPulse = json['pre_op_pulse'];
    otCase.preOpTemp = json['pre_op_temp'] != null ? double.tryParse(json['pre_op_temp'].toString()) : null;
    otCase.preOpSpo2 = json['pre_op_spo2'];

    // PAC & Anaesthesia
    otCase.anaesthesiaNotes = json['anaesthesia_notes'];
    otCase.anaesthesiaType = json['anaesthesia_type'];
    otCase.anaesthesiaCleared = json['anaesthesia_cleared'] ?? false;
    otCase.pacStatus = json['pac_status'] ?? 'Pending';
    if ((otCase.pacStatus == 'Pending' || otCase.pacStatus.isEmpty) &&
        (otCase.anaesthesiaCleared || 
         otCase.status == 'Anaesthesia Cleared' || 
         otCase.status == 'Patient In OT' || 
         otCase.status == 'Surgery In Progress' || 
         otCase.status == 'Surgery Completed' || 
         otCase.status == 'Post-Op Monitoring' || 
         otCase.status == 'OT Case Closed')) {
      otCase.pacStatus = 'Cleared';
    }
    otCase.pacClearedBy = json['pac_cleared_by'];
    otCase.pacClearedAt = json['pac_cleared_at'] != null ? DateTime.parse(json['pac_cleared_at']).toLocal() : null;
    if (json['pac_details'] != null) {
      otCase.pacDetails = json['pac_details'] is String 
          ? jsonDecode(json['pac_details']) 
          : Map<String, dynamic>.from(json['pac_details']);
    } else {
      otCase.pacDetails = {};
    }

    // WHO Checklist
    if (json['who_checklist'] != null) {
      otCase.whoChecklist = json['who_checklist'] is String
          ? jsonDecode(json['who_checklist'])
          : Map<String, dynamic>.from(json['who_checklist']);
    } else {
      otCase.whoChecklist = {};
    }

    otCase.patientArrived = json['patient_arrived'] ?? false;
    otCase.handoverVerified = json['handover_verified'] ?? false;
    otCase.handoverNotes = json['handover_notes'];

    otCase.surgeryStartTime = json['surgery_start_time'] != null ? DateTime.parse(json['surgery_start_time']).toLocal() : null;
    otCase.surgeryEndTime = json['surgery_end_time'] != null ? DateTime.parse(json['surgery_end_time']).toLocal() : null;
    otCase.procedureDetails = json['procedure_details'];
    otCase.surgicalFindings = json['surgical_findings'];
    otCase.complications = json['complications'];

    // Parse Intra-Op Logs
    if (json['intra_op_logs'] != null) {
      final List logsJson = json['intra_op_logs'] is String 
          ? jsonDecode(json['intra_op_logs']) 
          : json['intra_op_logs'];
      otCase.intraOpLogs = logsJson.map((l) => IntraOpLog(
        timestamp: DateTime.parse(l['timestamp']).toLocal(),
        bp: l['bp'] ?? '',
        pulse: l['pulse'] ?? 72,
        temp: double.tryParse(l['temp'].toString()) ?? 98.4,
        spo2: l['spo2'] ?? 99,
        medications: l['medications'] ?? '',
        fluids: l['fluids'] ?? '',
        blood: l['blood'] ?? '',
        instrumentCount: l['instrumentCount'] ?? 0,
      )).toList();
    } else {
      otCase.intraOpLogs = [];
    }

    otCase.operationSummary = json['operation_summary'];
    otCase.procedurePerformed = json['procedure_performed'];
    otCase.outcome = json['outcome'];
    otCase.postOpInstructions = json['post_op_instructions'];
    otCase.followUpRecommendations = json['follow_up_recommendations'];

    otCase.transferDestination = json['transfer_destination'];
    otCase.transferDetails = json['transfer_details'];
    otCase.nursingHandoverNotes = json['nursing_handover_notes'];

    // Parse String Arrays
    if (json['nurse_care_vitals_logs'] != null) {
      final List list = json['nurse_care_vitals_logs'] is String 
          ? jsonDecode(json['nurse_care_vitals_logs']) 
          : json['nurse_care_vitals_logs'];
      otCase.nurseCareVitalsLogs = list.map((e) => e.toString()).toList();
    } else {
      otCase.nurseCareVitalsLogs = [];
    }

    if (json['nurse_medications_administered'] != null) {
      final List list = json['nurse_medications_administered'] is String 
          ? jsonDecode(json['nurse_medications_administered']) 
          : json['nurse_medications_administered'];
      otCase.nurseMedicationsAdministered = list.map((e) => e.toString()).toList();
    } else {
      otCase.nurseMedicationsAdministered = [];
    }

    if (json['doctor_progress_notes'] != null) {
      final List list = json['doctor_progress_notes'] is String 
          ? jsonDecode(json['doctor_progress_notes']) 
          : json['doctor_progress_notes'];
      otCase.doctorProgressNotes = list.map((e) => e.toString()).toList();
    } else {
      otCase.doctorProgressNotes = [];
    }

    // Parse Audit Logs
    if (json['audit_logs'] != null) {
      final List list = json['audit_logs'] is String 
          ? jsonDecode(json['audit_logs']) 
          : json['audit_logs'];
      otCase.auditLogs = list.map((l) => AuditLog(
        actorName: l['actorName'] ?? 'Unknown',
        role: l['role'] ?? 'Staff',
        timestamp: DateTime.parse(l['timestamp']).toLocal(),
        action: l['action'] ?? '',
      )).toList();
    } else {
      otCase.auditLogs = [];
    }

    // Parse Consumables Used
    if (json['consumables_used'] != null) {
      final List list = json['consumables_used'] is String
          ? jsonDecode(json['consumables_used'])
          : json['consumables_used'];
      otCase.consumablesUsed = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      otCase.consumablesUsed = [];
    }

    // Parse Implants Used
    if (json['implants_used'] != null) {
      final List list = json['implants_used'] is String
          ? jsonDecode(json['implants_used'])
          : json['implants_used'];
      otCase.implantsUsed = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      otCase.implantsUsed = [];
    }

    return otCase;
  }
}
