import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class DoctorController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  // ✅ Update Profile
  Future<UserModel> updateProfile({
    required String fullname,
    String? mobile,
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
      '$baseUrl/doctor/update-profile',
      {
        'fullname': fullname,
        'mobile': mobile ?? '',
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
      throw Exception(data['error'] ?? 'Failed to update doctor profile');
    }
  }
}
