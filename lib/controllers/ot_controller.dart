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
    required String anaesthetist,
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
        'surgeon': surgeon,
        'anaesthetist': anaesthetist,
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
    otCase.anaesthetist = json['anaesthetist'];
    otCase.remarks = json['remarks'];

    otCase.otRoom = json['ot_room'];
    otCase.surgerySlot = json['surgery_slot'];
    otCase.nursingTeam = json['nursing_team'];

    otCase.idVerified = json['id_verified'] ?? false;
    otCase.consentSigned = json['consent_signed'] ?? false;
    otCase.fastingConfirmed = json['fasting_confirmed'] ?? false;
    otCase.labVerified = json['lab_verified'] ?? false;
    otCase.bloodAvailable = json['blood_available'] ?? false;
    otCase.preOpBp = json['pre_op_bp'];
    otCase.preOpPulse = json['pre_op_pulse'];
    otCase.preOpTemp = json['pre_op_temp'] != null ? double.tryParse(json['pre_op_temp'].toString()) : null;
    otCase.preOpSpo2 = json['pre_op_spo2'];

    otCase.anaesthesiaNotes = json['anaesthesia_notes'];
    otCase.anaesthesiaType = json['anaesthesia_type'];
    otCase.anaesthesiaCleared = json['anaesthesia_cleared'] ?? false;

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

    return otCase;
  }
}
