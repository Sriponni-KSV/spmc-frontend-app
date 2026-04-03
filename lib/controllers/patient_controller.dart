import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/patient_model.dart';
import '../services/api_service.dart';

class PatientController {
  String get baseUrl => dotenv.env['BASE_URL']!;

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

  /// Fetch all patients (for future patient list screen)
  Future<List<PatientModel>> fetchPatients() async {
    try {
      final response = await ApiService.get('$baseUrl/patients');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => PatientModel.fromJson(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch patients');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}