import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

import '../../config/api_config.dart';

class NurseController {
  String get baseUrl => ApiEndpoints.baseUrl;

  // ✅ Update Profile
  Future<UserModel> updateProfile({
    required String fullname,
    String? mobile,
    String? bio,
    String? qualification,
    String? nursingRegistrationNumber,
    String? yearsOfExperience,
    List<String>? workingDays,
    String? shiftStartTime,
    String? shiftEndTime,
    String? shiftType,
    String? registrationCertificate,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/nurse/update-profile',
      {
        'fullname': fullname,
        'mobile': mobile ?? '',
        'bio': bio ?? '',
        'qualification': qualification ?? '',
        'nursing_registration_number': nursingRegistrationNumber ?? '',
        'years_of_experience': yearsOfExperience ?? '',
        'working_days': workingDays,
        'shift_start_time': shiftStartTime ?? '',
        'shift_end_time': shiftEndTime ?? '',
        'shift_type': shiftType ?? '',
        'registration_certificate': registrationCertificate ?? '',
        'weekly_off_days': weeklyOffDays,
        'specific_leave_dates': specificLeaveDates,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return UserModel.fromJson(data['user']);
    } else {
      throw Exception(data['error'] ?? 'Failed to update nurse profile');
    }
  }
}
