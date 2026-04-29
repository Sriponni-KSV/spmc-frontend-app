import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/appointment_model.dart';
import '../services/api_service.dart';

class AppointmentController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  Future<List<AppointmentModel>> fetchAppointments() async {
    try {
      final response = await ApiService.get('$baseUrl/appointments');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => AppointmentModel.fromJson(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch appointments');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> bookAppointment(AppointmentModel appointment) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/appointments',
        appointment.toJson(),
      );
      final body = jsonDecode(response.body);

      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to book appointment');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateStatus(int id, String status) async {
    try {
      final response = await ApiService.patch(
        '$baseUrl/appointments/$id/status',
        {'status': status},
      );
      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> saveConsultation(Map<String, dynamic> consultationData) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/appointments/consultation',
        consultationData,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode != 201) {
        throw Exception(body['message'] ?? 'Failed to save consultation');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateConsultation(int consultationId, Map<String, dynamic> consultationData) async {
    try {
      final response = await ApiService.put(
        '$baseUrl/appointments/consultation/$consultationId',
        consultationData,
      );
      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to update consultation');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchConsultationsByPatient(int patientId) async {
    try {
      final response = await ApiService.get('$baseUrl/appointments/consultation/patient/$patientId');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch consultations');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
  Future<List<Map<String, dynamic>>> fetchConsultationsByDoctor(String doctorName) async {
    try {
      final encodedName = Uri.encodeComponent(doctorName);
      final response = await ApiService.get('$baseUrl/appointments/consultation/doctor/$encodedName');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch doctor consultations');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
