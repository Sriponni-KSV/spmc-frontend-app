import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthController {
  String get baseUrl {
    return dotenv.env['BASE_URL'] ?? 'http://192.168.68.100:3000/api/auth';
  }

  Future<UserModel?> signup({
    required String fullname,
    required String email,
    required String password,
    required String role,
    String? medicalLicense,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullname': fullname,
          'email': email,
          'password': password,
          'role': role,
          'medical_license': medicalLicense,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception(data['error'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
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
}
