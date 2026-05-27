import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class IpdController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  /// Fetch all beds
  Future<List<Map<String, dynamic>>> fetchBeds() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/beds');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch beds');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all active nurses (for nurse assignment dropdown)
  Future<List<Map<String, dynamic>>> fetchNurses() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/nurses');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch nurses');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all admissions
  Future<List<Map<String, dynamic>>> fetchAdmissions() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch admissions');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch appointments marked 'Admitted' by doctor but not yet assigned a bed
  Future<List<Map<String, dynamic>>> fetchPendingAdmissions() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/pending-admissions');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch pending admissions');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create new admission (assigns bed to patient)
  Future<void> createAdmission(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create admission');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Doctor recommends patient for IPD admission (no bed allocated yet).
  /// Creates a pending admission record that the nurse will fulfil.
  Future<void> createPendingAdmission(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/pending-admission-request',
        data,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create admission request');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Add a doctor progress note to an active admission (reuses daily-updates route).
  Future<void> addDoctorProgressNote(
    int admissionId,
    Map<String, dynamic> noteData,
  ) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admissions/$admissionId/daily-updates',
        noteData,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to save progress note');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Add daily nurse notes and vitals update
  Future<void> addDailyUpdate(int admissionId, Map<String, dynamic> updateData) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admissions/$admissionId/daily-updates',
        updateData,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to save daily update');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Discharge patient and record summary
  /// For doctor role, pass the structured fields (finalDiagnosis, treatmentSummary, medicationPlan)
  /// and the backend will auto-assemble the discharge_summary.
  Future<void> dischargePatient(
    int admissionId,
    String dischargeSummary, {
    String? finalDiagnosis,
    String? treatmentSummary,
    String? medicationPlan,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (finalDiagnosis != null && finalDiagnosis.isNotEmpty) {
        body['final_diagnosis'] = finalDiagnosis;
        if (treatmentSummary != null && treatmentSummary.isNotEmpty) {
          body['treatment_summary'] = treatmentSummary;
        }
        if (medicationPlan != null && medicationPlan.isNotEmpty) {
          body['medication_plan'] = medicationPlan;
        }
      } else {
        body['discharge_summary'] = dischargeSummary;
      }
      final response = await ApiService.post(
        '$baseUrl/ipd/admissions/$admissionId/discharge',
        body,
      );
      final respBody = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(respBody['message'] ?? 'Failed to discharge patient');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
