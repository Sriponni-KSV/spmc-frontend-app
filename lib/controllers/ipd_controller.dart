import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

import '../config/api_config.dart';

class IpdController {
  String get baseUrl => ApiEndpoints.baseUrl;

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

  /// Fetch appointments marked 'Admission Requested' by doctor (awaiting Front Desk processing)
  Future<List<Map<String, dynamic>>> fetchPendingRequests() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/pending-requests');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch pending requests');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch IPD admission records in 'Pending Allocation' status (awaiting nurse bed assignment)
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
  /// Front Desk will verify and create the admission record.
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

  /// Front Desk creates the admission record after verifying patient, insurance and docs.
  /// Creates a 'Pending Allocation' admission record for the nurse to allocate a bed.
  Future<Map<String, dynamic>> createAdmissionRecord(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admissions/admission-counter',
        data,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create admission record');
      }
      return Map<String, dynamic>.from(body['data'] ?? {});
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

  /// Fetch prescriptions for an admission
  Future<List<Map<String, dynamic>>> fetchPrescriptions(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/prescriptions');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch prescriptions');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create new prescription
  Future<void> createPrescription(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/prescriptions', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create prescription');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Stop a prescription
  Future<void> stopPrescription(int prescriptionId) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/prescriptions/$prescriptionId/stop', {});
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to stop prescription');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch medication logs for an admission
  Future<List<Map<String, dynamic>>> fetchMedicationLogs(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/medication-logs');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch medication logs');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create medication log
  Future<void> createMedicationLog(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/medication-logs', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create medication log');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch vitals history for an admission
  Future<List<Map<String, dynamic>>> fetchVitals(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/vitals');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch vitals');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create vitals entry
  Future<void> createVitals(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/vitals', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create vitals entry');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch ICU alerts for an admission
  Future<List<Map<String, dynamic>>> fetchIcuAlerts(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/icu-alerts');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch ICU alerts');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Resolve ICU alert
  Future<void> resolveIcuAlert(int alertId) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/icu-alerts/$alertId/resolve', {});
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to resolve alert');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch ICU active alerts across all patients
  Future<List<Map<String, dynamic>>> fetchIcuDashboard() async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/icu/dashboard');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch ICU dashboard');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch progress notes for an admission
  Future<List<Map<String, dynamic>>> fetchProgressNotes(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/progress-notes');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch progress notes');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create progress notes
  Future<void> createProgressNote(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/progress-notes', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create progress note');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch lab orders for an admission
  Future<List<Map<String, dynamic>>> fetchLabOrders(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/lab-orders');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch lab orders');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create lab order
  Future<void> createLabOrder(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/lab-orders', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create lab order');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update lab order status
  Future<void> updateLabOrderStatus(int labOrderId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/lab-orders/$labOrderId/status', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to update lab order status');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch shift handovers for an admission
  Future<List<Map<String, dynamic>>> fetchShiftHandovers(int admissionId) async {
    try {
      final response = await ApiService.get('$baseUrl/ipd/admissions/$admissionId/shift-handovers');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch shift handovers');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Create shift handover
  Future<void> createShiftHandover(int admissionId, Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('$baseUrl/ipd/admissions/$admissionId/shift-handovers', data);
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to create shift handover');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
