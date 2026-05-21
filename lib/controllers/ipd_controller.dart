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
  Future<void> dischargePatient(int admissionId, String dischargeSummary) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/ipd/admissions/$admissionId/discharge',
        {'discharge_summary': dischargeSummary},
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to discharge patient');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
