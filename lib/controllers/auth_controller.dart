import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthController {
  String get baseUrl {
    return dotenv.env['BASE_URL'];
  }

// Not in use - signup
  // Future<UserModel?> signup({
  //   required String fullname,
  //   required String email,
  //   required String password,
  //   required String role,
  //   String? medicalLicense,
  //  }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/signup'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'fullname': fullname,
  //         'email': email,
  //         'password': password,
  //         'role': role,
  //         'medical_license': medicalLicense,
  //       }),
  //     );

  //     final data = jsonDecode(response.body);
      
  //     if (response.statusCode == 201) {
  //       return UserModel.fromJson(data['user']);
  //     } else {
  //       throw Exception(data['error'] ?? 'Signup failed');
  //     }
  //   } catch (e) {
  //     throw Exception(e.toString().replaceAll('Exception: ', ''));
  //   }
  // }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception(data['error'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<UserModel>> fetchStaff({String? role}) async {
    try {
      String url = '$baseUrl/admin/staff';
      if (role != null && role != 'All') {
        url += '?role=$role';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = body['data'] ?? [];
        return data.map((item) => UserModel.fromJson(item)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch staff');
      }
    } on FormatException {
      throw Exception('Invalid response from server');
    } on http.ClientException {
      throw Exception('Network error. Please check your connection.');
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
      final response = await http.put(
        Uri.parse('$baseUrl/admin/staff/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullname': fullname,
          'email': email,
          'role': role,
          'medical_license': medicalLicense,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update staff');
      }
    } on FormatException {
      throw Exception('Invalid response from server');
    } on http.ClientException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteStaff(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/staff/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete staff');
      }
    } on FormatException {
      throw Exception('Invalid response from server');
    } on http.ClientException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
