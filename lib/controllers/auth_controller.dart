import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class AuthController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/auth/login',
      {
        'email': email,
        'password': password,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await TokenService.saveToken(data['token']);
      return UserModel.fromJson(data['user']);
    } else {
      throw Exception(data['errorCode'] ?? data['error'] ?? 'Login failed');
    }
  }

  // ✅ Reset Password
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/auth/reset-password',
      {
        'email': email,
        'newPassword': newPassword,
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to reset password');
    }
  }

  // ✅ Fetch Permissions
  Future<List<dynamic>> fetchLivePermissions() async {
    final response = await ApiService.get('$baseUrl/auth/permissions');
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['permissions'] as List<dynamic>;
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch permissions');
    }
  }

  // ✅ Update Profile
  Future<UserModel> updateProfile({
    required String fullname,
    String? medicalLicense,
    String? qualification,
    String? experience,
    String? bio,
    String? patientsAttended,
    List<String>? availableDays,
    String? slotStartTime,
    String? slotEndTime,
    String? slotDuration,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
    String? clinicName,
    String? clinicLocation,
    String? consultationFee,
    String? areasOfExpertise,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/auth/update-profile',
      {
        'fullname': fullname,
        'medical_license': medicalLicense ?? '',
        'qualification': qualification ?? '',
        'experience': experience ?? '',
        'bio': bio ?? '',
        'patients_attended': patientsAttended ?? '',
        'available_days': availableDays,
        'slot_start_time': slotStartTime ?? '',
        'slot_end_time': slotEndTime ?? '',
        'slot_duration': slotDuration ?? '',
        'weekly_off_days': weeklyOffDays,
        'specific_leave_dates': specificLeaveDates,
        'clinic_name': clinicName ?? '',
        'clinic_location': clinicLocation ?? '',
        'consultation_fee': consultationFee ?? '',
        'areas_of_expertise': areasOfExpertise ?? '',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return UserModel.fromJson(data['user']);
    } else {
      throw Exception(data['error'] ?? 'Failed to update profile');
    }
  }
}