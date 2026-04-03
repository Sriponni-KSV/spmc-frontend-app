import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AdminController {
  String get baseUrl => dotenv.env['BASE_URL']!;

Future<void> createStaff({
  required String fullname,
  required String email,
  required String password,
  required String role,
  String? medicalLicense,
   }) async {
   try {
    final response = await ApiService.post(
      '$baseUrl/admin/create',
      {
        "fullname": fullname,
        "email": email,
        "password": password,
        "role": role,
        "medical_license": medicalLicense,
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

 Future<List<UserModel>> fetchStaff({String? role})  async {
    try {
      String url = '$baseUrl/admin/staff';
      if (role != null && role != 'All') {
        url += '?role=$role';
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
    required String role,
    String? medicalLicense,
   }) async {
    try {
      final response = await ApiService.put(
        '$baseUrl/admin/staff/$id',
        {
          'fullname': fullname,
          'email': email,
          'role': role,
          'medical_license': medicalLicense,
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
}