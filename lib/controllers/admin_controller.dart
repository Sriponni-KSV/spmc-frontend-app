import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AdminController {
  String get baseUrl => dotenv.env['BASE_URL']!;

  Future<void> createStaff({
    required String fullname,
    required String email,
    String? mobile,
    required String password,
    required String role,
    String? medicalLicense,
    int? specializationId,
    String? qualification,
    String? experience,
    int? patientsAttended,
    String? bio,
    List<String>? availableDays,
    String? slotStartTime,
    String? slotEndTime,
    String? slotDuration,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
    String? clinicName,
    String? clinicLocation,
    double? consultationFee,
    String? areasOfExpertise,
  }) async {
    try {
      final response = await ApiService.post(
        '$baseUrl/admin/create',
        {
          "fullname": fullname,
          "email": email,
          "mobile": mobile,
          "password": password,
          "role": role,
          "medical_license": medicalLicense,
          "specialization_id": specializationId,
          "qualification": qualification,
          "experience": experience,
          "patients_attended": patientsAttended,
          "bio": bio,
          "available_days": availableDays,
          "slot_start_time": slotStartTime,
          "slot_end_time": slotEndTime,
          "slot_duration": slotDuration,
          "weekly_off_days": weeklyOffDays,
          "specific_leave_dates": specificLeaveDates,
          "clinic_name": clinicName,
          "clinic_location": clinicLocation,
          "consultation_fee": consultationFee,
          "areas_of_expertise": areasOfExpertise,
        },
      );

    final body = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(body['message'] ?? 'Failed to create staff');
    }
  } catch (e) {
    print("ERROR TYPE: ${e.runtimeType}");
    print("ERROR MESSAGE: $e");
    
    // 3. Throw a clean message for the UI
    throw Exception(e.toString().replaceAll('Exception: ', ''));
  }
}

 Future<List<UserModel>> fetchStaff({String? role, bool showDeleted = false})  async {
    try {
      String url = '$baseUrl/admin/staff?showDeleted=$showDeleted';
      if (role != null && role != 'All') {
        url += '&role=$role';
      }

      final response = await ApiService.get(url);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List data = body['data'] ?? [];
        return data.map((e) => UserModel.fromJson(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch staff');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateStaff({
    required int id,
    required String fullname,
    required String email,
    String? mobile,
    required String role,
    String? status,
    String? medicalLicense,
    int? specializationId,
    String? qualification,
    String? experience,
    int? patientsAttended,
    String? bio,
    List<String>? availableDays,
    String? slotStartTime,
    String? slotEndTime,
    String? slotDuration,
    List<String>? weeklyOffDays,
    List<String>? specificLeaveDates,
    String? clinicName,
    String? clinicLocation,
    double? consultationFee,
    String? areasOfExpertise,
  }) async {
    try {
      final response = await ApiService.put(
        '$baseUrl/admin/staff/$id',
        {
          'fullname': fullname,
          'email': email,
          'mobile': mobile,
          'role': role,
          'status': status,
          'medical_license': medicalLicense,
          'specialization_id': specializationId,
          'qualification': qualification,
          'experience': experience,
          'patients_attended': patientsAttended,
          'bio': bio,
          'available_days': availableDays,
          'slot_start_time': slotStartTime,
          'slot_end_time': slotEndTime,
          'slot_duration': slotDuration,
          'weekly_off_days': weeklyOffDays,
          'specific_leave_dates': specificLeaveDates,
          'clinic_name': clinicName,
          'clinic_location': clinicLocation,
          'consultation_fee': consultationFee,
          'areas_of_expertise': areasOfExpertise,
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update staff');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteStaff(int id) async {
    try {
      final response = await ApiService.delete(
        '$baseUrl/admin/staff/$id',
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete staff');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpecializations() async {
    try {
      final response = await ApiService.get('$baseUrl/admin/specializations');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch specializations');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> fetchRbacData() async {
    try {
      final response = await ApiService.get('$baseUrl/admin/rbac');
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'];
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch RBAC data');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> createRoleRbac(String roleName, String description, List<int> permissionIds) async {
    try {
      final response = await ApiService.post('$baseUrl/admin/rbac/roles', {
        'role_name': roleName,
        'description': description,
        'permission_ids': permissionIds,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 201 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to create role');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateRolePermissions(int roleId, List<int> permissionIds) async {
    try {
      final response = await ApiService.put('$baseUrl/admin/rbac/roles/$roleId', {
        'permission_ids': permissionIds,
      });
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update role permissions');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteRole(int roleId) async {
    try {
      final response = await ApiService.delete('$baseUrl/admin/rbac/roles/$roleId');
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete role');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}