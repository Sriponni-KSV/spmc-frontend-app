import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {

  final AuthController _authController = AuthController();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;

  Future<void> refreshPermissions() async {
    if (_user == null) return;
    try {
      final permissionsJson = await _authController.fetchLivePermissions();
      _user = _user!.updateFromPermissions(permissionsJson);
      notifyListeners();
    } catch (e) {
      print('Failed to refresh permissions: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authController.login(
        email: email,
        password: password,
      );

      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      final err = e.toString().replaceFirst('Exception: ', '');
      _errorCode = err;
      
      switch (err) {
        case 'invalid_credentials':
          _errorMessage = 'Invalid email or password.';
          break;
        case 'inactive':
          _errorMessage = 'Your account is currently inactive. Please contact the administrator to regain access.';
          break;
        case 'suspended':
          _errorMessage = 'Your account has been suspended due to policy or security reasons. Please contact support for assistance.';
          break;
        case 'deleted':
          _errorMessage = 'This account is no longer available. Please contact the administrator if you believe this is an error.';
          break;
        default:
          _errorMessage = err.isNotEmpty ? err : 'An unexpected error occurred. Please try again.';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await TokenService.deleteToken();
    _user = null;
    notifyListeners();
  }

  void updateUser(UserModel newUser) {
    _user = newUser;
    notifyListeners();
  }
}