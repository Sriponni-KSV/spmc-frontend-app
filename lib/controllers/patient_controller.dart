import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/patient_model.dart';
import '../services/api_service.dart';

import '../config/api_config.dart';

class PatientController {
  String get baseUrl => ApiEndpoints.baseUrl;

  /// Register a new patient
  Future<void> registerPatient(PatientModel patient) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/patients/register',
        patient.toJson(),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to register patient');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update an existing patient
  Future<void> updatePatient(int id, PatientModel patient) async {
    try {
      // When updating from full registration, we set isQuickRegister to false
      Map<String, dynamic> data = patient.toJson();
      data['isQuickRegister'] = false; // Mark completion

      final response = await ApiService.put(
        '$baseUrl/patients/$id',
        data,
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to update patient');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch all patients
  Future<List<PatientModel>> fetchPatients() async {
  try {
    final url = '$baseUrl/patients';
    final response = await ApiService.get(url);

    if (response.statusCode != 200) {
      switch (response.statusCode) {
        case 401:
          throw Exception('Unauthorized — please log in again.');
        case 403:
          throw Exception('Forbidden — no permission.');
        case 404:
          throw Exception('Endpoint not found — check BASE_URL ($baseUrl)');
        default:
          throw Exception('Server error ${response.statusCode}');
      }
    }

    final body = jsonDecode(response.body);

    if (body is Map) {
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Unknown error');
      }

      final List data = body['data'] ?? [];
      return data.map((e) => PatientModel.fromJson(e)).toList();
    }

    if (body is List) {
      return body.map((e) => PatientModel.fromJson(e)).toList();
    }

    throw Exception('Unexpected response format');

    } catch (e) {
      rethrow;
    }
  }

  /// Fetch latest vitals for a patient
  Future<Map<String, dynamic>?> fetchLatestVitals(int patientId, {int? appointmentId}) async {
    try {
      String url = '$baseUrl/patients/$patientId/vitals';
      if (appointmentId != null) {
        url += '?appointment_id=$appointmentId';
      }
      final response = await ApiService.get(url);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching latest vitals: $e');
      return null;
    }
  }

  /// Fetch vitals history for a patient
  Future<List<Map<String, dynamic>>> fetchVitalsHistory(int patientId) async {
    try {
      final url = '$baseUrl/patients/$patientId/vitals-history';
      final response = await ApiService.get(url);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as List<dynamic>;
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching vitals history: $e');
      return [];
    }
  }

  /// Delete a patient by ID
  Future<void> deletePatient(int patientId) async {
    try {
      final response = await ApiService.delete('$baseUrl/patients/$patientId');
      
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to delete patient');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
  /// Save patient insights
  Future<void> savePatientInsights(int patientId, Map<String, String> insights) async {
    try {
      final url = '$baseUrl/patients/$patientId/insights';
      final response = await ApiService.post(
        url,
        {'insights': insights},
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['error'] ?? body['message'] ?? 'Failed to save insights');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch patient insights
  Future<Map<String, dynamic>> fetchPatientInsights(int patientId) async {
    try {
      final response = await ApiService.get('$baseUrl/patients/$patientId/insights');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'] ?? {};
      }
      return {};
    } catch (e) {
      print('Error fetching insights: $e');
      return {};
    }
  }

  /// Fetch patients matching a phone number
  Future<List<PatientModel>> fetchPatientsByPhone(String phone) async {
    try {
      final response = await ApiService.get('$baseUrl/patients/phone/$phone');

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to search patients by phone');
      }

      final body = jsonDecode(response.body);

      if (body is List) {
        return body.map((e) => PatientModel.fromJson(e)).toList();
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}