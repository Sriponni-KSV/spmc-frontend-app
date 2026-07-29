import 'dart:convert';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

class RequiresPasswordChangeException implements Exception {
  final String message;
  RequiresPasswordChangeException(this.message);
  @override
  String toString() => message;
}

class AuthController {
  String get baseUrl => ApiEndpoints.baseUrl;

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
      if (data['requiresPasswordChange'] == true) {
        throw RequiresPasswordChangeException(data['message'] ?? 'Password change required');
      }
      await TokenService.saveToken(data['token']);
      return UserModel.fromJson(data['user']);
    } else {
      throw Exception(data['errorCode'] ?? data['error'] ?? 'Login failed');
    }
  }

  // ✅ Forgot Password
  Future<void> forgotPassword(String email) async {
    final response = await ApiService.post(
      '$baseUrl/auth/forgot-password',
      {'email': email},
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'User not found');
    }
  }

  // ✅ Resend OTP
  Future<void> resendOtp(String email) async {
    final response = await ApiService.post(
      '$baseUrl/auth/resend-otp',
      {'email': email},
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to resend OTP');
    }
  }

  // ✅ Verify OTP
  Future<void> verifyOtp(String email, String otp) async {
    final response = await ApiService.post(
      '$baseUrl/auth/verify-otp',
      {
        'email': email,
        'otp': otp,
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Invalid OTP');
    }
  }

  // ✅ Reset Password
  Future<UserModel?> resetPassword({
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['token'] != null && data['user'] != null) {
        await TokenService.saveToken(data['token']);
        return UserModel.fromJson(data['user']);
      }
      return null;
    } else {
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

  // ✅ Fetch current user with fresh profile data from backend
  Future<UserModel?> fetchMe() async {
    try {
      final response = await ApiService.get('$baseUrl/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

}