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

  // ─── Admin-only Methods ───────────────────────────────────────────────────

  /// Fetch appointments with optional filters (Admin/Super Admin only)
  Future<List<AppointmentModel>> fetchAdminAppointments({
    String? date,
    String? doctor,
    String? status,
    String? department,
  }) async {
    try {
      final params = <String, String>{};
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (doctor != null && doctor.isNotEmpty) params['doctor'] = doctor;
      if (status != null && status != 'All') params['status'] = status;
      if (department != null && department != 'All') params['department'] = department;

      final uri = Uri.parse('$baseUrl/admin-appointments')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await ApiService.get(uri.toString());
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

  /// Admin override: update status, reassign doctor, reschedule
  /// [overrideReason] is mandatory
  Future<void> adminOverrideAppointment({
    required int id,
    String? status,
    String? doctorName,
    String? appointmentDate,
    String? appointmentTime,
    String? patientName,
    String? department,
    String? appointmentType,
    required String overrideReason,
  }) async {
    try {
      final body = <String, dynamic>{
        'override_reason': overrideReason,
      };
      if (status != null) body['status'] = status;
      if (doctorName != null) body['doctor_name'] = doctorName;
      if (appointmentDate != null) body['appointment_date'] = appointmentDate;
      if (appointmentTime != null) body['appointment_time'] = appointmentTime;
      if (patientName != null) body['patient_name'] = patientName;
      if (department != null) body['department'] = department;
      if (appointmentType != null) body['appointment_type'] = appointmentType;

      final response = await ApiService.patch(
        '$baseUrl/admin-appointments/$id/override',
        body,
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
            responseBody['message'] ?? 'Failed to apply admin override');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Fetch a single appointment by ID with audit fields (Admin/Super Admin only)
  Future<AppointmentModel> fetchAdminAppointmentById(int id) async {
    try {
      final response =
          await ApiService.get('$baseUrl/admin-appointments/$id');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return AppointmentModel.fromJson(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch appointment');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
