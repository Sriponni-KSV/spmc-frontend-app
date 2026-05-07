import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class NurseController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  // ✅ Update Profile
  Future<UserModel> updateProfile({
    required String fullname,
    String? qualification,
    String? nursingRegistrationNumber,
    String? yearsOfExperience,
    List<String>? workingDays,
    String? shiftStartTime,
    String? shiftEndTime,
    String? shiftType,
    String? department,
    String? areasOfExpertise,
    String? registrationCertificate,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
  }) async {
    final response = await ApiService.post(
      '$baseUrl/nurse/update-profile',
      {
        'fullname': fullname,
        'qualification': qualification ?? '',
        'nursing_registration_number': nursingRegistrationNumber ?? '',
        'years_of_experience': yearsOfExperience ?? '',
        'working_days': workingDays,
        'shift_start_time': shiftStartTime ?? '',
        'shift_end_time': shiftEndTime ?? '',
        'shift_type': shiftType ?? '',
        'department': department ?? '',
        'areas_of_expertise': areasOfExpertise ?? '',
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
