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


}